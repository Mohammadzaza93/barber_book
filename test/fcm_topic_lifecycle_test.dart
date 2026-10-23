import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/providers/auth_provider.dart';
import 'package:barber_app/providers/connection_provider.dart';
import 'package:barber_app/services/connectivity_source.dart';
import 'package:barber_app/services/firebase_status.dart';
import 'package:barber_app/services/shop_manager.dart';

/// PHASE 4.7 — FCM topic lifecycle, reconnect recovery, and race coverage.
///
/// Every scenario below is deterministic: the FCM layer is replaced by
/// [_FakeTopics] and connectivity by [_FakeConnectivitySource], so no test
/// touches Firebase or the real network.

typedef _Resolved = ({String? shopId, AppRole role});

/// Deterministic stand-in for the topic subscribe/unsubscribe operations.
///
/// Records every call (and its order via [events]) and can hold operations open
/// with `Completer`s to model in-flight work, timeouts, and late completion.
class _FakeTopics {
  bool subscribeResult = true;
  bool unsubscribeResult = true;

  /// When true ops complete immediately; when false they return a `Completer`
  /// the test must complete explicitly.
  bool autoComplete = true;

  final List<String> subscribeCalls = <String>[];
  final List<String> unsubscribeCalls = <String>[];

  /// Interleaved call log, e.g. `sub:shop-A`, `unsub:shop-A`.
  final List<String> events = <String>[];

  final Map<String, Completer<bool>> _pendingSubscribes = {};
  final Map<String, Completer<bool>> _pendingUnsubscribes = {};

  Future<bool> subscribe(String shopId) {
    subscribeCalls.add(shopId);
    events.add('sub:$shopId');
    if (autoComplete) return Future<bool>.value(subscribeResult);
    final completer = Completer<bool>();
    _pendingSubscribes[shopId] = completer;
    return completer.future;
  }

  Future<bool> unsubscribe(String shopId) {
    unsubscribeCalls.add(shopId);
    events.add('unsub:$shopId');
    if (autoComplete) return Future<bool>.value(unsubscribeResult);
    final completer = Completer<bool>();
    _pendingUnsubscribes[shopId] = completer;
    return completer.future;
  }

  /// Completes a held subscribe if one is pending; harmless otherwise.
  void completeSubscribe(String shopId, [bool value = true]) {
    final completer = _pendingSubscribes.remove(shopId);
    if (completer != null && !completer.isCompleted) completer.complete(value);
  }

  /// Completes a held unsubscribe if one is pending; harmless otherwise.
  void completeUnsubscribe(String shopId, [bool value = true]) {
    final completer = _pendingUnsubscribes.remove(shopId);
    if (completer != null && !completer.isCompleted) completer.complete(value);
  }
}

/// Hand-driven [ConnectivitySource] mirroring the one used by the PHASE 4.5
/// suite, so the reconnect edge can be triggered without the platform plugin.
class _FakeConnectivitySource implements ConnectivitySource {
  _FakeConnectivitySource(this.initial);

  final List<ConnectivityResult> initial;
  final StreamController<List<ConnectivityResult>> _controller =
      StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> check() async => initial;

  @override
  Stream<List<ConnectivityResult>> get changes => _controller.stream;

  void emit(List<ConnectivityResult> results) => _controller.add(results);

  Future<void> close() => _controller.close();
}

AuthProvider _auth(
  _FakeTopics fake, {
  _Resolved Function(String uid)? resolve,
  Duration topicRetryDelay = const Duration(seconds: 5),
  int maxTopicRetries = 3,
}) {
  final auth = AuthProvider(
    resolveShop: (uid) async =>
        resolve?.call(uid) ?? (shopId: 'shop-$uid', role: AppRole.admin),
    subscribeShopNotifications: fake.subscribe,
    unsubscribeShopNotifications: fake.unsubscribe,
    topicRetryDelay: topicRetryDelay,
    maxTopicRetries: maxTopicRetries,
  );
  // Guarantees any pending retry timer is cancelled when the test ends.
  addTearDown(auth.dispose);
  return auth;
}

