import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/booking_settings.dart';
import '../models/employee.dart';
import '../models/service.dart';
import '../services/firestore_service.dart';
import '../services/shop_manager.dart';

class ShopProvider extends ChangeNotifier {
  BookingSettings? settings;
  List<Service> services = [];
  List<Employee> employees = [];
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
    _listen(FirestoreService.instance.watchSettings(shopId), (s) {
      settings = s;
      // Publish the shop's UTC offset so day-bucketing in providers and screens
      // agrees with the server's working-hours validation.
      ShopManager.timezoneOffsetMinutes = s.timezoneOffsetMinutes;
      loading = false;
    }, gatesLoading: true);
    _listen(FirestoreService.instance.watchServices(shopId), (list) {
      services = list;
    });
    _listen(FirestoreService.instance.watchEmployees(shopId), (list) {
      employees = list;
    });
  }

  /// Subscribes [stream] with a shared error path so a denied or offline read
  /// clears [loading] instead of spinning forever.
  void _listen<T>(
    Stream<T> stream,
    void Function(T value) onData, {
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

  List<Service> get activeServices =>
      services.where((s) => s.active).toList();

  List<Employee> get activeEmployees =>
      employees.where((e) => e.active).toList();

  Service? serviceById(String id) {
    for (final s in services) {
      if (s.id == id) return s;
    }
    return null;
  }

  Employee? employeeById(String id) {
    for (final e in employees) {
      if (e.id == id) return e;
    }
    return null;
  }

  Future<void> saveSettings(BookingSettings s, String shopId) async {
    await FirestoreService.instance
        .updateSettings(shopId, s.toMap());
  }

  Future<void> addService(Service s, String shopId) =>
      FirestoreService.instance.addService(shopId, s);

  Future<void> updateService(Service s, String shopId) async {
    await FirestoreService.instance.updateService(shopId, s);
  }

  Future<void> deleteService(String id, String shopId) =>
      FirestoreService.instance.deleteService(shopId, id);

  Future<void> addEmployee(Employee e, String shopId) =>
      FirestoreService.instance.addEmployee(shopId, e);

  Future<void> updateEmployee(Employee e, String shopId) async {
    await FirestoreService.instance.updateEmployee(shopId, e);
  }

  Future<void> deleteEmployee(String id, String shopId) =>
      FirestoreService.instance.deleteEmployee(shopId, id);

  String newId() => const Uuid().v4();

  /// Drops the bound shop and all cached data. Used on sign-out so the next
  /// session never renders the previous tenant's services or staff.
  void reset() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _boundShopId = null;
    settings = null;
    ShopManager.timezoneOffsetMinutes = defaultTimezoneOffsetMinutes;
    services = [];
    employees = [];
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
