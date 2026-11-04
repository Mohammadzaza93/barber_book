import '../models/inventory_models.dart';

/// إحصاء مادة واحدة داخل فترة زمنية.
class ItemMovementStats {
  final String itemId;
  final int movementCount;
  final double purchasedQty;
  final double purchasedValue;
  final double usedQty;
  final double usedValue;
  final double wastedQty;
  final double wastedValue;
  final double adjustmentGainValue;
  final double adjustmentLossValue;
  final DateTime? lastMovementAt;

  const ItemMovementStats({
    required this.itemId,
    this.movementCount = 0,
    this.purchasedQty = 0,
    this.purchasedValue = 0,
    this.usedQty = 0,
    this.usedValue = 0,
    this.wastedQty = 0,
    this.wastedValue = 0,
    this.adjustmentGainValue = 0,
    this.adjustmentLossValue = 0,
    this.lastMovementAt,
  });

  bool get hasActivity => movementCount > 0;
  double get wasteValue => wastedValue;
  double get netAdjustmentValue => adjustmentGainValue - adjustmentLossValue;
}

/// تقرير مخزون لفترة: إجماليات + تفصيل لكل مادة.
class InventoryPeriodReport {
  final DateTime from;
  final DateTime to;
  final List<InventoryMovement> movements;
  final List<ItemMovementStats> items;

  const InventoryPeriodReport({
    required this.from,
    required this.to,
    required this.movements,
    required this.items,
  });

  int get movementCount => movements.length;
  double get purchasedValue =>
      items.fold<double>(0, (sum, item) => sum + item.purchasedValue);
  double get usedValue =>
      items.fold<double>(0, (sum, item) => sum + item.usedValue);
  double get wastedValue =>
      items.fold<double>(0, (sum, item) => sum + item.wastedValue);
  double get adjustmentGainValue =>
      items.fold<double>(0, (sum, item) => sum + item.adjustmentGainValue);
  double get adjustmentLossValue =>
      items.fold<double>(0, (sum, item) => sum + item.adjustmentLossValue);

  /// صافي التغيّر القيمي للمخزون خلال الفترة.
  double get netChangeValue =>
      purchasedValue +
      adjustmentGainValue -
      usedValue -
      wastedValue -
      adjustmentLossValue;

  bool get isEmpty => movements.isEmpty;

  ItemMovementStats? forItem(String itemId) {
    for (final item in items) {
      if (item.itemId == itemId) return item;
    }
    return null;
  }

  List<ItemMovementStats> topConsumed(int limit) {
    final list = items.where((item) => item.usedValue > 0).toList()
      ..sort((a, b) => b.usedValue.compareTo(a.usedValue));
    return list.take(limit).toList();
  }

  List<ItemMovementStats> topWasted(int limit) {
    final list = items.where((item) => item.wastedValue > 0).toList()
      ..sort((a, b) => b.wastedValue.compareTo(a.wastedValue));
    return list.take(limit).toList();
  }

  List<ItemMovementStats> topPurchased(int limit) {
    final list = items.where((item) => item.purchasedValue > 0).toList()
      ..sort((a, b) => b.purchasedValue.compareTo(a.purchasedValue));
    return list.take(limit).toList();
  }
}

/// اقتراح شراء لمادة ناقصة.
class RestockSuggestion {
  final InventoryItem item;
  final double quantity;
  final String reason;

  const RestockSuggestion({
    required this.item,
    required this.quantity,
    required this.reason,
  });

  double get estimatedCost => quantity * item.unitCost;
}

/// ملخص صحة المخزون في لحظة معيّنة.
class InventoryHealth {
  final int activeItems;
  final int outOfStock;
  final int lowStock;
  final int expiringSoon;
  final int expired;
  final int inactive;
  final double totalValue;

  const InventoryHealth({
    this.activeItems = 0,
    this.outOfStock = 0,
    this.lowStock = 0,
    this.expiringSoon = 0,
    this.expired = 0,
    this.inactive = 0,
    this.totalValue = 0,
  });

