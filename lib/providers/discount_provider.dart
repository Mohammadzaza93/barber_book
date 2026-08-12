import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/discount.dart';
import '../services/firestore_service.dart';

class DiscountProvider extends ChangeNotifier {
  List<Discount> discounts = [];
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
        .watchDiscounts(shopId)
        .listen((list) {
      discounts = list;
      loading = false;
      notifyListeners();
    }));
  }

  Future<void> add(Discount d, String shopId) =>
      FirestoreService.instance.addDiscount(shopId, d);

  Future<void> update(Discount d, String shopId) =>
      FirestoreService.instance.updateDiscount(shopId, d);

  Future<void> delete(String id, String shopId) =>
      FirestoreService.instance.deleteDiscount(shopId, id);

  Future<void> recordUsage(String id, String shopId) =>
      FirestoreService.instance.incrementDiscountUsage(shopId, id);

  Discount? findActiveByCode(String code) {
    for (final d in discounts) {
      if (d.code.toLowerCase() == code.trim().toLowerCase()) return d;
    }
    return null;
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

String newDiscountId() => const Uuid().v4();
