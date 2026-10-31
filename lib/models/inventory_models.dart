import 'firestore_date.dart';

DateTime _readDate(dynamic value, [DateTime? fallback]) =>
    readFirestoreDate(value, fallback) ?? DateTime.now().toUtc();

DateTime? _readNullableDate(dynamic value) => readFirestoreDate(value);

/// مادة مخزون — صالون واحد، تقييم بتكلفة آخر شراء.
class InventoryItem {
  final String id;
  final String name;
  final String sku;
  final String barcode;
  final String category;
  final String brand;
  final String description;
  final String unit;
  final double quantity;
  /// تكلفة الوحدة = آخر سعر شراء (طريقة أ).
  final double unitCost;
  final double reorderLevel;
  final double maxStock;
  final double reorderQty;
  final String supplier;
  final String location;
  final DateTime? expiresAt;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;
  final String? updatedBy;
  /// خدمات تُستهلك منها هذه المادة تلقائياً عند التحصيل.
  final List<String> linkedServiceIds;
  /// الكمية المخصومة لكل عملية خدمة مرتبطة.
  final double consumePerUse;

  const InventoryItem({
    required this.id,
    required this.name,
    this.sku = '',
    this.barcode = '',
    this.category = 'general',
    this.brand = '',
    this.description = '',
    this.unit = 'piece',
    this.quantity = 0,
    this.unitCost = 0,
    this.reorderLevel = 0,
    this.maxStock = 0,
    this.reorderQty = 0,
    this.supplier = '',
    this.location = '',
    this.expiresAt,
    this.active = true,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
    this.updatedBy,
    this.linkedServiceIds = const [],
    this.consumePerUse = 0,
  });

  /// قيمة المخزون = الكمية × تكلفة آخر شراء.
  double get stockValue => quantity * unitCost;

  bool get lowStock => active && quantity > 0 && quantity <= reorderLevel;
  bool get outOfStock => active && quantity <= 0;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get expiringSoon {
    if (expiresAt == null || isExpired) return false;
    return expiresAt!.difference(DateTime.now()).inDays <= 30;
  }

  /// اقتراح طلب: إن وُجد هدف (maxStock) وإلا reorderQty أو الفرق عن الحد.
  double get suggestedReorder {
    if (!active) return 0;
    if (maxStock > 0) {
      final s = maxStock - quantity;
      return s > 0 ? s : 0;
    }
    if (reorderQty > 0 && lowStock) return reorderQty;
    if (lowStock) {
      final s = reorderLevel * 2 - quantity;
      return s > 0 ? s : 0;
    }
    return 0;
  }

  InventoryItem copyWith({
    String? name,
    String? sku,
    String? barcode,
    String? category,
    String? brand,
    String? description,
    String? unit,
    double? quantity,
    double? unitCost,
    double? reorderLevel,
    double? maxStock,
    double? reorderQty,
    String? supplier,
    String? location,
    DateTime? expiresAt,
    bool clearExpiresAt = false,
    bool? active,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
    List<String>? linkedServiceIds,
    double? consumePerUse,
  }) =>
      InventoryItem(
        id: id,
        name: name ?? this.name,
        sku: sku ?? this.sku,
        barcode: barcode ?? this.barcode,
        category: category ?? this.category,
        brand: brand ?? this.brand,
        description: description ?? this.description,
        unit: unit ?? this.unit,
        quantity: quantity ?? this.quantity,
        unitCost: unitCost ?? this.unitCost,
        reorderLevel: reorderLevel ?? this.reorderLevel,
        maxStock: maxStock ?? this.maxStock,
        reorderQty: reorderQty ?? this.reorderQty,
        supplier: supplier ?? this.supplier,
        location: location ?? this.location,
        expiresAt: clearExpiresAt ? null : (expiresAt ?? this.expiresAt),
        active: active ?? this.active,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        createdBy: createdBy ?? this.createdBy,
        updatedBy: updatedBy ?? this.updatedBy,
        linkedServiceIds: linkedServiceIds ?? this.linkedServiceIds,
        consumePerUse: consumePerUse ?? this.consumePerUse,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'sku': sku,
        'barcode': barcode,
        'category': category,
        'brand': brand,
        'description': description,
        'unit': unit,
        'quantity': quantity,
        'unitCost': unitCost,
        'reorderLevel': reorderLevel,
        'maxStock': maxStock,
        'reorderQty': reorderQty,
        'supplier': supplier,
        'location': location,
        'expiresAt': expiresAt,
        'active': active,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'createdBy': createdBy,
        'updatedBy': updatedBy,
        'valuationMethod': 'last_purchase',
        'linkedServiceIds': linkedServiceIds,
        'consumePerUse': consumePerUse,
      };

