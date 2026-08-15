import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/business_features.dart';
import '../services/firestore_service.dart';

class BusinessToolsProvider extends ChangeNotifier {
  String? _shopId;
  final List<StreamSubscription> _subs = [];

  List<PortfolioItem> portfolio = [];
  List<LoyaltyAccount> loyalty = [];
  List<Chair> chairs = [];
  List<QueueEntry> queue = [];
  List<Payment> payments = [];
  bool loading = true;

  void bind(String shopId) {
    if (_shopId == shopId) return;
    _shopId = shopId;
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    loading = true;
    final db = FirestoreService.instance;
    _subs.add(db.watchPortfolio(shopId).listen((value) {
      portfolio = value;
      notifyListeners();
    }));
    _subs.add(db.watchLoyalty(shopId).listen((value) {
      loyalty = value;
      notifyListeners();
    }));
    _subs.add(db.watchChairs(shopId).listen((value) {
      chairs = value;
      notifyListeners();
    }));
    _subs.add(db.watchQueue(shopId).listen((value) {
      queue = value;
      notifyListeners();
    }));
    _subs.add(db.watchPayments(shopId).listen((value) {
      payments = value;
      loading = false;
      notifyListeners();
    }));
  }

  String get shopId => _shopId!;
  String newId() => const Uuid().v4();

  Future<void> addPortfolio(PortfolioItem item) =>
      FirestoreService.instance.addPortfolioItem(shopId, item);
  Future<void> deletePortfolio(String id) =>
      FirestoreService.instance.deletePortfolioItem(shopId, id);
  Future<void> saveLoyalty(LoyaltyAccount account) =>
      FirestoreService.instance.saveLoyalty(shopId, account);
  Future<void> addPoints(String id, int points) =>
      FirestoreService.instance.addLoyaltyPoints(shopId, id, points);
  Future<void> saveChair(Chair chair) =>
      FirestoreService.instance.saveChair(shopId, chair);
  Future<void> deleteChair(String id) =>
      FirestoreService.instance.deleteChair(shopId, id);
  Future<void> saveQueue(QueueEntry entry) =>
      FirestoreService.instance.updateQueueEntry(shopId, entry);
  Future<void> addQueue(QueueEntry entry) =>
      FirestoreService.instance.saveQueueEntry(shopId, entry);
  Future<void> addPayment(Payment payment) async {
    await FirestoreService.instance.addPayment(shopId, payment);
    final phone = payment.customerPhone.trim();
    if (phone.isEmpty) return;
    final earned = payment.amount.floor().clamp(1, 10000).toInt();
    final existing = loyalty.where((account) => account.customerPhone == phone).firstOrNull;
    if (existing != null) {
      await addPoints(existing.id, earned);
    } else {
      final account = LoyaltyAccount(
        id: phone,
        customerName: payment.customerName,
        customerPhone: phone,
        points: earned,
        updatedAt: DateTime.now(),
      );
      await saveLoyalty(account.copyWith(tier: account.calculatedTier));
    }
  }
  Future<void> deletePayment(String id) =>
      FirestoreService.instance.deletePayment(shopId, id);

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
