import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/appointment.dart';
import 'package:barber_app/models/enums.dart';
import 'package:barber_app/models/expense.dart';
import 'package:barber_app/services/analytics_service.dart';

Appointment appointment({
  required String id,
  required DateTime startTime,
  AppointmentStatus status = AppointmentStatus.completed,
  double totalAmount = 100,
}) {
  return Appointment(
    id: id,
    shopId: 'shop',
    reference: id,
    customerName: 'Customer $id',
    customerPhone: id,
    customerEmail: '',
    employeeId: 'barber',
    serviceIds: const ['service'],
    startTime: startTime,
    endTime: startTime.add(const Duration(minutes: 30)),
    status: status,
    totalAmount: totalAmount,
    createdAt: startTime,
  );
}

void main() {
  final analytics = AnalyticsService.instance;

  test('calculates daily booking counts and excludes cancelled bookings', () {
    final start = DateTime(2026, 1, 1);
    final appointments = [
      appointment(id: 'a1', startTime: start),
      appointment(id: 'a2', startTime: start.add(const Duration(hours: 2))),
      appointment(
        id: 'a3',
        startTime: start,
        status: AppointmentStatus.cancelled,
      ),
    ];

    final result = analytics.dailyBookings(appointments, start, 2);
    expect(result[DateTime(2026, 1, 1)], 2);
    expect(result[DateTime(2026, 1, 2)], 0);
  });

  test('calculates completion rate from finished appointments only', () {
    final date = DateTime(2026, 1, 1);
    final appointments = [
      appointment(id: 'a1', startTime: date),
      appointment(
        id: 'a2',
        startTime: date,
        status: AppointmentStatus.noShow,
      ),
      appointment(
        id: 'a3',
        startTime: date,
        status: AppointmentStatus.cancelled,
      ),
    ];

    expect(analytics.completionRate(appointments), closeTo(33.333, 0.01));
  });

  test('calculates net profit after expenses', () {
    final date = DateTime(2026, 1, 1);
    final appointments = [
      appointment(id: 'a1', startTime: date, totalAmount: 250),
    ];
    final expenses = [
      Expense(id: 'e1', title: 'Supplies', amount: 75, date: date),
    ];

    expect(analytics.netProfit(appointments, expenses), 175);
  });
}
