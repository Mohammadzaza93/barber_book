import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:barber_app/models/appointment.dart';
import 'package:barber_app/models/booking_settings.dart';
import 'package:barber_app/models/customer_profile.dart';
import 'package:barber_app/models/employee.dart';
import 'package:barber_app/models/enums.dart';
import 'package:barber_app/models/service.dart';
import 'package:barber_app/providers/business_tools_provider.dart';
import 'package:barber_app/providers/shop_provider.dart';
import 'package:barber_app/screens/admin/customer_profile_screen.dart';

void main() {
  final year = DateTime.now().year;

  CustomerProfile customer({int visits = 2, double spent = 180}) =>
      CustomerProfile(
        id: '0500000000',
        name: 'علي أحمد',
        phone: '0500000000',
        area: 'الرياض',
        visitCount: visits,
        totalSpent: spent,
        createdAt: DateTime(year, 1, 1),
        updatedAt: DateTime(year, 1, 1),
      );

  Appointment appointment({
    required String id,
    required DateTime start,
    AppointmentStatus status = AppointmentStatus.completed,
    double total = 100,
    double collected = 0,
    List<String> services = const ['cut'],
  }) =>
      Appointment(
        id: id,
        shopId: 'shop',
        reference: id,
        customerName: 'علي أحمد',
        customerPhone: '0500000000',
        employeeId: 'e1',
        serviceIds: services,
        startTime: start,
        endTime: start.add(const Duration(hours: 1)),
        status: status,
        totalAmount: total,
        collectedAmount: collected,
        createdAt: start,
      );

  Future<void> pumpScreen(
    WidgetTester tester, {
    required CustomerProfile profile,
    required Future<List<Appointment>> Function(String phone) loader,
  }) async {
    // شاشة طويلة: نكبّر السطح ليبني الاختبار كل الأقسام دون تمرير.
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BusinessToolsProvider>(
            create: (_) => BusinessToolsProvider(),
          ),
          ChangeNotifierProvider<ShopProvider>(
            create: (_) => ShopProvider(
              watchSettings: (_) => const Stream<BookingSettings>.empty(),
              watchServices: (_) => const Stream<List<Service>>.empty(),
              watchEmployees: (_) => const Stream<List<Employee>>.empty(),
            ),
          ),
        ],
        child: MaterialApp(
          home: CustomerProfileScreen(customer: profile, loader: loader),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows summary, yearly analysis and attendance history',
      (tester) async {
    final profile = customer();
    final history = [
      appointment(
        id: 'a1',
        start: DateTime(year, 1, 10, 12),
        total: 100,
        collected: 100,
      ),
      appointment(
        id: 'a2',
        start: DateTime(year, 2, 15, 17),
        total: 80,
        status: AppointmentStatus.confirmed,
      ),
    ];

    await pumpScreen(
      tester,
      profile: profile,
      loader: (_) async => history,
    );

    expect(find.text('ملخص الزبون'), findsOneWidget);
    expect(find.text('تحليل السنة'), findsOneWidget);
    expect(find.textContaining('سجل الحضور'), findsOneWidget);
    expect(find.text('إجمالي السنة'), findsOneWidget);
    // الزيارة المكتملة تظهر كمكتملة، والموعد القادم كمؤكد.
    expect(find.text('مكتمل'), findsOneWidget);
    expect(find.text('مؤكد'), findsOneWidget);
    // الخدمة تظهر من معرّفها عند غياب كتالوج الخدمات.
    expect(find.text('cut'), findsWidgets);
    // المبلغ المحصّل يظهر في الملخص.
    expect(find.textContaining('100.00 SAR'), findsWidgets);
  });

  testWidgets('empty history keeps the profile and explains the empty log',
      (tester) async {
    await pumpScreen(
      tester,
      profile: customer(visits: 0, spent: 0),
      loader: (_) async => const [],
    );

    expect(find.text('علي أحمد'), findsWidgets);
    expect(find.text('لا مواعيد مسجّلة بعد'), findsOneWidget);
    expect(find.text('لا يوجد نشاط مسجّل في $year.'), findsOneWidget);
    expect(find.text('ملخص الزبون'), findsOneWidget);
  });
}
