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

/// تسامح صغير لفروق التقريب في الكميات العشرية (مل / غرام / لتر).
const double kStockEpsilon = 0.0001;

/// حالة جلسة الجرد.
enum StocktakeStatus { draft, posting, completed, cancelled }

StocktakeStatus stocktakeStatusFromName(String? value) => switch (value) {
      'posting' => StocktakeStatus.posting,
      'completed' => StocktakeStatus.completed,
      'cancelled' => StocktakeStatus.cancelled,
      _ => StocktakeStatus.draft,
    };

extension StocktakeStatusX on StocktakeStatus {
  bool get isOpen =>
      this == StocktakeStatus.draft || this == StocktakeStatus.posting;
  String get label => switch (this) {
        StocktakeStatus.draft => 'مسودة',
        StocktakeStatus.posting => 'قيد الترحيل',
        StocktakeStatus.completed => 'مُرحّل',
        StocktakeStatus.cancelled => 'ملغى',
      };
}

/// سطر جرد لمادة واحدة.
///
/// [expectedQty] لقطة من رصيد النظام وقت بدء الجلسة، و[countedQty] ما عدّه
/// المستخدم فعلياً. لا تُكتب الكمية في المخزون إلا عند الترحيل.
class StocktakeLine {
  final String itemId;
  final String itemName;
  final String unit;
  final double unitCost;
  final double expectedQty;
  final double? countedQty;
  final bool posted;
  final DateTime? postedAt;

  /// تعارض: تغيّر رصيد النظام بعد أخذ اللقطة (بيع/صرف أثناء الجرد).
  final bool conflict;
  final double? conflictQty;

  /// سبب تعذّر الترحيل (مادة محذوفة مثلاً).
  final String issue;

  const StocktakeLine({
    required this.itemId,
    required this.itemName,
    this.unit = 'piece',
    this.unitCost = 0,
    required this.expectedQty,
    this.countedQty,
    this.posted = false,
    this.postedAt,
    this.conflict = false,
    this.conflictQty,
    this.issue = '',
  });

  bool get isCounted => countedQty != null;

  /// الفرق = المعدود − رصيد النظام. غير المعدود لا يُحسب.
  double get variance => isCounted ? countedQty! - expectedQty : 0;

  double get varianceValue => variance * unitCost;

  bool get hasVariance => variance.abs() > kStockEpsilon;

  bool get needsAttention => conflict || issue.isNotEmpty;

  StocktakeLine copyWith({
    String? itemName,
    String? unit,
    double? unitCost,
    double? expectedQty,
    double? countedQty,
    bool clearCounted = false,
    bool? posted,
    DateTime? postedAt,
    bool? conflict,
    double? conflictQty,
    bool clearConflict = false,
    String? issue,
  }) =>
      StocktakeLine(
        itemId: itemId,
        itemName: itemName ?? this.itemName,
        unit: unit ?? this.unit,
        unitCost: unitCost ?? this.unitCost,
        expectedQty: expectedQty ?? this.expectedQty,
        countedQty: clearCounted ? null : (countedQty ?? this.countedQty),
        posted: posted ?? this.posted,
        postedAt: postedAt ?? this.postedAt,
        conflict: clearConflict ? false : (conflict ?? this.conflict),
        conflictQty: clearConflict ? null : (conflictQty ?? this.conflictQty),
        issue: issue ?? this.issue,
      );

  Map<String, dynamic> toMap() => {
        'itemId': itemId,
        'itemName': itemName,
        'unit': unit,
        'unitCost': unitCost,
        'expectedQty': expectedQty,
        'countedQty': countedQty,
        'posted': posted,
        'postedAt': postedAt,
        'conflict': conflict,
        'conflictQty': conflictQty,
        'issue': issue,
      };

  factory StocktakeLine.fromMap(Map<String, dynamic> m) => StocktakeLine(
        itemId: (m['itemId'] as String?) ?? '',
        itemName: (m['itemName'] as String?) ?? '',
        unit: (m['unit'] as String?) ?? 'piece',
        unitCost: ((m['unitCost'] as num?) ?? 0).toDouble(),
        expectedQty: ((m['expectedQty'] as num?) ?? 0).toDouble(),
        countedQty: (m['countedQty'] as num?)?.toDouble(),
        posted: (m['posted'] as bool?) ?? false,
        postedAt: _readNullableDate(m['postedAt']),
        conflict: (m['conflict'] as bool?) ?? false,
        conflictQty: (m['conflictQty'] as num?)?.toDouble(),
        issue: (m['issue'] as String?) ?? '',
      );
}

