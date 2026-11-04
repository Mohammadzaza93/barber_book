import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/app_role.dart';
import '../models/appointment.dart';
import '../models/business_features.dart';
import '../models/enums.dart';
import '../services/firestore_service.dart';
import '../services/firestore_inventory.dart';

bool canSyncCustomerProfiles(AppRole? role) =>
    role == null || role == AppRole.admin;

typedef StocktakeSaver = Future<void> Function(
    String shopId, Stocktake stocktake);
typedef StocktakeCountSaver = Future<Stocktake> Function({
  required String shopId,
  required String stocktakeId,
  required Map<String, double?> counts,
});
typedef StocktakePoster = Future<StocktakePostResult> Function({
  required String shopId,
  required String stocktakeId,
  String? actorId,
});
typedef StocktakeRefresher = Future<Stocktake> Function({
  required String shopId,
  required String stocktakeId,
});
typedef StocktakeDeleter = Future<void> Function(
    String shopId, String stocktakeId);
typedef CustomerAppointmentLoader = Future<List<Appointment>> Function(
    String shopId, String phone);
typedef InventoryHistoryLoader = Future<List<InventoryMovement>> Function(
    String shopId, DateTime from, DateTime to);

Future<List<InventoryMovement>> _firestoreInventoryHistory(
        String shopId, DateTime from, DateTime to) =>
    FirestoreInventory.instance.fetchInventoryMovementsBetween(
      shopId: shopId,
      from: from,
      to: to,
    );

class BusinessToolsProvider extends ChangeNotifier {
  BusinessToolsProvider({
    StocktakeSaver? saveStocktake,
    StocktakeCountSaver? saveStocktakeCounts,
    StocktakePoster? postStocktake,
    StocktakeRefresher? refreshStocktakeExpected,
    StocktakeDeleter? deleteStocktake,
    CustomerAppointmentLoader? loadCustomerAppointments,
    InventoryHistoryLoader? loadInventoryMovements,
  })  : _saveStocktake =
            saveStocktake ?? FirestoreInventory.instance.saveStocktake,
        _saveStocktakeCounts = saveStocktakeCounts ??
            FirestoreInventory.instance.saveStocktakeCounts,
        _postStocktake =
            postStocktake ?? FirestoreInventory.instance.postStocktake,
        _refreshStocktakeExpected = refreshStocktakeExpected ??
            FirestoreInventory.instance.refreshStocktakeExpected,
        _deleteStocktake =
            deleteStocktake ?? FirestoreInventory.instance.deleteStocktake,
        _loadCustomerAppointments = loadCustomerAppointments ??
            FirestoreService.instance.findAppointmentsByPhone,
        _loadInventoryMovements =
            loadInventoryMovements ?? _firestoreInventoryHistory;

  String? _shopId;
  AppRole? _role;
  final List<StreamSubscription> _subs = [];

  final StocktakeSaver _saveStocktake;
  final StocktakeCountSaver _saveStocktakeCounts;
  final StocktakePoster _postStocktake;
  final StocktakeRefresher _refreshStocktakeExpected;
  final StocktakeDeleter _deleteStocktake;
  final CustomerAppointmentLoader _loadCustomerAppointments;
  final InventoryHistoryLoader _loadInventoryMovements;

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
  List<Stocktake> stocktakes = [];
  bool loading = true;
  String? error;
  bool permissionDenied = false;

  /// صحيح إذا تعذّر تحميل سجل الحركات الكامل فاعتمد التقرير على النافذة المحلية.
  bool inventoryHistoryDegraded = false;

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
    final inv = FirestoreInventory.instance;

    _listen(db.watchCustomers(shopId), (v) => customers = v);
    _listen(db.watchLoyalty(shopId), (v) => loyalty = v);
    _listen(db.watchLoyaltyRules(shopId), (v) => loyaltyRules = v);
    _listen(db.watchLoyaltyGifts(shopId), (v) => loyaltyGifts = v);
    _listen(db.watchChairs(shopId), (v) => chairs = v);
    _listen(db.watchChairSupplies(shopId), (v) => chairSupplies = v);
    _listen(db.watchChairWeeklyProfits(shopId), (v) => weeklyProfits = v);
    _listen(db.watchQueue(shopId), (v) => queue = v);
    _listen(inv.watchInventory(shopId), (v) => inventory = v);
    _listen(inv.watchInventoryMovements(shopId), (v) => inventoryMovements = v);
    _listen(inv.watchStocktakes(shopId), (v) => stocktakes = v);
    _listen(db.watchPayments(shopId), (v) => payments = v);

