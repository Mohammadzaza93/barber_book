import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/booking_settings.dart';
import '../models/employee.dart';
import '../models/service.dart';
import '../services/firestore_service.dart';

class ShopProvider extends ChangeNotifier {
  BookingSettings? settings;
  List<Service> services = [];
  List<Employee> employees = [];
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
        .watchSettings(shopId)
        .listen((s) {
      settings = s;
      loading = false;
      notifyListeners();
    }));
    _subs.add(FirestoreService.instance
        .watchServices(shopId)
        .listen((list) {
      services = list;
      notifyListeners();
    }));
    _subs.add(FirestoreService.instance
        .watchEmployees(shopId)
        .listen((list) {
      employees = list;
      notifyListeners();
    }));
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

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
