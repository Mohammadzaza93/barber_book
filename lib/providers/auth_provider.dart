import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../models/staff_permissions.dart';
import '../services/auth_service.dart';
import '../services/firebase_status.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/shop_manager.dart';

/// Resolves the shop and role for an authenticated uid. Overridable so session
/// transitions can be exercised deterministically without Firebase.
typedef ShopResolver = Future<({String? shopId, AppRole role})> Function(
    String uid);

/// Subscribes to / unsubscribes from a shop's FCM topic, given the explicit
/// tenant id. Returns `true` only when the operation completed (see
/// [NotificationService.subscribeToShop]).
typedef ShopTopicOp = Future<bool> Function(String shopId);

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    ShopResolver? resolveShop,
    ShopTopicOp? subscribeShopNotifications,
    ShopTopicOp? unsubscribeShopNotifications,
    Duration topicRetryDelay = const Duration(seconds: 5),
    int maxTopicRetries = 3,
  })  : _resolveShop =
            resolveShop ?? FirestoreService.instance.resolveShopForUser,
        _subscribeShopNotifications = subscribeShopNotifications ??
            NotificationService.instance.subscribeToShop,
        _unsubscribeShopNotifications = unsubscribeShopNotifications ??
            NotificationService.instance.unsubscribeFromShop,
        _topicRetryDelay = topicRetryDelay,
        _maxTopicRetries = maxTopicRetries {
    // When Firebase failed to initialize there is no auth stream to listen to,
    // and touching it here would throw before the config error screen renders.
    if (!firebaseReady) {
      initializing = false;
      return;
    }
    _authSub = AuthService.instance.authStateChanges.listen(
      _onAuthChanged,
      onError: (Object e, StackTrace _) {
        // A failing auth stream must not strand the app on the splash screen.
        error = e.toString();
        initializing = false;
        notifyListeners();
      },
    );
  }

  User? user;
  String? shopId;
  AppRole role = AppRole.staff;
  StaffPermissions _staffPermissions = StaffPermissions.minimal;
  StaffPermissions get permissions =>
      role.isAdmin ? StaffPermissions.all : _staffPermissions;
  bool initializing = true;
  String? error;

  final ShopResolver _resolveShop;
  final ShopTopicOp _subscribeShopNotifications;
  final ShopTopicOp _unsubscribeShopNotifications;

  /// Base delay before an in-session topic reconcile is retried. Injectable so
  /// tests can drive retries with real (short) timers instead of waiting 5s.
  final Duration _topicRetryDelay;

  /// Upper bound on consecutive retries for one desired topic state. A bound
  /// (rather than a periodic loop) means a persistent failure eventually stops
  /// burning battery; the next session transition or connectivity edge still
  /// restarts the process with a fresh budget.
  final int _maxTopicRetries;

  StreamSubscription<User?>? _authSub;

  /// Pending retry of a reconcile that did not settle. Cancelled on dispose and
  /// whenever a newer explicit transition supersedes it.
  Timer? _retryTimer;

  /// Retries already spent for the current desired state (reset by every
  /// explicit [_scheduleTopicReconcile]).
  int _retryAttempt = 0;

  bool _disposed = false;

  /// Monotonically increasing token for the latest session transition. A resolve
  /// that completes after a newer transition is discarded, so an old account's
  /// shop/role can never overwrite (or resurrect) the current session.
  int _sessionGeneration = 0;

  /// The FCM topic this device is *confirmed* to be subscribed to, tracked
  /// independently of `ShopManager.shopId` (which the tenant-switch path resets
  /// before cleanup runs). Set only after `subscribeToShop` reports success and
  /// cleared only after `unsubscribeFromShop` reports success, so the app never
  /// claims a subscription/unsubscription that did not actually happen.
  ///
  /// `null` on a fresh start means "unknown" (the device may still be
  /// subscribed server-side from a previous process); the next reconcile
  /// re-subscribes the current session's shop, which is the safe convergence.
  String? _confirmedTopic;

  /// Serializes every topic subscribe/unsubscribe transition. FCM topic
  /// operations are not cancelable, so ordering them through one FIFO queue is
  /// what prevents a late subscribe for the previous tenant from surviving a
  /// sign-out or a switch (each transition reconciles to the *current* desired
  /// topic instead of appending independent operations).
  Future<void> _topicQueue = Future<void>.value();

  bool get isOwner => role == AppRole.admin;
  bool get canManageRules => role.canManageRules;
  bool get canManageOperations => role.canManageOperations;
  bool get canViewReports => role.canViewReports;

  /// The FCM topic the device is confirmed to be subscribed to, or `null`.
  /// Exposed for diagnostics and tests; never used to derive authorization.
  @visibleForTesting
  String? get confirmedTopic => _confirmedTopic;

  /// Completes when every queued topic transition has finished. Test-only.
  @visibleForTesting
  Future<void> get pendingTopicWork => _topicQueue;

  Future<void> _onAuthChanged(User? u) async {
    user = u;
    await _applySession(u?.uid);
  }

  /// Applies a session transition for [uid] (null = signed out). Every call
  /// bumps [_sessionGeneration]; a late resolve whose generation no longer
  /// matches is dropped, and a null transition clears the session immediately.
  Future<void> _applySession(String? uid) async {
    final generation = ++_sessionGeneration;
    if (uid == null) {
      _clearSession();
      initializing = false;
      notifyListeners();
      return;
    }
    try {
      final resolved = await _resolveShop(uid);
      if (generation != _sessionGeneration) return;
      shopId = resolved.shopId;
      role = resolved.role;
      ShopManager.shopId = shopId;
      // Best-effort side effect: reconciling the shop's FCM topic must never
      // gate the session transition. Offline, FCM's topic subscribe never
      // completes, so awaiting it here stranded the app on the splash screen
      // (initializing stayed true forever). Fire it off instead; a failure is
      // non-fatal and must not clear the session.
      _scheduleTopicReconcile(shopId, guarded: true, generation: generation);
    } catch (e) {
      // Without this guard a Firestore/network failure here rejected the
      // listener's future, left `initializing == true`, and hung the app on
      // the splash screen with no way out.
      if (generation != _sessionGeneration) return;
      error = e.toString();
      shopId = null;
      role = AppRole.staff;
      ShopManager.reset();
    }
    initializing = false;
    notifyListeners();
  }

  /// Test-only entry point that drives the same session-transition logic as the
  /// auth stream, without requiring a Firebase [User]. Never used in production.
  @visibleForTesting
  Future<void> applySessionForTest(String? uid) => _applySession(uid);

  /// Drops every trace of the signed-in session. Called on sign-out and when
  /// Firebase reports no user, so no shop-scoped state survives the transition.
  void _clearSession() {
    shopId = null;
    role = AppRole.staff;
    ShopManager.reset();
    // Reconcile the device to "no shop topic". Enqueued *without* a generation
    // guard so it always runs — even after a newer session begins — and always
    // after any in-flight subscribe, closing the race where a late subscribe
    // for the previous tenant would otherwise survive sign-out. Remote
    // unsubscription stays best-effort and never blocks local cleanup.
    _scheduleTopicReconcile(null, guarded: false);
  }

  /// Enqueues a reconcile-to-[target] transition on the FIFO topic queue.
  ///
  /// When [guarded], the transition is dropped if [generation] is no longer the
  /// current session — so a stale callback cannot (re)subscribe a previous
  /// tenant after a switch or sign-out. This is the *explicit* entry point: it
  /// supersedes any pending retry and restarts the retry budget.
  void _scheduleTopicReconcile(
    String? target, {
    required bool guarded,
    int? generation,
  }) {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
    _enqueueReconcile(target, guarded: guarded, generation: generation);
  }

  void _enqueueReconcile(
    String? target, {
    required bool guarded,
    int? generation,
  }) {
    _topicQueue = _topicQueue.then((_) async {
      if (guarded && generation != _sessionGeneration) return;
      final settled = await _reconcileTopic(target);
      // An unsettled transition means the device may still be subscribed to a
      // previous tenant (unsubscribe failed) or not yet subscribed to the
      // current one (subscribe failed). If the device stays online but no
      // reconnect edge ever fires, nothing else would retry — so retry in
      // process, bounded. Only guarded (current-session) transitions retry;
      // the unguarded sign-out reconcile is covered by the next session or a
      // reconnect edge instead.
      if (!settled && guarded && generation == _sessionGeneration) {
        _scheduleRetry();
      }
    }).catchError((Object e) {
      debugPrint('AuthProvider: topic transition failed: $e');
    });
  }

  /// Schedules one bounded, delayed retry of the current desired topic state.
  ///
  /// Re-reads `shopId` and the session generation when the timer fires, so a
  /// retry enqueued for an old session cannot target a newer tenant.
  void _scheduleRetry() {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = null;
    if (_retryAttempt >= _maxTopicRetries) {
      debugPrint('AuthProvider: giving up topic reconcile after '
          '$_retryAttempt retries; will retry on the next session or '
          'connectivity change');
      return;
    }
    _retryAttempt++;
    final delay = _topicRetryDelay * _retryAttempt;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (_disposed) return;
      _enqueueReconcile(shopId, guarded: true, generation: _sessionGeneration);
    });
  }

  /// Converges the confirmed subscription to [target] (null = none).
  ///
  /// Unsubscribes any previously confirmed topic that differs from [target]
  /// first, and only then subscribes [target]. If the unsubscribe does not
  /// complete, the new subscription is deferred: staying subscribed to the old
  /// tenant is preferable to being subscribed to two tenants at once
  /// (cross-tenant push leakage). A later reconcile retries the whole step.
  ///
  /// Returns `true` when the device has converged to [target] (nothing further
  /// to do), or `false` when the state is still unsettled and a retry is
  /// warranted.
  Future<bool> _reconcileTopic(String? target) async {
    final previous = _confirmedTopic;
    if (previous != null && previous != target) {
      final removed = await _unsubscribeShopNotifications(previous);
      if (!removed) {
        debugPrint('AuthProvider: could not unsubscribe from $previous; '
            'deferring subscription to $target to avoid cross-tenant delivery');
        return false;
      }
      if (_confirmedTopic == previous) _confirmedTopic = null;
    }
    if (target != null && _confirmedTopic != target) {
      final subscribed = await _subscribeShopNotifications(target);
      if (subscribed) {
        _confirmedTopic = target;
      } else {
        return false;
      }
    }
    return true;
  }

  /// Reconciles the FCM topic for the *current* validated session. Called when
  /// connectivity is restored (see [ConnectionProvider]) so a subscription that
  /// timed out while offline is re-established. Re-reads `shopId` and the
  /// session generation at call time, so a stale reconnect cannot target a
  /// previous tenant, and no-ops while already subscribed.
  void reconcileShopTopic() {
    _scheduleTopicReconcile(shopId, guarded: true, generation: _sessionGeneration);
  }

  Future<bool> signIn(String email, String password) async {
    error = null;
    try {
      await AuthService.instance.signIn(email, password);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> register(String email, String password) async {
    error = null;
    try {
      await AuthService.instance.register(email, password);
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<String> createShop({
    required String shopName,
    required String phone,
    required String address,
    required String currency,
    String? primaryColorHex,
    String? accentColorHex,
  }) async {
    error = null;
    try {
      final uid = user!.uid;
      final id = await FirestoreService.instance.createShop(
        ownerId: uid,
        shopName: shopName,
        phone: phone,
        address: address,
        currency: currency,
        primaryColorHex: primaryColorHex,
        accentColorHex: accentColorHex,
      );
      shopId = id;
      ShopManager.shopId = id;
      // Re-resolve instead of assuming the role: firestore.rules derives owner
      // server-side, so the client's role must come from that same source.
      final resolved = await _resolveShop(uid);
      role = resolved.role;
      await _loadStaffPermissions(id, uid, user?.email);
      _scheduleTopicReconcile(id, guarded: true, generation: _sessionGeneration);
      notifyListeners();
      return id;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// انضمام الحساب الحالي إلى محل قائم: لم يعد هناك كود انضمام — Membership
  /// now happens only when an admin adds the account by email.
  Future<bool> joinShopByCode(String code) async {
    error = 'join-code-removed';
    notifyListeners();
    return false;
  }

  Future<void> signOut() async {
    try {
      await AuthService.instance.signOut();
    } catch (e) {
      debugPrint('signOut: Firebase sign-out failed: $e');
    } finally {
      // Clear local state even if Firebase sign-out throws, otherwise the UI
      // keeps rendering the previous shop's data behind the login screen.
      // `_applySession(null)` bumps the generation immediately (invalidating
      // any pending transition) and enqueues a best-effort unsubscribe on the
      // topic queue, so local sign-out never waits on FCM reaching the network.
      error = null;
      await _applySession(null);
    }
  }

  Future<void> _loadStaffPermissions(
      String shopId, String uid, String? email) async {
    if (role.isAdmin) {
      _staffPermissions = StaffPermissions.all;
      notifyListeners();
      return;
    }
    try {
      final db = FirebaseFirestore.instance;
      var snap = await db
          .collection('shops')
          .doc(shopId)
          .collection('employees')
          .where('authUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (snap.docs.isEmpty && email != null && email.isNotEmpty) {
        snap = await db
            .collection('shops')
            .doc(shopId)
            .collection('employees')
            .where('email', isEqualTo: email.toLowerCase())
            .limit(1)
            .get();
      }
      if (snap.docs.isNotEmpty) {
        final data = snap.docs.first.data();
        _staffPermissions = StaffPermissions.fromMap(
            data['permissions'] as Map<String, dynamic>?);
      } else {
        _staffPermissions = StaffPermissions.minimal;
      }
    } catch (e) {
      _staffPermissions = StaffPermissions.minimal;
    }
    notifyListeners();
  }

  Future<void> sendPasswordReset(String email) =>
      AuthService.instance.sendPasswordReset(email);

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }
}
