import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';
import '../services/shop_manager.dart';

class AuthProvider extends ChangeNotifier {
  User? user;
  String? shopId;
  bool initializing = true;
  String? error;

  AuthProvider() {
    AuthService.instance.authStateChanges.listen(_onAuthChanged);
  }

  Future<void> _onAuthChanged(User? u) async {
    user = u;
    if (u == null) {
      shopId = null;
      ShopManager.shopId = null;
    } else {
      shopId = await FirestoreService.instance.findShopByOwner(u.uid);
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

  Future<void> signOut() async {
    await NotificationService.instance.unsubscribeFromShop();
    await AuthService.instance.signOut();
  }

  Future<void> sendPasswordReset(String email) =>
      AuthService.instance.sendPasswordReset(email);
}
