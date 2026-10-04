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

class AuthProvider extends ChangeNotifier {
  User? user;
  String? shopId;
  AppRole role = AppRole.staff;
  bool initializing = true;
  String? error;

  StreamSubscription<User?>? _authSub;

  AuthProvider() {
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

  bool get isOwner => role == AppRole.owner;
  bool get canManageRules => role.canManageRules;
  bool get canManageOperations => role.canManageOperations;
  bool get canViewReports => role.canViewReports;

  Future<void> _onAuthChanged(User? u) async {
    user = u;
    if (u == null) {
      _clearSession();
    } else {
      try {
        final resolved =
            await FirestoreService.instance.resolveShopForUser(u.uid);
        shopId = resolved.shopId;
        role = resolved.role;
        ShopManager.shopId = shopId;
        if (shopId != null) {
          await NotificationService.instance.subscribeToShop();
        }
      } catch (e) {
        // Without this guard a Firestore/network failure here rejected the
        // listener's future, left `initializing == true`, and hung the app on
        // the splash screen with no way out.
        error = e.toString();
        shopId = null;
        role = AppRole.staff;
        ShopManager.shopId = null;
      }
    }
    initializing = false;
    notifyListeners();
  }

  /// Drops every trace of the signed-in session. Called on sign-out and when
  /// Firebase reports no user, so no shop-scoped state survives the transition.
  void _clearSession() {
    shopId = null;
    role = AppRole.staff;
    ShopManager.shopId = null;
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
      final resolved = await FirestoreService.instance.resolveShopForUser(uid);
      role = resolved.role;
      await NotificationService.instance.subscribeToShop();
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
      final resolved =
          await FirestoreService.instance.resolveShopForUser(user!.uid);
      shopId = resolved.shopId;
      role = resolved.role;
      ShopManager.shopId = shopId;
      if (shopId != null) {
        await NotificationService.instance.subscribeToShop();
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
      await NotificationService.instance.unsubscribeFromShop();
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
