enum QueueStatus { waiting, inService, completed, cancelled }

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
        createdAt: (m['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
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
        updatedAt: (m['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
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
  final String? employeeId;
  final bool active;

  const Chair({
    required this.id,
    required this.name,
    this.employeeId,
    this.active = true,
  });

  Chair copyWith({String? name, String? employeeId, bool? active}) => Chair(
        id: id,
        name: name ?? this.name,
        employeeId: employeeId ?? this.employeeId,
        active: active ?? this.active,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'employeeId': employeeId,
        'active': active,
      };

  factory Chair.fromMap(String id, Map<String, dynamic> m) => Chair(
        id: id,
        name: (m['name'] as String?) ?? '',
        employeeId: m['employeeId'] as String?,
        active: (m['active'] as bool?) ?? true,
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
  });

  QueueEntry copyWith({
    String? employeeId,
    String? chairId,
    List<String>? serviceIds,
    QueueStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
  }) => QueueEntry(
        id: id,
        customerName: customerName,
        customerPhone: customerPhone,
        employeeId: employeeId ?? this.employeeId,
        chairId: chairId ?? this.chairId,
        serviceIds: serviceIds ?? this.serviceIds,
        status: status ?? this.status,
        joinedAt: joinedAt,
        startedAt: startedAt ?? this.startedAt,
        completedAt: completedAt ?? this.completedAt,
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
        joinedAt: (m['joinedAt'] as dynamic)?.toDate() ?? DateTime.now(),
        startedAt: (m['startedAt'] as dynamic)?.toDate(),
        completedAt: (m['completedAt'] as dynamic)?.toDate(),
      );
}

class Payment {
  final String id;
  final String appointmentId;
  final String customerName;
  final String customerPhone;
  final double amount;
  final String method;
  final DateTime paidAt;
  final String notes;

  const Payment({
    required this.id,
    required this.appointmentId,
    required this.customerName,
    this.customerPhone = '',
    required this.amount,
    required this.method,
    required this.paidAt,
    this.notes = '',
  });

  Map<String, dynamic> toMap() => {
        'appointmentId': appointmentId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'amount': amount,
        'method': method,
        'paidAt': paidAt,
        'notes': notes,
      };

  factory Payment.fromMap(String id, Map<String, dynamic> m) => Payment(
        id: id,
        appointmentId: (m['appointmentId'] as String?) ?? '',
        customerName: (m['customerName'] as String?) ?? '',
        customerPhone: (m['customerPhone'] as String?) ?? '',
        amount: ((m['amount'] as num?) ?? 0).toDouble(),
        method: (m['method'] as String?) ?? 'cash',
        paidAt: (m['paidAt'] as dynamic)?.toDate() ?? DateTime.now(),
        notes: (m['notes'] as String?) ?? '',
      );
}
