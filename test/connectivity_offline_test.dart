import 'dart:async';

import 'package:barber_app/providers/connection_provider.dart';
import 'package:barber_app/services/connectivity_source.dart';
import 'package:barber_app/widgets/connection_banner.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A [ConnectivitySource] with a hand-driven stream so the provider's state
/// machine can be exercised without the platform plugin.
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

void main() {
  group('hasConnection', () {
    test('is false only when the sole result is none', () {
      expect(hasConnection([ConnectivityResult.none]), isFalse);
      expect(hasConnection([ConnectivityResult.wifi]), isTrue);
      expect(
        hasConnection([ConnectivityResult.none, ConnectivityResult.mobile]),
        isTrue,
      );
    });
  });

  group('ConnectionProvider', () {
    test('starts offline when no interface is available', () async {
      final source = _FakeConnectivitySource([ConnectivityResult.none]);
      final provider = ConnectionProvider(
        source: source,
        flushPendingWrites: () async {},
      );
      addTearDown(provider.dispose);
      addTearDown(source.close);

      await provider.start();
      expect(provider.status, SyncStatus.offline);
      expect(provider.isOffline, isTrue);
    });

    test('reports syncing then online after regaining connectivity', () async {
      final source = _FakeConnectivitySource([ConnectivityResult.none]);
      final flush = Completer<void>();
      final provider = ConnectionProvider(
        source: source,
        flushPendingWrites: () => flush.future,
      );
      addTearDown(provider.dispose);
      addTearDown(source.close);

      await provider.start();
      expect(provider.status, SyncStatus.offline);

      source.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, SyncStatus.syncing);

      flush.complete();
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, SyncStatus.online);
    });

    test('surfaces syncError when the flush fails, then recovers', () async {
      final source = _FakeConnectivitySource([ConnectivityResult.none]);
      var attempts = 0;
      final provider = ConnectionProvider(
        source: source,
        flushPendingWrites: () async {
          attempts++;
          if (attempts == 1) throw StateError('rejected');
        },
      );
      addTearDown(provider.dispose);
      addTearDown(source.close);

      await provider.start();
      source.emit([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, SyncStatus.syncError);

      // A later connectivity change retries the flush and clears the error.
      source.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, SyncStatus.online);
    });

    test('does not re-flush on unrelated interface changes while online',
        () async {
      final source = _FakeConnectivitySource([ConnectivityResult.wifi]);
      var flushes = 0;
      final provider = ConnectionProvider(
        source: source,
        flushPendingWrites: () async => flushes++,
      );
      addTearDown(provider.dispose);
      addTearDown(source.close);

      await provider.start();
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, SyncStatus.online);
      expect(flushes, 1);

      source.emit([ConnectivityResult.mobile]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, SyncStatus.online);
      expect(flushes, 1, reason: 'still connected; no new flush expected');
    });

    test('ignores events after dispose', () async {
      final source = _FakeConnectivitySource([ConnectivityResult.none]);
      final provider = ConnectionProvider(
        source: source,
        flushPendingWrites: () async {},
      );

      await provider.start();
      provider.dispose();
      source.emit([ConnectivityResult.wifi]);
      await Future<void>.delayed(Duration.zero);
      expect(provider.status, SyncStatus.offline);
      await source.close();
    });
  });

  group('ConnectionBanner', () {
    testWidgets('renders the offline message when offline', (tester) async {
      final source = _FakeConnectivitySource([ConnectivityResult.none]);
      final provider = ConnectionProvider(
        source: source,
        flushPendingWrites: () async {},
      );
      addTearDown(provider.dispose);
      addTearDown(source.close);
      await provider.start();

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionProvider>.value(
          value: provider,
          child: const MaterialApp(
            locale: Locale('ar'),
            supportedLocales: [Locale('ar'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: ConnectionBanner()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
    });

    testWidgets('renders nothing when online', (tester) async {
      final source = _FakeConnectivitySource([ConnectivityResult.wifi]);
      final provider = ConnectionProvider(
        source: source,
        flushPendingWrites: () async {},
      );
      addTearDown(provider.dispose);
      addTearDown(source.close);
      await provider.start();

      await tester.pumpWidget(
        ChangeNotifierProvider<ConnectionProvider>.value(
          value: provider,
          child: const MaterialApp(
            locale: Locale('ar'),
            supportedLocales: [Locale('ar'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: ConnectionBanner()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(Icon), findsNothing);
    });
  });
}
