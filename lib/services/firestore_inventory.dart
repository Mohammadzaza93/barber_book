import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_models.dart';

/// وصول Firestore للمخزون (صالون واحد عبر shopId).
class FirestoreInventory {
  FirestoreInventory._();
  static final instance = FirestoreInventory._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _items(String shopId) =>
      _db.collection('shops').doc(shopId).collection('inventory');

  CollectionReference<Map<String, dynamic>> _movements(String shopId) =>
      _db.collection('shops').doc(shopId).collection('inventoryMovements');

  Stream<List<InventoryItem>> watchInventory(String shopId) => _items(shopId)
      .orderBy('name')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => InventoryItem.fromMap(d.id, d.data()))
          .toList());

  Future<void> saveInventoryItem(String shopId, InventoryItem item) =>
      _items(shopId).doc(item.id).set(item.toMap(), SetOptions(merge: true));

  /// تعطيل ناعم — لا نحذف سجلاً له حركات.
  Future<void> deactivateInventoryItem(String shopId, String id) =>
      _items(shopId).doc(id).set({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

  Future<void> deleteInventoryItem(String shopId, String id) =>
      _items(shopId).doc(id).delete();

  Stream<List<InventoryMovement>> watchInventoryMovements(String shopId) =>
      _movements(shopId)
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => InventoryMovement.fromMap(d.id, d.data()))
              .toList());

  Future<void> addInventoryMovement(
          String shopId, InventoryMovement movement) =>
      _movements(shopId).doc(movement.id).set(movement.toMap());

  /// تطبيق حركة داخل معاملة: قراءة الرصيد → حركة → تحديث الصنف.
  /// الشراء يحدّث unitCost بتكلفة آخر شراء.
  Future<void> applyMovementAtomic({
    required String shopId,
    required String movementId,
    required String itemId,
    required String type,
    required double quantity,
    required double unitCost,
    required String reason,
    String? actorId,
    bool allowNegative = false,
  }) async {
    if (quantity < 0) {
      throw StateError('الكمية يجب أن تكون ≥ 0');
    }
    if (type != 'purchase' &&
        type != 'adjustment' &&
        reason.trim().isEmpty) {
      throw StateError('السبب مطلوب لهذه الحركة');
    }

    final itemRef = _items(shopId).doc(itemId);
    final movRef = _movements(shopId).doc(movementId);

    await _db.runTransaction((tx) async {
      final snap = await tx.get(itemRef);
      if (!snap.exists) {
        throw StateError('المادة غير موجودة في المخزون');
      }
      final data = snap.data()!;
      final item = InventoryItem.fromMap(snap.id, data);
      final before = item.quantity;
      late double after;
      double newUnitCost = item.unitCost;

      switch (type) {
        case 'purchase':
          after = before + quantity;
          if (unitCost > 0) newUnitCost = unitCost;
          break;
        case 'usage':
        case 'waste':
        case 'damage':
        case 'expiry':
          if (!allowNegative && quantity > before) {
            throw StateError(
                'الرصيد غير كافٍ (${before.toStringAsFixed(2)} ${item.unit})');
          }
          after = before - quantity;
          break;
        case 'adjustment':
          // quantity = الرصيد الفعلي بعد الجرد
          after = quantity;
          break;
        default:
          throw StateError('نوع حركة غير معروف: $type');
      }

      final movement = InventoryMovement(
        id: movementId,
        itemId: itemId,
        type: type,
        quantity: type == 'adjustment' ? (after - before).abs() : quantity,
        unitCost: type == 'purchase' ? newUnitCost : item.unitCost,
        reason: reason.trim(),
        balanceBefore: before,
        balanceAfter: after,
        actorId: actorId,
        createdAt: DateTime.now().toUtc(),
      );

      tx.set(movRef, movement.toMap());
      tx.set(
        itemRef,
        item
            .copyWith(
              quantity: after,
              unitCost: newUnitCost,
              updatedAt: DateTime.now().toUtc(),
              updatedBy: actorId,
            )
            .toMap(),
        SetOptions(merge: true),
      );
    });
  }
}