/// Lets the FIFO topic queue drain, including transitions appended by
/// completing a held `Completer`.
Future<void> _drain(AuthProvider auth) async {
  for (var i = 0; i < 8; i++) {
    await auth.pendingTopicWork;
    await Future<void>.delayed(Duration.zero);
  }
}

/// Yields until [predicate] holds, letting queued transitions start. Fails the
/// test if it never becomes true, so a hang is reported as a failure.
Future<void> _until(bool Function() predicate) async {
  for (var i = 0; i < 200 && !predicate(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(predicate(), isTrue, reason: 'condition was never reached');
}

/// Waits on the *real* clock until [predicate] holds (used for bounded retries
/// that are driven by actual `Timer`s).
Future<void> _waitFor(
  bool Function() predicate, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!predicate() && DateTime.now().isBefore(deadline)) {
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  expect(predicate(), isTrue, reason: 'condition was never reached in time');
}

void main() {
  setUp(() {
    firebaseReady = false;
    ShopManager.reset();
  });

  group('Group A — topic lifecycle', () {
    test('A1 subscribes to the session shop and confirms it', () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);

      expect(fake.subscribeCalls, ['shop-A']);
      expect(auth.confirmedTopic, 'shop-A');
    });

    test('A2 a Shop A -> Shop B transition unsubscribes A then subscribes B',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      await auth.applySessionForTest('B');
      await _drain(auth);

      expect(fake.events, ['sub:shop-A', 'unsub:shop-A', 'sub:shop-B']);
      expect(auth.confirmedTopic, 'shop-B');
    });

    test('A3 sign-out after subscribing to A unsubscribes A', () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      await auth.applySessionForTest(null);
      await _drain(auth);

      expect(fake.unsubscribeCalls, ['shop-A']);
      expect(auth.confirmedTopic, isNull);
    });

    test('A4 auth-stream sign-out (same _applySession(null) path) cleans up',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      // The auth stream calls exactly this path when it emits a null user.
      await auth.applySessionForTest(null);
      await _drain(auth);

      expect(fake.subscribeCalls, ['shop-A']);
      expect(fake.unsubscribeCalls, ['shop-A']);
      expect(auth.confirmedTopic, isNull);
      expect(ShopManager.shopId, isNull);
    });

    test('A5 re-authentication to the same shop re-subscribes', () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      await auth.applySessionForTest(null);
      await _drain(auth);
      await auth.applySessionForTest('A');
      await _drain(auth);

      expect(fake.subscribeCalls, ['shop-A', 'shop-A']);
      expect(auth.confirmedTopic, 'shop-A');
    });

    test('A6 switching shops offline keeps the old topic until it is removed',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      expect(auth.confirmedTopic, 'shop-A');

      // Offline: both ops time out/fail.
      fake.subscribeResult = false;
      fake.unsubscribeResult = false;
      await auth.applySessionForTest('B');
      await _drain(auth);

      expect(fake.unsubscribeCalls, ['shop-A']);
      expect(fake.subscribeCalls, ['shop-A'],
          reason: 'must not subscribe B while still subscribed to A');
      expect(auth.confirmedTopic, 'shop-A',
          reason: 'A was not confirmed removed, so tracking stays honest');
    });

    test('A7 unsubscribe failure does not clear local session', () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      fake.unsubscribeResult = false;
      await auth.applySessionForTest(null);
      await _drain(auth);

      expect(auth.shopId, isNull, reason: 'local sign-out must still complete');
      expect(auth.initializing, isFalse);
      expect(auth.confirmedTopic, 'shop-A',
          reason: 'a failed unsubscribe is not proof of removal');
    });

    test('A8 subscribe failure is non-fatal and leaves the session intact',
        () async {
      final fake = _FakeTopics()..subscribeResult = false;
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);

      expect(fake.subscribeCalls, ['shop-A']);
      expect(auth.shopId, 'shop-A');
      expect(auth.error, isNull);
      expect(auth.confirmedTopic, isNull);
    });

    test('A9 unknown initial state converges by subscribing the session shop',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      expect(auth.confirmedTopic, isNull, reason: 'unknown after startup');

      await auth.applySessionForTest('A');
      await _drain(auth);

      expect(auth.confirmedTopic, 'shop-A');
    });
  });

  group('Group B — reconnect recovery', () {
    test('B1 offline->online reconciles the current shop', () async {
      final source = _FakeConnectivitySource([ConnectivityResult.none]);
      final fake = _FakeTopics()..subscribeResult = false; // offline
      final auth = _auth(fake);
      addTearDown(source.close);

      await auth.applySessionForTest('A');
      await _drain(auth);
      expect(auth.confirmedTopic, isNull, reason: 'subscribe failed offline');

      final conn = ConnectionProvider(
        source: source,
        flushPendingWrites: () async {},
        onReconnected: auth.reconcileShopTopic,
      );
      addTearDown(conn.dispose);
      await conn.start();
      expect(conn.status, SyncStatus.offline);

      fake.subscribeResult = true; // network is back
      source.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      await _drain(auth);

      expect(fake.subscribeCalls, ['shop-A', 'shop-A']);
      expect(auth.confirmedTopic, 'shop-A');
    });

    test('B2 reconnect while signed out triggers no subscription', () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      await auth.applySessionForTest(null);
      await _drain(auth);
      fake.subscribeCalls.clear();

      auth.reconcileShopTopic();
      await _drain(auth);

      expect(fake.subscribeCalls, isEmpty);
      expect(auth.confirmedTopic, isNull);
    });

    test('B3 reconnect with an unknown shop triggers no subscription',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(
        fake,
        resolve: (_) => (shopId: null, role: AppRole.staff),
      );

      await auth.applySessionForTest('A');
      await _drain(auth);

      auth.reconcileShopTopic();
      await _drain(auth);

      expect(fake.subscribeCalls, isEmpty);
      expect(auth.confirmedTopic, isNull);
    });

    test('B4 duplicate connectivity events do not duplicate recovery',
        () async {
      final source = _FakeConnectivitySource([ConnectivityResult.none]);
      var recovered = 0;
      final conn = ConnectionProvider(
        source: source,
        flushPendingWrites: () async {},
        onReconnected: () => recovered++,
      );
      addTearDown(conn.dispose);
      addTearDown(source.close);

      await conn.start();
      source.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(recovered, 1);

      // While already online, further interface events must not re-recover.
      source.emit([ConnectivityResult.mobile]);
      source.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(recovered, 1);
    });

    test('B5 a failed subscription is retried on the next reconcile', () async {
      final fake = _FakeTopics()..subscribeResult = false;
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      expect(auth.confirmedTopic, isNull);

      fake.subscribeResult = true;
      auth.reconcileShopTopic();
      await _drain(auth);

      expect(fake.subscribeCalls, ['shop-A', 'shop-A']);
      expect(auth.confirmedTopic, 'shop-A');
    });

    test('B6 reconnect after an offline switch targets only the current shop',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);

      // Offline switch A -> B: both ops fail, so A stays confirmed.
      fake.subscribeResult = false;
      fake.unsubscribeResult = false;
      await auth.applySessionForTest('B');
      await _drain(auth);
      expect(auth.confirmedTopic, 'shop-A');

      // Reconnect: remove A, then subscribe B.
      fake.subscribeResult = true;
      fake.unsubscribeResult = true;
      auth.reconcileShopTopic();
      await _drain(auth);

      // The offline switch already tried (and failed) to remove A; the
      // reconnect retries that removal and then subscribes B.
      expect(fake.events, [
        'sub:shop-A',
        'unsub:shop-A',
        'unsub:shop-A',
        'sub:shop-B',
      ]);
      expect(auth.confirmedTopic, 'shop-B');
    });
  });

  group('Group C — race conditions', () {
    test('C1 a pending A subscribe cannot survive a switch to B', () async {
      final fake = _FakeTopics()..autoComplete = false;
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      // Ensure A's subscribe is actually in flight before switching.
      await _until(() => fake.subscribeCalls.contains('shop-A'));
      await auth.applySessionForTest('B'); // queued behind the in-flight sub

      fake.autoComplete = true;
      fake.completeSubscribe('shop-A');
      await _drain(auth);

      expect(fake.events, ['sub:shop-A', 'unsub:shop-A', 'sub:shop-B']);
      expect(auth.confirmedTopic, 'shop-B');
    });

    test('C2 a pending subscribe is cleaned up by sign-out', () async {
      final fake = _FakeTopics()..autoComplete = false;
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _until(() => fake.subscribeCalls.contains('shop-A'));
      await auth.applySessionForTest(null); // sign-out queued

      fake.autoComplete = true;
      fake.completeSubscribe('shop-A');
      await _drain(auth);

      expect(fake.unsubscribeCalls, ['shop-A']);
      expect(auth.confirmedTopic, isNull);
      expect(auth.shopId, isNull);
    });

    test('C3 a new subscribe does not begin until the unsubscribe completes',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);

      // Freeze the unsubscribe so the A -> B transitions is in flight.
      fake.autoComplete = false;
      await auth.applySessionForTest('B');
      await _until(() => fake.unsubscribeCalls.contains('shop-A'));
      // A concurrent reconcile (as a reconnect would issue) must queue, not
      // interleave and start B early.
      auth.reconcileShopTopic();

      fake.autoComplete = true;
      fake.completeUnsubscribe('shop-A');
      await _drain(auth);

      final unsubIndex = fake.events.indexOf('unsub:shop-A');
      final subBIndex = fake.events.indexOf('sub:shop-B');
      expect(unsubIndex, greaterThanOrEqualTo(0));
      expect(subBIndex, greaterThan(unsubIndex),
          reason: 'B must not be subscribed before A is unsubscribed');
      expect(auth.confirmedTopic, 'shop-B');
    });

    test('C4 a late A subscribe is corrected when re-login targets C', () async {
      final fake = _FakeTopics()..autoComplete = false;
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _until(() => fake.subscribeCalls.contains('shop-A')); // A in flight
      await auth.applySessionForTest(null); // gen2 clear queued
      await auth.applySessionForTest('C'); // gen3 reconcile queued

      fake.autoComplete = true;
      fake.completeSubscribe('shop-A');
      await _drain(auth);

      expect(fake.unsubscribeCalls, contains('shop-A'),
          reason: 'the late A subscribe must be undone');
      expect(auth.confirmedTopic, 'shop-C');
    });

    test('C5 a stale callback cannot change the active topic', () async {
      final fake = _FakeTopics()..autoComplete = false;
      final auth = _auth(fake);

      // A subscribe is in flight for gen1.
      await auth.applySessionForTest('A');
      await _until(() => fake.subscribeCalls.contains('shop-A'));

      // The session moves on to B while A is still pending.
      await auth.applySessionForTest('B');

      // A's completer fires after B has become the current session.
      fake.autoComplete = true;
      fake.completeSubscribe('shop-A');
      await _drain(auth);

      expect(auth.confirmedTopic, 'shop-B',
          reason: 'a stale completion must not clobber the current topic');
      expect(auth.shopId, 'shop-B');
    });

    test('C6 a timed-out subscribe is retried, not treated as definitive',
        () async {
      final fake = _FakeTopics()..subscribeResult = false; // "timeout"
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _drain(auth);
      expect(auth.confirmedTopic, isNull,
          reason: 'a timeout is not proof of success OR failure');

      // The later retry (here standing in for the reconnect reconcile) lands.
      fake.subscribeResult = true;
      auth.reconcileShopTopic();
      await _drain(auth);

      expect(auth.confirmedTopic, 'shop-A');
      expect(fake.subscribeCalls, ['shop-A', 'shop-A']);
    });

    test('C7 duplicate reconciles while subscribing do not double-subscribe',
        () async {
      final fake = _FakeTopics()..autoComplete = false;
      final auth = _auth(fake);

      await auth.applySessionForTest('A');
      await _until(() => fake.subscribeCalls.contains('shop-A'));
      // Further reconciles before the first subscribe confirms must coalesce.
      auth.reconcileShopTopic();
      auth.reconcileShopTopic();

      fake.autoComplete = true;
      fake.completeSubscribe('shop-A');
      await _drain(auth);

      expect(fake.subscribeCalls, ['shop-A']);
      expect(auth.confirmedTopic, 'shop-A');
    });
  });

  group('Group D — regression: startup is never gated by FCM', () {
    test('a never-completing subscribe does not stall session init', () async {
      final auth = AuthProvider(
        resolveShop: (_) async => (shopId: 'shop-A', role: AppRole.admin),
        subscribeShopNotifications: (_) => Completer<bool>().future,
        unsubscribeShopNotifications: (_) async => true,
      );

      await auth.applySessionForTest('A').timeout(const Duration(seconds: 2));

      expect(auth.initializing, isFalse);
      expect(auth.shopId, 'shop-A');
      expect(auth.confirmedTopic, isNull);
      auth.dispose();
    });
  });

  group('Group E — bounded in-session retry (no reconnect edge)', () {
    const fast = Duration(milliseconds: 10);

    test('E1 a deferred tenant switch converges without a reconnect edge',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(fake, topicRetryDelay: fast);

      await auth.applySessionForTest('A');
      await _drain(auth);
      expect(auth.confirmedTopic, 'shop-A');

      // Offline switch: the unsubscribe fails, so the new subscription is
      // deferred and a retry is scheduled — even though connectivity never
      // reports an offline->online edge here.
      fake.unsubscribeResult = false;
      await auth.applySessionForTest('B');
      await _drain(auth);
      expect(auth.confirmedTopic, 'shop-A',
          reason: 'A must remain confirmed until it is provably removed');

      // Network recovers; the pending retry alone (no manual reconcile) must
      // finish the switch.
      fake.unsubscribeResult = true;
      fake.subscribeResult = true;
      await _waitFor(() => auth.confirmedTopic == 'shop-B');

      expect(auth.confirmedTopic, 'shop-B');
      expect(fake.events, [
        'sub:shop-A',
        'unsub:shop-A',
        'unsub:shop-A',
        'sub:shop-B',
      ]);
    });

    test('E2 a persistently failing reconcile retries a bounded number of times',
        () async {
      final fake = _FakeTopics();
      final auth = _auth(fake, topicRetryDelay: fast, maxTopicRetries: 2);

      await auth.applySessionForTest('A');
      await _drain(auth);

      // Every unsubscribe attempt fails from here on: the device stays on A
      // and each retry re-attempts removal, then gives up after the bound.
      fake.unsubscribeResult = false;
      await auth.applySessionForTest('B');
      await _drain(auth);

      await _waitFor(() => fake.unsubscribeCalls.length >= 3);
      final attempts = fake.unsubscribeCalls.length;
      expect(attempts, 3,
          reason: '1 switch attempt + exactly maxTopicRetries(2) retries');

      // After giving up, no further attempts are made.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(fake.unsubscribeCalls.length, attempts);
      expect(auth.confirmedTopic, 'shop-A');
    });

    test('E3 a transient subscribe failure is retried and then confirmed',
        () async {
      final fake = _FakeTopics()..subscribeResult = false; // "timeout" once
      final auth = _auth(fake, topicRetryDelay: fast);

      await auth.applySessionForTest('A');
      await _drain(auth);
      expect(auth.confirmedTopic, isNull);

      fake.subscribeResult = true;
      await _waitFor(() => auth.confirmedTopic == 'shop-A');

      expect(auth.confirmedTopic, 'shop-A');
      expect(fake.subscribeCalls, ['shop-A', 'shop-A']);
    });

    test('E4 dispose cancels a pending retry', () async {
      final fake = _FakeTopics();
      final auth = _auth(fake, topicRetryDelay: fast);

      await auth.applySessionForTest('A');
      await _drain(auth);

      fake.unsubscribeResult = false; // schedule a retry that will never land
      await auth.applySessionForTest('B');
      await _drain(auth);
      expect(fake.unsubscribeCalls, ['shop-A']);

      auth.dispose();

      // Any surviving timer would reconcile to the current shop; make the
      // operation succeed so it would be observable if it ran.
      fake.unsubscribeResult = true;
      fake.subscribeResult = true;
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(fake.unsubscribeCalls, ['shop-A'],
          reason: 'a disposed provider must not run its retry');
      expect(fake.subscribeCalls, ['shop-A']);
    });
  });
}
