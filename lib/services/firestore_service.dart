import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../models/app_role.dart';
import '../models/business_features.dart';
import '../models/booking_settings.dart';
import '../models/discount.dart';
import '../models/employee.dart';
import '../models/expense.dart';
import '../models/feedback.dart';
import '../models/member.dart';
import '../models/service.dart';
import '../models/unavailability_request.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _shops() =>
      _db.collection('shops');

  CollectionReference<Map<String, dynamic>> _coll(
          String shopId, String name) =>
      _shops().doc(shopId).collection(name);

  // ---------- Shop ----------

  Future<String> createShop({
    required String ownerId,
    required String shopName,
    required String phone,
    required String address,
    required String currency,
    String? primaryColorHex,
    String? accentColorHex,
    String? slug,
  }) async {
    final doc = _shops().doc();
    final settings = BookingSettings(
      shopName: shopName,
      phone: phone,
      address: address,
      currency: currency,
      primaryColorHex: primaryColorHex ?? '0xFF121316',
      accentColorHex: accentColorHex ?? '0xFFC6CBD4',
      slug: slug ?? 'shop-${doc.id.substring(0, 6)}',
    );
    await doc.set({
      ...settings.toMap(),
      'ownerId': ownerId,
      'joinCode': genJoinCode(),
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<String?> findShopByOwner(String ownerId) async {
    final snap = await _shops()
        .where('ownerId', isEqualTo: ownerId)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Stream<BookingSettings> watchSettings(String shopId) =>
      _shops().doc(shopId).snapshots().map(
          (d) => BookingSettings.fromMap(d.data() ?? const {}));

  Future<void> updateSettings(String shopId, Map<String, dynamic> data) async {
    await _shops().doc(shopId).set(
        {...data, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  // ---------- Services ----------

  Stream<List<Service>> watchServices(String shopId) => _coll(shopId, 'services')
      .orderBy('sortOrder')
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => Service.fromMap(d.id, d.data()))
          .toList());

  Future<void> addService(String shopId, Service s) async {
    await _coll(shopId, 'services').doc(s.id).set(s.toMap());
  }

  Future<void> updateService(String shopId, Service s) async {
    await _coll(shopId, 'services').doc(s.id).set(s.toMap());
  }

  Future<void> deleteService(String shopId, String id) async {
    await _coll(shopId, 'services').doc(id).delete();
  }

  // ---------- Employees ----------

  Stream<List<Employee>> watchEmployees(String shopId) =>
      _coll(shopId, 'employees')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => Employee.fromMap(d.id, d.data()))
              .toList());

  Future<void> addEmployee(String shopId, Employee e) async {
    await _coll(shopId, 'employees').doc(e.id).set(e.toMap());
  }

  Future<void> updateEmployee(String shopId, Employee e) async {
    await _coll(shopId, 'employees').doc(e.id).set(e.toMap());
  }

  Future<void> deleteEmployee(String shopId, String id) async {
    await _coll(shopId, 'employees').doc(id).delete();
  }

  // ---------- Appointments ----------

  Stream<List<Appointment>> watchAppointments(String shopId) =>
      _coll(shopId, 'appointments')
          .orderBy('startTime')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => Appointment.fromMap(d.id, d.data()))
              .toList());

  Future<void> addAppointment(String shopId, Appointment a) async {
    await _coll(shopId, 'appointments').doc(a.id).set(a.toMap());
  }

  Future<void> updateAppointment(String shopId, Appointment a) async {
    await _coll(shopId, 'appointments').doc(a.id).set(a.toMap());
  }

  Future<void> deleteAppointment(String shopId, String id) async {
    await _coll(shopId, 'appointments').doc(id).delete();
  }

  Future<Appointment?> findAppointment(
      String shopId, String reference) async {
    final snap = await _coll(shopId, 'appointments')
        .where('reference', isEqualTo: reference)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final d = snap.docs.first;
    return Appointment.fromMap(d.id, d.data());
  }

  Future<List<Appointment>> findAppointmentsByPhone(
      String shopId, String phone) async {
    final snap = await _coll(shopId, 'appointments')
        .where('customerPhone', isEqualTo: phone)
        .get();
    return snap.docs
        .map((d) => Appointment.fromMap(d.id, d.data()))
        .toList();
  }

  // ---------- Discounts ----------

  Stream<List<Discount>> watchDiscounts(String shopId) =>
      _coll(shopId, 'discounts')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => Discount.fromMap(d.id, d.data()))
              .toList());

  Future<void> addDiscount(String shopId, Discount d) async {
    await _coll(shopId, 'discounts').doc(d.id).set(d.toMap());
  }

  Future<void> updateDiscount(String shopId, Discount d) async {
    await _coll(shopId, 'discounts').doc(d.id).set(d.toMap());
  }

  Future<void> deleteDiscount(String shopId, String id) async {
    await _coll(shopId, 'discounts').doc(id).delete();
  }

  Future<void> incrementDiscountUsage(String shopId, String id) async {
    await _coll(shopId, 'discounts').doc(id).update({
      'usageCount': FieldValue.increment(1),
    });
  }

  // ---------- Expenses ----------

  Stream<List<Expense>> watchExpenses(String shopId) =>
      _coll(shopId, 'expenses')
          .orderBy('date', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => Expense.fromMap(d.id, d.data()))
              .toList());

  Future<void> addExpense(String shopId, Expense e) async {
    await _coll(shopId, 'expenses').doc(e.id).set(e.toMap());
  }

  Future<void> updateExpense(String shopId, Expense e) async {
    await _coll(shopId, 'expenses').doc(e.id).set(e.toMap());
  }

  Future<void> deleteExpense(String shopId, String id) async {
    await _coll(shopId, 'expenses').doc(id).delete();
  }

  // ---------- Feedback ----------

  Stream<List<Feedback>> watchFeedback(String shopId) =>
      _coll(shopId, 'feedback')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => Feedback.fromMap(d.id, d.data()))
              .toList());

  Future<void> addFeedback(String shopId, Feedback f) async {
    await _coll(shopId, 'feedback').doc(f.id).set(f.toMap());
  }

  Future<void> updateFeedback(String shopId, Feedback f) async {
    await _coll(shopId, 'feedback').doc(f.id).set(f.toMap());
  }

  Future<void> deleteFeedback(String shopId, String id) async {
    await _coll(shopId, 'feedback').doc(id).delete();
  }

  // ---------- Unavailability requests ----------

  Stream<List<UnavailabilityRequest>> watchUnavailabilityRequests(
          String shopId) =>
      _coll(shopId, 'requests')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => UnavailabilityRequest.fromMap(d.id, d.data()))
              .toList());

  Future<void> addUnavailabilityRequest(
      String shopId, UnavailabilityRequest r) async {
    await _coll(shopId, 'requests').doc(r.id).set(r.toMap());
  }

  Future<void> updateUnavailabilityRequest(
      String shopId, UnavailabilityRequest r) async {
    await _coll(shopId, 'requests').doc(r.id).set(r.toMap());
  }

    // ---------- Portfolio ----------
  Stream<List<PortfolioItem>> watchPortfolio(String shopId) =>
      _coll(shopId, 'portfolio')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => PortfolioItem.fromMap(d.id, d.data()))
              .toList());

  Future<void> addPortfolioItem(String shopId, PortfolioItem item) =>
      _coll(shopId, 'portfolio').doc(item.id).set(item.toMap());
  Future<void> updatePortfolioItem(String shopId, PortfolioItem item) =>
      _coll(shopId, 'portfolio').doc(item.id).set(item.toMap());
  Future<void> deletePortfolioItem(String shopId, String id) =>
      _coll(shopId, 'portfolio').doc(id).delete();

  // ---------- Customers ----------
  Stream<List<CustomerProfile>> watchCustomers(String shopId) =>
      _coll(shopId, 'customers')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => CustomerProfile.fromMap(d.id, d.data()))
              .toList());

  Future<void> saveCustomer(String shopId, CustomerProfile customer) =>
      _coll(shopId, 'customers').doc(customer.id).set(customer.toMap());

  Future<void> deleteCustomer(String shopId, String id) =>
      _coll(shopId, 'customers').doc(id).delete();

  // ---------- Loyalty ----------
  Stream<List<LoyaltyAccount>> watchLoyalty(String shopId) =>
      _coll(shopId, 'loyalty')
          .orderBy('points', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => LoyaltyAccount.fromMap(d.id, d.data()))
              .toList());
  Future<void> saveLoyalty(String shopId, LoyaltyAccount account) =>
      _coll(shopId, 'loyalty').doc(account.id).set(account.toMap());

  Future<void> addLoyaltyPoints(String shopId, String id, int points) async {
    final ref = _coll(shopId, 'loyalty').doc(id);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) return;
      final current = LoyaltyAccount.fromMap(ref.id, snap.data() ?? {});
      final updated = current.copyWith(
        points: (current.points + points).clamp(0, 100000000).toInt(),
        tier: current.copyWith(points: current.points + points).calculatedTier,
        updatedAt: DateTime.now(),
      );
      transaction.set(ref, updated.toMap());
    });
  }

  Stream<List<LoyaltyRule>> watchLoyaltyRules(String shopId) =>
      _coll(shopId, 'loyaltyRules')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => LoyaltyRule.fromMap(d.id, d.data()))
              .toList());

  Future<void> saveLoyaltyRule(String shopId, LoyaltyRule rule) =>
      _coll(shopId, 'loyaltyRules').doc(rule.id).set(rule.toMap());

  Future<void> deleteLoyaltyRule(String shopId, String id) =>
      _coll(shopId, 'loyaltyRules').doc(id).delete();

  Stream<List<LoyaltyGift>> watchLoyaltyGifts(String shopId) =>
      _coll(shopId, 'loyaltyGifts')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => LoyaltyGift.fromMap(d.id, d.data()))
              .toList());

  Future<void> saveLoyaltyGift(String shopId, LoyaltyGift gift) =>
      _coll(shopId, 'loyaltyGifts').doc(gift.id).set(gift.toMap());

  Future<void> deleteLoyaltyGift(String shopId, String id) =>
      _coll(shopId, 'loyaltyGifts').doc(id).delete();

  Future<void> redeemLoyaltyGift(String shopId, String accountId, LoyaltyGift gift) async {
    final accountRef = _coll(shopId, 'loyalty').doc(accountId);
    final giftRef = _coll(shopId, 'loyaltyGifts').doc(gift.id);
    await _db.runTransaction((transaction) async {
      final accountSnap = await transaction.get(accountRef);
      final giftSnap = await transaction.get(giftRef);
      if (!accountSnap.exists || !giftSnap.exists) {
        throw StateError('السجل غير موجود');
      }
      final account = LoyaltyAccount.fromMap(accountId, accountSnap.data() ?? {});
      final currentGift = LoyaltyGift.fromMap(gift.id, giftSnap.data() ?? {});
      if (account.points < currentGift.pointsCost || !currentGift.isAvailable) {
        throw StateError('النقاط غير كافية أو الهدية غير متاحة');
      }
      final updatedAccount = account.copyWith(
        points: account.points - currentGift.pointsCost,
        tier: account.copyWith(points: account.points - currentGift.pointsCost).calculatedTier,
        updatedAt: DateTime.now(),
      );
      transaction.set(accountRef, updatedAccount.toMap());
      transaction.update(giftRef, {
        'redeemedCount': FieldValue.increment(1),
      });
    });
  }

  // ---------- Chairs ----------
  Stream<List<Chair>> watchChairs(String shopId) =>
      _coll(shopId, 'chairs').orderBy('name').snapshots().map((snap) => snap.docs
          .map((d) => Chair.fromMap(d.id, d.data()))
          .toList());
  Future<void> saveChair(String shopId, Chair chair) =>
      _coll(shopId, 'chairs').doc(chair.id).set(chair.toMap());
  Future<void> deleteChair(String shopId, String id) =>
      _coll(shopId, 'chairs').doc(id).delete();

  // ---------- Chair supplies ----------
  Stream<List<ChairSupply>> watchChairSupplies(String shopId) =>
      _coll(shopId, 'chairSupplies')
          .orderBy('updatedAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => ChairSupply.fromMap(d.id, d.data()))
              .toList());

  Future<void> saveChairSupply(String shopId, ChairSupply supply) =>
      _coll(shopId, 'chairSupplies').doc(supply.id).set(supply.toMap());

  Future<void> deleteChairSupply(String shopId, String id) =>
      _coll(shopId, 'chairSupplies').doc(id).delete();

  // ---------- Weekly chair profitability ----------
  Stream<List<ChairWeeklyProfit>> watchChairWeeklyProfits(String shopId) =>
      _coll(shopId, 'chairWeeklyProfits')
          .orderBy('weekStart', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => ChairWeeklyProfit.fromMap(d.id, d.data()))
              .toList());

  Future<void> saveChairWeeklyProfit(String shopId, ChairWeeklyProfit report) =>
      _coll(shopId, 'chairWeeklyProfits').doc(report.id).set(report.toMap());

  // ---------- Queue ----------
  Stream<List<QueueEntry>> watchQueue(String shopId) =>
      _coll(shopId, 'queue')
          .orderBy('joinedAt')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => QueueEntry.fromMap(d.id, d.data()))
              .toList());
  Future<void> saveQueueEntry(String shopId, QueueEntry entry) =>
      _coll(shopId, 'queue').doc(entry.id).set(entry.toMap());
  Future<void> updateQueueEntry(String shopId, QueueEntry entry) =>
      _coll(shopId, 'queue').doc(entry.id).set(entry.toMap());

  // ---------- Payments ----------
  Stream<List<Payment>> watchPayments(String shopId) =>
      _coll(shopId, 'payments')
          .orderBy('paidAt', descending: true)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => Payment.fromMap(d.id, d.data()))
              .toList());
  Future<void> addPayment(String shopId, Payment payment) =>
      _coll(shopId, 'payments').doc(payment.id).set(payment.toMap());
  Future<void> deletePayment(String shopId, String id) =>
      _coll(shopId, 'payments').doc(id).delete();

  // ---------- Members / Roles ----------

  CollectionReference<Map<String, dynamic>> _members(String shopId) =>
      _coll(shopId, 'members');

  CollectionReference<Map<String, dynamic>> _users() =>
      _db.collection('users');

  Stream<List<Member>> watchMembers(String shopId) => _members(shopId)
      .orderBy('createdAt', descending: false)
      .snapshots()
      .map((snap) =>
          snap.docs.map((d) => Member.fromMap(d.id, d.data())).toList());

  Future<Member?> getMember(String shopId, String uid) async {
    final snap = await _members(shopId).doc(uid).get();
    if (!snap.exists) return null;
    return Member.fromMap(snap.id, snap.data() ?? {});
  }

  /// يبحث عن محل يملكه المستخدم، وإلا عن محل انضم إليه كعضو.
  Future<({String? shopId, AppRole role})> resolveShopForUser(
      String uid) async {
    final ownedShopId = await findShopByOwner(uid);
    if (ownedShopId != null) {
      return (shopId: ownedShopId, role: AppRole.owner);
    }
    final profile = await getUserProfile(uid);
    final joinedShopId = profile?['joinedShopId'] as String?;
    if (joinedShopId == null || joinedShopId.isEmpty) {
      return (shopId: null, role: AppRole.staff);
    }
    final membership = await getMember(joinedShopId, uid);
    if (membership == null) {
      return (shopId: null, role: AppRole.staff);
    }
    return (shopId: joinedShopId, role: membership.role);
  }

  Future<Map<String, dynamic>?> getUserProfile(String uid) async {
    final snap = await _users().doc(uid).get();
    return snap.exists ? snap.data() : null;
  }

  Future<void> _setUserProfile(
      String uid, String email, String? joinedShopId) async {
    await _users().doc(uid).set({
      'email': email,
      if (joinedShopId != null) 'joinedShopId': joinedShopId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// انضمام المستخدم إلى محل عبر كود الانضمام.
  /// العضو الجديد يحصل على دور [AppRole.staff] دائماً (أقل صلاحية).
  Future<void> joinShopByCode({
    required String uid,
    required String email,
    required String code,
  }) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) throw StateError('joinCodeRequired');
    final snap = await _shops()
        .where('joinCode', isEqualTo: clean)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) throw StateError('joinCodeNotFound');
    final shop = snap.docs.first;

    // منع الانضمام مرتين أو انضمام المالك لمحله بكود.
    final existing = await getMember(shop.id, uid);
    if (existing != null) throw StateError('alreadyMember');

    await _members(shop.id).doc(uid).set(Member(
          uid: uid,
          email: email,
          role: AppRole.staff,
          createdAt: DateTime.now(),
        ).toMap());
    await _setUserProfile(uid, email, shop.id);
  }

  Future<void> updateMemberRole(
      String shopId, String uid, AppRole role) async {
    await _members(shopId).doc(uid).update({'role': role.name});
  }

  Future<void> removeMember(String shopId, String uid) async {
    await _members(shopId).doc(uid).delete();
    // إزالة الربط من ملف المستخدم إن كان يشير لنفس المحل.
    final profile = await getUserProfile(uid);
    if (profile?['joinedShopId'] == shopId) {
      await _users().doc(uid).set({
        'joinedShopId': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<String> rotateJoinCode(String shopId) async {
    final code = genJoinCode();
    await updateSettings(shopId, {'joinCode': code});
    return code;
  }

  static String genJoinCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    var seed = rand ^ (rand >> 7);
    String s = '';
    for (var i = 0; i < 6; i++) {
      s += chars[seed % chars.length];
      seed = seed ~/ 17 + 31 * (i + 1);
    }
    return s;
  }

  // ---------- Inventory ----------
  Stream<List<InventoryItem>> watchInventory(String shopId) =>
      _coll(shopId, 'inventory')
          .orderBy('name')
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => InventoryItem.fromMap(d.id, d.data()))
              .toList());

  Future<void> saveInventoryItem(String shopId, InventoryItem item) =>
      _coll(shopId, 'inventory').doc(item.id).set(item.toMap());

  Future<void> deleteInventoryItem(String shopId, String id) =>
      _coll(shopId, 'inventory').doc(id).delete();

  Stream<List<InventoryMovement>> watchInventoryMovements(String shopId) =>
      _coll(shopId, 'inventoryMovements')
          .orderBy('createdAt', descending: true)
          .limit(200)
          .snapshots()
          .map((snap) => snap.docs
              .map((d) => InventoryMovement.fromMap(d.id, d.data()))
              .toList());

  Future<void> addInventoryMovement(
          String shopId, InventoryMovement movement) =>
      _coll(shopId, 'inventoryMovements').doc(movement.id).set(movement.toMap());

  // ---------- Customer helpers ----------
  static String genReference() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = DateTime.now().microsecondsSinceEpoch;
    String s = '';
    var seed = rand;
    for (var i = 0; i < 6; i++) {
      s += chars[seed % chars.length];
      seed = seed ~/ 31;
    }
    return s;
  }
}
