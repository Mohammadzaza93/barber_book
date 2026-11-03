import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../config/owner.dart';
import '../models/appointment.dart';
import '../models/app_role.dart';
import '../models/business_features.dart';
import '../models/booking_settings.dart';
import '../models/discount.dart';
import '../models/employee.dart';
import '../models/enums.dart';
import '../models/feedback.dart';
import '../models/member.dart';
import '../models/service.dart';
import '../models/shop_invite.dart';
import '../models/staff_permissions.dart';
import '../models/unavailability_request.dart';

class FirestoreService {
  FirestoreService._();
  static final instance = FirestoreService._();

  FirebaseFirestore get _db => FirebaseFirestore.instance;

  static const int offlineCacheSizeBytes = 40 * 1024 * 1024;

  bool _offlineConfigured = false;

  void configureOfflinePersistence() {
    if (_offlineConfigured) return;
    _db.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: offlineCacheSizeBytes,
    );
    _offlineConfigured = true;
  }

  CollectionReference<Map<String, dynamic>> _shops() => _db.collection('shops');

  CollectionReference<Map<String, dynamic>> _coll(String shopId, String name) =>
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
    // Defence in depth: `firestore.rules` also pins this to the owner email.
    if (!isOwnerEmail(FirebaseAuth.instance.currentUser?.email)) {
      throw StateError('owner-only');
    }
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
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await publishPrimaryShop(doc.id);
    return doc.id;
  }

  /// Publishes `appConfig/primaryShop` = {shopId} so a staff account can find
  /// the salon with two direct document reads. This avoids depending on the
  /// collection-group index that resolving membership by `members.uid` needs.
  /// Owner-only in `firestore.rules`; best-effort and idempotent.
  Future<void> publishPrimaryShop(String shopId) async {
    try {
      await _db.collection('appConfig').doc('primaryShop').set({
        'shopId': shopId,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Never block the session on this pointer.
    }
  }

  Future<String?> findShopByOwner(String ownerId) async {
    final snap =
        await _shops().where('ownerId', isEqualTo: ownerId).limit(1).get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  Stream<BookingSettings> watchSettings(String shopId) => _shops()
      .doc(shopId)
      .snapshots()
      .map((d) => BookingSettings.fromMap(d.data() ?? const {}));

  Future<void> updateSettings(String shopId, Map<String, dynamic> data) async {
    await _shops().doc(shopId).set(
        {...data, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true));
  }

  // ---------- Services ----------

  Stream<List<Service>> watchServices(String shopId) =>
      _coll(shopId, 'services').orderBy('sortOrder').snapshots().map((snap) =>
          snap.docs.map((d) => Service.fromMap(d.id, d.data())).toList());

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
      _coll(shopId, 'employees').snapshots().map((snap) =>
          snap.docs.map((d) => Employee.fromMap(d.id, d.data())).toList());

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

  /// تحميل كسول: آخر [windowDays] يوماً (بدل كل التاريخ) لتسريع المزامنة.
  Stream<List<Appointment>> watchAppointments(
    String shopId, {
    int windowDays = 120,
  }) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: windowDays));
    return _coll(shopId, 'appointments')
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .orderBy('startTime')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => Appointment.fromMap(d.id, d.data())).toList());
  }

  Future<Appointment?> findAppointment(String shopId, String reference) async {
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
    return snap.docs.map((d) => Appointment.fromMap(d.id, d.data())).toList();
  }

  // ---------- Discounts ----------

  Stream<List<Discount>> watchDiscounts(String shopId) =>
      _coll(shopId, 'discounts').snapshots().map((snap) =>
          snap.docs.map((d) => Discount.fromMap(d.id, d.data())).toList());

  Future<void> addDiscount(String shopId, Discount d) async {
    await _coll(shopId, 'discounts').doc(d.id).set(d.toMap());
  }

  Future<void> updateDiscount(String shopId, Discount d) async {
    await _coll(shopId, 'discounts').doc(d.id).set(d.toMap());
  }

  Future<void> deleteDiscount(String shopId, String id) async {
    await _coll(shopId, 'discounts').doc(id).delete();
  }

  // ---------- Feedback ----------

  Stream<List<Feedback>> watchFeedback(String shopId) =>
      _coll(shopId, 'feedback')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => Feedback.fromMap(d.id, d.data())).toList());

  Future<void> addFeedback(String shopId, Feedback f) async {
    await _coll(shopId, 'feedback').doc(f.id).set(f.toMap());
  }

  Future<void> updateFeedback(String shopId, Feedback f) async {
    await _coll(shopId, 'feedback').doc(f.id).set(f.toMap());
  }

  Future<void> deleteFeedback(String shopId, String id) async {
    await _coll(shopId, 'feedback').doc(id).delete();
  }

  // ---------- Unavailability ----------

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

  Future<void> redeemLoyaltyGift(
      String shopId, String accountId, LoyaltyGift gift) async {
    final accountRef = _coll(shopId, 'loyalty').doc(accountId);
    final giftRef = _coll(shopId, 'loyaltyGifts').doc(gift.id);
    await _db.runTransaction((transaction) async {
      final accountSnap = await transaction.get(accountRef);
      final giftSnap = await transaction.get(giftRef);
      if (!accountSnap.exists || !giftSnap.exists) {
        throw StateError('السجل غير موجود');
      }
      final account =
          LoyaltyAccount.fromMap(accountId, accountSnap.data() ?? {});
      final currentGift = LoyaltyGift.fromMap(gift.id, giftSnap.data() ?? {});
      if (account.points < currentGift.pointsCost || !currentGift.isAvailable) {
        throw StateError('النقاط غير كافية أو الهدية غير متاحة');
      }
      final updatedAccount = account.copyWith(
        points: account.points - currentGift.pointsCost,
        tier: account
            .copyWith(points: account.points - currentGift.pointsCost)
            .calculatedTier,
        updatedAt: DateTime.now(),
      );
      transaction.set(accountRef, updatedAccount.toMap());
      transaction.update(giftRef, {'redeemedCount': FieldValue.increment(1)});
    });
  }

  // ---------- Chairs ----------

  Stream<List<Chair>> watchChairs(String shopId) =>
      _coll(shopId, 'chairs').orderBy('name').snapshots().map((snap) =>
          snap.docs.map((d) => Chair.fromMap(d.id, d.data())).toList());

  Future<void> saveChair(String shopId, Chair chair) =>
      _coll(shopId, 'chairs').doc(chair.id).set(chair.toMap());
  Future<void> deleteChair(String shopId, String id) =>
      _coll(shopId, 'chairs').doc(id).delete();

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
      _coll(shopId, 'queue').orderBy('joinedAt').snapshots().map((snap) =>
          snap.docs.map((d) => QueueEntry.fromMap(d.id, d.data())).toList());

  Future<void> saveQueueEntry(String shopId, QueueEntry entry) =>
      _coll(shopId, 'queue').doc(entry.id).set(entry.toMap());
  Future<void> updateQueueEntry(String shopId, QueueEntry entry) =>
      _coll(shopId, 'queue').doc(entry.id).set(entry.toMap());

  // ---------- Payments ----------

  Stream<List<Payment>> watchPayments(String shopId) =>
      _coll(shopId, 'payments')
          .orderBy('paidAt', descending: true)
          .snapshots()
          .map((snap) =>
              snap.docs.map((d) => Payment.fromMap(d.id, d.data())).toList());

  Future<PaymentStatus> recordPayment(String shopId, Payment payment) async {
    final payments = _coll(shopId, 'payments');
    final appointmentId = payment.appointmentId.trim();
    if (appointmentId.isEmpty) {
      await payments.doc(payment.id).set(payment.toMap());
      return PaymentStatus.paid;
    }
    if (payment.amount <= 0) throw Exception('invalid-input');
    final ref = _coll(shopId, 'appointments').doc(appointmentId);
    var status = PaymentStatus.unpaid;
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('appointment-not-found');
      final data = snap.data()!;
      final total = ((data['totalAmount'] as num?) ?? 0).toDouble();
      final collected = ((data['collectedAmount'] as num?) ?? 0).toDouble();
      final next = collected + payment.amount;
      if (next > total + 0.01) throw Exception('invalid-pricing');
      status =
          next >= total - 0.01 ? PaymentStatus.paid : PaymentStatus.depositPaid;
      tx.update(ref, {
        'collectedAmount': next,
        'paymentStatus': status.name,
      });
      tx.set(payments.doc(payment.id), payment.toMap());
    });
    return status;
  }

  Future<void> deletePayment(String shopId, String id) =>
      _coll(shopId, 'payments').doc(id).delete();

  // ---------- Members ----------

  CollectionReference<Map<String, dynamic>> _members(String shopId) =>
      _coll(shopId, 'members');

  /// Direct self-readable mirror of a membership: `memberships/{uid}`.
  ///
  /// Session restore reads this single document, so a staff login never depends
  /// on the collection-group index that a `members.uid` query needs. The
  /// canonical role/permission source remains `shops/{shopId}/members/{uid}`.
  CollectionReference<Map<String, dynamic>> _membershipPointers() =>
      _db.collection('memberships');

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

  /// The owner-controlled capability map for [uid].
  ///
  /// This is the same document `firestore.rules` reads, so the UI and the
  /// server enforcement always agree. A missing membership means no capability.
  Future<StaffPermissions> getMemberPermissions(
      String shopId, String uid) async {
    final snap = await _members(shopId).doc(uid).get();
    final data = snap.data();
    if (data == null) return StaffPermissions.minimal;
    return StaffPermissions.fromMap(
        data['permissions'] as Map<String, dynamic>?);
  }

  /// Resolves the shop + role for an authenticated uid.
  ///
  /// Ownership is a direct `shops.ownerId` lookup. Everyone else is resolved
  /// through the collection-group query on `members.uid`; there is no writable
  /// `/users` profile any more. An unknown account is a *staff* account with no
  /// shop, never an admin fallback.
  Future<({String? shopId, AppRole role})> resolveShopForUser(
      String uid) async {
    final ownedShopId = await findShopByOwner(uid);
    if (ownedShopId != null) {
      // Keep the staff lookup pointer fresh whenever the owner signs in. Not
      // awaited on purpose: offline, a Firestore write only completes once the
      // server acknowledges it, and the session must never wait on that.
      // ignore: unawaited_futures
      publishPrimaryShop(ownedShopId);
      return (shopId: ownedShopId, role: AppRole.admin);
    }

    // 1) Direct self-readable mirror: memberships/{uid}. This is the primary
    // staff path and needs no composite/collection-group index.
    try {
      final pointer = await _membershipPointers().doc(uid).get();
      final data = pointer.data();
      final pointed = data?['shopId'];
      if (data != null && pointed is String && pointed.isNotEmpty) {
        if (data['active'] == false) {
          return (shopId: null, role: AppRole.staff);
        }
        // The canonical membership stays authoritative: a stale pointer after a
        // failed delete must never keep a removed employee inside the shop.
        final memberSnap = await _members(pointed).doc(uid).get();
        final memberData = memberSnap.data();
        if (memberData == null || memberData['active'] == false) {
          return (shopId: null, role: AppRole.staff);
        }
        return (
          shopId: pointed,
          role: Member.fromMap(uid, memberData).role,
        );
      }
    } on FirebaseException {
      // Rules not deployed yet / offline: fall through to the shop pointer.
    }

    // 2) Direct path, no index needed: appConfig/primaryShop -> members/{uid}.
    try {
      final cfg = await _db.collection('appConfig').doc('primaryShop').get();
      final pointed = cfg.data()?['shopId'];
      if (pointed is String && pointed.isNotEmpty) {
        final memberSnap = await _members(pointed).doc(uid).get();
        if (memberSnap.exists) {
          final data = memberSnap.data() ?? <String, dynamic>{};
          // A deactivated account keeps its document but has no access.
          if (data['active'] == false) {
            return (shopId: null, role: AppRole.staff);
          }
          return (
            shopId: pointed,
            role: Member.fromMap(memberSnap.id, data).role,
          );
        }
      }
    } on FirebaseException {
      // Pointer missing / not deployed yet: fall through to the group query.
    }

    // 3) Collection-group lookup. Needs the single-field COLLECTION_GROUP index
    // on members.uid (see firestore.indexes.json). A failure here is rethrown
    // so the caller can show the real reason instead of "no shop".
    final snap = await _db
        .collectionGroup('members')
        .where('uid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) {
      return (shopId: null, role: AppRole.staff);
    }
    final doc = snap.docs.first;
    if (doc.data()['active'] == false) {
      return (shopId: null, role: AppRole.staff);
    }
    final shopId = doc.reference.parent.parent?.id;
    if (shopId == null || shopId.isEmpty) {
      return (shopId: null, role: AppRole.staff);
    }
    final member = Member.fromMap(doc.id, doc.data());
    return (shopId: shopId, role: member.role);
  }

  /// True only for the immutable `shops.ownerId` holder.
  Future<bool> isShopOwner(String shopId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final snap = await _shops().doc(shopId).get();
    final data = snap.data();
    return data != null && data['ownerId'] == uid;
  }

  /// Creates (or links) the membership document for [uid].
  ///
  /// Written by the owner only. `permissions` is the server-enforced copy of
  /// the employee's capability set.
  Future<void> saveMember(
    String shopId,
    String uid, {
    required String email,
    required String name,
    required AppRole role,
    required StaffPermissions permissions,
    bool active = true,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _members(shopId).doc(uid).set({
      'uid': uid,
      'email': normalizedEmail,
      'name': name,
      'role': role.name,
      'permissions': permissions.toMap(),
      'active': active,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _writeMembershipPointer(
      shopId,
      uid,
      email: normalizedEmail,
      name: name,
      role: role,
      permissions: permissions,
      active: active,
    );
  }

  /// Best-effort mirror read by session restore through `memberships/{uid}`.
  ///
  /// A failure here must never fail the canonical membership write: the account
  /// is already linked, and the older appConfig/collection-group paths remain.
  Future<void> _writeMembershipPointer(
    String shopId,
    String uid, {
    required String email,
    required String name,
    required AppRole role,
    required StaffPermissions permissions,
    required bool active,
  }) async {
    try {
      await _membershipPointers().doc(uid).set({
        'uid': uid,
        'shopId': shopId,
        'email': email.trim().toLowerCase(),
        'name': name,
        'role': role.name,
        'permissions': permissions.toMap(),
        'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Pointer rules may not be deployed yet. Keep the canonical membership.
    }
  }

  /// Keeps the server-enforced permissions/role in sync when an employee is
  /// edited. Never touches identity fields (`uid` / `createdAt`).
  Future<void> updateMemberPermissions(
    String shopId,
    String uid, {
    required StaffPermissions permissions,
    AppRole? role,
    String? name,
    String? email,
    bool? active,
  }) async {
    final normalizedEmail = email?.trim().toLowerCase();
    await _members(shopId).doc(uid).set({
      // Included so a merge-write can also CREATE a missing membership (the
      // owner re-saving an employee repairs an older unlinked account).
      'uid': uid,
      'permissions': permissions.toMap(),
      if (role != null) 'role': role.name,
      if (name != null) 'name': name,
      if (normalizedEmail != null) 'email': normalizedEmail,
      if (active != null) 'active': active,
    }, SetOptions(merge: true));
    try {
      await _membershipPointers().doc(uid).set({
        'uid': uid,
        'shopId': shopId,
        'permissions': permissions.toMap(),
        if (role != null) 'role': role.name,
        if (name != null) 'name': name,
        if (normalizedEmail != null) 'email': normalizedEmail,
        if (active != null) 'active': active,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {
      // Non-fatal: the canonical membership is authoritative.
    }
  }

  Future<void> removeMember(String shopId, String uid) async {
    // Revoke the fast lookup path first. Even if the canonical delete then
    // fails, the account cannot resolve the shop from a leftover pointer.
    try {
      await _membershipPointers().doc(uid).delete();
    } catch (_) {
      // Older rules may not know this collection yet; the canonical membership
      // is still deleted below and resolution verifies it before granting access.
    }
    await _members(shopId).doc(uid).delete();
  }

  /// Finds the canonical membership for an employee email.
  ///
  /// Used when an older employee document has no `authUid` (for example an
  /// account linked through an owner-issued pairing code). Owner/admin only:
  /// the rules gate `members` listing.
  Future<String?> findMemberUidByEmail(String shopId, String? email) async {
    final normalized = email?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return null;
    final snap = await _members(shopId)
        .where('email', isEqualTo: normalized)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  /// Revokes every membership that belongs to [email].
  ///
  /// Removing an employee must not leave a paired account with access just
  /// because the roster document never received an `authUid`.
  Future<void> removeMembersByEmail(String shopId, String? email) async {
    final normalized = email?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return;
    final snap =
        await _members(shopId).where('email', isEqualTo: normalized).get();
    for (final doc in snap.docs) {
      await removeMember(shopId, doc.id);
    }
  }

  // ---------- Pairing invites ----------

  CollectionReference<Map<String, dynamic>> _invites() =>
      _db.collection('invites');

  static const _inviteAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  /// 20 characters from a 32-symbol alphabet = 100 bits. The code is the
  /// secret; it is never derived from the email or uid.
  static String _newInviteCode([Random? random]) {
    final rnd = random ?? Random.secure();
    return List.generate(
      20,
      (_) => _inviteAlphabet[rnd.nextInt(_inviteAlphabet.length)],
    ).join();
  }

  /// Creates a single-use pairing code for an existing Auth account.
  ///
  /// Owner-only in `firestore.rules`. The caller must be the true shop owner.
  Future<ShopInvite> createInvite(
    String shopId, {
    required String email,
    required String name,
    required AppRole role,
    required StaffPermissions permissions,
    Duration ttl = const Duration(days: 7),
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const InviteClaimException('يجب تسجيل الدخول أولاً');
    }
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw const InviteClaimException('أدخل بريداً صحيحاً للموظف');
    }
    final effectivePermissions =
        role.isAdmin ? StaffPermissions.all : permissions;
    final code = _newInviteCode();
    final expiresAt = DateTime.now().toUtc().add(ttl);
    await _invites().doc(code).set({
      'code': code,
      'shopId': shopId,
      'email': normalized,
      'name': name.trim(),
      'role': role.name,
      'permissions': effectivePermissions.toMap(),
      'active': true,
      'createdBy': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'expiresAt': Timestamp.fromDate(expiresAt),
    });
    return ShopInvite(
      code: code,
      shopId: shopId,
      email: normalized,
      name: name.trim(),
      role: role,
      permissions: effectivePermissions,
      expiresAt: expiresAt,
    );
  }

  Future<ShopInvite?> getInvite(String code) async {
    final snap = await _invites().doc(code).get();
    final data = snap.data();
    if (data == null) return null;
    return ShopInvite.fromMap(snap.id, data);
  }

  /// Claims [code] for the signed-in account.
  ///
  /// Security properties enforced by the server rules (not by this client):
  /// * the invite must belong to the shop in the member path,
  /// * the signed-in token email must equal the invited email,
  /// * role and permissions must be copied verbatim from the invite,
  /// * the invite must be unexpired.
  ///
  /// Returns the shop id. The caller should refresh the session afterwards.
  Future<String> claimInvite(String code) async {
    final trimmed = code.trim().toUpperCase();
    if (trimmed.isEmpty) {
      throw const InviteClaimException('أدخل رمز الربط');
    }
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email?.trim().toLowerCase();
    if (user == null || email == null || email.isEmpty) {
      throw const InviteClaimException('يجب تسجيل الدخول أولاً');
    }

    final ShopInvite? invite;
    try {
      invite = await getInvite(trimmed);
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        throw const InviteClaimException('الرمز غير صالح أو لا يخص هذا البريد');
      }
      rethrow;
    }
    if (invite == null || invite.shopId.isEmpty) {
      throw const InviteClaimException('رمز الربط غير موجود');
    }
    if (invite.email != email) {
      throw const InviteClaimException('هذا الرمز مخصص لبريد آخر');
    }
    if (invite.isExpired) {
      throw const InviteClaimException('انتهت صلاحية رمز الربط');
    }

    final role = invite.role;
    final permissions =
        role.isAdmin ? StaffPermissions.all : invite.permissions;
    // The rules also validate these fields against the invite document.
    await _members(invite.shopId).doc(user.uid).set({
      'uid': user.uid,
      'email': email,
      'name': invite.name,
      'role': role.name,
      'permissions': permissions.toMap(),
      'active': true,
      'createdAt': FieldValue.serverTimestamp(),
      'inviteCode': trimmed,
    });

    // Best-effort fast lookup. Resolution falls back to appConfig + the
    // canonical member document when this write is denied.
    unawaited(_writeMembershipPointer(
      invite.shopId,
      user.uid,
      email: email,
      name: invite.name,
      role: role,
      permissions: permissions,
      active: true,
    ));

    // Attach the trusted uid to the roster document(s) for this email, so the
    // owner's edit/delete actions keep revoking the correct account.
    try {
      final employees = await _coll(invite.shopId, 'employees')
          .where('email', isEqualTo: email)
          .get();
      for (final doc in employees.docs) {
        final current = doc.data()['authUid'];
        if (current == null || current == '') {
          await doc.reference.update({'authUid': user.uid});
        }
      }
    } catch (_) {
      // The canonical membership already grants access; the roster can be
      // repaired by the owner later.
    }

    // Single-use: consume the code. If this fails, a second create for the same
    // uid is still rejected because the member document already exists.
    try {
      await _invites().doc(trimmed).delete();
    } catch (_) {}

    return invite.shopId;
  }

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