    _listen(
      db.watchAppointments(shopId),
      (v) {
        _appointments = v;
        _syncCustomerProfiles(v);
      },
      gatesLoading: true,
    );
  }

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
        if (gatesLoading) loading = false;
        notifyListeners();
      },
    ));
  }

  bool get isBound => _shopId != null;
  String get shopId => _shopId ?? '';
  List<Appointment> get appointments => List.unmodifiable(_appointments);
  String newId() => const Uuid().v4();

  Future<void> saveCustomer(CustomerProfile customer) =>
      FirestoreService.instance.saveCustomer(shopId, customer);
  Future<void> deleteCustomer(String id) =>
      FirestoreService.instance.deleteCustomer(shopId, id);

  /// يحمّل سجل الزبون الكامل (كل السنوات) بدمج:
  /// 1) المواعيد المحمّلة محلياً (نافذة قريبة) — تغطي صيغ الهاتف المختلفة.
  /// 2) استعلام Firestore بالهاتف المعياري — يغطي التاريخ القديم.
  ///
  /// الدمج بالمعرّف يمنع تكرار الموعد، ويُرتّب تصاعدياً حسب الوقت.
  Future<List<Appointment>> loadCustomerHistory(String phone) async {
    final shop = _shopId;
    if (shop == null || shop.isEmpty) {
      throw StateError('لا يوجد محل مرتبط');
    }
    final normalized = normalizePhone(phone);
    if (normalized.isEmpty) return const [];

    final seenIds = <String>{};
    final merged = <Appointment>[];
    void addAll(Iterable<Appointment> appointments) {
      for (final appointment in appointments) {
        if (seenIds.add(appointment.id)) merged.add(appointment);
      }
    }

    addAll(_appointments.where(
      (a) => normalizePhone(a.customerPhone) == normalized,
    ));

    try {
      addAll(await _loadCustomerAppointments(shop, normalized));
    } on FirebaseException catch (e) {
      // السجل الكامل ميزة إضافية؛ لا نُفشل الصفحة إذا مُنع الوصول.
      if (e.code != 'permission-denied') rethrow;
    }

    merged.sort((a, b) => a.startTime.compareTo(b.startTime));
    return merged;
  }

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
    final appointmentId = payment.appointmentId.trim().isEmpty
        ? null
        : payment.appointmentId.trim();
    await FirestoreService.instance.recordPayment(
        shopId,
        Payment(
          id: payment.id,
          appointmentId: appointmentId ?? '',
          customerName: payment.customerName,
          customerPhone: payment.customerPhone,
          chairId: payment.chairId,
          employeeId: payment.employeeId,
          amount: payment.amount,
          materialCost: payment.materialCost,
          method: payment.method,
          paidAt: payment.paidAt,
          notes: payment.notes,
        ));
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

  Future<void> deletePayment(String id) async {
    if (_shopId == null) return;
    await FirestoreService.instance.deletePayment(_shopId!, id);
  }

  Future<void> saveInventoryItem(InventoryItem item) =>
      FirestoreInventory.instance.saveInventoryItem(shopId, item);

  Future<void> deleteInventoryItem(String id) async {
    final item = inventory.where((i) => i.id == id).firstOrNull;
    final hasStock = (item?.quantity ?? 0) > kStockEpsilon;

    // لا نحذف مادة لها رصيد أو حركات. عند تعذّر التحقق (انقطاع) نعطّل بدل
    // الحذف، حتى لا نفقد صنفاً له سجل محاسبي.
    bool hasMoves;
    try {
      hasMoves = await FirestoreInventory.instance.hasMovements(shopId, id);
    } catch (_) {
      hasMoves = true;
    }

    if (hasMoves || hasStock) {
      await FirestoreInventory.instance.deactivateInventoryItem(shopId, id);
    } else {
      await FirestoreInventory.instance.deleteInventoryItem(shopId, id);
    }
  }

  Future<void> applyInventoryMovement(InventoryMovement movement) async {
    await FirestoreInventory.instance.applyMovementAtomic(
      shopId: shopId,
      movementId: movement.id,
      itemId: movement.itemId,
      type: movement.type,
      quantity: movement.quantity,
      unitCost: movement.unitCost,
      reason: movement.reason,
      actorId: movement.actorId,
    );
  }

  /// إنشاء مادة جديدة + رصيد افتتاحي كحركة شراء (معاملة واحدة).
  Future<void> createInventoryItem(
    InventoryItem item, {
    double openingQty = 0,
  }) =>
      FirestoreInventory.instance.createItemWithOpeningStock(
        shopId: shopId,
        item: item,
        openingQty: openingQty,
      );

  /// يحمّل حركات المخزون لفترة التقرير.
  ///
  /// يبدأ بالنافذة المحمّلة (سريعة وتعمل بلا اتصال)، ثم يدمج حركات الفترة من
  /// Firestore. أي فشل وصول لا يُفشل التقرير؛ يُعلَّم [inventoryHistoryDegraded]
  /// لتظهر ملاحظة أن الأرقام قد تكون ناقصة.
  Future<List<InventoryMovement>> loadInventoryMovements({
    required DateTime from,
    required DateTime to,
  }) async {
    inventoryHistoryDegraded = false;
    final local = _movementsBetween(from, to);
    final shop = _shopId;
    if (shop == null || shop.isEmpty) return local;

    try {
      final remote = await _loadInventoryMovements(shop, from, to);
      final byId = <String, InventoryMovement>{
        for (final movement in local) movement.id: movement,
        for (final movement in remote) movement.id: movement,
      };
      final merged = byId.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return merged;
    } on FirebaseException {
      inventoryHistoryDegraded = true;
      return local;
    } catch (_) {
      inventoryHistoryDegraded = true;
      return local;
    }
  }

  List<InventoryMovement> _movementsBetween(DateTime from, DateTime to) =>
      inventoryMovements
          .where((m) => !m.createdAt.isBefore(from) && !m.createdAt.isAfter(to))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  // ---------- Stocktaking (جرد) ----------

  /// يبدأ جلسة جرد من الأرصدة الحالية للمواد النشطة.
  ///
  /// اللقطة تُحفظ في مستند واحد، ثم تُملأ الكميات المعدودة وتُرحّل لاحقاً.
  Future<Stocktake> startStocktake({String? note, String? actorId}) async {
    final shop = _shopId;
    if (shop == null || shop.isEmpty) {
      throw StateError('لا يوجد محل مرتبط');
    }
    final active = inventory.where((item) => item.active).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    if (active.isEmpty) {
      throw StateError('لا توجد مواد نشطة للجرد');
    }
    if (active.length > Stocktake.maxLines) {
      throw StateError(
          'عدد المواد أكبر من الحد المسموح (${Stocktake.maxLines}). '
          'قسّم الجرد على أكثر من جلسة.');
    }
    final now = DateTime.now().toUtc();
    final session = Stocktake(
      id: newId(),
      status: StocktakeStatus.draft,
      note: note?.trim() ?? '',
      lines: [
        for (final item in active)
          StocktakeLine(
            itemId: item.id,
            itemName: item.name,
            unit: item.unit,
            unitCost: item.unitCost,
            expectedQty: item.quantity,
          ),
      ],
      createdAt: now,
      createdBy: actorId,
      updatedAt: now,
    );
    await _saveStocktake(shop, session);
    _replaceStocktake(session);
    return session;
  }

  /// يحفظ الكميات المعدودة دفعة واحدة (كتابة واحدة على الخطة المجانية).
  Future<Stocktake> saveStocktakeCounts(
    String stocktakeId,
    Map<String, double?> counts,
  ) async {
    final shop = _shopId;
    if (shop == null || shop.isEmpty) {
      throw StateError('لا يوجد محل مرتبط');
    }
    final updated = await _saveStocktakeCounts(
      shopId: shop,
      stocktakeId: stocktakeId,
      counts: counts,
    );
    _replaceStocktake(updated);
    return updated;
  }

  /// ترحيل الجرد. يرجع نتيجة تفصيلية؛ لا تفترض النجاح إذا وُجد تعارض.
  Future<StocktakePostResult> postStocktake(
    String stocktakeId, {
    String? actorId,
  }) async {
    final shop = _shopId;
    if (shop == null || shop.isEmpty) {
      throw StateError('لا يوجد محل مرتبط');
    }
    final result = await _postStocktake(
      shopId: shop,
      stocktakeId: stocktakeId,
      actorId: actorId,
    );
    final session = result.session;
    if (session != null) _replaceStocktake(session);
    return result;
  }

  /// إعادة أخذ لقطة الأرصدة بعد تعارض (تغيّر المخزون أثناء العد).
  Future<Stocktake> refreshStocktakeExpected(String stocktakeId) async {
    final shop = _shopId;
    if (shop == null || shop.isEmpty) {
      throw StateError('لا يوجد محل مرتبط');
    }
    final updated = await _refreshStocktakeExpected(
      shopId: shop,
      stocktakeId: stocktakeId,
    );
    _replaceStocktake(updated);
    return updated;
  }

  /// إلغاء جلسة قبل ترحيلها. لا يحذف السجل (يبقى للأثر).
  Future<Stocktake> cancelStocktake(Stocktake session) async {
    final shop = _shopId;
    if (shop == null || shop.isEmpty) {
      throw StateError('لا يوجد محل مرتبط');
    }
    if (!session.isOpen) {
      throw StateError('لا يمكن إلغاء جلسة مغلقة');
    }
    final updated = session.copyWith(
      status: StocktakeStatus.cancelled,
      updatedAt: DateTime.now().toUtc(),
    );
    await _saveStocktake(shop, updated);
    _replaceStocktake(updated);
    return updated;
  }

  /// حذف مسودة/ملغى فقط؛ الجلسات المرحّلة سجل تدقيق.
  Future<void> deleteStocktake(Stocktake session) async {
    final shop = _shopId;
    if (shop == null || shop.isEmpty) {
      throw StateError('لا يوجد محل مرتبط');
    }
    if (session.isCompleted || session.postedCount > 0) {
      throw StateError('لا يمكن حذف جلسة رُحّلت إلى المخزون');
    }
    if (!session.isDeletable) {
      throw StateError('لا يمكن حذف جلسة قيد الترحيل');
    }
    await _deleteStocktake(shop, session.id);
    stocktakes = stocktakes.where((s) => s.id != session.id).toList();
    notifyListeners();
  }

  Stocktake? stocktakeById(String id) =>
      stocktakes.where((s) => s.id == id).firstOrNull;

  void _replaceStocktake(Stocktake session) {
    final next = List<Stocktake>.from(stocktakes);
    final index = next.indexWhere((s) => s.id == session.id);
    if (index >= 0) {
      next[index] = session;
    } else {
      next.insert(0, session);
    }
    stocktakes = next;
    notifyListeners();
  }

  /// يسمح للاختبارات بربط محل دون فتح اشتراكات Firestore.
  @visibleForTesting
  void bindForTest(String shopId, {AppRole? role}) {
    _shopId = shopId;
    _role = role;
    loading = false;
  }

  String normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _syncCustomerProfiles(List<Appointment> appointments) async {
    if (!canSyncCustomerProfiles(_role)) return;
    final boundShop = _shopId;
    if (boundShop == null) return;
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
      if (_shopId != boundShop) return;
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
      final first = completed.isEmpty
          ? existing?.firstVisitAt
          : completed.first.startTime;
      final last =
          completed.isEmpty ? existing?.lastVisitAt : completed.last.startTime;
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
        averageVisitIntervalDays:
            interval > 0 ? interval : (existing?.averageVisitIntervalDays ?? 0),
        preferredServiceIds: serviceIds.isEmpty
            ? (existing?.preferredServiceIds ?? const [])
            : serviceIds,
        preferredEmployeeId: employeeId ?? existing?.preferredEmployeeId,
        preferredTime:
            last == null ? (existing?.preferredTime ?? '') : _timeBucket(last),
        notes: existing?.notes ?? '',
        marketingOptIn: existing?.marketingOptIn ?? false,
        createdAt: existing?.createdAt ?? (first ?? DateTime.now()),
        updatedAt: DateTime.now(),
      );
      if (existing == null || !_sameComputedFields(existing, profile)) {
        try {
          await FirestoreService.instance.saveCustomer(boundShop, profile);
        } on FirebaseException catch (e) {
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

  String? _topValue(Iterable<String> values) =>
      _topValues(values, limit: 1).firstOrNull;

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

  void reset() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    _shopId = null;
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
    stocktakes = [];
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
