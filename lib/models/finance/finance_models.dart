import 'package:cloud_firestore/cloud_firestore.dart';

enum ExpenseType { fixed, recurring, material, fuel, laundry, marketing, other }
enum PaymentMethod { cash, card, transfer, other }
enum BarberPayType { percent, fixed }

class StartupCost {
  final String id;
  final String title;
  final double amountSyp;
  final DateTime date;
  final String notes;
  final String category;

  StartupCost({
    required this.id,
    required this.title,
    required this.amountSyp,
    required this.date,
    this.notes = '',
    this.category = 'other',
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'amountSyp': amountSyp,
        'date': Timestamp.fromDate(date),
        'notes': notes,
        'category': category,
      };

  factory StartupCost.fromMap(String id, Map<String, dynamic> m) => StartupCost(
        id: id,
        title: m['title'] ?? '',
        amountSyp: (m['amountSyp'] as num?)?.toDouble() ?? 0,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        notes: m['notes'] ?? '',
        category: m['category'] ?? 'other',
      );
}

class OperatingExpense {
  final String id;
  final String title;
  final double amountSyp;
  final DateTime date;
  final ExpenseType type;
  final String notes;
  final bool isRecurring;

  OperatingExpense({
    required this.id,
    required this.title,
    required this.amountSyp,
    required this.date,
    required this.type,
    this.notes = '',
    this.isRecurring = false,
  });

  Map<String, dynamic> toMap() => {
        'title': title,
        'amountSyp': amountSyp,
        'date': Timestamp.fromDate(date),
        'type': type.name,
        'notes': notes,
        'isRecurring': isRecurring,
      };

  factory OperatingExpense.fromMap(String id, Map<String, dynamic> m) =>
      OperatingExpense(
        id: id,
        title: m['title'] ?? '',
        amountSyp: (m['amountSyp'] as num?)?.toDouble() ?? 0,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        type: ExpenseType.values.firstWhere(
            (e) => e.name == (m['type'] ?? 'other'),
            orElse: () => ExpenseType.other),
        notes: m['notes'] ?? '',
        isRecurring: m['isRecurring'] ?? false,
      );
}

class BarberSettlement {
  final String barberId;
  final String barberName;
  final BarberPayType payType;
  final double percent;
  final double fixedRate;
  final bool active;

  BarberSettlement({
    required this.barberId,
    required this.barberName,
    this.payType = BarberPayType.percent,
    this.percent = 50,
    this.fixedRate = 0,
    this.active = true,
  });

  Map<String, dynamic> toMap() => {
        'barberId': barberId,
        'barberName': barberName,
        'payType': payType.name,
        'percent': percent,
        'fixedRate': fixedRate,
        'active': active,
      };

  factory BarberSettlement.fromMap(Map<String, dynamic> m) => BarberSettlement(
        barberId: m['barberId'] ?? '',
        barberName: m['barberName'] ?? '',
        payType: BarberPayType.values.firstWhere(
            (e) => e.name == (m['payType'] ?? 'percent'),
            orElse: () => BarberPayType.percent),
        percent: (m['percent'] as num?)?.toDouble() ?? 50,
        fixedRate: (m['fixedRate'] as num?)?.toDouble() ?? 0,
        active: m['active'] ?? true,
      );

  BarberSettlement copyWith(
      {BarberPayType? payType, double? percent, double? fixedRate}) {
    return BarberSettlement(
      barberId: barberId,
      barberName: barberName,
      payType: payType ?? this.payType,
      percent: percent ?? this.percent,
      fixedRate: fixedRate ?? this.fixedRate,
      active: active,
    );
  }
}

class DailyFinanceEntry {
  final String id;
  final DateTime date;
  final String customerName;
  final String serviceName;
  final double totalAmount;
  final String barberId;
  final String barberName;
  final double barberPercent;
  final double materialCost;
  final double netAfterMaterial;
  final double barberShare;
  final double salonShare;
  final PaymentMethod paymentMethod;
  final String notes;
  final bool manualBarberShare;
  /// بقشيش منفصل عن أجرة الخدمة (لا يدخل في تقسيم الصالون/الحلاق تلقائياً).
  final double tipAmount;

  DailyFinanceEntry({
    required this.id,
    required this.date,
    required this.customerName,
    required this.serviceName,
    required this.totalAmount,
    required this.barberId,
    required this.barberName,
    required this.barberPercent,
    this.materialCost = 0,
    required this.netAfterMaterial,
    required this.barberShare,
    required this.salonShare,
    this.paymentMethod = PaymentMethod.cash,
    this.notes = '',
    this.manualBarberShare = true,
    this.tipAmount = 0,
  });

  /// ما دفعه الزبون فعلياً = أجرة الخدمة + البقشيش.
  double get collectedTotal => totalAmount + tipAmount;

  Map<String, dynamic> toMap() => {
        'date': Timestamp.fromDate(date),
        'customerName': customerName,
        'serviceName': serviceName,
        'totalAmount': totalAmount,
        'barberId': barberId,
        'barberName': barberName,
        'barberPercent': barberPercent,
        'materialCost': materialCost,
        'netAfterMaterial': netAfterMaterial,
        'barberShare': barberShare,
        'salonShare': salonShare,
        'paymentMethod': paymentMethod.name,
        'notes': notes,
        'manualBarberShare': manualBarberShare,
        'tipAmount': tipAmount,
      };

  factory DailyFinanceEntry.fromMap(String id, Map<String, dynamic> m) =>
      DailyFinanceEntry(
        id: id,
        date: (m['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        customerName: m['customerName'] ?? '',
        serviceName: m['serviceName'] ?? '',
        totalAmount: (m['totalAmount'] as num?)?.toDouble() ?? 0,
        barberId: m['barberId'] ?? '',
        barberName: m['barberName'] ?? '',
        barberPercent: (m['barberPercent'] as num?)?.toDouble() ?? 0,
        materialCost: (m['materialCost'] as num?)?.toDouble() ?? 0,
        netAfterMaterial: (m['netAfterMaterial'] as num?)?.toDouble() ?? 0,
        barberShare: (m['barberShare'] as num?)?.toDouble() ?? 0,
        salonShare: (m['salonShare'] as num?)?.toDouble() ?? 0,
        paymentMethod: PaymentMethod.values.firstWhere(
            (e) => e.name == (m['paymentMethod'] ?? 'cash'),
            orElse: () => PaymentMethod.cash),
        notes: m['notes'] ?? '',
        manualBarberShare: m['manualBarberShare'] ?? true,
        tipAmount: (m['tipAmount'] as num?)?.toDouble() ?? 0,
      );
}

class CashBoxSplit {
  final double barberWages;
  final double operatingMaterials;
  final double generatorFuel;
  final double laundryTowels;
  final double netProfit;

  const CashBoxSplit({
    required this.barberWages,
    required this.operatingMaterials,
    required this.generatorFuel,
    required this.laundryTowels,
    required this.netProfit,
  });
}