  int get needsAttention => outOfStock + lowStock + expiringSoon + expired;
}

/// حسابات مخزون نقية (بلا Firestore) — قابلة للاختبار.
class InventoryAnalytics {
  InventoryAnalytics._();

  /// تقرير فترة من الحركات. لا يحتاج أي فهرس أو خدمة خارجية.
  static InventoryPeriodReport periodReport({
    required Iterable<InventoryMovement> movements,
    required DateTime from,
    DateTime? to,
  }) {
    final end = to ?? DateTime.now();
    final filtered = movements
        .where((m) => !m.createdAt.isBefore(from) && !m.createdAt.isAfter(end))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final byItem = <String, _MutableStats>{};
    for (final movement in filtered) {
      final stats = byItem.putIfAbsent(
        movement.itemId,
        () => _MutableStats(movement.itemId),
      );
      stats.movementCount++;
      stats.lastMovementAt = movement.createdAt;
      final value = movement.quantity * movement.unitCost;
      switch (movement.type) {
        case 'purchase':
          stats.purchasedQty += movement.quantity;
          stats.purchasedValue += value;
        case 'usage':
          stats.usedQty += movement.quantity;
          stats.usedValue += value;
        case 'waste':
        case 'damage':
        case 'expiry':
          stats.wastedQty += movement.quantity;
          stats.wastedValue += value;
        case 'adjustment':
          final delta = movement.signedDelta;
          if (delta >= 0) {
            stats.adjustmentGainValue += delta * movement.unitCost;
          } else {
            stats.adjustmentLossValue += -delta * movement.unitCost;
          }
      }
    }

    final items = byItem.values.map((s) => s.freeze()).toList()
      ..sort((a, b) => b.usedValue.compareTo(a.usedValue));

    return InventoryPeriodReport(
      from: from,
      to: end,
      movements: List.unmodifiable(filtered),
      items: List.unmodifiable(items),
    );
  }

  /// إحصاء مادة واحدة من الحركات المحمّلة.
  static ItemMovementStats itemStats({
    required Iterable<InventoryMovement> movements,
    required String itemId,
    required DateTime from,
    DateTime? to,
  }) {
    final report = periodReport(movements: movements, from: from, to: to);
    return report.forItem(itemId) ?? ItemMovementStats(itemId: itemId);
  }

  /// المواد التي تحتاج شراءً: نافدة أو تحت حد إعادة الطلب.
  static List<RestockSuggestion> restockSuggestions(
    Iterable<InventoryItem> items,
  ) {
    final suggestions = <RestockSuggestion>[];
    for (final item in items) {
      if (!item.active) continue;
      final isOut = item.quantity <= 0;
      if (!isOut && !item.lowStock) continue;

      var quantity = item.suggestedReorder;
      if (quantity <= kStockEpsilon) {
        if (item.reorderLevel > 0) {
          quantity = item.reorderLevel - item.quantity;
        } else {
          quantity = 1;
        }
      }
      if (quantity <= kStockEpsilon) quantity = 1;

      suggestions.add(
        RestockSuggestion(
          item: item,
          quantity: quantity,
          reason: isOut ? 'نافد' : 'تحت الحد',
        ),
      );
    }
    suggestions.sort((a, b) {
      final aOut = a.item.quantity <= 0 ? 0 : 1;
      final bOut = b.item.quantity <= 0 ? 0 : 1;
      if (aOut != bOut) return aOut.compareTo(bOut);
      return b.estimatedCost.compareTo(a.estimatedCost);
    });
    return suggestions;
  }

  /// مواد راكدة: نشطة ولها رصيد ولم تُحرَّك منذ [from].
  static List<InventoryItem> slowMovingItems({
    required Iterable<InventoryItem> items,
    required Iterable<InventoryMovement> movements,
    required DateTime from,
    int limit = 20,
  }) {
    final touched = movements
        .where((m) => !m.createdAt.isBefore(from))
        .map((m) => m.itemId)
        .toSet();
    final list = items
        .where((i) => i.active && i.quantity > 0 && !touched.contains(i.id))
        .toList()
      ..sort((a, b) => b.stockValue.compareTo(a.stockValue));
    return list.take(limit).toList();
  }

