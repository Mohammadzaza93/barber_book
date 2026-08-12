import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/appointment.dart';
import '../models/booking_settings.dart';
import '../models/discount.dart';
import '../models/employee.dart';
import '../models/expense.dart';
import '../models/feedback.dart';
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
      primaryColorHex: primaryColorHex ?? '0xFF111827',
      accentColorHex: accentColorHex ?? '0xFF2563EB',
      slug: slug ?? 'shop-${doc.id.substring(0, 6)}',
    );
    await doc.set({
      ...settings.toMap(),
      'ownerId': ownerId,
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
