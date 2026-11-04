import '../models/appointment.dart';
import '../models/enums.dart';

/// قيمة مع تكرار — تُستخدم للخدمات والحلاقين الأكثر طلباً.
class ValueCount {
  final String id;
  final int count;

  const ValueCount(this.id, this.count);
}

/// إحصاء شهر واحد لزبون.
class CustomerMonthStat {
  final int year;
  final int month;
  final int visits;
  final int cancellations;
  final int noShows;
  final double spent;

  const CustomerMonthStat({
    required this.year,
    required this.month,
    this.visits = 0,
    this.cancellations = 0,
    this.noShows = 0,
    this.spent = 0,
  });

  int get activity => visits + cancellations + noShows;
  bool get isEmpty => activity == 0 && spent.abs() < 0.005;
}

/// تحليل كامل لسجل زبون من مواعيده.
///
/// يُحسب من كل تاريخ المواعيد (وليس نافذة تحميل محددة)، لذلك يصلح لتحليل
/// سنة كاملة أو أكثر. لا يعتمد على Firestore كي يبقى قابلاً للاختبار.
class CustomerInsights {
  /// كل المواعيد مرتبة تصاعدياً حسب وقت البداية.
  final List<Appointment> appointments;

  /// الزيارات المكتملة فقط.
  final List<Appointment> completed;

  final int visitCount;
  final int cancellationCount;
  final int noShowCount;
  final double totalSpent;
  final double averageTicket;
  final DateTime? firstVisitAt;
  final DateTime? lastVisitAt;
  final DateTime? nextAppointmentAt;

  /// متوسط الفاصل بين الزيارات المكتملة (بالأيام).
  final double averageIntervalDays;

  /// الخدمات الأكثر طلباً (معرّفات) مرتبة تنازلياً.
  final List<ValueCount> topServiceIds;

  /// الحلاقون الأكثر زيارةً (معرّفات) مرتبة تنازلياً.
  final List<ValueCount> topEmployeeIds;

  /// السنوات المتاحة في السجل، تنازلياً، وتشمل السنة الحالية دائماً.
  final List<int> years;

  const CustomerInsights({
    required this.appointments,
    required this.completed,
    required this.visitCount,
    required this.cancellationCount,
    required this.noShowCount,
    required this.totalSpent,
    required this.averageTicket,
    required this.firstVisitAt,
    required this.lastVisitAt,
    required this.nextAppointmentAt,
    required this.averageIntervalDays,
    required this.topServiceIds,
    required this.topEmployeeIds,
    required this.years,
  });

  bool get hasHistory => appointments.isNotEmpty;
  bool get hasVisits => completed.isNotEmpty;

  /// المبلغ المحصّل فعلياً إن وُجد، وإلا قيمة الموعد. لا نجمع الاثنين.
  static double amountOf(Appointment appointment) =>
      appointment.collectedAmount > 0
          ? appointment.collectedAmount
          : appointment.totalAmount;

  factory CustomerInsights.from(
    Iterable<Appointment> source, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final list = source.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final completed = list
        .where((a) => a.status == AppointmentStatus.completed)
        .toList(growable: false);
    final cancelled = list
        .where((a) => a.status == AppointmentStatus.cancelled)
        .toList(growable: false);
    final noShows = list
        .where((a) => a.status == AppointmentStatus.noShow)
        .toList(growable: false);

    var totalSpent = 0.0;
    final serviceCounts = <String, int>{};
    final employeeCounts = <String, int>{};
    for (final appointment in completed) {
      totalSpent += amountOf(appointment);
      for (final id in appointment.serviceIds) {
        if (id.trim().isEmpty) continue;
        serviceCounts[id] = (serviceCounts[id] ?? 0) + 1;
      }
      if (appointment.employeeId.trim().isNotEmpty) {
        employeeCounts[appointment.employeeId] =
            (employeeCounts[appointment.employeeId] ?? 0) + 1;
      }
    }

    var intervalTotal = 0.0;
    for (var i = 1; i < completed.length; i++) {
      intervalTotal += completed[i]
              .startTime
              .difference(completed[i - 1].startTime)
              .inMinutes /
          1440;
    }

    Appointment? next;
    for (final appointment in list) {
      if (appointment.startTime.isBefore(reference)) continue;
      if (appointment.status != AppointmentStatus.confirmed &&
          appointment.status != AppointmentStatus.requested) {
        continue;
      }
      next = appointment;
      break;
    }

    final yearSet = <int>{
      for (final appointment in list) appointment.startTime.year,
      reference.year,
    };
    final years = yearSet.toList()..sort((a, b) => b.compareTo(a));

    return CustomerInsights(
      appointments: List.unmodifiable(list),
      completed: List.unmodifiable(completed),
      visitCount: completed.length,
      cancellationCount: cancelled.length,
      noShowCount: noShows.length,
      totalSpent: totalSpent,
      averageTicket: completed.isEmpty ? 0 : totalSpent / completed.length,
      firstVisitAt: completed.isEmpty ? null : completed.first.startTime,
      lastVisitAt: completed.isEmpty ? null : completed.last.startTime,
      nextAppointmentAt: next?.startTime,
      averageIntervalDays:
          completed.length < 2 ? 0 : intervalTotal / (completed.length - 1),
      topServiceIds: _rank(serviceCounts),
      topEmployeeIds: _rank(employeeCounts),
      years: List.unmodifiable(years),
    );
  }

  /// إحصاء كل شهور سنة معينة (12 شهراً، بما فيها الفارغة).
  List<CustomerMonthStat> monthsFor(int year) {
    final visits = List<int>.filled(12, 0);
    final cancellations = List<int>.filled(12, 0);
    final noShows = List<int>.filled(12, 0);
    final spent = List<double>.filled(12, 0);

    for (final appointment in appointments) {
      if (appointment.startTime.year != year) continue;
      final month = appointment.startTime.month - 1;
      switch (appointment.status) {
        case AppointmentStatus.completed:
          visits[month]++;
          spent[month] += amountOf(appointment);
        case AppointmentStatus.cancelled:
          cancellations[month]++;
        case AppointmentStatus.noShow:
          noShows[month]++;
        case AppointmentStatus.requested:
        case AppointmentStatus.confirmed:
          break;
      }
    }

    return List<CustomerMonthStat>.generate(
      12,
      (i) => CustomerMonthStat(
        year: year,
        month: i + 1,
        visits: visits[i],
        cancellations: cancellations[i],
        noShows: noShows[i],
        spent: spent[i],
      ),
    );
  }

  /// إجمالي سنة كاملة.
  CustomerMonthStat totalFor(int year) {
    var visits = 0;
    var cancellations = 0;
    var noShows = 0;
    var spent = 0.0;
    for (final month in monthsFor(year)) {
      visits += month.visits;
      cancellations += month.cancellations;
      noShows += month.noShows;
      spent += month.spent;
    }
    return CustomerMonthStat(
      year: year,
      month: 0,
      visits: visits,
      cancellations: cancellations,
      noShows: noShows,
      spent: spent,
    );
  }

  static List<ValueCount> _rank(Map<String, int> counts) {
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return List.unmodifiable(
      entries.map((e) => ValueCount(e.key, e.value)),
    );
  }
}
