import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/expense.dart';
import '../services/firestore_service.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Expense> expenses = [];
  bool loading = true;

  /// First non-permission stream failure, surfaced instead of hanging.
  String? error;
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
    error = null;
    _subs.add(FirestoreService.instance.watchExpenses(shopId).listen(
      (list) {
        expenses = list;
        loading = false;
        notifyListeners();
      },
      // Expenses are manager-only. A denied read must clear `loading` rather
      // than leave the tab spinning forever.
      onError: (Object e, StackTrace _) {
        if (e is! FirebaseException || e.code != 'permission-denied') {
          if (error == null) error = e.toString();
        }
        loading = false;
        notifyListeners();
      },
    ));
  }

  Future<void> add(Expense e, String shopId) =>
      FirestoreService.instance.addExpense(shopId, e);

  Future<void> update(Expense e, String shopId) =>
      FirestoreService.instance.updateExpense(shopId, e);

  Future<void> delete(String id, String shopId) =>
      FirestoreService.instance.deleteExpense(shopId, id);

  /// Drops the bound shop and cached expenses. Used on sign-out.
  void reset() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _boundShopId = null;
    expenses = [];
    loading = true;
    error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

String newExpenseId() => const Uuid().v4();
