import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/activity_log.dart';

/// تسجيل نشاطات غير متزامن — لا يعطل واجهة المستخدم عند الفشل.
class ActivityLogService {
  ActivityLogService._();
  static final instance = ActivityLogService._();

  final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String shopId) =>
      _db.collection('shops').doc(shopId).collection('activity_log');

  Future<void> log({
    required String shopId,
    required String action,
    required String entity,
    String entityId = '',
    String summary = '',
    String actorUid = '',
    String actorName = '',
    Map<String, dynamic> meta = const {},
  }) async {
    if (shopId.isEmpty) return;
    try {
      final id = const Uuid().v4();
      final entry = ActivityLogEntry(
        id: id,
        action: action,
        entity: entity,
        entityId: entityId,
        summary: summary,
        actorUid: actorUid,
        actorName: actorName,
        at: DateTime.now(),
        meta: meta,
      );
      await _col(shopId).doc(id).set(entry.toMap());
    } catch (_) {
      // Best-effort: لا نكسر العملية الأساسية بسبب فشل السجل.
    }
  }

  Stream<List<ActivityLogEntry>> watch(String shopId, {int limit = 200}) {
    return _col(shopId)
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (s) => s.docs
              .map((d) => ActivityLogEntry.fromMap(d.id, d.data()))
              .toList(),
        );
  }
}
