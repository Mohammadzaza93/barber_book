import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/models/booking_settings.dart';
import 'package:barber_app/providers/business_tools_provider.dart';
import 'package:barber_app/providers/discount_provider.dart';
import 'package:barber_app/providers/feedback_provider.dart';
import 'package:barber_app/screens/admin/admin_home_screen.dart';
import 'package:barber_app/services/shop_manager.dart';

void main() {
  group('adminTabVisible (AUTH-001)', () {
    test('admin sees every admin tab', () {
      for (var i = 0; i <= 11; i++) {
        expect(adminTabVisible(AppRole.admin, i), isTrue, reason: 'tab $i');
      }
    });

    test('staff sees only operational tabs and their own profile', () {
      // appointments(1), profile(10) after expenses tab removal
      const allowed = {1, 10};
      for (var i = 0; i <= 11; i++) {
        expect(adminTabVisible(AppRole.staff, i), allowed.contains(i),
            reason: 'tab $i');
      }
    });

    test('staff cannot reach admin-only tabs', () {
      for (final tab in const [0, 2, 3, 4, 5, 6, 7, 8, 9, 11]) {
        expect(adminTabVisible(AppRole.staff, tab), isFalse,
            reason: 'tab $tab');
      }
    });
  });

  group('canSyncCustomerProfiles (AUTH-002)', () {
    test('admin may sync customer profiles', () {
      expect(canSyncCustomerProfiles(AppRole.admin), isTrue);
    });

    test('staff may not sync customer profiles', () {
      expect(canSyncCustomerProfiles(AppRole.staff), isFalse);
    });

    test('unknown role preserves legacy behaviour', () {
      expect(canSyncCustomerProfiles(null), isTrue);
    });
  });

  group('ShopManager.reset (STATE-002)', () {
    tearDown(ShopManager.reset);

    test('clears every shop-scoped value on logout/transition', () {
      ShopManager.shopId = 'shop-a';
      ShopManager.shopName = 'Shop A';
      ShopManager.timezoneOffsetMinutes = 300;

      ShopManager.reset();

      expect(ShopManager.shopId, isNull);
      expect(ShopManager.shopName, isNull);
      expect(ShopManager.timezoneOffsetMinutes, defaultTimezoneOffsetMinutes);
    });

    test('a second session cannot observe the first shop identity', () {
      ShopManager.shopId = 'shop-a';
      ShopManager.shopName = 'Shop A';
      ShopManager.reset();

      ShopManager.shopId = 'shop-b';
      ShopManager.shopName = 'Shop B';

      expect(ShopManager.shopName, 'Shop B');
      expect(ShopManager.shopName, isNot('Shop A'));
      expect(ShopManager.shopId, isNot('shop-a'));
    });
  });

  group('manager-only providers expose a denial state (AUTH-003)', () {
    test('providers start with no denial or error', () {
      expect(DiscountProvider().permissionDenied, isFalse);
      expect(FeedbackProvider().permissionDenied, isFalse);
    });

    test('retry before bind is a safe no-op', () {
      expect(() => DiscountProvider().retry(), returnsNormally);
      expect(() => FeedbackProvider().retry(), returnsNormally);
    });
  });

  group('provider reset clears cached shop state (B2/B4/B6)', () {
    test('DiscountProvider.reset drops data and denial state', () {
      final p = DiscountProvider();
      p
        ..loading = false
        ..permissionDenied = true
        ..error = 'boom'
        ..discounts = const [];

      p.reset();

      expect(p.loading, isTrue);
      expect(p.permissionDenied, isFalse);
      expect(p.error, isNull);
      expect(p.discounts, isEmpty);
    });

    test('FeedbackProvider.reset drops data and denial state', () {
      final p = FeedbackProvider();
      p
        ..loading = false
        ..permissionDenied = true
        ..error = 'boom'
        ..feedback = const [];

      p.reset();

      expect(p.loading, isTrue);
      expect(p.permissionDenied, isFalse);
      expect(p.error, isNull);
      expect(p.feedback, isEmpty);
    });

    test('BusinessToolsProvider.reset drops every cached collection', () {
      final p = BusinessToolsProvider();
      p
        ..loading = false
        ..permissionDenied = true
        ..error = 'boom';

      p.reset();

      expect(p.loading, isTrue);
      expect(p.permissionDenied, isFalse);
      expect(p.error, isNull);
      expect(p.customers, isEmpty);
      expect(p.payments, isEmpty);
      expect(p.chairs, isEmpty);
      expect(p.isBound, isFalse);
    });
  });
}
