import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';
import '../services/firestore_service.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> expenses = [];
  bool loading = true;
  String? _boundShopId;
  final List<StreamSubscription> _subs = [];

  void bind(String shopId) {
    if (_boundShopId == shopId) return;
    _boundShopId = shopId;
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    loading = true;
    _subs.add(FirestoreService.instance
        .watchExpenses(shopId)
        .listen((list) {
      expenses = list;
      loading = false;
      notifyListeners();
    }));
  }

  Future<void> add(Expense e, String shopId) =>
      FirestoreService.instance.addExpense(shopId, e);

  Future<void> update(Expense e, String shopId) =>
      FirestoreService.instance.updateExpense(shopId, e);

  Future<void> delete(String id, String shopId) =>
      FirestoreService.instance.deleteExpense(shopId, id);

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

String newExpenseId() => const Uuid().v4();
