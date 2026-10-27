import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/booking_settings.dart';
import '../models/employee.dart';
import '../models/service.dart';
import '../services/app_error.dart';
import '../services/firestore_service.dart';
import '../services/local_cache.dart';
import '../services/shop_manager.dart';

class ShopProvider extends ChangeNotifier {
  ShopProvider({
    Stream<BookingSettings> Function(String shopId)? watchSettings,
    Stream<List<Service>> Function(String shopId)? watchServices,
    Stream<List<Employee>> Function(String shopId)? watchEmployees,
  })  : _watchSettings =
            watchSettings ?? FirestoreService.instance.watchSettings,
        _watchServices =
            watchServices ?? FirestoreService.instance.watchServices,
        _watchEmployees =
            watchEmployees ?? FirestoreService.instance.watchEmployees;

  final Stream<BookingSettings> Function(String shopId) _watchSettings;
  final Stream<List<Service>> Function(String shopId) _watchServices;
  final Stream<List<Employee>> Function(String shopId) _watchEmployees;

  BookingSettings? settings;
  List<Service> services = [];
  List<Employee> employees = [];
  bool loading = true;

  String? error;
  String? errorSuggestion;
  bool fromCache = false;

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
    errorSuggestion = null;
    fromCache = false;
    _hydrateCache(shopId);
    _listen(_watchSettings(shopId), (s) {
      settings = s;
      ShopManager.timezoneOffsetMinutes = s.timezoneOffsetMinutes;
      loading = false;
      fromCache = false;
      _persistSettings(shopId, s);
    }, gatesLoading: true);
    _listen(_watchServices(shopId), (list) {
      services = list;
      fromCache = false;
      _persistServices(shopId, list);
    });
    _listen(_watchEmployees(shopId), (list) {
      employees = list;
      fromCache = false;
      _persistEmployees(shopId, list);
    });
  }

  void rebind() {
    final id = _boundShopId;
    if (id == null) return;
    _boundShopId = null;
    bind(id);
  }

  Future<void> _hydrateCache(String shopId) async {
    try {
      final cache = LocalCache.instance;
      final sRaw = await cache.getJson(cache.shopKey(shopId, 'settings'),
          maxAge: const Duration(days: 14));
      final svcRaw = await cache.getJson(cache.shopKey(shopId, 'services'),
          maxAge: const Duration(days: 14));
      final empRaw = await cache.getJson(cache.shopKey(shopId, 'employees'),
          maxAge: const Duration(days: 14));
      if (_boundShopId != shopId) return;
      var hit = false;
      if (sRaw is Map && settings == null) {
        settings = BookingSettings.fromMap(sRaw.cast<String, dynamic>());
        ShopManager.timezoneOffsetMinutes = settings!.timezoneOffsetMinutes;
        hit = true;
      }
      if (svcRaw is List && services.isEmpty) {
        services = [
          for (final item in svcRaw)
            if (item is Map)
              Service.fromMap(
                (item['id'] as String?) ?? '',
                item.cast<String, dynamic>(),
              )
        ].where((s) => s.id.isNotEmpty).toList();
        hit = true;
      }
      if (empRaw is List && employees.isEmpty) {
        employees = [
          for (final item in empRaw)
            if (item is Map)
              Employee.fromMap(
                (item['id'] as String?) ?? '',
                item.cast<String, dynamic>(),
              )
        ].where((e) => e.id.isNotEmpty).toList();
        hit = true;
      }
      if (hit) {
        loading = false;
        fromCache = true;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _persistSettings(String shopId, BookingSettings s) async {
    try {
      await LocalCache.instance.putJson(
        LocalCache.instance.shopKey(shopId, 'settings'),
        s.toMap(),
      );
    } catch (_) {}
  }

  Future<void> _persistServices(String shopId, List<Service> list) async {
    try {
      await LocalCache.instance.putJson(
        LocalCache.instance.shopKey(shopId, 'services'),
        list.map((s) => s.toMap()..['id'] = s.id).toList(),
      );
    } catch (_) {}
  }

  Future<void> _persistEmployees(String shopId, List<Employee> list) async {
    try {
      await LocalCache.instance.putJson(
        LocalCache.instance.shopKey(shopId, 'employees'),
        list.map((e) => e.toMap()..['id'] = e.id).toList(),
      );
    } catch (_) {}
  }

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
        final app = AppError.from(e);
        final code = e is FirebaseException ? e.code : app.code;
        if (code != 'permission-denied' && error == null) {
          error = app.message;
          errorSuggestion = app.suggestion;
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

  Future<void> saveSettings(BookingSettings s) async {
    final id = _boundShopId ?? ShopManager.shopId;
    if (id == null) return;
    await FirestoreService.instance.updateSettings(id, s.toMap());
  }

  Future<void> addService(Service s) async {
    final id = _boundShopId ?? ShopManager.shopId;
    if (id == null) return;
    await FirestoreService.instance.addService(id, s);
  }

  Future<void> updateService(Service s) async {
    final id = _boundShopId ?? ShopManager.shopId;
    if (id == null) return;
    await FirestoreService.instance.updateService(id, s);
  }

  Future<void> deleteService(String serviceId) async {
    final id = _boundShopId ?? ShopManager.shopId;
    if (id == null) return;
    await FirestoreService.instance.deleteService(id, serviceId);
  }

  Future<void> addEmployee(Employee e) async {
    final id = _boundShopId ?? ShopManager.shopId;
    if (id == null) return;
    await FirestoreService.instance.addEmployee(id, e);
  }

  Future<void> updateEmployee(Employee e) async {
    final id = _boundShopId ?? ShopManager.shopId;
    if (id == null) return;
    await FirestoreService.instance.updateEmployee(id, e);
  }

  Future<void> deleteEmployee(String employeeId) async {
    final id = _boundShopId ?? ShopManager.shopId;
    if (id == null) return;
    await FirestoreService.instance.deleteEmployee(id, employeeId);
  }

  void reset() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    _boundShopId = null;
    settings = null;
    services = [];
    employees = [];
    loading = true;
    error = null;
    errorSuggestion = null;
    fromCache = false;
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

String newServiceId() => const Uuid().v4();
String newEmployeeId() => const Uuid().v4();
