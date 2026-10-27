import '../models/appointment.dart';
import '../models/enums.dart';
import '../models/finance/finance_models.dart';

/// تنبؤ إيرادات محلي 100% — بدون APIs أو نماذج مدفوعة.
///
/// يعتمد على:
/// 1) متوسط متحرك بسيط
/// 2) موسمية يوم الأسبوع (مثلاً السبت أعلى من الإثنين)
/// 3) اتجاه خطي بسيط (انحدار على الأيام)
class RevenueForecastService {
  RevenueForecastService._();
  static final instance = RevenueForecastService._();

  /// سلسلة يومية من واردات المالية (المصدر المفضّل).
  Map<DateTime, double> seriesFromFinance(
    List<DailyFinanceEntry> entries, {
    int lookbackDays = 90,
  }) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: lookbackDays - 1));
    final map = <DateTime, double>{};
    for (var i = 0; i < lookbackDays; i++) {
      final d = start.add(Duration(days: i));
      map[DateTime(d.year, d.month, d.day)] = 0;
    }
    for (final e in entries) {
      final key = DateTime(e.date.year, e.date.month, e.date.day);
      if (!map.containsKey(key)) continue;
      map[key] = (map[key] ?? 0) + e.totalAmount;
    }
    return map;
  }

  /// احتياطي من المواعيد المكتملة إذا لم تُسجَّل مبيعات يومية.
  Map<DateTime, double> seriesFromAppointments(
    List<Appointment> appointments, {
    int lookbackDays = 90,
  }) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: lookbackDays - 1));
    final map = <DateTime, double>{};
    for (var i = 0; i < lookbackDays; i++) {
      final d = start.add(Duration(days: i));
      map[DateTime(d.year, d.month, d.day)] = 0;
    }
    for (final a in appointments) {
      if (a.status != AppointmentStatus.completed) continue;
      final key =
          DateTime(a.startTime.year, a.startTime.month, a.startTime.day);
      if (!map.containsKey(key)) continue;
      map[key] = (map[key] ?? 0) + a.totalAmount;
    }
    return map;
  }

  /// يفضّل المالية؛ إن كان مجموعها صفراً تقريباً يستخدم المواعيد.
  Map<DateTime, double> buildSeries({
    required List<DailyFinanceEntry> financeEntries,
    required List<Appointment> appointments,
    int lookbackDays = 90,
  }) {
    final fromFinance =
        seriesFromFinance(financeEntries, lookbackDays: lookbackDays);
    final sumF = fromFinance.values.fold<double>(0, (a, b) => a + b);
    if (sumF > 0) return fromFinance;
    return seriesFromAppointments(appointments, lookbackDays: lookbackDays);
  }

  ForecastResult forecast(
    Map<DateTime, double> series, {
    int horizonDays = 7,
  }) {
    final sortedKeys = series.keys.toList()..sort();
    if (sortedKeys.isEmpty) {
      return ForecastResult.empty();
    }

    final values = sortedKeys.map((k) => series[k] ?? 0).toList();
    final n = values.length;

    // أيام فيها نشاط فعلي
    final activeDays = values.where((v) => v > 0).length;
    final total = values.fold<double>(0, (a, b) => a + b);
    final avgAll = n == 0 ? 0.0 : total / n;

    // متوسط متحرك لآخر 14 يوماً (أو المتاح)
    final window = n >= 14 ? 14 : n;
    final recent = values.sublist(n - window);
    final sma =
        recent.isEmpty ? 0.0 : recent.fold<double>(0, (a, b) => a + b) / recent.length;

    // متوسط لكل يوم أسبوع (0=الإثنين في DateTime.weekday ... 7=الأحد)
    final weekdaySum = List<double>.filled(8, 0);
    final weekdayCount = List<int>.filled(8, 0);
    for (var i = 0; i < sortedKeys.length; i++) {
      final wd = sortedKeys[i].weekday; // 1..7
      weekdaySum[wd] += values[i];
      weekdayCount[wd] += 1;
    }
    final weekdayAvg = List<double>.generate(8, (wd) {
      if (wd == 0 || weekdayCount[wd] == 0) return sma;
      return weekdaySum[wd] / weekdayCount[wd];
    });

    // انحدار خطي بسيط: y = a + b*x على آخر min(30, n) نقطة
    final regN = n >= 30 ? 30 : n;
    final regStart = n - regN;
    var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumXX = 0.0;
    for (var i = 0; i < regN; i++) {
      final x = i.toDouble();
      final y = values[regStart + i];
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumXX += x * x;
    }
    final denom = regN * sumXX - sumX * sumX;
    final slope = denom.abs() < 1e-9 ? 0.0 : (regN * sumXY - sumX * sumY) / denom;
    final intercept =
        regN == 0 ? 0.0 : (sumY - slope * sumX) / regN;

    // توقع كل يوم في الأفق: مزج موسمية الأسبوع + اتجاه
    final lastDay = sortedKeys.last;
    final breakdown = <ForecastDay>[];
    var horizonTotal = 0.0;
    for (var h = 1; h <= horizonDays; h++) {
      final day = lastDay.add(Duration(days: h));
      final seasonal = weekdayAvg[day.weekday];
      // نقطة الاتجاه عند x = regN-1 + h نسبياً من نافذة الانحدار
      final trendPoint = intercept + slope * (regN - 1 + h);
      // مزج: 70% موسمية، 30% اتجاه (مع حماية من السالب)
      final blended = (seasonal * 0.7 + trendPoint * 0.3).clamp(0.0, double.infinity);
      // إن لم توجد بيانات كافية، اقترب من SMA
      final amount = activeDays < 7
          ? sma.clamp(0.0, double.infinity)
          : blended;
      breakdown.add(ForecastDay(date: day, amount: amount));
      horizonTotal += amount;
    }

    // تقدير 30 يوماً بنفس الأسلوب إن طُلب أفق 7 فقط نكرّر المنطق
    var next30 = horizonTotal;
    if (horizonDays < 30) {
      next30 = 0;
      for (var h = 1; h <= 30; h++) {
        final day = lastDay.add(Duration(days: h));
        final seasonal = weekdayAvg[day.weekday];
        final trendPoint = intercept + slope * (regN - 1 + h);
        final blended =
            (seasonal * 0.7 + trendPoint * 0.3).clamp(0.0, double.infinity);
        next30 += activeDays < 7 ? sma.clamp(0.0, double.infinity) : blended;
      }
    }

    final confidence = activeDays >= 28
        ? ForecastConfidence.medium
        : activeDays >= 7
            ? ForecastConfidence.low
            : ForecastConfidence.veryLow;

    return ForecastResult(
      avgDaily: sma,
      avgAllPeriod: avgAll,
      trendPerDay: slope,
      next7Days: horizonDays >= 7
          ? breakdown.take(7).fold<double>(0, (s, d) => s + d.amount)
          : horizonTotal,
      next30Days: next30,
      nextWeek: breakdown.take(7).toList(),
      activeDays: activeDays,
      sampleDays: n,
      confidence: confidence,
      sourceNote: total > 0 ? 'finance_or_appointments' : 'empty',
    );
  }
}

