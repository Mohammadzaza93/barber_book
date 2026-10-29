import '../models/business_features.dart';
import '../models/customer_profile.dart';
import '../models/finance/finance_models.dart';
import '../models/inventory_models.dart';

/// مساعدات تشغيل يومية مجانية (حسابات فقط).
class OpsHelpers {
  /// متوسط مدة الخدمة من آخر [sample] خدمات مكتملة (بالدقائق).
  static int avgServiceMinutes(List<QueueEntry> queue, {int sample = 20}) {
    final done = queue
        .where((e) =>
            e.status == QueueStatus.completed &&
            e.startedAt != null &&
            e.completedAt != null)
        .toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
    final take = done.take(sample).toList();
    if (take.isEmpty) return 25;
    final total = take.fold<int>(
      0,
      (s, e) => s + e.completedAt!.difference(e.startedAt!).inMinutes,
    );
    final avg = (total / take.length).round();
    return avg.clamp(10, 120);
  }

  /// تقدير انتظار الدقائق للطابور الحالي.
  static int estimatedWaitMinutes({
    required List<QueueEntry> queue,
    required int waitingAhead,
  }) {
    final avg = avgServiceMinutes(queue);
    final inService =
        queue.where((e) => e.status == QueueStatus.inService).length;
    final load = waitingAhead + (inService > 0 ? inService : 0);
    return (load * avg * 0.7).round().clamp(0, 240);
  }

  /// عملاء يستحقون اتصال: آخر زيارة منذ أيام كثيرة أو لم يزوروا.
  static List<CustomerProfile> customersToCall(
    List<CustomerProfile> customers, {
    int inactiveDays = 30,
    int limit = 50,
  }) {
    final list = customers.where((c) {
      if (c.phone.trim().isEmpty) return false;
      final days = c.daysSinceLastVisit;
      if (days == null) return c.visitCount == 0;
      return days >= inactiveDays;
    }).toList()
      ..sort((a, b) {
        final da = a.daysSinceLastVisit ?? 9999;
        final db = b.daysSinceLastVisit ?? 9999;
        return db.compareTo(da);
      });
    return list.take(limit).toList();
  }

  /// مواد تحت حد إعادة الطلب.
  static List<InventoryItem> lowStockItems(List<InventoryItem> items) {
    return items
        .where((i) => i.active && i.quantity <= i.reorderLevel)
        .toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));
  }

  static String csvEscape(String v) {
    final s = v.replaceAll('"', '""');
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"$s"';
    }
    return s;
  }

  static String dailySalesCsv(List<DailyFinanceEntry> entries) {
    final buf = StringBuffer();
    buf.writeln(
        'date,customer,service,total,barber,barberShare,salonShare,method,notes');
    for (final e in entries) {
      buf.writeln([
        e.date.toIso8601String(),
        csvEscape(e.customerName),
        csvEscape(e.serviceName),
        e.totalAmount.toStringAsFixed(2),
        csvEscape(e.barberName),
        e.barberShare.toStringAsFixed(2),
        e.salonShare.toStringAsFixed(2),
        e.paymentMethod.name,
        csvEscape(e.notes),
      ].join(','));
    }
    return buf.toString();
  }

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);
  static DateTime dayEnd(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59);

  static DateTime weekStart(DateTime d) {
    final day = dayStart(d);
    return day.subtract(Duration(days: day.weekday - 1));
  }
}
