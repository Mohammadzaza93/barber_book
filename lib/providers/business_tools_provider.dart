import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/appointment.dart';
import '../models/business_features.dart';
import '../models/enums.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class BusinessToolsProvider extends ChangeNotifier {
  String? _shopId;
  final List<StreamSubscription> _subs = [];

  List<PortfolioItem> portfolio = [];
  List<CustomerProfile> customers = [];
  List<LoyaltyAccount> loyalty = [];
  List<LoyaltyRule> loyaltyRules = [];
  List<LoyaltyGift> loyaltyGifts = [];
  List<Chair> chairs = [];
  List<ChairSupply> chairSupplies = [];
  List<ChairWeeklyProfit> weeklyProfits = [];
  List<QueueEntry> queue = [];
  List<Payment> payments = [];
  bool loading = true;
  List<Appointment> _appointments = [];

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
    _subs.add(db.watchCustomers(shopId).listen((value) {
      customers = value;
      notifyListeners();
    }));
    _subs.add(db.watchLoyalty(shopId).listen((value) {
      loyalty = value;
      notifyListeners();
    }));
    _subs.add(db.watchLoyaltyRules(shopId).listen((value) {
      loyaltyRules = value;
      notifyListeners();
    }));
    _subs.add(db.watchLoyaltyGifts(shopId).listen((value) {
      loyaltyGifts = value;
      notifyListeners();
    }));
    _subs.add(db.watchChairs(shopId).listen((value) {
      chairs = value;
      notifyListeners();
    }));
    _subs.add(db.watchChairSupplies(shopId).listen((value) {
      chairSupplies = value;
      notifyListeners();
    }));
    _subs.add(db.watchChairWeeklyProfits(shopId).listen((value) {
      weeklyProfits = value;
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
    _subs.add(db.watchAppointments(shopId).listen((value) {
      _appointments = value;
      _syncCustomerProfiles(value);
    }));
  }

  String get shopId => _shopId!;
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  String newId() => const Uuid().v4();

  Future<void> addPortfolio(PortfolioItem item) =>
      FirestoreService.instance.addPortfolioItem(shopId, item);
  Future<void> deletePortfolio(String id) =>
      FirestoreService.instance.deletePortfolioItem(shopId, id);

  Future<void> saveCustomer(CustomerProfile customer) =>
      FirestoreService.instance.saveCustomer(shopId, customer);
  Future<void> deleteCustomer(String id) =>
      FirestoreService.instance.deleteCustomer(shopId, id);

  Future<void> saveLoyalty(LoyaltyAccount account) =>
      FirestoreService.instance.saveLoyalty(shopId, account);
  Future<void> addPoints(String id, int points) =>
      FirestoreService.instance.addLoyaltyPoints(shopId, id, points);
  Future<void> saveLoyaltyRule(LoyaltyRule rule) =>
      FirestoreService.instance.saveLoyaltyRule(shopId, rule);
  Future<void> deleteLoyaltyRule(String id) =>
      FirestoreService.instance.deleteLoyaltyRule(shopId, id);
  Future<void> saveLoyaltyGift(LoyaltyGift gift) =>
      FirestoreService.instance.saveLoyaltyGift(shopId, gift);
  Future<void> deleteLoyaltyGift(String id) =>
      FirestoreService.instance.deleteLoyaltyGift(shopId, id);
  Future<void> redeemGift(String accountId, LoyaltyGift gift) =>
      FirestoreService.instance.redeemLoyaltyGift(shopId, accountId, gift);

  Future<void> saveChair(Chair chair) =>
      FirestoreService.instance.saveChair(shopId, chair);
  Future<void> deleteChair(String id) =>
      FirestoreService.instance.deleteChair(shopId, id);
  Future<void> saveChairSupply(ChairSupply supply) =>
      FirestoreService.instance.saveChairSupply(shopId, supply);
  Future<void> deleteChairSupply(String id) =>
      FirestoreService.instance.deleteChairSupply(shopId, id);
  Future<void> saveWeeklyProfit(ChairWeeklyProfit report) =>
      FirestoreService.instance.saveChairWeeklyProfit(shopId, report);

  Future<void> saveQueue(QueueEntry entry) =>
      FirestoreService.instance.updateQueueEntry(shopId, entry);
  Future<void> addQueue(QueueEntry entry) =>
      FirestoreService.instance.saveQueueEntry(shopId, entry);

  Future<void> addPayment(Payment payment) async {
    await FirestoreService.instance.addPayment(shopId, payment);
    final phone = payment.customerPhone.trim();
    if (phone.isEmpty) return;
    final matchingRules = loyaltyRules.where((rule) => rule.enabled);
    final configuredPoints = matchingRules.fold<int>(
      0,
      (sum, rule) => sum + rule.calculatePoints(payment.amount),
    );
    final earned = matchingRules.isEmpty
        ? payment.amount.floor().clamp(1, 10000).toInt()
        : configuredPoints;
    if (earned <= 0) return;
    final existing = loyalty
        .where((account) => account.customerPhone.trim() == phone)
        .firstOrNull;
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
    await NotificationService.instance.show(
      'تمت إضافة نقاط الولاء',
      'تمت إضافة $earned نقطة للعميل ${payment.customerName.isEmpty ? payment.customerPhone : payment.customerName}.',
    );
  }

  Future<void> deletePayment(String id) =>
      FirestoreService.instance.deletePayment(shopId, id);

  String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _syncCustomerProfiles(List<Appointment> appointments) async {
    if (_shopId == null) return;
    final grouped = <String, List<Appointment>>{};
    for (final appointment in appointments) {
      final phone = normalizePhone(appointment.customerPhone);
      if (phone.isEmpty) continue;
      if (appointment.status == AppointmentStatus.cancelled ||
          appointment.status == AppointmentStatus.noShow) {
        continue;
      }
      grouped.putIfAbsent(phone, () => []).add(appointment);
    }

    for (final entry in grouped.entries) {
      final phone = entry.key;
      final history = entry.value;
      final completed = history
          .where((a) => a.status == AppointmentStatus.completed)
          .toList()
        ..sort((a, b) => a.startTime.compareTo(b.startTime));
      final existing = customers.where((c) => c.id == phone).firstOrNull;
      final source = history.lastWhere(
        (a) => a.customerName.trim().isNotEmpty,
        orElse: () => history.last,
      );
      final visits = completed.length;
      final spent = completed.fold<double>(0, (sum, a) => sum + a.totalAmount);
      final first = completed.isEmpty ? existing?.firstVisitAt : completed.first.startTime;
      final last = completed.isEmpty ? existing?.lastVisitAt : completed.last.startTime;
      final interval = _averageIntervalDays(completed);
      final expected = last != null && interval > 0
          ? last.add(Duration(days: interval.round()))
          : existing?.nextExpectedVisitAt;
      final serviceIds = _topValues(
        completed.expand((a) => a.serviceIds),
        limit: 3,
      );
      final employeeId = _topValue(completed.map((a) => a.employeeId));
      final profile = CustomerProfile(
        id: phone,
        name: source.customerName.trim().isEmpty
            ? (existing?.name ?? '')
            : source.customerName.trim(),
        phone: phone,
        email: source.customerEmail.trim().isEmpty
            ? (existing?.email ?? '')
            : source.customerEmail.trim(),
        visitCount: visits,
        totalSpent: spent,
        firstVisitAt: first,
        lastVisitAt: last,
        nextExpectedVisitAt: expected,
        averageVisitIntervalDays: interval > 0
            ? interval
            : (existing?.averageVisitIntervalDays ?? 0),
        preferredServiceIds: serviceIds.isEmpty
            ? (existing?.preferredServiceIds ?? const [])
            : serviceIds,
        preferredEmployeeId: employeeId ?? existing?.preferredEmployeeId,
        preferredTime: last == null ? (existing?.preferredTime ?? '') : _timeBucket(last),
        notes: existing?.notes ?? '',
        marketingOptIn: existing?.marketingOptIn ?? false,
        createdAt: existing?.createdAt ?? (first ?? DateTime.now()),
        updatedAt: DateTime.now(),
      );
      if (existing == null || !_sameComputedFields(existing, profile)) {
        await FirestoreService.instance.saveCustomer(shopId, profile);
      }
    }
  }

  double _averageIntervalDays(List<Appointment> appointments) {
    if (appointments.length < 2) return 0;
    var total = 0.0;
    for (var i = 1; i < appointments.length; i++) {
      total += appointments[i]
          .startTime
          .difference(appointments[i - 1].startTime)
          .inHours /
          24;
    }
    return total / (appointments.length - 1);
  }

  List<String> _topValues(Iterable<String> values, {int limit = 3}) {
    final counts = <String, int>{};
    for (final value in values) {
      if (value.trim().isEmpty) continue;
      counts[value] = (counts[value] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(limit).map((e) => e.key).toList();
  }

  String? _topValue(Iterable<String> values) => _topValues(values, limit: 1).firstOrNull;

  String _timeBucket(DateTime date) {
    final hour = date.hour;
    if (hour < 12) return 'صباحًا';
    if (hour < 17) return 'ظهرًا';
    return 'مساءً';
  }

  bool _sameComputedFields(CustomerProfile a, CustomerProfile b) =>
      a.name == b.name &&
      a.email == b.email &&
      a.visitCount == b.visitCount &&
      a.totalSpent == b.totalSpent &&
      a.firstVisitAt == b.firstVisitAt &&
      a.lastVisitAt == b.lastVisitAt &&
      a.nextExpectedVisitAt == b.nextExpectedVisitAt &&
      a.averageVisitIntervalDays == b.averageVisitIntervalDays &&
      _listEquals(a.preferredServiceIds, b.preferredServiceIds) &&
      a.preferredEmployeeId == b.preferredEmployeeId &&
      a.preferredTime == b.preferredTime;

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
