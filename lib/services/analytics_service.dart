import '../models/appointment.dart';
import '../models/enums.dart';
import '../models/expense.dart';
import '../models/service.dart';

class AnalyticsService {
  AnalyticsService._();
  static final instance = AnalyticsService._();

  List<Appointment> _completed(List<Appointment> all) =>
      all.where((a) => a.status == AppointmentStatus.completed).toList();

  double revenue(List<Appointment> all, {DateTime? from, DateTime? to}) {
    var total = 0.0;
    for (final a in _completed(all)) {
      final d = a.startTime;
      if (from != null && d.isBefore(from)) continue;
      if (to != null && d.isAfter(to)) continue;
      total += a.totalAmount;
    }
    return total;
  }

  double revenueForDay(List<Appointment> all, DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    return revenue(
      all,
      from: start,
      to: end.subtract(const Duration(microseconds: 1)),
    );
  }

  int bookingsInRange(List<Appointment> all,
      {DateTime? from, DateTime? to}) {
    return all.where((a) {
      if (a.status == AppointmentStatus.cancelled ||
          a.status == AppointmentStatus.noShow) {
        return false;
      }
      final d = a.startTime;
      if (from != null && d.isBefore(from)) return false;
      if (to != null && d.isAfter(to)) return false;
      return true;
    }).length;
  }

  Map<DateTime, double> dailyRevenue(
      List<Appointment> all, DateTime start, int days) {
    final map = <DateTime, double>{};
    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      map[DateTime(day.year, day.month, day.day)] =
          revenueForDay(all, day);
    }
    return map;
  }

  Map<DateTime, int> dailyBookings(
      List<Appointment> all, DateTime start, int days) {
    final map = <DateTime, int>{};
    for (var i = 0; i < days; i++) {
      final day = start.add(Duration(days: i));
      final from = DateTime(day.year, day.month, day.day);
      final to = from.add(const Duration(days: 1));
      map[from] = bookingsInRange(
        all,
        from: from,
        to: to.subtract(const Duration(microseconds: 1)),
      );
    }
    return map;
  }

  double completionRate(List<Appointment> all) {
    final finished = all.where((a) =>
        a.status == AppointmentStatus.completed ||
        a.status == AppointmentStatus.noShow ||
        a.status == AppointmentStatus.cancelled).length;
    if (finished == 0) return 0;
    return all.where((a) => a.status == AppointmentStatus.completed).length /
        finished * 100;
  }

  Map<String, double> popularServices(
      List<Appointment> all, List<Service> services) {
    final counts = <String, double>{};
    for (final a in _completed(all)) {
      for (final sid in a.serviceIds) {
        counts[sid] = (counts[sid] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((x, y) => y.value.compareTo(x.value));
    final names = <String, double>{};
    for (final e in sorted.take(5)) {
      final s = services.where((x) => x.id == e.key).firstOrNull;
      names[s?.name ?? e.key] = e.value;
    }
    return names;
  }

  Map<String, double> staffPerformance(List<Appointment> all,
      Map<String, String> staffNames) {
    final map = <String, double>{};
    for (final a in _completed(all)) {
      map[staffNames[a.employeeId] ?? a.employeeId] =
          (map[staffNames[a.employeeId] ?? a.employeeId] ?? 0) + a.totalAmount;
    }
    return map;
  }

  double noShowRate(List<Appointment> all) {
    if (all.isEmpty) return 0;
    final relevant = all
        .where((a) => a.status == AppointmentStatus.completed ||
            a.status == AppointmentStatus.noShow ||
            a.status == AppointmentStatus.cancelled)
        .length;
    if (relevant == 0) return 0;
    final noShows = all
        .where((a) => a.status == AppointmentStatus.noShow)
        .length;
    return (noShows / relevant) * 100;
  }

  int uniqueCustomers(List<Appointment> all) =>
      all.map((a) => a.customerPhone.trim().toLowerCase()).toSet().length;

  double avgTicket(List<Appointment> all) {
    final comp = _completed(all);
    if (comp.isEmpty) return 0;
    return revenue(all) / comp.length;
  }

  double netProfit(List<Appointment> all, List<Expense> expenses) =>
      revenue(all) - expenses.fold(0.0, (s, e) => s + e.amount);

  double totalExpenses(List<Expense> expenses, {DateTime? from, DateTime? to}) {
    return expenses
        .where((e) =>
            (from == null || !e.date.isBefore(from)) &&
            (to == null || !e.date.isAfter(to)))
        .fold(0.0, (s, e) => s + e.amount);
  }

  Map<String, double> expensesByCategory(List<Expense> expenses) {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map;
  }
}
