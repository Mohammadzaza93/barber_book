import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/models/appointment.dart';
import 'package:barber_app/models/booking_settings.dart';
import 'package:barber_app/models/unavailability_request.dart';
import 'package:barber_app/providers/appointment_provider.dart';
import 'package:barber_app/providers/auth_provider.dart';
import 'package:barber_app/providers/business_tools_provider.dart';
import 'package:barber_app/providers/discount_provider.dart';
import 'package:barber_app/providers/feedback_provider.dart';
import 'package:barber_app/providers/shop_provider.dart';
import 'package:barber_app/screens/admin/appointment_edit_screen.dart';
import 'package:barber_app/screens/admin/business_tools_screen.dart';
import 'package:barber_app/screens/admin/discounts_screen.dart';
import 'package:barber_app/screens/admin/services_screen.dart';
import 'package:barber_app/screens/admin/settings_screen.dart';
import 'package:barber_app/screens/admin/staff_screen.dart';
import 'package:barber_app/screens/admin/unavailability_screen.dart';
import 'package:barber_app/services/shop_manager.dart';

AuthProvider _auth(AppRole role) {
  final provider = AuthProvider();
  provider.role = role;
  return provider;
}

Widget _app({required List<SingleChildWidget> providers, required Widget home}) {
  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: KeyedSubtree(key: UniqueKey(), child: home),
    ),
  );
}

void _useLargeSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 4000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Appointment _appointment({String? createdById}) => Appointment(
      id: 'apt-1',
      shopId: 'shop-1',
      reference: 'REF-1',
      customerName: 'Customer',
      customerPhone: '0500000000',
      employeeId: 'emp-1',
      serviceIds: const [],
      startTime: DateTime(2026, 1, 1, 10),
      endTime: DateTime(2026, 1, 1, 10, 30),
      createdById: createdById,
      createdAt: DateTime(2026, 1, 1, 8),
    );

