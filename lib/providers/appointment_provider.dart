import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/appointment.dart';
import '../models/enums.dart';
import '../models/shop_time.dart';
import '../models/unavailability_request.dart';
import '../services/firestore_service.dart';
import '../services/shop_manager.dart';

class AppointmentProvider extends ChangeNotifier {
  List<Appointment> appointments = [];
  List<UnavailabilityRequest> requests = [];
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
    _listen(FirestoreService.instance.watchAppointments(shopId), (list) {
      appointments = list;
      loading = false;
    }, gatesLoading: true);
    _listen(FirestoreService.instance.watchUnavailabilityRequests(shopId),
        (list) {
      requests = list;
    });
  }

  /// Subscribes [stream] with a shared error path so a denied or offline read
  /// clears [loading] instead of spinning forever.
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
        if (code != 'permission-denied' && error == null) {
          error = e.toString();
        }
        if (gatesLoading) loading = false;
        notifyListeners();
      },
    ));
  }

  List<Appointment> get todayAppointments {
    final now = DateTime.now();
    // Window boundaries come from the shop's UTC offset, not the device zone,
    // so "today" matches the shop's calendar day on any device.
    final offset = ShopManager.timezoneOffsetMinutes;
    final start = shopDayStart(now, offset);
    final end = shopDayEnd(now, offset);
    return appointments.where((a) {
      final d = a.startTime;
      return !d.isBefore(start) && d.isBefore(end);
    }).toList();
  }

  List<Appointment> get upcomingAppointments {
    final now = DateTime.now();
    return appointments
        .where((a) =>
            a.startTime.isAfter(now) &&
            (a.status == AppointmentStatus.confirmed ||
                a.status == AppointmentStatus.requested))
        .toList();
  }

  List<UnavailabilityRequest> get pendingRequests =>
      requests.where((r) => r.status == 'pending').toList();

  bool hasConflict({
    required String employeeId,
    String? chairId,
    required DateTime start,
    required DateTime end,
    String? excludeId,
  }) {
    return appointments.any((existing) {
      if (existing.id == excludeId ||
          existing.status == AppointmentStatus.cancelled ||
          existing.status == AppointmentStatus.noShow) {
        return false;
      }
      final sameEmployee = existing.employeeId == employeeId;
      final sameChair = chairId != null && existing.chairId == chairId;
      final overlaps = start.isBefore(existing.endTime) &&
          end.isAfter(existing.startTime);
      return overlaps && (sameEmployee || sameChair);
    });
  }

  /// Creates appointment directly via transaction to avoid conflicts
  Future<String> create({
    required String shopId,
    required String employeeId,
    String? chairId,
    required List<String> serviceIds,
    required DateTime start,
    required DateTime end,
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    String? notes,
    bool recurring = false,
    String? seriesId,
    bool outOfHours = false,
    required double totalAmount,
    String? createdById,
  }) async {
    final db = FirebaseFirestore.instance;
    final ref = db.collection('shops').doc(shopId).collection('appointments').doc();
    await db.runTransaction((tx) async {
      // Check for conflicts
      final snap = await db
          .collection('shops')
          .doc(shopId)
          .collection('appointments')
          .where('employeeId', isEqualTo: employeeId)
          .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data['status'] == 'cancelled' || data['status'] == 'noShow') continue;
        final s = (data['startTime'] as Timestamp).toDate();
        final e = (data['endTime'] as Timestamp).toDate();
        if (start.isBefore(e) && end.isAfter(s)) {
          throw Exception('appointment-conflict');
        }
      }
      final refNum = DateTime.now().millisecondsSinceEpoch.toString().substring(7);
      tx.set(ref, {
        'shopId': shopId,
        'reference': 'APT-$refNum',
        'customerName': customerName,
        'customerPhone': customerPhone ?? '',
        'customerEmail': customerEmail ?? '',
        'employeeId': employeeId,
        'chairId': chairId,
        'serviceIds': serviceIds,
        'startTime': Timestamp.fromDate(start),
        'endTime': Timestamp.fromDate(end),
        'status': AppointmentStatus.confirmed.name,
        'paymentStatus': PaymentStatus.unpaid.name,
        'totalAmount': totalAmount,
        'depositAmount': 0,
        'collectedAmount': 0,
        'discountCode': null,
        'discountAmount': 0,
        'notes': notes ?? '',
        'recurring': recurring,
        'seriesId': seriesId,
        'outOfHours': outOfHours,
        'createdById': createdById,
        'createdAt': FieldValue.serverTimestamp(),
        'reminderSent': false,
        'rating': null,
      });
    });
    return ref.id;
  }

  Future<void> updateContact(Appointment a, String shopId,
      {String? customerName, String? customerPhone, String? customerEmail, String? notes}) async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('appointments')
        .doc(a.id)
        .update({
      if (customerName != null) 'customerName': customerName,
      if (customerPhone != null) 'customerPhone': customerPhone,
      if (customerEmail != null) 'customerEmail': customerEmail,
      if (notes != null) 'notes': notes,
    });
  }

  Future<void> delete(Appointment a, String shopId) async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('appointments')
        .doc(a.id)
        .delete();
  }

  /// Cancel series in one operation
  Future<void> cancelSeries(String shopId, String seriesId) async {
    final db = FirebaseFirestore.instance;
    final snap = await db
        .collection('shops')
        .doc(shopId)
        .collection('appointments')
        .where('seriesId', isEqualTo: seriesId)
        .get();
    final batch = db.batch();
    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['status'] == 'completed') continue;
      batch.update(doc.reference, {'status': AppointmentStatus.cancelled.name});
    }
    await batch.commit();
  }

  Future<void> setStatus(Appointment a, AppointmentStatus s, String shopId,
      {bool applyToSeries = false}) async {
    if (applyToSeries && a.seriesId != null) {
      await cancelSeries(shopId, a.seriesId!);
      return;
    }
    if (!a.status.canTransitionTo(s)) {
      throw Exception('invalid-transition');
    }
    final db = FirebaseFirestore.instance;
    if (s == AppointmentStatus.cancelled && a.recurring && a.seriesId != null) {
      await cancelSeries(shopId, a.seriesId!);
      return;
    }
    await db
        .collection('shops')
        .doc(shopId)
        .collection('appointments')
        .doc(a.id)
        .update({'status': s.name});
  }

  /// Records a payment with caps
  Future<void> recordPayment(Appointment a, String shopId,
      {required String method, required double amount}) async {
    if (amount <= 0) throw Exception('invalid-input');
    final db = FirebaseFirestore.instance;
    final ref = db.collection('shops').doc(shopId).collection('appointments').doc(a.id);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw Exception('appointment-not-found');
      final data = snap.data()!;
      final total = ((data['totalAmount'] as num?) ?? 0).toDouble();
      final collected = ((data['collectedAmount'] as num?) ?? 0).toDouble();
      final newCollected = collected + amount;
      if (newCollected > total + 0.01) throw Exception('invalid-pricing');
      PaymentStatus ps = PaymentStatus.unpaid;
      if (newCollected >= total - 0.01) {
        ps = PaymentStatus.paid;
      } else if (newCollected > 0) {
        ps = PaymentStatus.depositPaid;
      }
      tx.update(ref, {
        'collectedAmount': newCollected,
        'paymentStatus': ps.name,
      });
      // Also write to payments collection for records
      final payRef = db.collection('shops').doc(shopId).collection('payments').doc();
      tx.set(payRef, {
        'appointmentId': a.id,
        'amount': amount,
        'method': method,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markReminderSent(Appointment a, String shopId) async {
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('appointments')
        .doc(a.id)
        .update({'reminderSent': true});
  }

  Future<void> setRating(Appointment a, int rating, String shopId) async {
    if (rating < 1 || rating > 5) throw Exception('invalid-rating');
    await FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('appointments')
        .doc(a.id)
        .update({'rating': rating});
  }

  Future<void> addRequest(
      UnavailabilityRequest r, String shopId) async {
    await FirestoreService.instance
        .addUnavailabilityRequest(shopId, r);
  }

  Future<void> updateRequest(
      UnavailabilityRequest r, String shopId) async {
    await FirestoreService.instance
        .updateUnavailabilityRequest(shopId, r);
  }

  /// Drops the bound shop and all cached appointments/requests. Used on
  /// sign-out so customer PII never survives into the next session.
  void reset() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _boundShopId = null;
    appointments = [];
    requests = [];
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

String newAppointmentId() => const Uuid().v4();
