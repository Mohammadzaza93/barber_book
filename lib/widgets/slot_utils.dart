import '../models/appointment.dart';
import '../models/enums.dart';
import '../models/employee.dart';

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

bool _overlaps(DateTime s1, DateTime e1, DateTime s2, DateTime e2) =>
    s1.isBefore(e2) && s2.isBefore(e1);

/// Generates free time slots for an employee on a given day.
List<DateTime> generateSlots({
  required Employee employee,
  required List<Appointment> appointments,
  required DateTime day,
  required int durationMinutes,
  int stepMinutes = 15,
}) {
  final result = <DateTime>[];
  final slots = employee.workingHours[day.weekday];
  if (slots == null || slots.isEmpty) return result;

  final dayStart = DateTime(day.year, day.month, day.day);
  final busy = appointments
      .where((a) =>
          a.employeeId == employee.id &&
          a.status != AppointmentStatus.cancelled &&
          a.status != AppointmentStatus.noShow &&
          _sameDay(a.startTime, day))
      .map((a) => (start: a.startTime, end: a.endTime))
      .toList();

  final now = DateTime.now();
  for (final ws in slots) {
    final start = dayStart.add(Duration(minutes: ws.startMinutes));
    final end = dayStart.add(Duration(minutes: ws.endMinutes));
    var cursor = start;
    while (cursor
            .add(Duration(minutes: durationMinutes))
            .compareTo(end) <=
        0) {
      final slotEnd = cursor.add(Duration(minutes: durationMinutes));
      final free = cursor.isAfter(now) &&
          !busy.any((b) => _overlaps(cursor, slotEnd, b.start, b.end));
      if (free) result.add(cursor);
      cursor = cursor.add(Duration(minutes: stepMinutes));
    }
  }
  return result;
}

/// Simple RRULE-based occurrence expansion for weekly recurring appointments.
List<DateTime> expandWeeklySeries({
  required DateTime first,
  required int count,
}) {
  final out = <DateTime>[first];
  for (var i = 1; i < count; i++) {
    out.add(first.add(Duration(days: 7 * i)));
  }
  return out;
}