/// جلسة جرد واحدة تحتوي كل سطورها.
///
/// السطور مدمجة في مستند الجلسة عمداً: صالون واحد بعدد مواد محدود، وهذا يقلل
/// القراءات والكتابات على الخطة المجانية (مستند واحد لكل جلسة بدل مستند لكل
/// مادة). الحد الأقصى للسطور يمنع تجاوز حجم المستند.
class Stocktake {
  static const int maxLines = 300;

  final String id;
  final StocktakeStatus status;
  final String note;
  final List<StocktakeLine> lines;
  final DateTime createdAt;
  final String? createdBy;
  final DateTime updatedAt;
  final DateTime? postedAt;
  final String? postedBy;

  const Stocktake({
    required this.id,
    this.status = StocktakeStatus.draft,
    this.note = '',
    this.lines = const [],
    required this.createdAt,
    this.createdBy,
    required this.updatedAt,
    this.postedAt,
    this.postedBy,
  });

  int get itemCount => lines.length;
  int get countedCount => lines.where((l) => l.isCounted).length;
  int get uncountedCount => lines.where((l) => !l.isCounted).length;
  int get postedCount => lines.where((l) => l.posted).length;
  int get varianceCount =>
      lines.where((l) => l.isCounted && l.hasVariance).length;
  int get conflictCount => lines.where((l) => l.needsAttention).length;

  double get totalVarianceValue =>
      lines.fold<double>(0, (sum, line) => sum + line.varianceValue);

  double get totalGainValue => lines
      .where((l) => l.isCounted && l.variance > 0)
      .fold<double>(0, (sum, l) => sum + l.varianceValue);

  double get totalLossValue => lines
      .where((l) => l.isCounted && l.variance < 0)
      .fold<double>(0, (sum, l) => sum + l.varianceValue.abs());

  bool get isOpen => status.isOpen;
  bool get isCompleted => status == StocktakeStatus.completed;
  bool get isCancelled => status == StocktakeStatus.cancelled;

  /// الحذف مسموح للمسودة والملغى فقط؛ المُرحّل و«قيد الترحيل» سجل تدقيق.
  bool get isDeletable =>
      status == StocktakeStatus.draft || status == StocktakeStatus.cancelled;

  /// يمكن الترحيل إذا وُجد سطر معدود لم يُرحّل بعد.
  bool get canPost => isOpen && lines.any((l) => l.isCounted && !l.posted);

  /// كل السطور المعدودة رُحّلت (قد تبقى سطور غير معدودة في جرد جزئي).
  bool get allCountedPosted => lines.every((l) => !l.isCounted || l.posted);

  Stocktake copyWith({
    StocktakeStatus? status,
    String? note,
    List<StocktakeLine>? lines,
    DateTime? updatedAt,
    DateTime? postedAt,
    String? postedBy,
  }) =>
      Stocktake(
        id: id,
        status: status ?? this.status,
        note: note ?? this.note,
        lines: lines ?? this.lines,
        createdAt: createdAt,
        createdBy: createdBy,
        updatedAt: updatedAt ?? this.updatedAt,
        postedAt: postedAt ?? this.postedAt,
        postedBy: postedBy ?? this.postedBy,
      );

  Map<String, dynamic> toMap() => {
        'status': status.name,
        'note': note,
        'lines': lines.map((l) => l.toMap()).toList(),
        'createdAt': createdAt,
        'createdBy': createdBy,
        'updatedAt': updatedAt,
        'postedAt': postedAt,
        'postedBy': postedBy,
      };

  factory Stocktake.fromMap(String id, Map<String, dynamic> m) => Stocktake(
        id: id,
        status: stocktakeStatusFromName(m['status'] as String?),
        note: (m['note'] as String?) ?? '',
        lines: (m['lines'] as List<dynamic>? ?? const [])
            .map((e) =>
                StocktakeLine.fromMap((e as Map).cast<String, dynamic>()))
            .toList(),
        createdAt: _readDate(m['createdAt'] ?? m['updatedAt']),
        createdBy: m['createdBy'] as String?,
        updatedAt: _readDate(m['updatedAt']),
        postedAt: _readNullableDate(m['postedAt']),
        postedBy: m['postedBy'] as String?,
      );
}

/// نتيجة ترحيل جلسة جرد. لا تُعتبر العملية ناجحة إذا بقي تعارض أو فشل سطر.
class StocktakePostResult {
  final String stocktakeId;
  final int posted;
  final int conflicts;
  final int failed;
  final bool completed;
  final Stocktake? session;

  const StocktakePostResult({
    required this.stocktakeId,
    required this.posted,
    required this.conflicts,
    required this.failed,
    required this.completed,
    this.session,
  });

  bool get hasIssues => conflicts > 0 || failed > 0;
  bool get isSuccess => !hasIssues && completed;
}
