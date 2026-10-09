import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_role.dart';
import '../models/appointment.dart';
import '../models/business_features.dart';
import '../models/enums.dart';
import '../services/firestore_service.dart';
import '../services/secure_api.dart';

/// The `customers` collection is manager/owner-only in firestore.rules, so only
/// those roles may run the appointment-derived customer-profile synchronisation.
/// A null role means "unknown/not provided" and preserves the previous behaviour
/// for callers that bind without a role (e.g. older tests).
bool canSyncCustomerProfiles(AppRole? role) =>
    role == null || role == AppRole.owner || role == AppRole.manager;

class BusinessToolsProvider extends ChangeNotifier {
  String? _shopId;
  AppRole? _role;
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
  List<InventoryItem> inventory = [];
  List<InventoryMovement> inventoryMovements = [];
  bool loading = true;

  /// First unrecoverable stream error, surfaced in the UI instead of hanging.
  String? error;

  /// True when Firestore rejected a read for this role. Staff legitimately
  /// lack access to the manager-only collections, so this is expected rather
  /// than exceptional.
  bool permissionDenied = false;

  List<Appointment> _appointments = [];

  void bind(String shopId, [AppRole? role]) {
    if (_shopId == shopId) {
      _role = role;
      return;
    }
    _shopId = shopId;
    _role = role;
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    loading = true;
    error = null;
    permissionDenied = false;
    final db = FirestoreService.instance;

    _listen(db.watchPortfolio(shopId), (v) => portfolio = v);
    _listen(db.watchCustomers(shopId), (v) => customers = v);
    _listen(db.watchLoyalty(shopId), (v) => loyalty = v);
    _listen(db.watchLoyaltyRules(shopId), (v) => loyaltyRules = v);
    _listen(db.watchLoyaltyGifts(shopId), (v) => loyaltyGifts = v);
    _listen(db.watchChairs(shopId), (v) => chairs = v);
    _listen(db.watchChairSupplies(shopId), (v) => chairSupplies = v);
    _listen(db.watchChairWeeklyProfits(shopId), (v) => weeklyProfits = v);
    _listen(db.watchQueue(shopId), (v) => queue = v);
    _listen(db.watchInventory(shopId), (v) => inventory = v);
    _listen(db.watchInventoryMovements(shopId), (v) => inventoryMovements = v);
    _listen(db.watchPayments(shopId), (v) => payments = v);

    // `appointments` is the gating stream: it is readable by every shop role
    // (firestore.rules canReadShopData), so `loading` always resolves. The
    // previously-gated `payments` stream is manager-only, which left staff
    // spinning forever.
    _listen(
      db.watchAppointments(shopId),
      (v) {
        _appointments = v;
        _syncCustomerProfiles(v);
      },
      gatesLoading: true,
    );
  }

  /// Subscribes [stream], funnelling both data and failures through one path so
  /// a single denied collection can never leave the screen on a spinner.
  void _listen<T>(
    Stream<List<T>> stream,
    void Function(List<T> value) onData, {
    bool gatesLoading = false,
  }) {
    _subs.add(stream.listen(
      (value) {
        onData(value);
        if (gatesLoading) loading = false;
        notifyListeners();
      },
      onError: (Object e, StackTrace _) {
        final code = e is FirebaseException ? e.code : '';
        if (code == 'permission-denied') {
          permissionDenied = true;
        } else {
          error ??= e.toString();
        }
        // Never leave the caller waiting on a stream that can no longer deliver.
        if (gatesLoading) loading = false;
        notifyListeners();
      },
    ));
  }

  bool get isBound => _shopId != null;
  String get shopId => _shopId ?? '';
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

  /// Records a payment through the callable so the appointment total and its
  /// derived payment status can never disagree, then applies the loyalty
  /// points that the shop rules award for the same sale.
  Future<void> addPayment(Payment payment) async {
    final appointmentId =
        payment.appointmentId.trim().isEmpty ? null : payment.appointmentId.trim();
    await SecureApi.instance.recordPayment(
      shopId: shopId,
      appointmentId: appointmentId,
      method: payment.method,
      amount: payment.amount,
    );
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
  }

  Future<void> deletePayment(String id) =>
      SecureApi.instance.deletePayment(shopId: shopId, paymentId: id);

  Future<void> saveInventoryItem(InventoryItem item) =>
      FirestoreService.instance.saveInventoryItem(shopId, item);

  Future<void> deleteInventoryItem(String id) =>
      FirestoreService.instance.deleteInventoryItem(shopId, id);

  /// يسجل حركة مخزون ويحدّث رصيد المادة تلقائياً.
  /// - purchase: إضافة الكمية للرصيد وتحديث تكلفة الوحدة.
  /// - usage / waste: خصم الكمية (يفشل إذا كان الرصيد غير كافٍ).
  /// - adjustment: ضبط الرصيد على الكمية الفعلية بعد الجرد.
  Future<void> applyInventoryMovement(InventoryMovement movement) async {
    final item = inventory.where((x) => x.id == movement.itemId).firstOrNull;
    if (item == null) throw StateError('المادة غير موجودة في المخزون');
    double newQuantity;
    switch (movement.type) {
      case 'purchase':
        newQuantity = item.quantity + movement.quantity;
        break;
      case 'usage':
      case 'waste':
        if (movement.quantity > item.quantity) {
          throw StateError('الرصيد غير كافٍ (${item.quantity} ${item.unit})');
        }
        newQuantity = item.quantity - movement.quantity;
        break;
      case 'adjustment':
        newQuantity = movement.quantity;
        break;
      default:
        throw StateError('نوع حركة غير معروف');
    }
    await FirestoreService.instance.saveInventoryItem(
      shopId,
      item.copyWith(
        quantity: newQuantity,
        unitCost: movement.type == 'purchase' && movement.unitCost > 0
            ? movement.unitCost
            : item.unitCost,
        updatedAt: DateTime.now(),
      ),
    );
    await FirestoreService.instance.addInventoryMovement(shopId, movement);
  }

  String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _syncCustomerProfiles(List<Appointment> appointments) async {
    // Skipping the sync for staff avoids a stream of denied writes instead of
    // relying on catching each one after Firestore rejects it.
    if (!canSyncCustomerProfiles(_role)) return;
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
        try {
          await FirestoreService.instance.saveCustomer(shopId, profile);
        } on FirebaseException catch (e) {
          // A permission-denied here is an expected capability boundary; any
          // other failure is a real problem and must stay observable.
          if (e.code != 'permission-denied') rethrow;
        }
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

  /// Drops the bound shop and all twelve cached collections. Used on sign-out so
  /// customer profiles and financials never survive into the next session.
  void reset() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _shopId = null;
    portfolio = [];
    customers = [];
    loyalty = [];
    loyaltyRules = [];
    loyaltyGifts = [];
    chairs = [];
    chairSupplies = [];
    weeklyProfits = [];
    queue = [];
    payments = [];
    inventory = [];
    inventoryMovements = [];
    _appointments = [];
    loading = true;
    error = null;
    permissionDenied = false;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    super.dispose();
  }
}
