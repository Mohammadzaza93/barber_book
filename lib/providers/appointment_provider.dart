import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/appointment.dart';
import '../models/enums.dart';
import '../models/unavailability_request.dart';
import '../services/firestore_service.dart';

class AppointmentProvider extends ChangeNotifier {
  List<Appointment> appointments = [];
  List<UnavailabilityRequest> requests = [];
  bool loading = true;

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
    _subs.add(FirestoreService.instance
        .watchAppointments(shopId)
        .listen((list) {
      appointments = list;
      loading = false;
      notifyListeners();
    }));
    _subs.add(FirestoreService.instance
        .watchUnavailabilityRequests(shopId)
        .listen((list) {
      requests = list;
      notifyListeners();
    }));
  }

  List<Appointment> get todayAppointments {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
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

  Future<void> add(Appointment a, String shopId) async {
    await FirestoreService.instance.addAppointment(shopId, a);
  }

  Future<void> update(Appointment a, String shopId) async {
    await FirestoreService.instance.updateAppointment(shopId, a);
  }

  Future<void> delete(String id, String shopId) async {
    await FirestoreService.instance.deleteAppointment(shopId, id);
  }

  Future<void> setStatus(Appointment a, AppointmentStatus s, String shopId,
      {bool applyToSeries = false}) async {
    if (applyToSeries && a.seriesId != null) {
      for (final item in appointments) {
        if (item.seriesId == a.seriesId &&
            (item.status == AppointmentStatus.confirmed ||
                item.status == AppointmentStatus.requested)) {
          await FirestoreService.instance
              .updateAppointment(shopId, item.copyWith(status: s));
        }
      }
    } else {
      await FirestoreService.instance
          .updateAppointment(shopId, a.copyWith(status: s));
    }
  }

  Future<void> setPayment(Appointment a, PaymentStatus p, String shopId) async {
    await FirestoreService.instance
        .updateAppointment(shopId, a.copyWith(paymentStatus: p));
  }

  Future<void> markReminderSent(Appointment a, String shopId) async {
    await FirestoreService.instance
        .updateAppointment(shopId, a.copyWith(reminderSent: true));
  }

  Future<void> setRating(Appointment a, int rating, String shopId) async {
    await FirestoreService.instance
        .updateAppointment(shopId, a.copyWith(rating: rating));
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

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}

String newAppointmentId() => const Uuid().v4();
