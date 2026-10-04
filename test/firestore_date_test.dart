import 'package:barber_app/models/appointment.dart';
import 'package:barber_app/models/enums.dart';
import 'package:barber_app/models/expense.dart';
import 'package:barber_app/models/feedback.dart';
import 'package:barber_app/models/firestore_date.dart';
import 'package:barber_app/models/member.dart';
import 'package:barber_app/models/unavailability_request.dart';
import 'package:flutter_test/flutter_test.dart';

/// Minimal stand-in for `cloud_firestore`'s Timestamp: exposes `toDate()`.
class _FakeTimestamp {
  _FakeTimestamp(this._value);
  final DateTime _value;
  DateTime toDate() => _value;
}

void main() {
  const isoString = '2026-01-15T10:00:00.000Z';
  final expected = DateTime.utc(2026, 1, 15, 10);

  group('readFirestoreDate', () {
    test('parses an ISO-8601 string returned by Cloud Functions', () {
      expect(readFirestoreDate(isoString), expected);
    });

    test('parses a Firestore Timestamp', () {
      expect(readFirestoreDate(_FakeTimestamp(expected)), expected);
    });

    test('parses a DateTime', () {
      expect(readFirestoreDate(expected), expected);
    });

    test('parses epoch millis', () {
      expect(
        readFirestoreDate(expected.millisecondsSinceEpoch),
        expected,
      );
    });

    test('returns the fallback for null', () {
      expect(readFirestoreDate(null, expected), expected);
      expect(readFirestoreDate(null), isNull);
    });

    test('returns the fallback for garbage instead of throwing', () {
      expect(readFirestoreDate('not-a-date', expected), expected);
      expect(readFirestoreDate(const {}, expected), expected);
    });

    test('normalizes a local DateTime to UTC', () {
      final local = DateTime(2026, 1, 15, 10);
      final parsed = readFirestoreDate(local);
      expect(parsed!.isUtc, isTrue);
      expect(parsed.isAtSameMomentAs(local), isTrue);
    });
  });

  group('Appointment.fromMap accepts callable payloads', () {
    // Regression: the callable returns ISO strings, while the model previously
    // assumed a Timestamp and called .toDate() unconditionally, throwing
    // NoSuchMethodError on every booking creation.
    Map<String, dynamic> callablePayload() => {
          'shopId': 'shop1',
          'reference': 'REF-1',
          'customerId': 'uid1',
          'customerName': 'Customer',
          'customerPhone': '0500000000',
          'customerEmail': 'a@b.com',
          'employeeId': 'emp1',
          'serviceIds': ['svc1'],
          'startTime': isoString,
          'endTime': '2026-01-15T11:00:00.000Z',
          'status': 'confirmed',
          'paymentStatus': 'paid',
          'totalAmount': 100.0,
          'depositAmount': 20.0,
          'collectedAmount': 100.0,
          'createdAt': isoString,
          'lateCancellation': false,
        };

    test('parses ISO string start/end/createdAt', () {
      final a = Appointment.fromMap('a1', callablePayload());
      expect(a.startTime, expected);
      expect(a.endTime, DateTime.utc(2026, 1, 15, 11));
      expect(a.createdAt, expected);
      expect(a.startTime.isUtc, isTrue);
    });

    test('preserves server-derived values', () {
      final a = Appointment.fromMap('a1', callablePayload());
      expect(a.status, AppointmentStatus.confirmed);
      expect(a.paymentStatus, PaymentStatus.paid);
      expect(a.collectedAmount, 100.0);
      expect(a.totalAmount, 100.0);
      expect(a.reference, 'REF-1');
    });

    test('still parses Firestore Timestamp documents', () {
      final a = Appointment.fromMap('a1', {
        ...callablePayload(),
        'startTime': _FakeTimestamp(expected),
        'endTime': _FakeTimestamp(DateTime.utc(2026, 1, 15, 11)),
        'createdAt': _FakeTimestamp(expected),
      });
      expect(a.startTime, expected);
    });

    test('does not throw when date fields are missing', () {
      final payload = callablePayload()..remove('startTime');
      final a = Appointment.fromMap('a1', payload);
      expect(a.startTime, isA<DateTime>());
    });

    test('unknown status and payment fall back safely', () {
      final a = Appointment.fromMap('a1', {
        ...callablePayload(),
        'status': 'teleported',
        'paymentStatus': 'refunded',
      });
      expect(a.status, AppointmentStatus.requested);
      expect(a.paymentStatus, PaymentStatus.unpaid);
    });
  });

  test('Feedback.fromMap parses ISO createdAt', () {
    final f = Feedback.fromMap('f1', {
      'appointmentId': 'a1',
      'customerName': 'C',
      'rating': 5,
      'comment': 'good',
      'createdAt': isoString,
    });
    expect(f.createdAt, expected);
  });

  test('Expense.fromMap parses ISO date', () {
    final e = Expense.fromMap('e1', {
      'title': 'Rent',
      'amount': 100.0,
      'date': isoString,
    });
    expect(e.date, expected);
  });

  test('UnavailabilityRequest.fromMap parses ISO dates', () {
    final r = UnavailabilityRequest.fromMap('r1', {
      'customerName': 'C',
      'requestedStart': isoString,
      'requestedEnd': '2026-01-15T12:00:00.000Z',
      'createdAt': isoString,
      'status': 'pending',
    });
    expect(r.requestedStart, expected);
    expect(r.requestedEnd, DateTime.utc(2026, 1, 15, 12));
    expect(r.createdAt, expected);
  });

  test('Member.fromMap reads createdAt (previously always null)', () {
    final m = Member.fromMap('u1', {
      'email': 'a@b.com',
      'name': 'C',
      'role': 'manager',
      'createdAt': _FakeTimestamp(expected),
    });
    expect(m.createdAt, expected);
  });

  test('Member.fromMap tolerates a legacy string createdAt', () {
    final m = Member.fromMap('u1', {
      'email': 'a@b.com',
      'role': 'staff',
      'createdAt': isoString,
    });
    expect(m.createdAt, expected);
  });
}