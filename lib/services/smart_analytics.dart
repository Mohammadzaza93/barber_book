import '../models/appointment.dart';
import '../models/enums.dart';
import '../models/finance/finance_models.dart';
import '../models/service.dart';
import 'performance_report.dart';
import 'revenue_forecast.dart';

enum InsightKind { positive, warning, info, tip }

class SmartInsight {
  final InsightKind kind;
  final String title;
  final String body;
  final IconKey icon;

  const SmartInsight({
    required this.kind,
    required this.title,
    required this.body,
    this.icon = IconKey.insights,
  });
}

enum IconKey { insights, trendingUp, trendingDown, schedule, star, money, people }

class SmartAnalyticsReport {
  final PeriodSnapshot today;
  final PeriodSnapshot thisWeek;
  final PeriodSnapshot thisMonth;
  final PeriodSnapshot lastMonth;
  final ComparisonResult monthVsLast;
  final List<double> forecastNext7;
  final List<SmartInsight> insights;
  final String? topServiceName;
  final String? topStaffName;
  final double peakHourRatio;
  final int peakHour; // 0-23

  const SmartAnalyticsReport({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.lastMonth,
    required this.monthVsLast,
    required this.forecastNext7,
    required this.insights,
    this.topServiceName,
    this.topStaffName,
    this.peakHourRatio = 0,
    this.peakHour = 12,
  });
}

/// تحليلات ذكية محلية — بدون أدوات مدفوعة.
class SmartAnalytics {
  SmartAnalytics._();
  static final instance = SmartAnalytics._();

  SmartAnalyticsReport build({
    required List<DailyFinanceEntry> financeEntries,
    required List<OperatingExpense> expenses,
    required List<Appointment> appointments,
    required List<Service> services,
    Map<String, String> staffNames = const {},
    DateTime? now,
  }) {
    final n = now ?? DateTime.now();
    final perf = PerformanceReportService.instance;

    final todayStart = DateTime(n.year, n.month, n.day);
    final today = perf.snapshot(
      from: todayStart,
      to: todayStart,
      financeEntries: financeEntries,
      expenses: expenses,
      appointments: appointments,
    );

    final weekStart = todayStart.subtract(Duration(days: n.weekday - 1));
    final thisWeek = perf.snapshot(
      from: weekStart,
      to: todayStart,
      financeEntries: financeEntries,
      expenses: expenses,
      appointments: appointments,
    );

    final monthStart = DateTime(n.year, n.month, 1);
    final thisMonth = perf.snapshot(
      from: monthStart,
      to: todayStart,
      financeEntries: financeEntries,
      expenses: expenses,
      appointments: appointments,
    );

    final lastMonthStart = DateTime(n.year, n.month - 1, 1);
    final lastMonthEnd = DateTime(n.year, n.month, 0);
    final lastMonth = perf.snapshot(
      from: lastMonthStart,
      to: lastMonthEnd,
      financeEntries: financeEntries,
      expenses: expenses,
      appointments: appointments,
    );

    final monthVsLast = perf.compare(thisMonth, lastMonth);

    // سلسلة يومية لـ 28 يوماً للتنبؤ
    final series = <double>[];
    for (var i = 27; i >= 0; i--) {
      final d = todayStart.subtract(Duration(days: i));
      final snap = perf.snapshot(
        from: d,
        to: d,
        financeEntries: financeEntries,
        expenses: expenses,
        appointments: appointments,
      );
      series.add(snap.revenue);
    }
    final forecast = RevenueForecast.instance.forecastNextDays(series, days: 7);

    final serviceNames = {for (final s in services) s.id: s.name};
    final topService = _topService(appointments, serviceNames);
    final topStaff = _topStaff(appointments, staffNames);
    final peak = _peakHour(appointments);

    final insights = _buildInsights(
      today: today,
      thisWeek: thisWeek,
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      monthVsLast: monthVsLast,
      forecast: forecast,
      topService: topService,
      topStaff: topStaff,
      peakHour: peak.$1,
      peakRatio: peak.$2,
      appointments: appointments,
    );

    return SmartAnalyticsReport(
      today: today,
      thisWeek: thisWeek,
      thisMonth: thisMonth,
      lastMonth: lastMonth,
      monthVsLast: monthVsLast,
      forecastNext7: forecast,
      insights: insights,
      topServiceName: topService,
      topStaffName: topStaff,
      peakHour: peak.$1,
      peakHourRatio: peak.$2,
    );
  }