  factory InventoryItem.fromMap(String id, Map<String, dynamic> m) =>
      InventoryItem(
        id: id,
        name: (m['name'] as String?) ?? '',
        sku: (m['sku'] as String?) ?? '',
        barcode: (m['barcode'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'general',
        brand: (m['brand'] as String?) ?? '',
        description: (m['description'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? 'piece',
        quantity: ((m['quantity'] as num?) ?? 0).toDouble(),
        unitCost: ((m['unitCost'] as num?) ?? 0).toDouble(),
        reorderLevel: ((m['reorderLevel'] as num?) ?? 0).toDouble(),
        maxStock: ((m['maxStock'] as num?) ?? 0).toDouble(),
        reorderQty: ((m['reorderQty'] as num?) ?? 0).toDouble(),
        supplier: (m['supplier'] as String?) ?? '',
        location: (m['location'] as String?) ?? '',
        expiresAt: _readNullableDate(m['expiresAt']),
        active: (m['active'] as bool?) ?? true,
        createdAt: _readDate(m['createdAt'] ?? m['updatedAt']),
        updatedAt: _readDate(m['updatedAt']),
        createdBy: m['createdBy'] as String?,
        updatedBy: m['updatedBy'] as String?,
        linkedServiceIds: (m['linkedServiceIds'] as List<dynamic>? ?? const [])
            .map((e) => e.toString())
            .toList(),
        consumePerUse: ((m['consumePerUse'] as num?) ?? 0).toDouble(),
      );
}

/// حركة مخزون غير قابلة للحذف المباشر.
class InventoryMovement {
  final String id;
  final String itemId;
  /// purchase | usage | waste | adjustment | damage | expiry
  final String type;
  /// كمية موجبة دائماً؛ الإشارة من النوع.
  final double quantity;
  final double unitCost;
  final String reason;
  final double? balanceBefore;
  final double? balanceAfter;
  final String? actorId;
  final DateTime createdAt;

  const InventoryMovement({
    required this.id,
    required this.itemId,
    required this.type,
    this.quantity = 0,
    this.unitCost = 0,
    this.reason = '',
    this.balanceBefore,
    this.balanceAfter,
    this.actorId,
    required this.createdAt,
  });

  double get signedDelta {
    switch (type) {
      case 'purchase':
        return quantity;
      case 'usage':
      case 'waste':
      case 'damage':
      case 'expiry':
        return -quantity;
      case 'adjustment':
        if (balanceBefore != null && balanceAfter != null) {
          return balanceAfter! - balanceBefore!;
        }
        return 0;
      default:
        return 0;
    }
  }

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'type': type,
        'quantity': quantity,
        'unitCost': unitCost,
        'reason': reason,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
        'actorId': actorId,
        'createdAt': createdAt,
      };

  factory InventoryMovement.fromMap(String id, Map<String, dynamic> m) =>
      InventoryMovement(
        id: id,
        itemId: (m['itemId'] as String?) ?? '',
        type: (m['type'] as String?) ?? 'adjustment',
        quantity: ((m['quantity'] as num?) ?? 0).toDouble(),
        unitCost: ((m['unitCost'] as num?) ?? 0).toDouble(),
        reason: (m['reason'] as String?) ?? '',
        balanceBefore: (m['balanceBefore'] as num?)?.toDouble(),
        balanceAfter: (m['balanceAfter'] as num?)?.toDouble(),
        actorId: m['actorId'] as String?,
        createdAt: _readDate(m['createdAt']),
      );
}
