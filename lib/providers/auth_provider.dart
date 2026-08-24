import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_role.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/shop_manager.dart';

class AuthProvider extends ChangeNotifier {
  User? user;
  String? shopId;
  AppRole role = AppRole.staff;
  bool initializing = true;
  String? error;

  AuthProvider() {
    AuthService.instance.authStateChanges.listen(_onAuthChanged);
  }

  bool get isOwner => role == AppRole.owner;
  bool get canManageRules => role.canManageRules;
  bool get canManageOperations => role.canManageOperations;
  bool get canViewReports => role.canViewReports;

  Future<void> _onAuthChanged(User? u) async {
    user = u;
    if (u == null) {
      shopId = null;
      role = AppRole.staff;
      ShopManager.shopId = null;
    } else {
      final resolved =
          await FirestoreService.instance.resolveShopForUser(u.uid);
      shopId = resolved.shopId;
      role = resolved.role;
      ShopManager.shopId = shopId;
      if (shopId != null) {
        NotificationService.instance.subscribeToShop();
      }
    }
    initializing = false;
    notifyListeners();
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
    await NotificationService.instance.subscribeToShop();
    notifyListeners();
    return id;
  }

  /// انضمام الحساب الحالي إلى محل قائم عبر كود الانضمام (بدور موظف).
  Future<bool> joinShopByCode(String code) async {
    error = null;
    try {
      await FirestoreService.instance.joinShopByCode(
        uid: user!.uid,
        email: user!.email ?? '',
        code: code,
      );
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
    await NotificationService.instance.unsubscribeFromShop();
    await AuthService.instance.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      AuthService.instance.sendPasswordReset(email);
}
