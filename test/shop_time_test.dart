import 'package:barber_app/models/booking_settings.dart';
import 'package:barber_app/models/shop_time.dart';
import 'package:flutter_test/flutter_test.dart';

/// Riyadh is UTC+3 (`DEFAULT_OFFSET_MINUTES = 180`).
const riyadh = 180;

void main() {
  group('shopDayStart / shopDayEnd', () {
    test('an instant before local midnight belongs to the previous day', () {
      // 22:30 UTC on the 15th is 01:30 on the 16th in Riyadh.
      final instant = DateTime.utc(2026, 1, 15, 22, 30);
      expect(shopDayStart(instant, riyadh), DateTime.utc(2026, 1, 15, 21));
    });

    test('an instant after local midnight belongs to the same UTC day', () {
      // 02:00 UTC on the 16th is 05:00 on the 16th in Riyadh.
      final instant = DateTime.utc(2026, 1, 16, 2);
      expect(shopDayStart(instant, riyadh), DateTime.utc(2026, 1, 15, 21));
      expect(shopDayEnd(instant, riyadh), DateTime.utc(2026, 1, 16, 21));
    });

    test('the window spans exactly 24 hours', () {
      final instant = DateTime.utc(2026, 3, 10, 5);
      expect(
        shopDayEnd(instant, riyadh).difference(shopDayStart(instant, riyadh)),
        const Duration(days: 1),
      );
    });

    test('negative offsets shift the window the other way', () {
      // 02:00 UTC on the 16th is 21:00 on the 15th at UTC-5.
      final instant = DateTime.utc(2026, 1, 16, 2);
      expect(shopDayStart(instant, -300), DateTime.utc(2026, 1, 15, 5));
    });
  });

  group('isSameShopDay', () {
    test('groups by the shop day, not the UTC day', () {
      // 23:30 UTC on the 15th -> 02:30 on the 16th in Riyadh.
      final lateNight = DateTime.utc(2026, 1, 15, 23, 30);
      final morning = DateTime.utc(2026, 1, 16, 6);
      expect(isSameShopDay(lateNight, morning, riyadh), isTrue);
    });

    test('separates genuinely different shop days', () {
      expect(
        isSameShopDay(
            DateTime.utc(2026, 1, 15, 12), DateTime.utc(2026, 1, 16, 12), riyadh),
        isFalse,
      );
    });

    test('is stable for a full shop day regardless of UTC date', () {
      final start = shopDayStart(DateTime.utc(2026, 1, 16, 0), riyadh);
      for (var i = 0; i < 24 * 60; i += 30) {
        final instant = start.add(Duration(minutes: i));
        expect(
          isSameShopDay(instant, start, riyadh),
          isTrue,
          reason: 'mismatch at ${instant.toIso8601String()}',
        );
      }
    });
  });

  group('shopWeekStart / shopMonthStart', () {
    test('week starts on Monday in the shop zone', () {
      // 2026-01-15 is a Thursday; Monday is the 12th.
      final start = shopWeekStart(DateTime.utc(2026, 1, 15, 12), riyadh);
      expect(start.toUtc(), DateTime.utc(2026, 1, 11, 21));
    });

    test('month starts on the 1st at local midnight', () {
      final start = shopMonthStart(DateTime.utc(2026, 2, 14, 12), riyadh);
      expect(start.toUtc(), DateTime.utc(2026, 1, 31, 21));
    });
  });

  group('BookingSettings.timezoneOffsetMinutes', () {
    test('defaults to 180 when absent', () {
      final s = BookingSettings.fromMap(const {});
      expect(s.timezoneOffsetMinutes, defaultTimezoneOffsetMinutes);
      expect(s.timezoneOffsetMinutes, 180);
    });

    test('reads the stored offset', () {
      final s = BookingSettings.fromMap(const {'timezoneOffsetMinutes': -300});
      expect(s.timezoneOffsetMinutes, -300);
    });

    test('clamps to the server range', () {
      expect(
        BookingSettings.fromMap(const {'timezoneOffsetMinutes': 5000})
            .timezoneOffsetMinutes,
        840,
      );
      expect(
        BookingSettings.fromMap(const {'timezoneOffsetMinutes': -5000})
            .timezoneOffsetMinutes,
        -840,
      );
    });

    test('round-trips through toMap', () {
      final s = BookingSettings.fromMap(const {'timezoneOffsetMinutes': 210});
      expect(s.toMap()['timezoneOffsetMinutes'], 210);
    });

    test('ignores a non-numeric value', () {
      final s = BookingSettings.fromMap(const {'timezoneOffsetMinutes': 'x'});
      expect(s.timezoneOffsetMinutes, defaultTimezoneOffsetMinutes);
    });
  });
}