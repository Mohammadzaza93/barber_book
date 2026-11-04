import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/appointment.dart';
import 'package:barber_app/models/enums.dart';
import 'package:barber_app/services/customer_insights.dart';

void main() {
  Appointment appointment({
    String id = 'a1',
    DateTime? start,
    AppointmentStatus status = AppointmentStatus.completed,
    PaymentStatus paymentStatus = PaymentStatus.unpaid,
    double total = 100,
    double collected = 0,
    List<String> services = const ['s1'],
    String employeeId = 'e1',
    int? rating,
  }) {
    final startTime = start ?? DateTime(2026, 1, 10, 12);
    return Appointment(
      id: id,
      shopId: 'shop',
      reference: id,
      customerName: 'Ali',
      customerPhone: '0500000000',
      employeeId: employeeId,
      serviceIds: services,
      startTime: startTime,
      endTime: startTime.add(const Duration(hours: 1)),
      status: status,
      paymentStatus: paymentStatus,
      totalAmount: total,
      collectedAmount: collected,
      createdAt: startTime,
      rating: rating,
    );
  }

  group('customer insights', () {
    test('counts only completed visits and uses collected when present', () {
      final insights = CustomerInsights.from(
        [
          appointment(id: '1', total: 100, collected: 100),
          appointment(id: '2', total: 80, collected: 0),
          appointment(
            id: '3',
            status: AppointmentStatus.cancelled,
            total: 999,
          ),
          appointment(id: '4', status: AppointmentStatus.noShow, total: 999),
          appointment(
            id: '5',
            status: AppointmentStatus.confirmed,
            total: 999,
          ),
        ],
        now: DateTime(2026, 6, 1),
      );

      expect(insights.visitCount, 2);
      expect(insights.cancellationCount, 1);
      expect(insights.noShowCount, 1);
      expect(insights.totalSpent, 180);
      expect(insights.averageTicket, 90);
    });

    test('average ticket and interval use completed visits only', () {
      final insights = CustomerInsights.from(
        [
          appointment(id: '1', start: DateTime(2026, 1, 1)),
          appointment(id: '2', start: DateTime(2026, 1, 11)),
          appointment(id: '3', start: DateTime(2026, 1, 31)),
          appointment(
            id: '4',
            start: DateTime(2026, 1, 20),
            status: AppointmentStatus.cancelled,
          ),
        ],
        now: DateTime(2026, 2, 1),
      );

      expect(insights.visitCount, 3);
      expect(insights.averageIntervalDays, closeTo(15, 0.001));
      expect(insights.firstVisitAt, DateTime(2026, 1, 1));
      expect(insights.lastVisitAt, DateTime(2026, 1, 31));
    });

    test('ranks top services and barbers by completed visits', () {
      final insights = CustomerInsights.from(
        [
          appointment(id: '1', services: ['cut', 'beard'], employeeId: 'e1'),
          appointment(id: '2', services: ['cut'], employeeId: 'e1'),
          appointment(id: '3', services: ['cut'], employeeId: 'e2'),
          appointment(
            id: '4',
            services: ['dye'],
            employeeId: 'e3',
            status: AppointmentStatus.cancelled,
          ),
        ],
        now: DateTime(2026, 6, 1),
      );

      expect(insights.topServiceIds.first.id, 'cut');
      expect(insights.topServiceIds.first.count, 3);
      expect(insights.topEmployeeIds.first.id, 'e1');
      expect(insights.topEmployeeIds.first.count, 2);
      // لا تُحتسب الخدمة من موعد ملغي.
      expect(
        insights.topServiceIds.any((s) => s.id == 'dye'),
        isFalse,
      );
    });

    test('next appointment is the first upcoming confirmed/requested one', () {
      final insights = CustomerInsights.from(
        [
          appointment(
            id: 'past',
            start: DateTime(2026, 1, 1),
            status: AppointmentStatus.confirmed,
          ),
          appointment(
            id: 'next',
            start: DateTime(2026, 7, 1),
            status: AppointmentStatus.confirmed,
          ),
          appointment(
            id: 'later',
            start: DateTime(2026, 8, 1),
            status: AppointmentStatus.requested,
          ),
          appointment(
            id: 'cancelled',
            start: DateTime(2026, 6, 1),
            status: AppointmentStatus.cancelled,
          ),
        ],
        now: DateTime(2026, 6, 15),
      );

      expect(insights.nextAppointmentAt, DateTime(2026, 7, 1));
    });

    test('monthsFor groups by month and totalFor sums the year', () {
      final insights = CustomerInsights.from(
        [
          appointment(
            id: '1',
            start: DateTime(2025, 1, 5),
            total: 50,
            collected: 50,
          ),
          appointment(
            id: '2',
            start: DateTime(2025, 1, 20),
            total: 70,
          ),
          appointment(
            id: '3',
            start: DateTime(2025, 3, 2),
            total: 30,
          ),
          appointment(
            id: '4',
            start: DateTime(2025, 3, 4),
            status: AppointmentStatus.cancelled,
          ),
          appointment(
            id: '5',
            start: DateTime(2025, 4, 4),
            status: AppointmentStatus.noShow,
          ),
        ],
        now: DateTime(2026, 6, 1),
      );

      final months = insights.monthsFor(2025);
      expect(months, hasLength(12));
      expect(months[0].visits, 2);
      expect(months[0].spent, 120);
      expect(months[2].visits, 1);
      expect(months[2].cancellations, 1);
      expect(months[3].noShows, 1);

      final total = insights.totalFor(2025);
      expect(total.visits, 3);
      expect(total.cancellations, 1);
      expect(total.noShows, 1);
      expect(total.spent, 150);
    });

    test('years include history years and the current year, newest first', () {
      final insights = CustomerInsights.from(
        [
          appointment(id: '1', start: DateTime(2023, 5, 1)),
          appointment(id: '2', start: DateTime(2025, 5, 1)),
        ],
        now: DateTime(2026, 6, 1),
      );

      expect(insights.years, [2026, 2025, 2023]);
    });

    test('empty history is safe', () {
      final insights =
          CustomerInsights.from(const [], now: DateTime(2026, 1, 1));

      expect(insights.hasHistory, isFalse);
      expect(insights.hasVisits, isFalse);
      expect(insights.visitCount, 0);
      expect(insights.totalSpent, 0);
      expect(insights.averageTicket, 0);
      expect(insights.averageIntervalDays, 0);
      expect(insights.firstVisitAt, isNull);
      expect(insights.lastVisitAt, isNull);
      expect(insights.nextAppointmentAt, isNull);
      expect(insights.years, [2026]);
      expect(insights.monthsFor(2026).every((m) => m.isEmpty), isTrue);
    });

    test('amountOf prefers collected money only when it is positive', () {
      expect(CustomerInsights.amountOf(appointment(total: 100)), 100);
      expect(
        CustomerInsights.amountOf(appointment(total: 100, collected: 40)),
        40,
      );
    });
  });
}
