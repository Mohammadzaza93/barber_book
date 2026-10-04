/// Single source of truth for parsing date-like values that arrive from
/// Firestore documents and from Cloud Functions callable responses.
///
/// The same logical field can arrive in several shapes:
///
///  * Firestore `Timestamp`   -> `.toDate()`
///  * Callable response       -> ISO-8601 `String` (functions `toIso()`)
///  * Client-side `DateTime`  -> passed straight through
///  * Epoch millis            -> legacy/seeded `int`
///
/// Every value is normalized to a UTC-flagged [DateTime] so that comparisons
/// against [DateTime.now] are epoch-correct regardless of source shape.
library;

/// Parses [value] into a UTC [DateTime].
///
/// Returns [fallback] when [value] is `null` or cannot be interpreted.
/// Never throws.
DateTime? readFirestoreDate(dynamic value, [DateTime? fallback]) {
  if (value == null) return fallback;

  if (value is DateTime) return value.toUtc();

  if (value is int) {
    return DateTime.fromMillisecondsSinceEpoch(value, isUtc: true);
  }

  if (value is double) {
    return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  }

  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    final parsed = DateTime.tryParse(trimmed);
    if (parsed == null) {
      final asEpoch = int.tryParse(trimmed);
      if (asEpoch == null) return fallback;
      return DateTime.fromMillisecondsSinceEpoch(asEpoch, isUtc: true);
    }
    return parsed.toUtc();
  }

  // Firestore Timestamp: duck-typed via `toDate()` so this file stays free of
  // a cloud_firestore import (keeps it trivially unit-testable).
  try {
    final asDate = (value as dynamic).toDate() as DateTime;
    return asDate.toUtc();
  } catch (_) {
    return fallback;
  }
}

/// Same as [readFirestoreDate] but guarantees a non-null result, falling back
/// to [DateTime.now] when the value is absent or unparseable.
DateTime readFirestoreDateOrNow(dynamic value) =>
    readFirestoreDate(value) ?? DateTime.now().toUtc();