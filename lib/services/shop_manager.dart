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

  /// Clears every shop-scoped value. Called on sign-out and on account/shop
  /// transitions so no previous shop's identity (id, name, timezone) can leak
  /// into the next session.
  static void reset() {
    shopId = null;
    shopName = null;
    timezoneOffsetMinutes = defaultTimezoneOffsetMinutes;
  }
}
