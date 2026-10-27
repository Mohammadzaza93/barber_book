import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/team/team_models.dart';
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

  Future<void> saveTask(TeamTask t) => _api.saveTask(_sid, t);
  Future<void> deleteTask(String id) => _api.deleteTask(_sid, id);

  Future<void> saveEvaluation(TeamEvaluation e) =>
      _api.saveEvaluation(_sid, e);
  Future<void> deleteEvaluation(String id) =>
      _api.deleteEvaluation(_sid, id);

  Future<void> saveAttendance(TeamAttendance a) =>
      _api.saveAttendance(_sid, a);
  Future<void> deleteAttendance(String id) =>
      _api.deleteAttendance(_sid, id);

  Future<void> saveTimeOff(TeamTimeOff t) => _api.saveTimeOff(_sid, t);
  Future<void> deleteTimeOff(String id) => _api.deleteTimeOff(_sid, id);

  /// شهادة عمل مبسّطة لشهر معيّن.
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
