import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/business_features.dart';

/// Inventory Firestore access (split from FirestoreService).
class FirestoreInventory {
  FirestoreInventory._();
  static final instance = FirestoreInventory._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  Stream<List<InventoryItem>> watchInventory(String shopId) =>
      _db.collection('shops').doc(shopId).collection('inventory')
          .orderBy('name')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => InventoryItem.fromMap(d.id, d.data()))
              .toList());

  Future<void> saveInventoryItem(String shopId, InventoryItem item) =>
      _db.collection('shops').doc(shopId).collection('inventory').doc(item.id).set(item.toMap());

  Future<void> deleteInventoryItem(String shopId, String id) =>
      _db.collection('shops').doc(shopId).collection('inventory').doc(id).delete();

  Stream<List<InventoryMovement>> watchInventoryMovements(String shopId) =>
      _db.collection('shops').doc(shopId).collection('inventoryMovements')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => InventoryMovement.fromMap(d.id, d.data()))
              .toList());

  Future<void> addInventoryMovement(
          String shopId, InventoryMovement movement) =>
      _db.collection('shops').doc(shopId).collection('inventoryMovements').doc(movement.id).set(movement.toMap());
}