  String? _topService(
      List<Appointment> appts, Map<String, String> names) {
    final counts = <String, int>{};
    for (final a in appts) {
      if (a.status == AppointmentStatus.cancelled) continue;
      for (final id in a.serviceIds) {
        counts[id] = (counts[id] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return names[best.key] ?? best.key;
  }

  String? _topStaff(
      List<Appointment> appts, Map<String, String> names) {
    final counts = <String, int>{};
    for (final a in appts) {
      if (a.status != AppointmentStatus.completed) continue;
      counts[a.employeeId] = (counts[a.employeeId] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    final best = counts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    return names[best.key] ?? best.key;
  }

  (int, double) _peakHour(List<Appointment> appts) {
    final hours = List<int>.filled(24, 0);
    var total = 0;
    for (final a in appts) {
      if (a.status == AppointmentStatus.cancelled) continue;
      hours[a.startTime.hour]++;
      total++;
    }
    if (total == 0) return (12, 0);
    var peak = 0;
    for (var h = 1; h < 24; h++) {
      if (hours[h] > hours[peak]) peak = h;
    }
    return (peak, hours[peak] / total);
  }

  List<SmartInsight> _buildInsights({
    required PeriodSnapshot today,
    required PeriodSnapshot thisWeek,
    required PeriodSnapshot thisMonth,
    required PeriodSnapshot lastMonth,
    required ComparisonResult monthVsLast,
    required List<double> forecast,
    required String? topService,
    required String? topStaff,
    required int peakHour,
    required double peakRatio,
    required List<Appointment> appointments,
  }) {
    final list = <SmartInsight>[];

    // مقارنة شهرية
    if (lastMonth.revenue > 0 || thisMonth.revenue > 0) {
      final pct = monthVsLast.revenuePct;
      if (pct >= 10) {
        list.add(SmartInsight(
          kind: InsightKind.positive,
          title: 'نمو الإيراد هذا الشهر',
          body:
              'الإيراد أعلى بحوالي ${pct.toStringAsFixed(0)}% عن الشهر الماضي. استمر على نفس الوتيرة.',
          icon: IconKey.trendingUp,
        ));
      } else if (pct <= -10) {
        list.add(SmartInsight(
          kind: InsightKind.warning,
          title: 'تراجع الإيراد',
          body:
              'انخفاض حوالي ${pct.abs().toStringAsFixed(0)}% عن الشهر الماضي. راجع العروض أو ساعات الذروة.',
          icon: IconKey.trendingDown,
        ));
      }
    }

    // نسبة الإكمال / عدم الحضور
    final relevant = appointments.where((a) =>
        a.status == AppointmentStatus.completed ||
        a.status == AppointmentStatus.noShow ||
        a.status == AppointmentStatus.cancelled);
    final noShow = appointments
        .where((a) => a.status == AppointmentStatus.noShow)
        .length;
    final finished = relevant.length;
    if (finished >= 5) {
      final rate = noShow / finished;
      if (rate >= 0.15) {
        list.add(SmartInsight(
          kind: InsightKind.warning,
          title: 'معدل عدم الحضور مرتفع',
          body:
              '${(rate * 100).toStringAsFixed(0)}% من المواعيد لم يحضر أصحابها. فعّل تذكيرات واتساب أو عربون حجز.',
          icon: IconKey.schedule,
        ));
      } else if (rate <= 0.05) {
        list.add(const SmartInsight(
          kind: InsightKind.positive,
          title: 'التزام ممتاز من الزبائن',
          body: 'نسبة عدم الحضور منخفضة. العملاء ملتزمون بالمواعيد.',
          icon: IconKey.star,
        ));
      }
    }

    // هامش الربح
    if (thisMonth.revenue > 0) {
      final margin = thisMonth.netProfit / thisMonth.revenue;
      if (margin < 0.1) {
        list.add(SmartInsight(
          kind: InsightKind.warning,
          title: 'هامش الربح ضيق',
          body:
              'صافي الربح أقل من 10% من الإيراد هذا الشهر. راجع المصاريف التشغيلية.',
          icon: IconKey.money,
        ));
      } else if (margin >= 0.3) {
        list.add(SmartInsight(
          kind: InsightKind.positive,
          title: 'هامش ربح صحي',
          body:
              'صافي الربح حوالي ${(margin * 100).toStringAsFixed(0)}% من الإيراد.',
          icon: IconKey.money,
        ));
      }
    }

    if (topService != null) {
      list.add(SmartInsight(
        kind: InsightKind.info,
        title: 'الخدمة الأكثر طلباً',
        body: '«$topService» تتصدّر الحجوزات. يمكن رفع سعرها قليلاً أو تقديم باقة معها.',
        icon: IconKey.star,
      ));
    }

    if (topStaff != null) {
      list.add(SmartInsight(
        kind: InsightKind.info,
        title: 'أداء الفريق',
        body: 'أكثر الحلاقين إنجازاً: $topStaff. فكر بمكافأة أو تقييم شهري.',
        icon: IconKey.people,
      ));
    }

    if (peakRatio >= 0.15) {
      list.add(SmartInsight(
        kind: InsightKind.tip,
        title: 'ساعة الذروة',
        body:
            'أكثر الحجوزات حول الساعة ${_fmtHour(peakHour)}. جهّز فريقاً إضافياً في هذا الوقت.',
        icon: IconKey.schedule,
      ));
    }

    // تنبؤ
    if (forecast.isNotEmpty) {
      final sumF = forecast.fold(0.0, (a, b) => a + b);
      final avgPast = thisWeek.avgDailyRevenue;
      if (avgPast > 0 && sumF / 7 > avgPast * 1.15) {
        list.add(SmartInsight(
          kind: InsightKind.tip,
          title: 'توقّع أسبوع أقوى',
          body:
              'النموذج يتوقع إيراداً أعلى من متوسط الأسبوع الحالي. تأكد من توفر المواد والموظفين.',
          icon: IconKey.trendingUp,
        ));
      }
    }

    if (today.bookings == 0 && thisWeek.bookings > 0) {
      list.add(const SmartInsight(
        kind: InsightKind.tip,
        title: 'لا حجوزات لليوم بعد',
        body: 'شارك رابط الحجز أو تواصل مع زبائن منتظمين لملء الجدول.',
        icon: IconKey.schedule,
      ));
    }

    if (list.isEmpty) {
      list.add(const SmartInsight(
        kind: InsightKind.info,
        title: 'ابدأ بتسجيل البيانات',
        body:
            'سجّل وارد الزبائن والمواعيد بانتظام لتحصل على تحليلات أدق وتوقعات أوضح.',
        icon: IconKey.insights,
      ));
    }

    return list;
  }

  String _fmtHour(int h) {
    final period = h < 12 ? 'ص' : 'م';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12 $period';
  }
}
