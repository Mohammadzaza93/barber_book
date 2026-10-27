import '../models/appointment.dart';
import '../models/enums.dart';
import '../models/finance/finance_models.dart';

/// تقرير أداء شامل — مقارنة شهرية وسنوية من البيانات المحلية.
class PerformanceReportService {
  PerformanceReportService._();
  static final instance = PerformanceReportService._();

  PeriodSnapshot snapshot({
    required DateTime from,
    required DateTime to,
    required List<DailyFinanceEntry> financeEntries,
    required List<OperatingExpense> expenses,
    required List<Appointment> appointments,
  }) {
    final end = DateTime(to.year, to.month, to.day, 23, 59, 59);
    final start = DateTime(from.year, from.month, from.day);

    final sales = financeEntries.where((e) {
      final d = e.date;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    final exp = expenses.where((e) {
      final d = e.date;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    final appts = appointments.where((a) {
      final d = a.startTime;
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList();

    final revenue = sales.fold<double>(0, (s, e) => s + e.totalAmount);
    final salonShare = sales.fold<double>(0, (s, e) => s + e.salonShare);
    final barberShare = sales.fold<double>(0, (s, e) => s + e.barberShare);
    final expenseTotal = exp.fold<double>(0, (s, e) => s + e.amountSyp);

    // احتياطي إيراد من المواعيد المكتملة إن لم تُسجَّل مبيعات
    final completed = appts
        .where((a) => a.status == AppointmentStatus.completed)
        .toList();
    final apptRevenue =
        completed.fold<double>(0, (s, a) => s + a.totalAmount);
    final effectiveRevenue = revenue > 0 ? revenue : apptRevenue;

    final bookings = appts
        .where((a) =>
            a.status != AppointmentStatus.cancelled &&
            a.status != AppointmentStatus.noShow)
        .length;
    final completedCount = completed.length;
    final noShows =
        appts.where((a) => a.status == AppointmentStatus.noShow).length;
    final cancelled =
        appts.where((a) => a.status == AppointmentStatus.cancelled).length;

    final days = end.difference(start).inDays + 1;
    final avgTicket = completedCount == 0
        ? 0.0
        : (revenue > 0 ? revenue : apptRevenue) / completedCount;

    return PeriodSnapshot(
      from: start,
      to: end,
      revenue: effectiveRevenue,
      salonShare: revenue > 0 ? salonShare : effectiveRevenue,
      barberShare: revenue > 0 ? barberShare : 0,
      expenses: expenseTotal,
      netProfit: (revenue > 0 ? salonShare : effectiveRevenue) - expenseTotal,
      bookings: bookings,
      completed: completedCount,
      noShows: noShows,
      cancelled: cancelled,
      salesOps: sales.length,
      avgTicket: avgTicket,
      avgDailyRevenue: days <= 0 ? 0 : effectiveRevenue / days,
      dayCount: days,
    );
  }

  /// آخر 12 شهراً تقويمياً (من الأقدم للأحدث).
  List<PeriodSnapshot> last12Months({
    required List<DailyFinanceEntry> financeEntries,
    required List<OperatingExpense> expenses,
    required List<Appointment> appointments,
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final list = <PeriodSnapshot>[];
    for (var i = 11; i >= 0; i--) {
      final ref = DateTime(n.year, n.month - i, 1);
      final from = DateTime(ref.year, ref.month, 1);
      final to = DateTime(ref.year, ref.month + 1, 0);
      list.add(snapshot(
        from: from,
        to: to,
        financeEntries: financeEntries,
        expenses: expenses,
        appointments: appointments,
      ));
    }
    return list;
  }

  /// السنوات المتاحة في البيانات + السنة الحالية.
  List<int> availableYears({
    required List<DailyFinanceEntry> financeEntries,
    required List<Appointment> appointments,
  }) {
    final years = <int>{DateTime.now().year};
    for (final e in financeEntries) {
      years.add(e.date.year);
    }
    for (final a in appointments) {
      years.add(a.startTime.year);
    }
    final sorted = years.toList()..sort();
    return sorted;
  }

  PeriodSnapshot yearSnapshot({
    required int year,
    required List<DailyFinanceEntry> financeEntries,
    required List<OperatingExpense> expenses,
    required List<Appointment> appointments,
  }) {
    return snapshot(
      from: DateTime(year, 1, 1),
      to: DateTime(year, 12, 31),
      financeEntries: financeEntries,
      expenses: expenses,
      appointments: appointments,
    );
  }

  ComparisonResult compare(PeriodSnapshot current, PeriodSnapshot previous) {
    return ComparisonResult(current: current, previous: previous);
  }
}

class PeriodSnapshot {
  final DateTime from;
  final DateTime to;
  final double revenue;
  final double salonShare;
  final double barberShare;
  final double expenses;
  final double netProfit;
  final int bookings;
  final int completed;
  final int noShows;
  final int cancelled;
  final int salesOps;
  final double avgTicket;
  final double avgDailyRevenue;
  final int dayCount;

  const PeriodSnapshot({
    required this.from,
    required this.to,
    required this.revenue,
    required this.salonShare,
    required this.barberShare,
    required this.expenses,
    required this.netProfit,
    required this.bookings,
    required this.completed,
    required this.noShows,
    required this.cancelled,
    required this.salesOps,
    required this.avgTicket,
    required this.avgDailyRevenue,
    required this.dayCount,
  });

  String get monthLabel {
    const names = [
      '',
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return '${names[from.month]} ${from.year}';
  }
}

class ComparisonResult {
  final PeriodSnapshot current;
  final PeriodSnapshot previous;

  const ComparisonResult({required this.current, required this.previous});

  /// نسبة التغير: (الحالي - السابق) / السابق * 100
  double pct(double cur, double prev) {
    if (prev.abs() < 1e-9) {
      if (cur.abs() < 1e-9) return 0;
      return cur > 0 ? 100 : -100;
    }
    return ((cur - prev) / prev.abs()) * 100;
  }

  double get revenuePct => pct(current.revenue, previous.revenue);
  double get expensesPct => pct(current.expenses, previous.expenses);
  double get netPct => pct(current.netProfit, previous.netProfit);
  double get bookingsPct =>
      pct(current.bookings.toDouble(), previous.bookings.toDouble());
  double get completedPct =>
      pct(current.completed.toDouble(), previous.completed.toDouble());
  double get avgTicketPct => pct(current.avgTicket, previous.avgTicket);
}
