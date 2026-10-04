import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/appointment.dart';
import '../models/enums.dart';
import '../models/shop_time.dart';
import '../models/unavailability_request.dart';
import '../services/firestore_service.dart';
import '../services/secure_api.dart';
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

  /// Creates the booking on the server and returns the authoritative rows.
  Future<List<Map<String, dynamic>>> create({
    required String shopId,
    required String employeeId,
    String? chairId,
    required List<String> serviceIds,
    required DateTime start,
    required String customerName,
    String? customerPhone,
    String? customerEmail,
    String? notes,
    String? discountCode,
    bool recurring = false,
    bool outOfHours = false,
    String? requestId,
  }) {
    return SecureApi.instance.createAppointment(
      shopId: shopId,
      employeeId: employeeId,
      chairId: chairId,
      serviceIds: serviceIds,
      startTime: start.toUtc().toIso8601String(),
      requestId: requestId ?? SecureApi.instance.newRequestId(),
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      notes: notes,
      discountCode: discountCode,
      recurring: recurring,
      outOfHours: outOfHours,
    );
  }

  Future<void> updateContact(Appointment a, String shopId,
      {String? customerName, String? customerPhone, String? customerEmail, String? notes}) async {
    await SecureApi.instance.updateContact(
      shopId: shopId,
      appointmentId: a.id,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      notes: notes,
    );
  }

  Future<void> delete(Appointment a, String shopId) async {
    await SecureApi.instance.deleteAppointment(
      shopId: shopId,
      appointmentId: a.id,
    );
  }

  Future<void> setStatus(Appointment a, AppointmentStatus s, String shopId,
      {bool applyToSeries = false}) async {
    if (applyToSeries && a.seriesId != null) {
      for (final item in appointments) {
        if (item.seriesId == a.seriesId &&
            (item.status == AppointmentStatus.confirmed ||
                item.status == AppointmentStatus.requested)) {
          await SecureApi.instance.setStatus(
            shopId: shopId,
            appointmentId: item.id,
            status: s.name,
          );
        }
      }
    } else {
      await SecureApi.instance.setStatus(
        shopId: shopId,
        appointmentId: a.id,
        status: s.name,
      );
    }
  }

  /// Records a payment against the appointment. The server owns the resulting
  /// payment status, so the client only supplies the amount and the method.
  Future<void> recordPayment(Appointment a, String shopId,
      {required String method, required double amount}) async {
    await SecureApi.instance.recordPayment(
      shopId: shopId,
      appointmentId: a.id,
      method: method,
      amount: amount,
    );
  }

  Future<void> markReminderSent(Appointment a, String shopId) async {
    await SecureApi.instance.markReminderSent(
      shopId: shopId,
      appointmentId: a.id,
    );
  }

  Future<void> setRating(Appointment a, int rating, String shopId) async {
    await SecureApi.instance.setRating(
      shopId: shopId,
      appointmentId: a.id,
      rating: rating,
    );
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