enum ForecastConfidence { veryLow, low, medium }

class ForecastDay {
  final DateTime date;
  final double amount;
  const ForecastDay({required this.date, required this.amount});
}

class ForecastResult {
  final double avgDaily;
  final double avgAllPeriod;
  final double trendPerDay;
  final double next7Days;
  final double next30Days;
  final List<ForecastDay> nextWeek;
  final int activeDays;
  final int sampleDays;
  final ForecastConfidence confidence;
  final String sourceNote;

  const ForecastResult({
    required this.avgDaily,
    required this.avgAllPeriod,
    required this.trendPerDay,
    required this.next7Days,
    required this.next30Days,
    required this.nextWeek,
    required this.activeDays,
    required this.sampleDays,
    required this.confidence,
    required this.sourceNote,
  });

  factory ForecastResult.empty() => const ForecastResult(
        avgDaily: 0,
        avgAllPeriod: 0,
        trendPerDay: 0,
        next7Days: 0,
        next30Days: 0,
        nextWeek: [],
        activeDays: 0,
        sampleDays: 0,
        confidence: ForecastConfidence.veryLow,
        sourceNote: 'empty',
      );

  String get confidenceLabelAr => switch (confidence) {
        ForecastConfidence.medium => 'متوسطة — بيانات كافية تقريباً',
        ForecastConfidence.low => 'منخفضة — يُفضّل أسبوعين+ من التسجيل',
        ForecastConfidence.veryLow => 'ضعيفة جداً — سجّل مبيعات أكثر',
      };

  String get trendLabelAr {
    if (trendPerDay.abs() < 1) return 'مستقر تقريباً';
    if (trendPerDay > 0) {
      return 'صاعد (~${trendPerDay.toStringAsFixed(0)} ل.س/يوم)';
    }
    return 'هابط (~${trendPerDay.abs().toStringAsFixed(0)} ل.س/يوم)';
  }
}
