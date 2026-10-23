import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/models/booking_settings.dart';
import 'package:barber_app/models/business_features.dart';
import 'package:barber_app/models/employee.dart';
import 'package:barber_app/models/service.dart';
import 'package:barber_app/providers/auth_provider.dart';
import 'package:barber_app/providers/business_tools_provider.dart';
import 'package:barber_app/providers/shop_provider.dart';
import 'package:barber_app/screens/admin/business_tools_screen.dart';

/// Regression coverage for the two defects found during the real-device run:
///
///  * `_PaymentsTab._addPayment` awaited the callable-backed `addPayment`
///    without a `try/catch`, so a server rejection (e.g. the referenced
///    appointment does not exist) escaped as an unhandled async exception
///    instead of a snackbar. (lib/screens/admin/business_tools_screen.dart)
///  * The six tab scaffolds of `BusinessToolsScreen` each owned a
///    `FloatingActionButton` with the *default* hero tag, so a route
///    transition threw "multiple heroes that share the same tag".
///    (lib/screens/admin/business_tools_screen.dart, business_management_tabs.dart)
void main() {
  AuthProvider owner() => AuthProvider(
        subscribeShopNotifications: (_) async => true,
        unsubscribeShopNotifications: (_) async => true,
      )..role = AppRole.admin;

  Widget harness({AuthProvider? auth, BusinessToolsProvider? tools}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              auth ??
              AuthProvider(
                subscribeShopNotifications: (_) async => true,
                unsubscribeShopNotifications: (_) async => true,
              ),
        ),
        ChangeNotifierProvider(
          create: (_) => ShopProvider(
            watchSettings: (_) => const Stream<BookingSettings>.empty(),
            watchServices: (_) => const Stream<List<Service>>.empty(),
            watchEmployees: (_) => const Stream<List<Employee>>.empty(),
          ),
        ),
        ChangeNotifierProvider(
            create: (_) => tools ?? BusinessToolsProvider()),
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
        home: Scaffold(body: BusinessToolsScreen()),
      ),
    );
  }

  Future<void> openToolTab(WidgetTester tester, String label) async {
    await tester.ensureVisible(find.text(label));
    await tester.tap(find.text(label));
    await tester.pumpAndSettle();
  }

  setUp(() {
    // The scrollable TabBar needs a viewport wide enough for every tab to be
    // tappable without horizontal scrolling.
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1600, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('business-tools tab FABs use distinct hero tags (HERO-001)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    final tags = <Object?>{};
    for (final label in const ['Queue', 'Payments']) {
      await openToolTab(tester, label);
      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton).first,
      );
      expect(fab.heroTag, isNotNull,
          reason: '$label FAB must have an explicit hero tag');
      tags.add(fab.heroTag);
    }
    // Default hero tags are a shared const, so a pre-fix build collapses to a
    // single value and the HeroController assertion fires on route changes.
    expect(tags.length, 2,
        reason: 'each tab FAB needs its own distinct hero tag');
  });

  testWidgets('add-customer dialog labels name/phone/email correctly (L10N-002)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await openToolTab(tester, 'Customers');
    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();

    final labels = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((f) => f.decoration?.labelText)
        .whereType<String>()
        .toList();
    expect(labels.take(3).toList(), ['Customer name', 'Phone number', 'Email']);
  });

  testWidgets('record payment surfaces a server rejection (PAY-001)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await openToolTab(tester, 'Payments');
    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();

    // Fields in order: name, phone, appointment ref, amount, material cost.
    await tester.enterText(find.byType(TextField).at(3), '50');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Without Firebase the callable layer rejects via SecureApiException; the
    // screen must handle it instead of leaking an unhandled exception.
    expect(tester.takeException(), isNull);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('add-customer dialog rejects a malformed email (L10N-003)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await openToolTab(tester, 'Customers');
    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();

    // Field 0 is the tab's search box; the dialog fields follow.
    await tester.enterText(find.byType(TextField).at(1), 'Ali');
    await tester.enterText(find.byType(TextField).at(2), '0500000000');
    await tester.enterText(find.byType(TextField).at(3), 'not-an-email');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'a malformed email must block submission');
    expect(find.text('required'), findsOneWidget);
  });

  testWidgets(
      'add-chair dialog requires a name instead of closing silently (CHAIR-001)',
      (tester) async {
    await tester.pumpWidget(harness(auth: owner()));
    await tester.pumpAndSettle();

    await openToolTab(tester, 'Chairs');
    await tester.ensureVisible(find.text('Add chair'));
    await tester.tap(find.text('Add chair'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget,
        reason: 'an empty chair name must keep the dialog open');
    expect(find.text('required'), findsOneWidget);
  });

  testWidgets(
      'add-material dialog pre-fills the localized category and unit (L10N-004)',
      (tester) async {
    final tools = BusinessToolsProvider()
      ..chairs = [const Chair(id: 'c1', name: 'Chair 1', number: '1')];
    await tester.pumpWidget(harness(auth: owner(), tools: tools));
    await tester.pumpAndSettle();

    await openToolTab(tester, 'Chairs');
    await tester.ensureVisible(find.text('Add material'));
    await tester.tap(find.text('Add material'));
    await tester.pumpAndSettle();

    final fields = find.descendant(
        of: find.byType(AlertDialog), matching: find.byType(TextField));
    final values = tester
        .widgetList<TextField>(fields)
        .map((f) => f.controller?.text)
        .toList();
    expect(values, contains('Shave'));
    expect(values, contains('Piece'));
  });
}
