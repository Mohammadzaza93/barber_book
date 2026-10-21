import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/providers/auth_provider.dart';
import 'package:barber_app/services/firebase_status.dart';
import 'package:barber_app/services/notification_service.dart';
import 'package:barber_app/services/shop_manager.dart';

/// Guards the startup crash reported as
/// `[core/no-app] No Firebase App '[DEFAULT]' has been created`.
///
/// `BarberApp` builds every provider eagerly, and those providers used to
/// resolve `FirebaseAuth.instance` in a field initializer. With no app
/// initialized that threw while the tree was building, so the config error
/// screen could never render.
void main() {
  // No Firebase app/auth stream: these tests drive _applySession directly so
  // an authStateChanges emission cannot mask a hang.
  setUp(() => firebaseReady = false);

  test('AuthProvider constructs without an initialized Firebase app', () {
    firebaseReady = false;
    expect(() => AuthProvider(), returnsNormally);
  });

  test('services can be referenced without an initialized Firebase app', () {
    firebaseReady = false;
    expect(() => NotificationService.instance, returnsNormally);
  });

  group('offline session restore cannot be stranded by notifications', () {
    // Regression guard for the reported bug: with no internet, FCM's
    // subscribeToTopic never completes, which used to leave
    // `_applySession` awaiting the notification side effect forever and kept
    // `initializing == true` (infinite splash = "app does not open").
    test('a never-completing notification subscribe does not strand init',
        () async {
      final auth = AuthProvider(
        resolveShop: (_) async => (shopId: 'shop-A', role: AppRole.admin),
        subscribeShopNotifications: (_) => Completer<bool>().future,
        unsubscribeShopNotifications: (_) async => true,
      );

      await auth.applySessionForTest('A').timeout(const Duration(seconds: 2));

      expect(auth.initializing, isFalse);
      expect(auth.shopId, 'shop-A',
          reason: 'a notification failure must not clear the session');
      expect(auth.role, AppRole.admin);
      expect(ShopManager.shopId, 'shop-A');
    });

    test('a failing notification subscribe does not clear the session',
        () async {
      final auth = AuthProvider(
        resolveShop: (_) async => (shopId: 'shop-A', role: AppRole.admin),
        subscribeShopNotifications: (_) async => throw Exception('fcm down'),
        unsubscribeShopNotifications: (_) async => true,
      );

      await auth.applySessionForTest('A').timeout(const Duration(seconds: 2));

      expect(auth.initializing, isFalse);
      expect(auth.shopId, 'shop-A');
      expect(auth.error, isNull,
          reason: 'notifications are best-effort, not session state');
      expect(auth.role, AppRole.admin);
    });

    test('an unresolvable shop still finishes init with a null session',
        () async {
      final auth = AuthProvider(
        resolveShop: (_) async => (shopId: null, role: AppRole.staff),
        subscribeShopNotifications: (_) => Completer<bool>().future,
        unsubscribeShopNotifications: (_) async => true,
      );

      await auth.applySessionForTest('A').timeout(const Duration(seconds: 2));

      expect(auth.initializing, isFalse);
      expect(auth.shopId, isNull);
      expect(auth.role, AppRole.staff);
    });
  });
}