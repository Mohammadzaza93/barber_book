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
import 'package:barber_app/providers/finance_provider.dart';
import 'package:barber_app/providers/shop_provider.dart';
import 'package:barber_app/screens/admin/business_tools_screen.dart';
import 'package:barber_app/screens/admin/inventory_tab.dart';
import 'package:barber_app/screens/admin/queue_finish_payment.dart';

/// Regression coverage for defects found during real-device runs:
///
///  * Tab scaffolds of `BusinessToolsScreen` used to share the default FAB
///    hero tag, so a route transition threw "multiple heroes that share the
///    same tag".
///  * The add-customer dialog must keep its localized labels and must reject a
///    malformed email instead of closing and submitting.
///  * Queue checkout used to await Firestore writes without a `try/catch`, so
///    a server rejection escaped as an unhandled async exception.
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
        ChangeNotifierProvider(create: (_) => tools ?? BusinessToolsProvider()),
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
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1600, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view =
        TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('business-tools customer FAB has an explicit hero tag (HERO-001)',
      (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

      final fab = tester.widget<FloatingActionButton>(
        find.byType(FloatingActionButton).first,
      );
    expect(fab.heroTag, 'bt_customers_fab',
        reason: 'the FAB must not use the shared default hero tag');

    // The other tabs must not add a second FAB with the same implicit tag.
    for (final label in const ['Loyalty', 'Chairs']) {
      await openToolTab(tester, label);
      expect(find.byType(FloatingActionButton), findsNothing);
    }
  });

  testWidgets(
      'add-customer dialog labels name/phone/email correctly (L10N-002)',
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
    expect(labels.take(2).toList(), ['Customer name', 'Phone number']);
    expect(labels, contains('Email'));
  });

  testWidgets('queue checkout surfaces a persistence failure (PAY-001)',
      (tester) async {
    final tools = BusinessToolsProvider();
    final shop = ShopProvider(
      watchSettings: (_) => const Stream<BookingSettings>.empty(),
      watchServices: (_) => const Stream<List<Service>>.empty(),
      watchEmployees: (_) => const Stream<List<Employee>>.empty(),
    )..services = [
        const Service(
          id: 'svc-1',
          name: 'Haircut',
          price: 50,
          durationMinutes: 30,
        ),
      ];
    final finance = FinanceProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessToolsProvider>.value(value: tools),
          ChangeNotifierProvider<ShopProvider>.value(value: shop),
          ChangeNotifierProvider<FinanceProvider>.value(value: finance),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () => QueueFinishPayment.show(
                    context,
                    QueueEntry(
                      id: 'queue-1',
                      customerName: 'Ali',
                      customerPhone: '0500000000',
                      employeeId: '',
                      joinedAt: DateTime(2026, 1, 1, 10),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // Without Firebase the queue write rejects; the screen must report it
    // instead of leaking an unhandled exception.
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

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

    // Fields inside the dialog: name, phone, alternate phone, email.
    final fields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), 'Ali');
    await tester.enterText(fields.at(1), '0500000000');
    await tester.enterText(fields.at(3), 'not-an-email');
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
      'inventory add-material sheet defaults to the general category and piece unit (L10N-004)',
      (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => BusinessToolsProvider()),
          ChangeNotifierProvider(
            create: (_) => ShopProvider(
              watchSettings: (_) => const Stream<BookingSettings>.empty(),
              watchServices: (_) => const Stream<List<Service>>.empty(),
              watchEmployees: (_) => const Stream<List<Employee>>.empty(),
            ),
          ),
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
          home: Scaffold(body: InventoryTab()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FloatingActionButton).first);
    await tester.pumpAndSettle();

    final dropdowns = tester
        .widgetList<DropdownButton<String>>(find.byType(DropdownButton<String>))
        .toList();
    expect(dropdowns.length, greaterThanOrEqualTo(2));
    expect(dropdowns[0].value, 'general');
    expect(dropdowns[1].value, 'piece');
  });
}
