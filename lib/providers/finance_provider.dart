import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/finance/finance_models.dart';
import '../services/activity_log_service.dart';

class FinanceProvider extends ChangeNotifier {
  String? _shopId;
  bool loading = true;
  String? error;

  List<StartupCost> startupCosts = [];
  List<OperatingExpense> expenses = [];
  List<BarberSettlement> barberSettlements = [];
  List<DailyFinanceEntry> entries = [];

  StreamSubscription? _subStartup;
  StreamSubscription? _subExp;
  StreamSubscription? _subBarbers;
  StreamSubscription? _subEntries;

  void bind(String? shopId) {
    if (_shopId == shopId && !loading) return;
    _shopId = shopId;
    _clear();
    if (shopId == null) {
      loading = false;
      notifyListeners();
      return;
    }
    _listen(shopId);
  }

  void _clear() {
    _subStartup?.cancel();
    _subExp?.cancel();
    _subBarbers?.cancel();
    _subEntries?.cancel();
    startupCosts.clear();
    expenses.clear();
    barberSettlements.clear();
    entries.clear();
    loading = true;
    error = null;
  }

  void reset() {
    _clear();
    _shopId = null;
    loading = true;
    notifyListeners();
  }

  CollectionReference<Map<String, dynamic>> _col(String name) {
    final id = _shopId!;
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(id)
        .collection('finance')
        .doc(name)
        .collection('items');
  }

  CollectionReference<Map<String, dynamic>> _daily() {
    final id = _shopId!;
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(id)
        .collection('finance_daily');
  }

  Future<void> _audit({
    required String action,
    required String entity,
    String entityId = '',
    String summary = '',
  }) async {
    final sid = _shopId;
    if (sid == null) return;
    await ActivityLogService.instance.log(
      shopId: sid,
      action: action,
      entity: entity,
      entityId: entityId,
      summary: summary,
    );
  }

  void _listen(String shopId) {
    _subStartup = _col('startup').orderBy('date').snapshots().listen((snap) {
      startupCosts = snap.docs
          .map((d) => StartupCost.fromMap(d.id, d.data()))
          .toList();
      notifyListeners();
    });
    _subExp = _col('expenses')
        .orderBy('date', descending: true)
        .snapshots()
        .listen((snap) {
      expenses = snap.docs
          .map((d) => OperatingExpense.fromMap(d.id, d.data()))
          .toList();
      notifyListeners();
    });
    _subBarbers = _col('barbers').snapshots().listen((snap) {
      barberSettlements = snap.docs
          .map((d) => BarberSettlement.fromMap(d.data()))
          .toList();
      notifyListeners();
    });
    _subEntries = _daily()
        .orderBy('date', descending: true)
        .limit(500)
        .snapshots()
        .listen((snap) {
      entries = snap.docs
          .map((d) => DailyFinanceEntry.fromMap(d.id, d.data()))
          .toList();
      loading = false;
      notifyListeners();
    }, onError: (e) {
      error = e.toString();
      loading = false;
      notifyListeners();
    });
  }

  Future<void> addStartupCost(StartupCost c) async {
    if (_shopId == null) return;
    await _col('startup').doc(c.id).set(c.toMap());
    await _audit(
      action: 'create',
      entity: 'startup_cost',
      entityId: c.id,
      summary: 'تأسيس: ${c.title}',
    );
  }

  Future<void> deleteStartupCost(String id) async {
    if (_shopId == null) return;
    await _col('startup').doc(id).delete();
    await _audit(
        action: 'delete', entity: 'startup_cost', entityId: id, summary: 'حذف بند تأسيس');
  }

  Future<void> addExpense(OperatingExpense e) async {
    if (_shopId == null) return;
    await _col('expenses').doc(e.id).set(e.toMap());
    await _audit(
      action: 'create',
      entity: 'expense',
      entityId: e.id,
      summary: 'مصروف: ${e.title} (${e.amountSyp})',
    );
  }

  Future<void> deleteExpense(String id) async {
    if (_shopId == null) return;
    await _col('expenses').doc(id).delete();
    await _audit(
        action: 'delete', entity: 'expense', entityId: id, summary: 'حذف مصروف');
  }

  Future<void> saveBarber(BarberSettlement b) async {
    if (_shopId == null) return;
    await _col('barbers').doc(b.barberId).set(b.toMap(), SetOptions(merge: true));
    await _audit(
      action: 'update',
      entity: 'barber_settlement',
      entityId: b.barberId,
      summary: 'تسوية حلاق ${b.barberId}',
    );
  }

  Future<void> addDailyEntry(DailyFinanceEntry e) async {
    if (_shopId == null) return;
    await _daily().doc(e.id).set(e.toMap());
    await _audit(
      action: 'create',
      entity: 'daily_sale',
      entityId: e.id,
      summary: 'وارد: ${e.serviceName} ${e.totalAmount}',
    );
  }

  Future<void> deleteDailyEntry(String id) async {
    if (_shopId == null) return;
    await _daily().doc(id).delete();
    await _audit(
        action: 'delete', entity: 'daily_sale', entityId: id, summary: 'حذف وارد');
  }

  double sumStartup() => startupCosts.fold(0, (s, c) => s + c.amountSyp);
  double sumExpenses() => expenses.fold(0, (s, e) => s + e.amountSyp);

  double sumDailyTotal({DateTime? from, DateTime? to}) {
    var list = entries;
    if (from != null) {
      list = list.where((e) => !e.date.isBefore(from)).toList();
    }
    if (to != null) {
      list = list.where((e) => !e.date.isAfter(to)).toList();
    }
    return list.fold(0, (s, e) => s + e.totalAmount);
  }

  double sumBarberShares({DateTime? from, DateTime? to}) {
    var list = entries;
    if (from != null) {
      list = list.where((e) => !e.date.isBefore(from)).toList();
    }
    if (to != null) {
      list = list.where((e) => !e.date.isAfter(to)).toList();
    }
    return list.fold(0, (s, e) => s + e.barberShare);
  }

  double sumSalonShares({DateTime? from, DateTime? to}) {
    var list = entries;
    if (from != null) {
      list = list.where((e) => !e.date.isBefore(from)).toList();
    }
    if (to != null) {
      list = list.where((e) => !e.date.isAfter(to)).toList();
    }
    return list.fold(0, (s, e) => s + e.salonShare);
  }

  CashBoxSplit dailySplit({DateTime? from, DateTime? to}) {
    final salon = sumSalonShares(from: from, to: to);
    final barber = sumBarberShares(from: from, to: to);
    final generator = salon * 0.25;
    final materials = salon * 0.25;
    final laundry = salon * 0.10;
    final net = salon - generator - materials - laundry;
    return CashBoxSplit(
      barberWages: barber,
      operatingMaterials: materials,
      generatorFuel: generator,
      laundryTowels: laundry,
      netProfit: net < 0 ? 0 : net,
    );
  }
}
