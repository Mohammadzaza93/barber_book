import '../models/booking_settings.dart';

class ShopManager {
  static String? shopId;
  static String? shopName;

  /// Minutes east of UTC for the shop's wall clock.
  ///
  /// Kept here (rather than injected) because day-bucketing is needed by
  /// providers and screens that have no reference to `ShopProvider`, and
  /// `RootGate` rebuilds cannot safely call `notifyListeners()` mid-build.
  static int timezoneOffsetMinutes = defaultTimezoneOffsetMinutes;
}
