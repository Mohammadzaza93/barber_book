import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/team/team_models.dart';
import '../services/activity_log_service.dart';
import '../services/firestore_team.dart';
import '../services/shop_manager.dart';

class TeamProvider extends ChangeNotifier {
  final _api = FirestoreTeam.instance;
  final List<StreamSubscription> _subs = [];

  List<TeamTask> tasks = [];
  List<TeamEvaluation> evaluations = [];
  List<TeamAttendance> attendance = [];
  List<TeamTimeOff> timeOff = [];
  bool loading = false;
  String? shopId;

  void bind(String? id) {
    if (id == shopId) return;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    shopId = id;
    tasks = [];
    evaluations = [];
    attendance = [];
    timeOff = [];
    if (id == null || id.isEmpty) {
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    _subs.addAll([
      _api.watchTasks(id).listen((list) {
        tasks = list;
        loading = false;
        notifyListeners();
      }),
      _api.watchEvaluations(id).listen((list) {
        evaluations = list;
        notifyListeners();
      }),
      _api.watchAttendance(id).listen((list) {
        attendance = list;
        notifyListeners();
      }),
      _api.watchTimeOff(id).listen((list) {
        timeOff = list;
        notifyListeners();
      }),
    ]);
  }

  String get _sid => shopId ?? ShopManager.shopId ?? '';

  Future<void> _audit(String action, String entity, String entityId, String summary) async {
    final sid = _sid;
    if (sid.isEmpty) return;
    await ActivityLogService.instance.log(
      shopId: sid,
      action: action,
      entity: entity,
      entityId: entityId,
      summary: summary,
    );
  }

  Future<void> saveTask(TeamTask t) async {
    await _api.saveTask(_sid, t);
    await _audit('update', 'team_task', t.id, 'مهمة: ${t.title}');
  }

  Future<void> deleteTask(String id) async {
    await _api.deleteTask(_sid, id);
    await _audit('delete', 'team_task', id, 'حذف مهمة');
  }

  Future<void> saveEvaluation(TeamEvaluation e) async {
    await _api.saveEvaluation(_sid, e);
    await _audit('create', 'team_evaluation', e.id,
        'تقييم ${e.employeeName}: ${e.score}/5');
  }

  Future<void> deleteEvaluation(String id) async {
    await _api.deleteEvaluation(_sid, id);
    await _audit('delete', 'team_evaluation', id, 'حذف تقييم');
  }

  Future<void> saveAttendance(TeamAttendance a) async {
    await _api.saveAttendance(_sid, a);
    await _audit('create', 'team_attendance', a.id,
        'حضور ${a.employeeName}');
  }

  Future<void> deleteAttendance(String id) async {
    await _api.deleteAttendance(_sid, id);
    await _audit('delete', 'team_attendance', id, 'حذف حضور');
  }

  Future<void> saveTimeOff(TeamTimeOff t) async {
    await _api.saveTimeOff(_sid, t);
    await _audit('update', 'team_time_off', t.id,
        'إجازة ${t.employeeName}: ${t.status.name}');
  }

  Future<void> deleteTimeOff(String id) async {
    await _api.deleteTimeOff(_sid, id);
    await _audit('delete', 'team_time_off', id, 'حذف إجازة');
  }

  WorkCertificate buildCertificate({
    required String employeeId,
    required String employeeName,
    required int year,
    required int month,
  }) {
    final days = attendance.where((a) {
      return a.employeeId == employeeId &&
          a.date.year == year &&
          a.date.month == month &&
          a.present;
    }).toList();
    final hours = days.fold<double>(0, (s, a) => s + a.hours);
    final pay = days.fold<double>(0, (s, a) => s + a.dayPay);
    return WorkCertificate(
      employeeId: employeeId,
      employeeName: employeeName,
      year: year,
      month: month,
      workDays: days.length,
      totalHours: hours,
      totalPay: pay,
    );
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

class WorkCertificate {
  final String employeeId;
  final String employeeName;
  final int year;
  final int month;
  final int workDays;
  final double totalHours;
  final double totalPay;

  const WorkCertificate({
    required this.employeeId,
    required this.employeeName,
    required this.year,
    required this.month,
    required this.workDays,
    required this.totalHours,
    required this.totalPay,
  });
}
