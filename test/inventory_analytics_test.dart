import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/inventory_models.dart';
import 'package:barber_app/services/inventory_analytics.dart';

void main() {
  final now = DateTime.utc(2026, 11, 4, 12);
  final from = DateTime.utc(2026, 10, 1);

  InventoryItem item({
    required String id,
    String name = 'مادة',
    double quantity = 10,
    double unitCost = 2,
    double reorderLevel = 0,
    double reorderQty = 0,
    double maxStock = 0,
    bool active = true,
    DateTime? expiresAt,
    String sku = '',
    String barcode = '',
  }) =>
      InventoryItem(
        id: id,
        name: name,
        quantity: quantity,
        unitCost: unitCost,
        reorderLevel: reorderLevel,
        reorderQty: reorderQty,
        maxStock: maxStock,
        active: active,
        expiresAt: expiresAt,
        sku: sku,
        barcode: barcode,
        createdAt: now,
        updatedAt: now,
      );

  InventoryMovement movement({
    required String id,
    required String itemId,
    required String type,
    required double quantity,
    double unitCost = 2,
    DateTime? at,
    double? before,
    double? after,
  }) =>
      InventoryMovement(
        id: id,
        itemId: itemId,
        type: type,
        quantity: quantity,
        unitCost: unitCost,
        balanceBefore: before,
        balanceAfter: after,
        createdAt: at ?? now,
      );

  group('periodReport', () {
    test('computes purchases, usage, waste and net change', () {
      final report = InventoryAnalytics.periodReport(
        movements: [
          movement(
            id: 'p1',
            itemId: 'a',
            type: 'purchase',
            quantity: 10,
            unitCost: 3,
          ),
          movement(id: 'u1', itemId: 'a', type: 'usage', quantity: 4),
          movement(id: 'w1', itemId: 'b', type: 'waste', quantity: 2),
          movement(id: 'd1', itemId: 'b', type: 'damage', quantity: 1),
          movement(id: 'e1', itemId: 'b', type: 'expiry', quantity: 1),
        ],
        from: from,
        to: now,
      );

      expect(report.movementCount, 5);
      expect(report.purchasedValue, 30);
      expect(report.usedValue, 8);
      // هدر + تلف + انتهاء = 4 وحدات × 2
      expect(report.wastedValue, 8);
      expect(report.adjustmentGainValue, 0);
      expect(report.adjustmentLossValue, 0);
      expect(report.netChangeValue, closeTo(30 - 8 - 8, 0.0001));
      expect(report.isEmpty, isFalse);
    });

    test('separates adjustment gain and loss using balance delta', () {
      final report = InventoryAnalytics.periodReport(
        movements: [
          movement(
            id: 'g1',
            itemId: 'a',
            type: 'adjustment',
            quantity: 3,
            unitCost: 5,
            before: 10,
            after: 13,
          ),
          movement(
            id: 'l1',
            itemId: 'a',
            type: 'adjustment',
            quantity: 2,
            unitCost: 5,
            before: 13,
            after: 11,
          ),
        ],
        from: from,
        to: now,
      );

      expect(report.adjustmentGainValue, 15);
      expect(report.adjustmentLossValue, 10);
      expect(report.netChangeValue, 5);
      final stats = report.forItem('a');
      expect(stats, isNotNull);
      expect(stats!.netAdjustmentValue, 5);
      expect(stats.movementCount, 2);
    });

    test('filters movements outside the period and sorts newest first', () {
      final report = InventoryAnalytics.periodReport(
        movements: [
          movement(
            id: 'old',
            itemId: 'a',
            type: 'purchase',
            quantity: 5,
            at: DateTime.utc(2026, 9, 1),
          ),
          movement(
            id: 'newer',
            itemId: 'a',
            type: 'usage',
            quantity: 1,
            at: now,
          ),
          movement(
            id: 'older',
            itemId: 'a',
            type: 'usage',
            quantity: 1,
            at: DateTime.utc(2026, 10, 15),
          ),
          movement(
            id: 'future',
            itemId: 'a',
            type: 'usage',
            quantity: 1,
            at: DateTime.utc(2026, 12, 1),
          ),
        ],
        from: from,
        to: now,
      );

      expect(report.movements.map((m) => m.id), ['newer', 'older']);
      expect(report.purchasedValue, 0);
      expect(report.usedValue, 4);
    });

    test('includes boundary timestamps', () {
      final report = InventoryAnalytics.periodReport(
        movements: [
          movement(
            id: 'start',
            itemId: 'a',
            type: 'purchase',
            quantity: 1,
            at: from,
          ),
          movement(
              id: 'end', itemId: 'a', type: 'purchase', quantity: 1, at: now),
        ],
        from: from,
        to: now,
      );
      expect(report.movementCount, 2);
    });

    test('top consumed/wasted/purchased are sorted and limited', () {
      final report = InventoryAnalytics.periodReport(
        movements: [
          movement(
            id: 'p1',
            itemId: 'a',
            type: 'purchase',
            quantity: 10,
            unitCost: 1,
          ),
          movement(
            id: 'p2',
            itemId: 'b',
            type: 'purchase',
            quantity: 2,
            unitCost: 10,
          ),
          movement(id: 'u1', itemId: 'a', type: 'usage', quantity: 1),
          movement(id: 'u2', itemId: 'b', type: 'usage', quantity: 5),
          movement(id: 'w1', itemId: 'b', type: 'waste', quantity: 2),
        ],
        from: from,
        to: now,
      );

      expect(report.topConsumed(1).single.itemId, 'b');
      expect(report.topConsumed(5).map((s) => s.itemId), ['b', 'a']);
      expect(report.topWasted(5).single.itemId, 'b');
      expect(report.topPurchased(1).single.itemId, 'b');
    });

    test('empty report has zero totals', () {
      final report = InventoryAnalytics.periodReport(
        movements: const [],
        from: from,
        to: now,
      );
      expect(report.isEmpty, isTrue);
      expect(report.forItem('none'), isNull);
      expect(report.netChangeValue, 0);
    });
  });

  group('itemStats', () {
    test('returns zeroed stats for an item with no movement', () {
      final stats = InventoryAnalytics.itemStats(
        movements: const [],
        itemId: 'x',
        from: from,
        to: now,
      );
      expect(stats.itemId, 'x');
      expect(stats.hasActivity, isFalse);
      expect(stats.lastMovementAt, isNull);
    });
  });

  group('restockSuggestions', () {
    test('out-of-stock comes first, then low stock by estimated cost', () {
      final suggestions = InventoryAnalytics.restockSuggestions([
        item(
          id: 'low',
          name: 'منخفض',
          quantity: 2,
          reorderLevel: 5,
          reorderQty: 3,
          unitCost: 10,
        ),
        item(
          id: 'out',
          name: 'نافد',
          quantity: 0,
          maxStock: 4,
          unitCost: 1,
        ),
        item(
          id: 'ok',
          name: 'متوفر',
          quantity: 50,
          reorderLevel: 5,
        ),
        item(
          id: 'inactive',
          name: 'معطّل',
          quantity: 0,
          active: false,
        ),
      ]);

      expect(suggestions.map((s) => s.item.id), ['out', 'low']);
      expect(suggestions.first.reason, 'نافد');
      expect(suggestions.first.quantity, 4);
      expect(suggestions.last.reason, 'تحت الحد');
      expect(suggestions.last.quantity, 3);
      expect(suggestions.last.estimatedCost, 30);
    });

    test('never suggests a zero quantity when reorder level is unset', () {
      final suggestions = InventoryAnalytics.restockSuggestions([
        item(id: 'out', quantity: 0, reorderLevel: 0, maxStock: 0),
      ]);
      expect(suggestions.single.quantity, 1);
    });

    test('targets double the reorder level without a fixed reorder quantity',
        () {
      final suggestions = InventoryAnalytics.restockSuggestions([
        item(id: 'low', quantity: 2, reorderLevel: 5),
      ]);
      expect(suggestions.single.quantity, 8);
    });
  });

  group('slowMovingItems', () {
    test('lists active stocked items with no movement since the period', () {
      final items = [
        item(id: 'idle', quantity: 5, unitCost: 10),
        item(id: 'moved', quantity: 5, unitCost: 10),
        item(id: 'empty', quantity: 0, unitCost: 10),
        item(id: 'off', quantity: 5, active: false),
      ];
      final slow = InventoryAnalytics.slowMovingItems(
        items: items,
        movements: [
          movement(
            id: 'm1',
            itemId: 'moved',
            type: 'usage',
            quantity: 1,
            at: DateTime.utc(2026, 10, 20),
          ),
        ],
        from: from,
      );

      expect(slow.map((i) => i.id), ['idle']);
    });

    test('honours the limit and sorts by stock value', () {
      final slow = InventoryAnalytics.slowMovingItems(
        items: [
          item(id: 'small', quantity: 1, unitCost: 1),
          item(id: 'big', quantity: 10, unitCost: 10),
        ],
        movements: const [],
        from: from,
        limit: 1,
      );
      expect(slow.single.id, 'big');
    });
  });

  group('expiry', () {
    final reference = DateTime.utc(2026, 11, 4);

    test('expiringItems includes soon dates but excludes expired ones', () {
      final items = [
        item(id: 'soon', expiresAt: reference.add(const Duration(days: 5))),
        item(id: 'today', expiresAt: reference),
        item(
            id: 'past', expiresAt: reference.subtract(const Duration(days: 1))),
        item(id: 'far', expiresAt: reference.add(const Duration(days: 90))),
        item(id: 'none'),
        item(
          id: 'off',
          expiresAt: reference.add(const Duration(days: 3)),
          active: false,
        ),
      ];
      final expiring = InventoryAnalytics.expiringItems(
        items,
        withinDays: 30,
        now: reference,
      );
      expect(expiring.map((i) => i.id), ['soon']);
    });

    test('expiredItems only includes stocked active items', () {
      final items = [
        item(
          id: 'past',
          quantity: 2,
          expiresAt: reference.subtract(const Duration(days: 1)),
        ),
        item(
          id: 'pastEmpty',
          quantity: 0,
          expiresAt: reference.subtract(const Duration(days: 1)),
        ),
        item(id: 'future', expiresAt: reference.add(const Duration(days: 1))),
      ];
      final expired = InventoryAnalytics.expiredItems(items, now: reference);
      expect(expired.map((i) => i.id), ['past']);
    });
  });

  group('health', () {
    test('counts statuses and totals stock value of active items', () {
      final health = InventoryAnalytics.health([
        item(id: 'ok', quantity: 10, unitCost: 2),
        item(id: 'low', quantity: 1, unitCost: 2, reorderLevel: 3),
        item(id: 'out', quantity: 0, unitCost: 5),
        item(id: 'inactive', quantity: 100, unitCost: 5, active: false),
        item(
          id: 'expired',
          quantity: 1,
          unitCost: 1,
          expiresAt: DateTime.utc(2020, 1, 1),
        ),
      ]);

      expect(health.activeItems, 4);
      expect(health.outOfStock, 1);
      expect(health.lowStock, 1);
      expect(health.expired, 1);
      expect(health.inactive, 1);
      expect(health.totalValue, closeTo(20 + 2 + 0 + 1, 0.0001));
      expect(health.needsAttention, 3);
    });
  });

  group('duplicateItemError', () {
    final existing = item(
      id: 'a',
      name: 'شامبو',
      sku: 'SKU-1',
      barcode: '123',
    );
    final items = [existing];

    test('detects duplicate name case-insensitively', () {
      final error = InventoryAnalytics.duplicateItemError(
        items,
        item(id: 'b', name: ' شامبو '),
      );
      expect(error, isNotNull);
      expect(error, contains('شامبو'));
    });

    test('detects duplicate sku and barcode', () {
      expect(
        InventoryAnalytics.duplicateItemError(
          items,
          item(id: 'b', name: 'آخر', sku: 'sku-1'),
        ),
        isNotNull,
      );
      expect(
        InventoryAnalytics.duplicateItemError(
          items,
          item(id: 'b', name: 'آخر', barcode: '123'),
        ),
        isNotNull,
      );
    });

    test('allows the same item to keep its own values', () {
      expect(
        InventoryAnalytics.duplicateItemError(
          items,
          existing.copyWith(name: 'شامبو'),
        ),
        isNull,
      );
    });

    test('ignores empty identifiers', () {
      expect(
        InventoryAnalytics.duplicateItemError(
          items,
          item(id: 'b', name: 'منتج جديد'),
        ),
        isNull,
      );
    });
  });
}
