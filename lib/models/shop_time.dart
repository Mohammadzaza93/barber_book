/// Day-boundary helpers for the shop's wall clock.
///
/// Appointments are persisted as UTC instants and parsed with UTC-flagged
/// `DateTime`s, while "which day is this?" is a shop-local question. Building
/// the boundary with `DateTime(y, m, d)` silently uses the *device* zone, so a
/// device outside the shop's timezone bucketed appointments into the wrong day
/// (and "today" shifted). These helpers build the day window from the shop's
/// own UTC offset instead, matching `functions/src/lib/time.js`.
library;

// Re-exported so call sites that already import this file do not also need
// `firestore_date.dart`.
export 'firestore_date.dart' show readFirestoreDate, readFirestoreDateOrNow;

/// The shop-local calendar day (year, month, day) that contains [instant].
({int year, int month, int day}) shopLocalDay(
  DateTime instant,
  int offsetMinutes,
) {
  final shifted =
      DateTime.fromMillisecondsSinceEpoch(
        instant.millisecondsSinceEpoch + offsetMinutes * 60000,
        isUtc: true,
      );
  return (year: shifted.year, month: shifted.month, day: shifted.day);
}

/// Start of the shop-local day containing [instant], as a UTC instant.
DateTime shopDayStart(DateTime instant, int offsetMinutes) {
  final local = shopLocalDay(instant, offsetMinutes);
  return DateTime.utc(local.year, local.month, local.day)
      .subtract(Duration(minutes: offsetMinutes));
}

/// Exclusive end of the shop-local day containing [instant], as a UTC instant.
DateTime shopDayEnd(DateTime instant, int offsetMinutes) =>
    shopDayStart(instant, offsetMinutes).add(const Duration(days: 1));

/// Whether [instant] falls on the shop-local day containing [reference].
/// [reference] defaults to now, giving an "is this today?" check.
bool isSameShopDay(
  DateTime instant,
  DateTime reference,
  int offsetMinutes,
) {
  final a = shopLocalDay(instant, offsetMinutes);
  final b = shopLocalDay(reference, offsetMinutes);
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// Start of the shop-local week (Monday) containing [instant], as UTC.
DateTime shopWeekStart(DateTime instant, int offsetMinutes) {
  final local = shopLocalDay(instant, offsetMinutes);
  // Built from the shop-local calendar date, so its `weekday` is the
  // shop-local weekday. Reading the weekday off a UTC instant instead would
  // shift the week boundary by a day for shops ahead of UTC.
  final localMidnight = DateTime.utc(local.year, local.month, local.day);
  return localMidnight
      .subtract(Duration(days: localMidnight.weekday - 1))
      .subtract(Duration(minutes: offsetMinutes));
}

/// Start of the shop-local month containing [instant], as UTC.
DateTime shopMonthStart(DateTime instant, int offsetMinutes) {
  final local = shopLocalDay(instant, offsetMinutes);
  return DateTime.utc(local.year, local.month, 1)
      .subtract(Duration(minutes: offsetMinutes));
}