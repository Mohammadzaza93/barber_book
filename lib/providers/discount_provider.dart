import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/discount.dart';
import '../services/firestore_service.dart';

class DiscountProvider extends ChangeNotifier {
  List<Discount> discounts = [];
  bool loading = true;

  /// First non-permission stream failure, surfaced instead of hanging.
  String? error;

  /// True when Firestore rejected the discounts read for this role. Discount
  /// management is manager-only, so a denial is an expected capability boundary
  /// rather than an exceptional error.
  bool permissionDenied = false;
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
    permissionDenied = false;
    _subs.add(FirestoreService.instance.watchDiscounts(shopId).listen(
      (list) {
        discounts = list;
        loading = false;
        notifyListeners();
      },
      // Discount management is manager-only; a denied read must clear `loading`
      // and surface an explicit access state instead of an empty list.
      onError: (Object e, StackTrace _) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          permissionDenied = true;
        } else {
          error ??= e.toString();
        }
        loading = false;
        notifyListeners();
      },
    ));
  }

  /// Re-subscribes to the bound shop after a transient error.
  void retry() {
    final shop = _boundShopId;
    if (shop == null) return;
    _boundShopId = null;
    bind(shop);
  }

  Future<void> add(Discount d, String shopId) =>
      FirestoreService.instance.addDiscount(shopId, d);

  Future<void> update(Discount d, String shopId) =>
      FirestoreService.instance.updateDiscount(shopId, d);

  Future<void> delete(String id, String shopId) =>
      FirestoreService.instance.deleteDiscount(shopId, id);

  // The redemption counter is incremented by the createAppointment callable
  // inside the booking transaction, so there is no client usage path.

  Discount? findActiveByCode(String code) {
    for (final d in discounts) {
      if (d.code.toLowerCase() == code.trim().toLowerCase()) return d;
    }
    return null;
  }

  /// Drops the bound shop and cached discounts. Used on sign-out.
  void reset() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _boundShopId = null;
    discounts = [];
    loading = true;
    error = null;
    permissionDenied = false;
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

String newDiscountId() => const Uuid().v4();
