import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/team/team_models.dart';

/// CRUD لمجموعات إدارة الفريق تحت shops/{shopId}/...
class FirestoreTeam {
  FirestoreTeam._();
  static final instance = FirestoreTeam._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String shopId, String name) =>
      _db.collection('shops').doc(shopId).collection(name);

  // ── Tasks ──────────────────────────────────────────
  Stream<List<TeamTask>> watchTasks(String shopId) =>
      _col(shopId, 'team_tasks').orderBy('createdAt', descending: true).snapshots().map(
            (s) => s.docs
                .map((d) => TeamTask.fromMap(d.id, d.data()))
                .toList(),
          );

  Future<void> saveTask(String shopId, TeamTask t) =>
      _col(shopId, 'team_tasks').doc(t.id).set(t.toMap(), SetOptions(merge: true));

  Future<void> deleteTask(String shopId, String id) =>
      _col(shopId, 'team_tasks').doc(id).delete();

  // ── Evaluations ────────────────────────────────────
  Stream<List<TeamEvaluation>> watchEvaluations(String shopId) =>
      _col(shopId, 'team_evaluations')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => TeamEvaluation.fromMap(d.id, d.data()))
                .toList(),
          );

  Future<void> saveEvaluation(String shopId, TeamEvaluation e) =>
      _col(shopId, 'team_evaluations')
          .doc(e.id)
          .set(e.toMap(), SetOptions(merge: true));

  Future<void> deleteEvaluation(String shopId, String id) =>
      _col(shopId, 'team_evaluations').doc(id).delete();

  // ── Attendance ─────────────────────────────────────
  Stream<List<TeamAttendance>> watchAttendance(String shopId) =>
      _col(shopId, 'team_attendance')
          .orderBy('date', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => TeamAttendance.fromMap(d.id, d.data()))
                .toList(),
          );

  Future<void> saveAttendance(String shopId, TeamAttendance a) =>
      _col(shopId, 'team_attendance')
          .doc(a.id)
          .set(a.toMap(), SetOptions(merge: true));

  Future<void> deleteAttendance(String shopId, String id) =>
      _col(shopId, 'team_attendance').doc(id).delete();

  // ── Time off ───────────────────────────────────────
  Stream<List<TeamTimeOff>> watchTimeOff(String shopId) =>
      _col(shopId, 'team_time_off')
          .orderBy('from', descending: true)
          .snapshots()
          .map(
            (s) => s.docs
                .map((d) => TeamTimeOff.fromMap(d.id, d.data()))
                .toList(),
          );

  Future<void> saveTimeOff(String shopId, TeamTimeOff t) =>
      _col(shopId, 'team_time_off').doc(t.id).set(t.toMap(), SetOptions(merge: true));

  Future<void> deleteTimeOff(String shopId, String id) =>
      _col(shopId, 'team_time_off').doc(id).delete();
}
