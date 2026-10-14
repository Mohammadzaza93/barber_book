import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';
import '../services/firebase_status.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/secure_api.dart';
import '../services/shop_manager.dart';

/// Resolves the shop and role for an authenticated uid. Overridable so session
/// transitions can be exercised deterministically without Firebase.
typedef ShopResolver = Future<({String? shopId, AppRole role})> Function(
    String uid);

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    ShopResolver? resolveShop,
    Future<void> Function()? subscribeShopNotifications,
    Future<void> Function()? unsubscribeShopNotifications,
  })  : _resolveShop =
            resolveShop ?? FirestoreService.instance.resolveShopForUser,
        _subscribeShopNotifications =
            subscribeShopNotifications ?? NotificationService.instance.subscribeToShop,
        _unsubscribeShopNotifications = unsubscribeShopNotifications ??
            NotificationService.instance.unsubscribeFromShop {
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
  bool initializing = true;
  String? error;

  final ShopResolver _resolveShop;
  final Future<void> Function() _subscribeShopNotifications;
  final Future<void> Function() _unsubscribeShopNotifications;

  StreamSubscription<User?>? _authSub;

  /// Monotonically increasing token for the latest session transition. A resolve
  /// that completes after a newer transition is discarded, so an old account's
  /// shop/role can never overwrite (or resurrect) the current session.
  int _sessionGeneration = 0;

  bool get isOwner => role == AppRole.owner;
  bool get canManageRules => role.canManageRules;
  bool get canManageOperations => role.canManageOperations;
  bool get canViewReports => role.canViewReports;

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
      if (shopId != null) {
        await _subscribeShopNotifications();
        if (generation != _sessionGeneration) return;
      }
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
    // Best-effort: a failure to unsubscribe must never block sign-out or leave
    // the previous account subscribed to the previous shop's topic.
    try {
      _unsubscribeShopNotifications();
    } catch (e) {
      debugPrint('_clearSession: unsubscribeFromShop failed: $e');
    }
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
      await _subscribeShopNotifications();
      notifyListeners();
      return id;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      rethrow;
    }
  }

  /// انضمام الحساب الحالي إلى محل قائم عبر كود الانضمام (بدور موظف).
  Future<bool> joinShopByCode(String code) async {
    error = null;
    try {
      await SecureApi.instance.joinShopByCode(code);
      final resolved = await _resolveShop(user!.uid);
      shopId = resolved.shopId;
      role = resolved.role;
      ShopManager.shopId = shopId;
      if (shopId != null) {
        await _subscribeShopNotifications();
      }
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _unsubscribeShopNotifications();
    } catch (e) {
      // Unsubscribing is best-effort; a failure here must not block sign-out.
      debugPrint('signOut: unsubscribeFromShop failed: $e');
    }
    try {
      await AuthService.instance.signOut();
    } finally {
      // Clear local state even if Firebase sign-out throws, otherwise the UI
      // keeps rendering the previous shop's data behind the login screen.
      _clearSession();
      error = null;
      initializing = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordReset(String email) =>
      AuthService.instance.sendPasswordReset(email);

  @override
  void dispose() {
    _authSub?.cancel();
    _authSub = null;
    super.dispose();
  }
}
