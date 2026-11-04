import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  CollectionReference<Map<String, dynamic>> _stocktakes(String shopId) =>
      _db.collection('shops').doc(shopId).collection('stocktakes');

  Stream<List<InventoryItem>> watchInventory(String shopId) =>
      _items(shopId).orderBy('name').snapshots().map((snap) =>
          snap.docs.map((d) => InventoryItem.fromMap(d.id, d.data())).toList());

  /// تحديث بيانات مادة موجودة دون المساس بالرصيد.
  ///
  /// الكمية تتغيّر فقط عبر الحركات أو الجرد، لذا لا تُكتب هنا حتى لا تدهس
  /// حركة سُجّلت أثناء فتح المحرّر. تاريخ الإنشاء ومنشئه يبقيان ثابتين.
  Future<void> saveInventoryItem(String shopId, InventoryItem item) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final data = item.toMap()
      ..remove('quantity')
      ..remove('createdAt')
      ..remove('createdBy')
      ..['updatedAt'] = FieldValue.serverTimestamp();
    if (uid != null) data['updatedBy'] = uid;
    return _items(shopId).doc(item.id).set(data, SetOptions(merge: true));
  }

  /// هل للمادة أي حركة تاريخية؟ يُستخدم قبل الحذف النهائي فقط.
  Future<bool> hasMovements(String shopId, String itemId) async {
    final snap = await _movements(shopId)
        .where('itemId', isEqualTo: itemId)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  /// تعطيل ناعم — لا نحذف سجلاً له حركات.
  Future<void> deactivateInventoryItem(String shopId, String id) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return _items(shopId).doc(id).set({
      'active': false,
      'updatedAt': FieldValue.serverTimestamp(),
      if (uid != null) 'updatedBy': uid,
    }, SetOptions(merge: true));
  }

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

  /// حركات فترة محددة — تُطلب عند فتح التقارير فقط (توفيراً للقراءات).
  ///
  /// الفلترة والترتيب على نفس الحقل `createdAt` لا يحتاجان فهرساً مركّباً.
  Future<List<InventoryMovement>> fetchInventoryMovementsBetween({
    required String shopId,
    required DateTime from,
    required DateTime to,
    int limit = 1000,
  }) async {
    final snap = await _movements(shopId)
        .where('createdAt', isGreaterThanOrEqualTo: from.toUtc())
        .where('createdAt', isLessThanOrEqualTo: to.toUtc())
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => InventoryMovement.fromMap(d.id, d.data()))
        .toList();
  }

  /// إنشاء مادة جديدة مع رصيد افتتاحي مسجّل كحركة شراء.

  /// الكتابة داخل معاملة واحدة: إما تُنشأ المادة وحركتها معاً أو لا شيء،
  /// حتى لا يظهر رصيد بلا أثر محاسبي.
  Future<void> createItemWithOpeningStock({
    required String shopId,
    required InventoryItem item,
    required double openingQty,
    String? actorId,
  }) async {
    if (openingQty < 0) {
      throw StateError('الرصيد الافتتاحي يجب أن يكون ≥ 0');
    }
    final itemRef = _items(shopId).doc(item.id);
    final movementRef = _movements(shopId).doc('opening_${item.id}');
    final uid = actorId ?? FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now().toUtc();

    await _db.runTransaction((tx) async {
      final snap = await tx.get(itemRef);
      if (snap.exists) {
        throw StateError('توجد مادة بنفس المعرّف مسبقاً');
      }
      final created = item.copyWith(
        quantity: openingQty,
        createdAt: now,
        updatedAt: now,
        createdBy: uid,
        updatedBy: uid,
      );
      tx.set(itemRef, created.toMap());
      if (openingQty > 0) {
        tx.set(
          movementRef,
          InventoryMovement(
            id: movementRef.id,
            itemId: item.id,
            type: 'purchase',
            quantity: openingQty,
            unitCost: item.unitCost,
            reason: 'رصيد افتتاحي',
            balanceBefore: 0,
            balanceAfter: openingQty,
            actorId: uid,
            createdAt: now,
          ).toMap(),
        );
      }
    });
  }

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
    if (type != 'purchase' && type != 'adjustment' && reason.trim().isEmpty) {
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

  // ---------- Stocktaking (جرد) ----------

  /// آخر 20 جلسة فقط: يقلل القراءات على الخطة المجانية.
  Stream<List<Stocktake>> watchStocktakes(String shopId) => _stocktakes(shopId)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Stocktake.fromMap(d.id, d.data())).toList());

  Future<Stocktake?> getStocktake(String shopId, String id) async {
    final snap = await _stocktakes(shopId).doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    return Stocktake.fromMap(snap.id, data);
  }

  /// إنشاء/حفظ جلسة جرد. السطور مدمجة في مستند واحد (كتابة واحدة).
  Future<void> saveStocktake(String shopId, Stocktake stocktake) =>
      _stocktakes(shopId)
          .doc(stocktake.id)
          .set(stocktake.toMap(), SetOptions(merge: true));

  Future<void> deleteStocktake(String shopId, String stocktakeId) =>
      _stocktakes(shopId).doc(stocktakeId).delete();

  /// حفظ الكميات المعدودة دفعة واحدة.
  ///
  /// داخل معاملة حتى لا تكتب لقطة قديمة فوق جلسة رُحّلت للتو، وحتى تُحفظ كل
  /// الأعداد بنجاح أو لا شيء منها.
  Future<Stocktake> saveStocktakeCounts({
    required String shopId,
    required String stocktakeId,
    required Map<String, double?> counts,
  }) async {
    final ref = _stocktakes(shopId).doc(stocktakeId);
    final now = DateTime.now().toUtc();
    return _db.runTransaction<Stocktake>((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('جلسة الجرد غير موجودة');
      final session = Stocktake.fromMap(snap.id, snap.data()!);
      if (!session.isOpen) {
        throw StateError('لا يمكن تعديل جلسة جرد مغلقة');
      }
      final lines = session.lines.map((line) {
        if (!counts.containsKey(line.itemId) || line.posted) return line;
        final value = counts[line.itemId];
        return line.copyWith(
          countedQty: value,
          clearCounted: value == null,
          clearConflict: true,
          issue: '',
        );
      }).toList();
      final updated = session.copyWith(lines: lines, updatedAt: now);
      tx.set(ref, updated.toMap(), SetOptions(merge: true));
      return updated;
    });
  }

  /// يعيد أخذ لقطة أرصدة النظام للسطور غير المرحّلة.
  ///
  /// تُستخدم عند تعارض «تغيّر الرصيد أثناء الجرد»: يرى المستخدم الفرق ثم يقرر
  /// إعادة العد أو ترحيل العدّ الحالي مقابل الرصيد المحدّث.
  Future<Stocktake> refreshStocktakeExpected({
    required String shopId,
    required String stocktakeId,
  }) async {
    final ref = _stocktakes(shopId).doc(stocktakeId);
    final snap = await ref.get();
    if (!snap.exists) throw StateError('جلسة الجرد غير موجودة');
    final session = Stocktake.fromMap(snap.id, snap.data()!);
    if (!session.isOpen) throw StateError('الجلسة مغلقة');

    final updatedLines = <StocktakeLine>[];
    const chunkSize = 50;
    for (var start = 0; start < session.lines.length; start += chunkSize) {
      final chunk = session.lines.skip(start).take(chunkSize).toList();
      final itemSnaps = await Future.wait(
          chunk.map((line) => _items(shopId).doc(line.itemId).get()));
      for (var i = 0; i < chunk.length; i++) {
        final line = chunk[i];
        if (line.posted) {
          updatedLines.add(line);
          continue;
        }
        final itemSnap = itemSnaps[i];
        if (!itemSnap.exists) {
          updatedLines.add(line.copyWith(
            issue: 'المادة غير موجودة',
            clearConflict: true,
          ));
          continue;
        }
        final item = InventoryItem.fromMap(itemSnap.id, itemSnap.data()!);
        updatedLines.add(line.copyWith(
          itemName: item.name,
          unit: item.unit,
          unitCost: item.unitCost,
          expectedQty: item.quantity,
          clearConflict: true,
          issue: '',
        ));
      }
    }

    final updated = session.copyWith(
      lines: updatedLines,
      updatedAt: DateTime.now().toUtc(),
    );
    await ref.set(updated.toMap(), SetOptions(merge: true));
    return updated;
  }

  /// ترحيل جلسة الجرد إلى المخزون.
  ///
  /// كل سطر يُطبّق في معاملة مستقلة (صنف + حركة + تحديث الجلسة). هذا يحافظ على
  /// الذرّية لكل مادة، ويجعل الترحيل قابلاً للاستئناف إذا انقطع الاتصال: السطور
  /// المرحّلة تُعلَّم `posted` ولا تتكرر. لا نستخدم Cloud Functions.
  Future<StocktakePostResult> postStocktake({
    required String shopId,
    required String stocktakeId,
    String? actorId,
  }) async {
    final sessionRef = _stocktakes(shopId).doc(stocktakeId);
    final initialSnap = await sessionRef.get();
    if (!initialSnap.exists) throw StateError('جلسة الجرد غير موجودة');
    final initial = Stocktake.fromMap(initialSnap.id, initialSnap.data()!);
    if (initial.isCompleted) {
      throw StateError('تم ترحيل هذه الجلسة مسبقاً');
    }
    if (initial.isCancelled) throw StateError('جلسة الجرد ملغاة');
    if (initial.countedCount == 0) {
      throw StateError('لا توجد كميات معدودة للترحيل');
    }
    final pending = initial.lines
        .where((l) => l.isCounted && !l.posted)
        .map((l) => l.itemId)
        .toList();

    final uid = actorId ?? FirebaseAuth.instance.currentUser?.uid;
    final now = DateTime.now().toUtc();
    if (initial.status == StocktakeStatus.draft) {
      await sessionRef.set(
        {
          'status': StocktakeStatus.posting.name,
          'updatedAt': now,
        },
        SetOptions(merge: true),
      );
    }

    var posted = 0;
    var conflicts = 0;
    var failed = 0;
    for (final itemId in pending) {
      final outcome = await _postStocktakeLine(
        shopId: shopId,
        sessionRef: sessionRef,
        itemId: itemId,
        actorId: uid,
      );
      switch (outcome) {
        case _StocktakeLineOutcome.posted:
          posted++;
        case _StocktakeLineOutcome.conflict:
          conflicts++;
        case _StocktakeLineOutcome.failed:
          failed++;
        case _StocktakeLineOutcome.skipped:
          break;
      }
    }

    final latestSnap = await sessionRef.get();
    final latest = latestSnap.exists
        ? Stocktake.fromMap(latestSnap.id, latestSnap.data()!)
        : initial;
    var completed = false;
    final finished = latest.countedCount > 0 &&
        latest.allCountedPosted &&
        latest.conflictCount == 0 &&
        failed == 0;
    if (finished) {
      await sessionRef.set(
        {
          'status': StocktakeStatus.completed.name,
          'postedAt': DateTime.now().toUtc(),
          'postedBy': uid,
          'updatedAt': DateTime.now().toUtc(),
        },
        SetOptions(merge: true),
      );
      completed = true;
    } else {
      await sessionRef.set(
        {'updatedAt': DateTime.now().toUtc()},
        SetOptions(merge: true),
      );
    }

    final finalSnap = await sessionRef.get();
    final finalSession = finalSnap.exists
        ? Stocktake.fromMap(finalSnap.id, finalSnap.data()!)
        : latest;
    return StocktakePostResult(
      stocktakeId: stocktakeId,
      posted: posted,
      conflicts: conflicts,
      failed: failed,
      completed: completed,
      session: finalSession,
    );
  }

  Future<_StocktakeLineOutcome> _postStocktakeLine({
    required String shopId,
    required DocumentReference<Map<String, dynamic>> sessionRef,
    required String itemId,
    String? actorId,
  }) async {
    final itemRef = _items(shopId).doc(itemId);
    final movementRef =
        _movements(shopId).doc('stocktake_${sessionRef.id}_$itemId');
    final now = DateTime.now().toUtc();

    return _db.runTransaction<_StocktakeLineOutcome>((tx) async {
      final sessionSnap = await tx.get(sessionRef);
      if (!sessionSnap.exists) throw StateError('جلسة الجرد غير موجودة');
      final session = Stocktake.fromMap(sessionSnap.id, sessionSnap.data()!);
      if (!session.isOpen) return _StocktakeLineOutcome.skipped;

      final index = session.lines.indexWhere((line) => line.itemId == itemId);
      if (index < 0) return _StocktakeLineOutcome.skipped;
      final line = session.lines[index];
      if (!line.isCounted || line.posted) {
        return _StocktakeLineOutcome.skipped;
      }

      final itemSnap = await tx.get(itemRef);
      if (!itemSnap.exists) {
        _writeStocktakeLine(
          tx,
          sessionRef,
          session,
          index,
          line.copyWith(issue: 'المادة غير موجودة', clearConflict: true),
          now,
        );
        return _StocktakeLineOutcome.failed;
      }

      final item = InventoryItem.fromMap(itemSnap.id, itemSnap.data()!);
      final before = item.quantity;

      // تغيّر الرصيد بعد أخذ اللقطة (بيع/صرف أثناء الجرد). لا نكتب فوقه بصمت.
      if ((before - line.expectedQty).abs() > kStockEpsilon) {
        _writeStocktakeLine(
          tx,
          sessionRef,
          session,
          index,
          line.copyWith(conflict: true, conflictQty: before),
          now,
        );
        return _StocktakeLineOutcome.conflict;
      }

      final after = line.countedQty!;
      if ((after - before).abs() > kStockEpsilon) {
        final movement = InventoryMovement(
          id: movementRef.id,
          itemId: itemId,
          type: 'adjustment',
          quantity: (after - before).abs(),
          unitCost: item.unitCost,
          reason: session.note.trim().isEmpty
              ? 'جرد المخزون'
              : 'جرد: ${session.note.trim()}',
          balanceBefore: before,
          balanceAfter: after,
          actorId: actorId,
          createdAt: now,
        );
        tx.set(movementRef, movement.toMap());
        tx.set(
          itemRef,
          item
              .copyWith(
                quantity: after,
                updatedAt: now,
                updatedBy: actorId,
              )
              .toMap(),
          SetOptions(merge: true),
        );
      }

      _writeStocktakeLine(
        tx,
        sessionRef,
        session,
        index,
        line.copyWith(
          posted: true,
          postedAt: now,
          clearConflict: true,
          issue: '',
        ),
        now,
      );
      return _StocktakeLineOutcome.posted;
    });
  }

  void _writeStocktakeLine(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> sessionRef,
    Stocktake session,
    int index,
    StocktakeLine line,
    DateTime now,
  ) {
    final lines = List<StocktakeLine>.from(session.lines);
    lines[index] = line;
    tx.set(
      sessionRef,
      {
        'lines': lines.map((l) => l.toMap()).toList(),
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }
}

enum _StocktakeLineOutcome { posted, conflict, failed, skipped }
