import 'firestore_date.dart';

export 'customer_profile.dart';

enum QueueStatus { waiting, inService, completed, cancelled }

/// Falls back to [fallback], then to now, so legacy documents missing a date
/// field still render instead of throwing.
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
  }) => PortfolioItem(
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

  factory PortfolioItem.fromMap(String id, Map<String, dynamic> m) => PortfolioItem(
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
  }) => LoyaltyRule(
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

  factory LoyaltyRule.fromMap(String id, Map<String, dynamic> m) => LoyaltyRule(
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

  bool get isAvailable => active && (stock < 0 || redeemedCount < stock) &&
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
  }) => LoyaltyGift(
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

  factory LoyaltyGift.fromMap(String id, Map<String, dynamic> m) => LoyaltyGift(
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
  }) => LoyaltyAccount(
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

  factory LoyaltyAccount.fromMap(String id, Map<String, dynamic> m) => LoyaltyAccount(
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

class Chair {
  final String id;
  final String name;
  final String number;
  final String? employeeId;
  final bool active;

  const Chair({
    required this.id,
    required this.name,
    this.number = '',
    this.employeeId,
    this.active = true,
  });

  Chair copyWith({String? name, String? number, String? employeeId, bool? active}) => Chair(
        id: id,
        name: name ?? this.name,
        number: number ?? this.number,
        employeeId: employeeId ?? this.employeeId,
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'number': number,
        'employeeId': employeeId,
        'active': active,
      );

  factory Chair.fromMap(String id, Map<String, dynamic> m) => Chair(
        id: id,
        name: (m['name'] as String?) ?? '',
        number: (m['number'] as String?) ?? '',
        employeeId: m['employeeId'] as String?,
        active: (m['active'] as bool?) ?? true,
      );
}
