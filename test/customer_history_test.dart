import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/appointment.dart';
import 'package:barber_app/models/enums.dart';
import 'package:barber_app/providers/business_tools_provider.dart';

void main() {
  Appointment appointment(String id, DateTime start) => Appointment(
        id: id,
        shopId: 'shop',
        reference: id,
        customerName: 'Ali',
        customerPhone: '0500000000',
        employeeId: 'e1',
        serviceIds: const ['s1'],
        startTime: start,
        endTime: start.add(const Duration(hours: 1)),
        status: AppointmentStatus.completed,
        createdAt: start,
      );

  test('loadCustomerHistory queries the normalized phone and sorts by time',
      () async {
    String? askedShop;
    String? askedPhone;
    final tools = BusinessToolsProvider(
      loadCustomerAppointments: (shopId, phone) async {
        askedShop = shopId;
        askedPhone = phone;
        return [
          appointment('b', DateTime(2026, 5, 1)),
          appointment('a', DateTime(2026, 1, 1)),
        ];
      },
    );
    tools.bindForTest('shop-A');

    final result = await tools.loadCustomerHistory('050-000-0000');

    expect(askedShop, 'shop-A');
    expect(askedPhone, '0500000000');
    expect(result.map((a) => a.id), ['a', 'b']);
  });

  test('a denied history query degrades to an empty log', () async {
    final tools = BusinessToolsProvider(
      loadCustomerAppointments: (_, __) async {
        throw FirebaseException(
          plugin: 'cloud_firestore',
          code: 'permission-denied',
        );
      },
    );
    tools.bindForTest('shop-A');

    expect(await tools.loadCustomerHistory('0500000000'), isEmpty);
  });

  test('loadCustomerHistory requires a bound shop', () async {
    final tools = BusinessToolsProvider(
      loadCustomerAppointments: (_, __) async => const [],
    );

    await expectLater(
      tools.loadCustomerHistory('0500000000'),
      throwsA(isA<StateError>()),
    );
  });

  test('an empty phone is not queried', () async {
    var queried = false;
    final tools = BusinessToolsProvider(
      loadCustomerAppointments: (_, __) async {
        queried = true;
        return const [];
      },
    );
    tools.bindForTest('shop-A');

    expect(await tools.loadCustomerHistory('---'), isEmpty);
    expect(queried, isFalse);
  });
}
