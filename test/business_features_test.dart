import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/business_features.dart';

void main() {
  test('loyalty tier is calculated from points', () {
    final bronze = LoyaltyAccount(
      id: '1',
      customerName: 'A',
      customerPhone: '1',
      points: 100,
      updatedAt: DateTime(2026, 1, 1),
    );
    final gold = bronze.copyWith(points: 700);
    final platinum = bronze.copyWith(points: 1200);

    expect(bronze.calculatedTier, 'bronze');
    expect(gold.calculatedTier, 'gold');
    expect(platinum.calculatedTier, 'platinum');
  });

  test('queue entry keeps its customer data while changing state', () {
    final entry = QueueEntry(
      id: 'q1',
      customerName: 'Customer',
      customerPhone: '0500000000',
      employeeId: 'barber1',
      joinedAt: DateTime(2026, 1, 1, 10),
    );
    final started = entry.copyWith(
      status: QueueStatus.inService,
      startedAt: DateTime(2026, 1, 1, 10, 15),
    );

    expect(started.status, QueueStatus.inService);
    expect(started.customerName, 'Customer');
    expect(started.startedAt, DateTime(2026, 1, 1, 10, 15));
  });
}
