import 'firestore_date.dart';

export 'customer_profile.dart';
export 'inventory_models.dart';

enum QueueStatus { waiting, inService, completed, cancelled }

DateTime _readDate(dynamic value, [DateTime? fallback]) =>
    readFirestoreDate(value, fallback) ?? DateTime.now().toUtc();

DateTime? _readNullableDate(dynamic value) => readFirestoreDate(value);

class PortfolioItem {
  final String id;
  final String title;
  final String imageUrl;
  final String category;
  final String description;
  final bool active;
  final DateTime createdAt;

  const PortfolioItem({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.category = 'general',
    this.description = '',
    this.active = true,
    required this.createdAt,
  });

  PortfolioItem copyWith({
    String? title,
    String? imageUrl,
    String? category,
    String? description,
    bool? active,
  }) =>
      PortfolioItem(
        id: id,
        title: title ?? this.title,
        imageUrl: imageUrl ?? this.imageUrl,
        category: category ?? this.category,
        description: description ?? this.description,
        active: active ?? this.active,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'title': title,
        'imageUrl': imageUrl,
        'category': category,
        'description': description,
        'active': active,
        'createdAt': createdAt,
      };

  factory PortfolioItem.fromMap(String id, Map<String, dynamic> m) =>
      PortfolioItem(
        id: id,
        title: (m['title'] as String?) ?? '',
        imageUrl: (m['imageUrl'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'general',
        description: (m['description'] as String?) ?? '',
        active: (m['active'] as bool?) ?? true,
        createdAt: _readDate(m['createdAt']),
      );
}

class LoyaltyRule {
  final String id;
  final String name;
  final String description;
  final bool enabled;
  final int pointsPerVisit;
  final double pointsPerCurrency;
  final double minimumSpend;
  final int bonusPoints;
  final int inactiveAfterDays;
  final DateTime updatedAt;

  const LoyaltyRule({
    required this.id,
    required this.name,
    this.description = '',
    this.enabled = true,
    this.pointsPerVisit = 0,
    this.pointsPerCurrency = 1,
    this.minimumSpend = 0,
    this.bonusPoints = 0,
    this.inactiveAfterDays = 45,
    required this.updatedAt,
  });

  int calculatePoints(double amount) {
    if (!enabled || amount < minimumSpend) return 0;
    return (amount * pointsPerCurrency).floor() + pointsPerVisit + bonusPoints;
  }

  LoyaltyRule copyWith({
    String? name,
    String? description,
    bool? enabled,
    int? pointsPerVisit,
    double? pointsPerCurrency,
    double? minimumSpend,
    int? bonusPoints,
    int? inactiveAfterDays,
    DateTime? updatedAt,
  }) =>
      LoyaltyRule(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        enabled: enabled ?? this.enabled,
        pointsPerVisit: pointsPerVisit ?? this.pointsPerVisit,
        pointsPerCurrency: pointsPerCurrency ?? this.pointsPerCurrency,
        minimumSpend: minimumSpend ?? this.minimumSpend,
        bonusPoints: bonusPoints ?? this.bonusPoints,
        inactiveAfterDays: inactiveAfterDays ?? this.inactiveAfterDays,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'enabled': enabled,
        'pointsPerVisit': pointsPerVisit,
        'pointsPerCurrency': pointsPerCurrency,
        'minimumSpend': minimumSpend,
        'bonusPoints': bonusPoints,
        'inactiveAfterDays': inactiveAfterDays,
        'updatedAt': updatedAt,
      };

  factory LoyaltyRule.fromMap(String id, Map<String, dynamic> m) =>
      LoyaltyRule(
        id: id,
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        enabled: (m['enabled'] as bool?) ?? true,
        pointsPerVisit: (m['pointsPerVisit'] as num?)?.toInt() ?? 0,
        pointsPerCurrency: ((m['pointsPerCurrency'] as num?) ?? 1).toDouble(),
        minimumSpend: ((m['minimumSpend'] as num?) ?? 0).toDouble(),
        bonusPoints: (m['bonusPoints'] as num?)?.toInt() ?? 0,
        inactiveAfterDays: (m['inactiveAfterDays'] as num?)?.toInt() ?? 45,
        updatedAt: _readDate(m['updatedAt']),
      );
}

class LoyaltyGift {
  final String id;
  final String name;
  final String description;
  final int pointsCost;
  final String minimumTier;
  final int stock;
  final int redeemedCount;
  final bool active;
  final DateTime? expiresAt;
  final DateTime createdAt;

  const LoyaltyGift({
    required this.id,
    required this.name,
    this.description = '',
    required this.pointsCost,
    this.minimumTier = 'bronze',
    this.stock = -1,
    this.redeemedCount = 0,
    this.active = true,
    this.expiresAt,
    required this.createdAt,
  });

  bool get isAvailable =>
      active &&
      (stock < 0 || redeemedCount < stock) &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  LoyaltyGift copyWith({
    String? name,
    String? description,
    int? pointsCost,
    String? minimumTier,
    int? stock,
    int? redeemedCount,
    bool? active,
    DateTime? expiresAt,
  }) =>
      LoyaltyGift(
        id: id,
        name: name ?? this.name,
        description: description ?? this.description,
        pointsCost: pointsCost ?? this.pointsCost,
        minimumTier: minimumTier ?? this.minimumTier,
        stock: stock ?? this.stock,
        redeemedCount: redeemedCount ?? this.redeemedCount,
        active: active ?? this.active,
        expiresAt: expiresAt ?? this.expiresAt,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'description': description,
        'pointsCost': pointsCost,
        'minimumTier': minimumTier,
        'stock': stock,
        'redeemedCount': redeemedCount,
        'active': active,
        'expiresAt': expiresAt,
        'createdAt': createdAt,
      };

  factory LoyaltyGift.fromMap(String id, Map<String, dynamic> m) =>
      LoyaltyGift(
        id: id,
        name: (m['name'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        pointsCost: (m['pointsCost'] as num?)?.toInt() ?? 0,
        minimumTier: (m['minimumTier'] as String?) ?? 'bronze',
        stock: (m['stock'] as num?)?.toInt() ?? -1,
        redeemedCount: (m['redeemedCount'] as num?)?.toInt() ?? 0,
        active: (m['active'] as bool?) ?? true,
        expiresAt: _readNullableDate(m['expiresAt']),
        createdAt: _readDate(m['createdAt']),
      );
}

class LoyaltyAccount {
  final String id;
  final String customerName;
  final String customerPhone;
  final int points;
  final String tier;
  final DateTime updatedAt;

  const LoyaltyAccount({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.points = 0,
    this.tier = 'bronze',
    required this.updatedAt,
  });

  LoyaltyAccount copyWith({
    String? customerName,
    String? customerPhone,
    int? points,
    String? tier,
    DateTime? updatedAt,
  }) =>
      LoyaltyAccount(
        id: id,
        customerName: customerName ?? this.customerName,
        customerPhone: customerPhone ?? this.customerPhone,
        points: points ?? this.points,
        tier: tier ?? this.tier,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'customerPhone': customerPhone,
        'points': points,
        'tier': tier,
        'updatedAt': updatedAt,
      };

  factory LoyaltyAccount.fromMap(String id, Map<String, dynamic> m) =>
      LoyaltyAccount(
        id: id,
        customerName: (m['customerName'] as String?) ?? '',
        customerPhone: (m['customerPhone'] as String?) ?? '',
        points: (m['points'] as num?)?.toInt() ?? 0,
        tier: (m['tier'] as String?) ?? 'bronze',
        updatedAt: _readDate(m['updatedAt']),
      );

  String get calculatedTier {
    if (points >= 1000) return 'platinum';
    if (points >= 500) return 'gold';
    if (points >= 200) return 'silver';
    return 'bronze';
  }
}

enum ChairFloorKind { idle, busy, onBreak }

class Chair {
  final String id;
  final String name;
  final String number;
  final String? employeeId;
  final bool active;
  final bool onBreak;
  final DateTime? breakStartedAt;

  const Chair({
    required this.id,
    required this.name,
    this.number = '',
    this.employeeId,
    this.active = true,
    this.onBreak = false,
    this.breakStartedAt,
  });

  Chair copyWith({
    String? name,
    String? number,
    String? employeeId,
    bool? active,
    bool? onBreak,
    DateTime? breakStartedAt,
    bool clearBreakStartedAt = false,
  }) =>
      Chair(
        id: id,
        name: name ?? this.name,
        number: number ?? this.number,
        employeeId: employeeId ?? this.employeeId,
        active: active ?? this.active,
        onBreak: onBreak ?? this.onBreak,
        breakStartedAt: clearBreakStartedAt
            ? null
            : (breakStartedAt ?? this.breakStartedAt),
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'number': number,
        'employeeId': employeeId,
        'active': active,
        'onBreak': onBreak,
        'breakStartedAt': breakStartedAt,
      };

  factory Chair.fromMap(String id, Map<String, dynamic> m) => Chair(
        id: id,
        name: (m['name'] as String?) ?? '',
        number: (m['number'] as String?) ?? '',
        employeeId: m['employeeId'] as String?,
        active: (m['active'] as bool?) ?? true,
        onBreak: (m['onBreak'] as bool?) ?? false,
        breakStartedAt: _readNullableDate(m['breakStartedAt']),
      );
}

class ChairSupply {
  final String id;
  final String chairId;
  final String name;
  final String category;
  final String unit;
  final double quantity;
  final double unitCost;
  final double reorderLevel;
  final DateTime updatedAt;

  const ChairSupply({
    required this.id,
    required this.chairId,
    required this.name,
    this.category = 'general',
    this.unit = 'piece',
    this.quantity = 0,
    this.unitCost = 0,
    this.reorderLevel = 0,
    required this.updatedAt,
  });

  double get stockValue => quantity * unitCost;
  bool get lowStock => quantity <= reorderLevel;

  ChairSupply copyWith({
    String? chairId,
    String? name,
    String? category,
    String? unit,
    double? quantity,
    double? unitCost,
    double? reorderLevel,
    DateTime? updatedAt,
  }) =>
      ChairSupply(
        id: id,
        chairId: chairId ?? this.chairId,
        name: name ?? this.name,
        category: category ?? this.category,
        unit: unit ?? this.unit,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
        reorderLevel: reorderLevel ?? this.reorderLevel,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'chairId': chairId,
        'name': name,
        'category': category,
        'unit': unit,
        'quantity': quantity,
        'unitCost': unitCost,
        'reorderLevel': reorderLevel,
        'updatedAt': updatedAt,
      };

  factory ChairSupply.fromMap(String id, Map<String, dynamic> m) =>
      ChairSupply(
        id: id,
        chairId: (m['chairId'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'general',
        unit: (m['unit'] as String?) ?? 'piece',
        quantity: ((m['quantity'] as num?) ?? 0).toDouble(),
        unitCost: ((m['unitCost'] as num?) ?? 0).toDouble(),
        reorderLevel: ((m['reorderLevel'] as num?) ?? 0).toDouble(),
        updatedAt: _readDate(m['updatedAt']),
      );
}

class ChairWeeklyProfit {
  final String id;
  final String chairId;
  final DateTime weekStart;
  final DateTime weekEnd;
  final double revenue;
  final double supplyCost;
  final double? manualProfit;
  final int completedVisits;
  final int workingMinutes;
  final String notes;
  final DateTime updatedAt;

  const ChairWeeklyProfit({
    required this.id,
    required this.chairId,
    required this.weekStart,
    required this.weekEnd,
    this.revenue = 0,
    this.supplyCost = 0,
    this.manualProfit,
    this.completedVisits = 0,
    this.workingMinutes = 0,
    this.notes = '',
    required this.updatedAt,
  });

  double get profit => manualProfit ?? (revenue - supplyCost);
  double get utilizationPercent => workingMinutes <= 0
      ? 0
      : ((workingMinutes / (7 * 8 * 60)) * 100).clamp(0, 100).toDouble();

  ChairWeeklyProfit copyWith({
    double? revenue,
    double? supplyCost,
    double? manualProfit,
    int? completedVisits,
    int? workingMinutes,
    String? notes,
    DateTime? updatedAt,
  }) =>
      ChairWeeklyProfit(
        id: id,
        chairId: chairId,
        weekStart: weekStart,
        weekEnd: weekEnd,
        revenue: revenue ?? this.revenue,
        supplyCost: supplyCost ?? this.supplyCost,
        manualProfit: manualProfit ?? this.manualProfit,
        completedVisits: completedVisits ?? this.completedVisits,
        workingMinutes: workingMinutes ?? this.workingMinutes,
        notes: notes ?? this.notes,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => {
        'chairId': chairId,
        'weekStart': weekStart,
        'weekEnd': weekEnd,
        'revenue': revenue,
        'supplyCost': supplyCost,
        'manualProfit': manualProfit,
        'completedVisits': completedVisits,
        'workingMinutes': workingMinutes,
        'notes': notes,
        'updatedAt': updatedAt,
      };

  factory ChairWeeklyProfit.fromMap(String id, Map<String, dynamic> m) =>
      ChairWeeklyProfit(
        id: id,
        chairId: (m['chairId'] as String?) ?? '',
        weekStart: _readDate(m['weekStart']),
        weekEnd: _readDate(m['weekEnd']),
        revenue: ((m['revenue'] as num?) ?? 0).toDouble(),
        supplyCost: ((m['supplyCost'] as num?) ?? 0).toDouble(),
        manualProfit: (m['manualProfit'] as num?)?.toDouble(),
        completedVisits: (m['completedVisits'] as num?)?.toInt() ?? 0,
        workingMinutes: (m['workingMinutes'] as num?)?.toInt() ?? 0,
        notes: (m['notes'] as String?) ?? '',
        updatedAt: _readDate(m['updatedAt']),
      );
}

class QueueEntry {
  final String id;
  final String customerName;
  final String customerPhone;
  final String employeeId;
  final String? chairId;
  final List<String> serviceIds;
  final QueueStatus status;
  final DateTime joinedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final int priority;

  const QueueEntry({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.employeeId,
    this.chairId,
    this.serviceIds = const [],
    this.status = QueueStatus.waiting,
    required this.joinedAt,
    this.startedAt,
    this.completedAt,
    this.priority = 0,
  });

  QueueEntry copyWith({
    String? employeeId,
    String? chairId,
    List<String>? serviceIds,
    QueueStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    int? priority,
    bool clearChairId = false,
    bool clearStartedAt = false,
  }) =>
      QueueEntry(
        id: id,
        customerName: customerName,
        customerPhone: customerPhone,
        employeeId: employeeId ?? this.employeeId,
        chairId: clearChairId ? null : (chairId ?? this.chairId),
        serviceIds: serviceIds ?? this.serviceIds,
        status: status ?? this.status,
        joinedAt: joinedAt,
        startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
        completedAt: completedAt ?? this.completedAt,
        priority: priority ?? this.priority,
      );

  Map<String, dynamic> toMap() => {
        'customerName': customerName,
        'customerPhone': customerPhone,
        'employeeId': employeeId,
        'chairId': chairId,
        'serviceIds': serviceIds,
        'status': status.name,
        'joinedAt': joinedAt,
        'startedAt': startedAt,
        'completedAt': completedAt,
        'priority': priority,
      };

  factory QueueEntry.fromMap(String id, Map<String, dynamic> m) => QueueEntry(
        id: id,
        customerName: (m['customerName'] as String?) ?? '',
        customerPhone: (m['customerPhone'] as String?) ?? '',
        employeeId: (m['employeeId'] as String?) ?? '',
        chairId: m['chairId'] as String?,
        serviceIds: (m['serviceIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        status: QueueStatus.values.firstWhere(
          (x) => x.name == m['status'],
          orElse: () => QueueStatus.waiting,
        ),
        joinedAt: _readDate(m['joinedAt']),
        startedAt: _readNullableDate(m['startedAt']),
        completedAt: _readNullableDate(m['completedAt']),
        priority: (m['priority'] as num?)?.toInt() ?? 0,
      );
}

class Payment {
  final String id;
  final String appointmentId;
  final String customerName;
  final String customerPhone;
  final String? chairId;
  final String? employeeId;
  final double amount;
  final double materialCost;
  final String method;
  final DateTime paidAt;
  final String notes;

  const Payment({
    required this.id,
    required this.appointmentId,
    required this.customerName,
    this.customerPhone = '',
    this.chairId,
    this.employeeId,
    required this.amount,
    this.materialCost = 0,
    required this.method,
    required this.paidAt,
    this.notes = '',
  });

  double get profit => amount - materialCost;

  Map<String, dynamic> toMap() => {
        'appointmentId': appointmentId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'chairId': chairId,
        'employeeId': employeeId,
        'amount': amount,
        'materialCost': materialCost,
        'method': method,
        'paidAt': paidAt,
        'notes': notes,
      };

  factory Payment.fromMap(String id, Map<String, dynamic> m) => Payment(
        id: id,
        appointmentId: (m['appointmentId'] as String?) ?? '',
        customerName: (m['customerName'] as String?) ?? '',
        customerPhone: (m['customerPhone'] as String?) ?? '',
        chairId: m['chairId'] as String?,
        employeeId: m['employeeId'] as String?,
        amount: ((m['amount'] as num?) ?? 0).toDouble(),
        materialCost: ((m['materialCost'] as num?) ?? 0).toDouble(),
        method: (m['method'] as String?) ?? 'cash',
        paidAt: _readDate(m['paidAt']),
        notes: (m['notes'] as String?) ?? '',
      );
}