  /// مواد تنتهي صلاحيتها خلال [withinDays] يوماً.
  static List<InventoryItem> expiringItems(
    Iterable<InventoryItem> items, {
    int withinDays = 30,
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final list = items
        .where((item) =>
            item.active &&
            item.expiresAt != null &&
            item.expiresAt!.isAfter(reference) &&
            item.expiresAt!.difference(reference).inDays <= withinDays)
        .toList()
      ..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));
    return list;
  }

  /// مواد منتهية الصلاحية وما زال لها رصيد.
  static List<InventoryItem> expiredItems(
    Iterable<InventoryItem> items, {
    DateTime? now,
  }) {
    final reference = now ?? DateTime.now();
    final list = items
        .where((item) =>
            item.active &&
            item.quantity > 0 &&
            item.expiresAt != null &&
            !item.expiresAt!.isAfter(reference))
        .toList()
      ..sort((a, b) => a.expiresAt!.compareTo(b.expiresAt!));
    return list;
  }

  /// ملخص سريع لصحة المخزون.
  static InventoryHealth health(Iterable<InventoryItem> items) {
    var active = 0;
    var out = 0;
    var low = 0;
    var expiring = 0;
    var expired = 0;
    var inactive = 0;
    var value = 0.0;
    for (final item in items) {
      if (!item.active) {
        inactive++;
        continue;
      }
      active++;
      value += item.stockValue;
      if (item.outOfStock) {
        out++;
      } else if (item.lowStock) {
        low++;
      }
      if (item.isExpired && item.quantity > 0) {
        expired++;
      } else if (item.expiringSoon) {
        expiring++;
      }
    }
    return InventoryHealth(
      activeItems: active,
      outOfStock: out,
      lowStock: low,
      expiringSoon: expiring,
      expired: expired,
      inactive: inactive,
      totalValue: value,
    );
  }

  /// رسالة تعارض إن كان الاسم/SKU/الباركود مستخدماً لصنف آخر.
  static String? duplicateItemError(
    Iterable<InventoryItem> items,
    InventoryItem candidate,
  ) {
    final name = candidate.name.trim().toLowerCase();
    final sku = candidate.sku.trim().toLowerCase();
    final barcode = candidate.barcode.trim();
    for (final other in items) {
      if (other.id == candidate.id) continue;
      if (name.isNotEmpty && other.name.trim().toLowerCase() == name) {
        return 'يوجد صنف بنفس الاسم: ${other.name}';
      }
      if (sku.isNotEmpty && other.sku.trim().toLowerCase() == sku) {
        return 'رمز SKU مستخدم في: ${other.name}';
      }
      if (barcode.isNotEmpty && other.barcode.trim() == barcode) {
        return 'الباركود مستخدم في: ${other.name}';
      }
    }
    return null;
  }
}

class _MutableStats {
  final String itemId;
  int movementCount = 0;
  double purchasedQty = 0;
  double purchasedValue = 0;
  double usedQty = 0;
  double usedValue = 0;
  double wastedQty = 0;
  double wastedValue = 0;
  double adjustmentGainValue = 0;
  double adjustmentLossValue = 0;
  DateTime? lastMovementAt;

  _MutableStats(this.itemId);

  ItemMovementStats freeze() => ItemMovementStats(
        itemId: itemId,
        movementCount: movementCount,
        purchasedQty: purchasedQty,
        purchasedValue: purchasedValue,
        usedQty: usedQty,
        usedValue: usedValue,
        wastedQty: wastedQty,
        wastedValue: wastedValue,
        adjustmentGainValue: adjustmentGainValue,
        adjustmentLossValue: adjustmentLossValue,
        lastMovementAt: lastMovementAt,
      );
}
