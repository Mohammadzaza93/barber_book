import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/booking_settings.dart';
import 'package:barber_app/models/discount.dart';
import 'package:barber_app/models/service.dart';
import 'package:barber_app/services/booking_calc.dart';

void main() {
  group('computeDiscount', () {
    test('calculates a percentage discount and caps it at the total', () {
      final discount = Discount(
        id: 'd1',
        code: 'SAVE20',
        type: 'percent',
        value: 20,
        maxDiscount: 0,
        active: true,
        usageCount: 0,
      );

      expect(computeDiscount(discount, 100), 20);
      expect(computeDiscount(discount, 0), 0);
    });

    test('honours the maximum discount limit', () {
      final discount = Discount(
        id: 'd2',
        code: 'CAP',
        type: 'percent',
        value: 50,
        maxDiscount: 30,
        active: true,
        usageCount: 0,
      );

      expect(computeDiscount(discount, 100), 30);
    });
  });

  group('computeDeposit', () {
    test('returns zero when deposits are disabled', () {
      final settings = BookingSettings(depositsEnabled: false);
      expect(computeDeposit(settings, const [], 100), 0);
    });

    test('calculates a percentage deposit for regular bookings', () {
      final settings = BookingSettings(
        depositsEnabled: true,
        depositPercent: 25,
        depositHighDemandOnly: false,
      );
      expect(computeDeposit(settings, const [], 200), 50);
    });

    test('uses the fixed amount for a high-demand service when present', () {
      final settings = BookingSettings(
        depositsEnabled: true,
        depositPercent: 25,
        depositHighDemandOnly: true,
      );
      final service = Service(
        id: 's1',
        name: 'Premium Cut',
        price: 100,
        durationMinutes: 45,
        highDemand: true,
        depositAmount: 35,
      );

      expect(computeDeposit(settings, [service], 100), 35);
    });
  });
}