void main() {
  group('O-2 catalog writes are owner-only', () {
    testWidgets('services: admin sees add affordances, staff does not',
        (tester) async {
      final owner = _auth(AppRole.admin);
      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: owner),
          ChangeNotifierProvider<ShopProvider>.value(value: ShopProvider()),
        ],
        home: const ServicesScreen(),
      ));
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
              value: _auth(AppRole.staff)),
          ChangeNotifierProvider<ShopProvider>.value(value: ShopProvider()),
        ],
        home: const ServicesScreen(),
      ));
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('staff: admin sees add affordances, staff does not',
        (tester) async {
      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _auth(AppRole.admin)),
          ChangeNotifierProvider<ShopProvider>.value(value: ShopProvider()),
        ],
        home: const StaffScreen(),
      ));
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _auth(AppRole.staff)),
          ChangeNotifierProvider<ShopProvider>.value(value: ShopProvider()),
        ],
        home: const StaffScreen(),
      ));
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('discounts: admin sees add affordance, staff does not',
        (tester) async {
      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _auth(AppRole.admin)),
          ChangeNotifierProvider<DiscountProvider>.value(
              value: DiscountProvider()..loading = false),
          ChangeNotifierProvider<ShopProvider>.value(value: ShopProvider()),
        ],
        home: const DiscountsScreen(),
      ));
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
              value: _auth(AppRole.staff)),
          ChangeNotifierProvider<DiscountProvider>.value(
              value: DiscountProvider()..loading = false),
          ChangeNotifierProvider<ShopProvider>.value(value: ShopProvider()),
        ],
        home: const DiscountsScreen(),
      ));
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('O-2 shop settings are admin-only', () {
    testWidgets('admin can save, staff sees a disabled save', (tester) async {
      _useLargeSurface(tester);
      final en = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _auth(AppRole.admin)),
          ChangeNotifierProvider<ShopProvider>.value(
              value: ShopProvider()..settings = const BookingSettings()),
        ],
        home: const SettingsScreen(),
      ));
      final ownerSave = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, en.saveSettings));
      expect(ownerSave.onPressed, isNotNull);

      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
              value: _auth(AppRole.staff)),
          ChangeNotifierProvider<ShopProvider>.value(
              value: ShopProvider()..settings = const BookingSettings()),
        ],
        home: const SettingsScreen(),
      ));
      await tester.pump();
      final managerSave = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, en.saveSettings));
      expect(managerSave.onPressed, isNull);
    });
  });

  group('O-2 out-of-hours decisions are admin-only', () {
    testWidgets('admin sees approve/reject, staff keeps a read-only view',
        (tester) async {
      final en = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
              value: _auth(AppRole.admin)),
          ChangeNotifierProvider<AppointmentProvider>.value(
              value: AppointmentProvider()
                ..loading = false
                ..requests = [_appointmentRequest()]),
        ],
        home: const UnavailabilityScreen(),
      ));
      expect(find.text(en.approved), findsOneWidget);
      expect(find.text(en.rejected), findsOneWidget);

      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _auth(AppRole.staff)),
          ChangeNotifierProvider<AppointmentProvider>.value(
              value: AppointmentProvider()
                ..loading = false
                ..requests = [_appointmentRequest()]),
        ],
        home: const UnavailabilityScreen(),
      ));
      await tester.pump();
      expect(find.text(en.approved), findsNothing);
      expect(find.text(en.rejected), findsNothing);
      expect(find.text('Customer'), findsOneWidget);
    });
  });

  group('O-2 appointment status/payment is admin-only', () {
    testWidgets('staff cannot see status or payment controls, admin can',
        (tester) async {
      _useLargeSurface(tester);
      final en = await AppLocalizations.delegate.load(const Locale('en'));

      Future<void> pumpFor(AuthProvider auth) async {
        final shop = ShopProvider()..settings = const BookingSettings();
        final tools = BusinessToolsProvider();
        final appts = AppointmentProvider()..loading = false;
        await tester.pumpWidget(_app(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: auth),
            ChangeNotifierProvider<ShopProvider>.value(value: shop),
            ChangeNotifierProvider<BusinessToolsProvider>.value(value: tools),
            ChangeNotifierProvider<AppointmentProvider>.value(value: appts),
          ],
          home: AppointmentEditScreen(appointment: _appointment()),
        ));
        await tester.pump();
      }

      await pumpFor(_auth(AppRole.admin));
      expect(find.text(en.actions), findsOneWidget);
      expect(find.text(en.paymentStatus), findsOneWidget);

      await pumpFor(_auth(AppRole.staff));
      expect(find.text(en.actions), findsNothing);
      expect(find.text(en.paymentStatus), findsNothing);
    });
  });

  group('O-2 owner-only business tools are gated', () {
    testWidgets('portfolio add affordance admin-only', (tester) async {
      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: _auth(AppRole.admin)),
          ChangeNotifierProvider<BusinessToolsProvider>.value(
              value: BusinessToolsProvider()),
          ChangeNotifierProvider<ShopProvider>.value(value: ShopProvider()),
        ],
        home: const BusinessToolsScreen(),
      ));
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.pumpWidget(_app(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(
              value: _auth(AppRole.staff)),
          ChangeNotifierProvider<BusinessToolsProvider>.value(
              value: BusinessToolsProvider()),
          ChangeNotifierProvider<ShopProvider>.value(value: ShopProvider()),
        ],
        home: const BusinessToolsScreen(),
      ));
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('O-4 provider reset purges tenant state', () {
    test('ShopProvider.reset clears settings and catalog', () {
      final p = ShopProvider()
        ..settings = const BookingSettings()
        ..loading = false;
      p.reset();
      expect(p.settings, isNull);
      expect(p.services, isEmpty);
      expect(p.employees, isEmpty);
      expect(p.loading, isTrue);
    });

    test('AppointmentProvider.reset clears appointments and requests', () {
      final p = AppointmentProvider()
        ..appointments = [_appointment()]
        ..requests = [_appointmentRequest()]
        ..loading = false;
      p.reset();
      expect(p.appointments, isEmpty);
      expect(p.requests, isEmpty);
      expect(p.loading, isTrue);
    });

    test('every provider purges together and ShopManager is cleared', () {
      ShopManager.shopId = 'shop-x';
      ShopManager.shopName = 'Shop X';

      final shop = ShopProvider()..settings = const BookingSettings();
      final appts = AppointmentProvider()..appointments = [_appointment()];
      final tools = BusinessToolsProvider();
      final discounts = DiscountProvider()..loading = false;
      final feedback = FeedbackProvider()..loading = false;

      shop.reset();
      appts.reset();
      tools.reset();
      discounts.reset();
      feedback.reset();
      ShopManager.reset();

      expect(shop.settings, isNull);
      expect(appts.appointments, isEmpty);
      expect(ShopManager.shopId, isNull);
      expect(ShopManager.shopName, isNull);
      expect(ShopManager.timezoneOffsetMinutes, defaultTimezoneOffsetMinutes);
    });
  });
}

UnavailabilityRequest _appointmentRequest() => UnavailabilityRequest(
      id: 'req-1',
      customerName: 'Customer',
      customerPhone: '0500000000',
      requestedStart: DateTime(2026, 1, 1, 22),
      requestedEnd: DateTime(2026, 1, 1, 22, 30),
      createdAt: DateTime(2026, 1, 1, 8),
    );
