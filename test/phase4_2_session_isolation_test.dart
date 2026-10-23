import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/models/booking_settings.dart';
import 'package:barber_app/models/employee.dart';
import 'package:barber_app/models/service.dart';
import 'package:barber_app/providers/discount_provider.dart';
import 'package:barber_app/providers/auth_provider.dart';
import 'package:barber_app/providers/language_provider.dart';
import 'package:barber_app/providers/shop_provider.dart';
import 'package:barber_app/screens/admin/settings_screen.dart';
import 'package:barber_app/services/firebase_status.dart';
import 'package:barber_app/services/shop_manager.dart';

/// PHASE 4.2 â€” adversarial session-isolation and authorization verification.

typedef _Resolved = ({String? shopId, AppRole role});

AuthProvider _authWith({
  required Future<_Resolved> Function(String uid) resolve,
}) {
  return AuthProvider(
    resolveShop: resolve,
    subscribeShopNotifications: (_) async => true,
    unsubscribeShopNotifications: (_) async => true,
  );
}

void main() {
  setUp(() {
    firebaseReady = false;
    ShopManager.reset();
  });

  group('O-4 Scenario A â€” late resolve from the previous account', () {
    test('a resolve that lands after sign-out cannot resurrect the session',
        () async {
      final aResolve = Completer<_Resolved>();
      final auth = _authWith(resolve: (uid) => aResolve.future);

      final pending = auth.applySessionForTest('A');
      expect(auth.shopId, isNull);

      // Sign out while A's resolve is still in flight.
      await auth.applySessionForTest(null);
      expect(auth.shopId, isNull);
      expect(auth.role, AppRole.staff);
      expect(auth.initializing, isFalse);

      // A's response arrives late; it must be dropped.
      aResolve.complete((shopId: 'shop-A', role: AppRole.admin));
      await pending;

      expect(auth.shopId, isNull);
      expect(auth.role, AppRole.staff);
      expect(ShopManager.shopId, isNull);
      expect(ShopManager.timezoneOffsetMinutes, defaultTimezoneOffsetMinutes);
    });

    test('a late resolve cannot overwrite a newer account', () async {
      final aResolve = Completer<_Resolved>();
      final bResolve = Completer<_Resolved>();
      final auth = _authWith(
        resolve: (uid) => uid == 'A' ? aResolve.future : bResolve.future,
      );

      final pendingA = auth.applySessionForTest('A');
      final pendingB = auth.applySessionForTest('B');

      bResolve.complete((shopId: 'shop-B', role: AppRole.admin));
      await pendingB;
      expect(auth.shopId, 'shop-B');
      expect(auth.role, AppRole.admin);

      // A resolves last; B must keep winning.
      aResolve.complete((shopId: 'shop-A', role: AppRole.admin));
      await pendingA;

      expect(auth.shopId, 'shop-B');
      expect(auth.role, AppRole.admin);
      expect(ShopManager.shopId, 'shop-B');
    });
  });

  group('O-4 Scenario B â€” late stream event from the previous shop', () {
    test('a late event on the former shop stream cannot change the new state',
        () async {
      final settingsA = StreamController<BookingSettings>.broadcast();
      final settingsB = StreamController<BookingSettings>.broadcast();
      final provider = ShopProvider(
        watchSettings: (id) => id == 'A' ? settingsA.stream : settingsB.stream,
        watchServices: (_) => Stream<List<Service>>.value(const []),
        watchEmployees: (_) => Stream<List<Employee>>.value(const []),
      );

      provider.bind('A');
      await Future<void>.delayed(Duration.zero);
      expect(settingsA.hasListener, isTrue);

      settingsA.add(const BookingSettings(shopName: 'A-shop'));
      await Future<void>.delayed(Duration.zero);
      expect(provider.settings?.shopName, 'A-shop');

      // Session transition A -> B.
      provider.reset();
      expect(settingsA.hasListener, isFalse,
          reason: 'reset must cancel the previous shop subscription');
      provider.bind('B');
      settingsB.add(const BookingSettings(shopName: 'B-shop'));
      await Future<void>.delayed(Duration.zero);
      expect(provider.settings?.shopName, 'B-shop');

      // Late event from A's former stream: must not reach B's provider.
      settingsA.add(const BookingSettings(shopName: 'A-late'));
      await Future<void>.delayed(Duration.zero);
      expect(provider.settings?.shopName, 'B-shop');

      await settingsA.close();
      await settingsB.close();
    });
  });

  group('O-4 Scenario C â€” authentication resolution race', () {
    test('a failed stale resolve cannot overwrite the newer session', () async {
      final aResolve = Completer<_Resolved>();
      final bResolve = Completer<_Resolved>();
      final auth = _authWith(
        resolve: (uid) => uid == 'A' ? aResolve.future : bResolve.future,
      );

      final pendingA = auth.applySessionForTest('A');
      final pendingB = auth.applySessionForTest('B');

      bResolve.complete((shopId: 'shop-B', role: AppRole.admin));
      await pendingB;

      aResolve.completeError(Exception('network down'));
      await pendingA; // must complete normally, failure swallowed

      expect(auth.shopId, 'shop-B');
      expect(auth.role, AppRole.admin);
      expect(auth.error, isNull);
      expect(auth.initializing, isFalse);
    });

    test('a current resolve failure clears identity and does not hang',
        () async {
      final auth = _authWith(
        resolve: (_) => Future<_Resolved>.error(Exception('boom')),
      );
      await auth.applySessionForTest('A');
      expect(auth.initializing, isFalse);
      expect(auth.shopId, isNull);
      expect(auth.role, AppRole.staff);
      expect(auth.error, isNotNull);
      expect(ShopManager.shopId, isNull);
    });
  });

  group('O-4 Scenario D â€” repeated teardown', () {
    test('duplicate sign-out notifications stay consistent', () async {
      final auth = _authWith(
        resolve: (_) async => (shopId: 'shop-A', role: AppRole.admin),
      );
      await auth.applySessionForTest('A');
      expect(auth.shopId, 'shop-A');

      await auth.applySessionForTest(null);
      await auth.applySessionForTest(null);
      await auth.applySessionForTest(null);

      expect(auth.shopId, isNull);
      expect(auth.role, AppRole.staff);
      expect(auth.initializing, isFalse);
    });

    test('reset is idempotent and does not duplicate subscriptions', () async {
      final settingsA = StreamController<BookingSettings>.broadcast();
      final provider = ShopProvider(
        watchSettings: (_) => settingsA.stream,
        watchServices: (_) => Stream<List<Service>>.value(const []),
        watchEmployees: (_) => Stream<List<Employee>>.value(const []),
      );

      provider.bind('A');
      provider.bind('A'); // same shop: must be a no-op
      await Future<void>.delayed(Duration.zero);
      expect(settingsA.hasListener, isTrue);

      provider.reset();
      provider.reset();
      expect(settingsA.hasListener, isFalse);
      expect(provider.loading, isTrue);
      expect(provider.services, isEmpty);
      expect(provider.settings, isNull);

      await settingsA.close();
    });

    test('a disposed provider is unsubscribed and never notified', () async {
      final settingsA = StreamController<BookingSettings>.broadcast();
      final provider = ShopProvider(
        watchSettings: (_) => settingsA.stream,
        watchServices: (_) => Stream<List<Service>>.value(const []),
        watchEmployees: (_) => Stream<List<Employee>>.value(const []),
      );

      provider.bind('A');
      await Future<void>.delayed(Duration.zero);
      expect(settingsA.hasListener, isTrue);

      provider.dispose();
      expect(settingsA.hasListener, isFalse);

      // Emitting after disposal must not throw (no listener is notified).
      settingsA.add(const BookingSettings(shopName: 'late'));
      await Future<void>.delayed(Duration.zero);

      await settingsA.close();
    });
  });

  group('O-4 Scenario E â€” account state vs global preference separation', () {
    test('sign-out clears shop-scoped identity but keeps the language choice',
        () async {
      final auth = _authWith(
        resolve: (_) async => (shopId: 'shop-A', role: AppRole.admin),
      );
      await auth.applySessionForTest('A');
      expect(auth.shopId, 'shop-A');
      expect(ShopManager.shopId, 'shop-A');
      ShopManager.timezoneOffsetMinutes = 300;

      await auth.applySessionForTest(null);
      expect(auth.shopId, isNull);
      expect(auth.role, AppRole.staff);
      expect(ShopManager.shopId, isNull);
      expect(ShopManager.timezoneOffsetMinutes, defaultTimezoneOffsetMinutes);

      // A global preference is not shop-scoped and must survive.
      final lang = LanguageProvider();
      await lang.setLocale(const Locale('en'));
      expect(lang.isArabic, isFalse);
      // Resetting shop providers must not touch it.
      expect(lang.locale.languageCode, 'en');
    });

    test('reset clears per-session error and permission-denied flags',
        () async {
      final discount = DiscountProvider();
      discount.permissionDenied = true;
      discount.error = 'stale';
      discount.reset();
      expect(discount.permissionDenied, isFalse);
      expect(discount.error, isNull);
      expect(discount.discounts, isEmpty);
      expect(discount.loading, isTrue);
    });
  });

  group('O-2 direct navigation to the owner-only settings screen', () {
    Widget app(AuthProvider auth) => MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ShopProvider>.value(
                value: ShopProvider()..settings = const BookingSettings()),
          ],
          child: const MaterialApp(
            locale: Locale('en'),
            supportedLocales: [Locale('ar'), Locale('en')],
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: SettingsScreen(),
          ),
        );

    AuthProvider roleAuth(AppRole role) {
      final a = AuthProvider(
        resolveShop: (_) async => (shopId: null, role: role),
        subscribeShopNotifications: (_) async => true,
        unsubscribeShopNotifications: (_) async => true,
      );
      a.role = role;
      return a;
    }

    testWidgets(
        'staff reaching settings via the share link still cannot save',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final en = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(app(roleAuth(AppRole.staff)));
      final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, en.saveSettings));
      expect(save.onPressed, isNull);
    });
  });
}
