import 'package:cloud_firestore/cloud_firestore.dart';

/// سجل إغلاق يوم تشغيل — يمنع التعديل العشوائي بعد الإغلاق.
class DayCloseRecord {
  final String id; // yyyy-MM-dd
  final DateTime date;
  final int servicesCount;
  final double revenue;
  final double barberShare;
  final double expenses;
  final double net;
  final int chairsWorked;
  final String closedBy;
  final DateTime closedAt;
  final String notes;

  const DayCloseRecord({
    required this.id,
    required this.date,
    required this.servicesCount,
    required this.revenue,
    required this.barberShare,
    required this.expenses,
    required this.net,
    required this.chairsWorked,
    required this.closedBy,
    required this.closedAt,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'servicesCount': servicesCount,
        'revenue': revenue,
        'barberShare': barberShare,
        'expenses': expenses,
        'net': net,
        'chairsWorked': chairsWorked,
        'closedBy': closedBy,
        'closedAt': Timestamp.fromDate(closedAt),
        'notes': notes,
      };

  factory DayCloseRecord.fromMap(String id, Map<String, dynamic> m) =>
      DayCloseRecord(
        id: id,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        servicesCount: (m['servicesCount'] as num?)?.toInt() ?? 0,
        revenue: (m['revenue'] as num?)?.toDouble() ?? 0,
        barberShare: (m['barberShare'] as num?)?.toDouble() ?? 0,
        expenses: (m['expenses'] as num?)?.toDouble() ?? 0,
        net: (m['net'] as num?)?.toDouble() ?? 0,
        chairsWorked: (m['chairsWorked'] as num?)?.toInt() ?? 0,
        closedBy: (m['closedBy'] as String?) ?? '',
        closedAt: (m['closedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        notes: (m['notes'] as String?) ?? '',
      );
}
