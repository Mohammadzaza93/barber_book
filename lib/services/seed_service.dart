import 'package:uuid/uuid.dart';

import '../models/employee.dart';
import '../models/service.dart';
import 'firestore_service.dart';

/// Seeds default services and staff so the app is usable right away.
class SeedService {
  SeedService._();
  static final instance = SeedService._();

  Future<void> seedIfEmpty(String shopId) async {
    final services = await FirestoreService.instance
        .watchServices(shopId)
        .first;
    if (services.isEmpty) {
      await _seedServices(shopId);
    }
    final employees = await FirestoreService.instance
        .watchEmployees(shopId)
        .first;
    if (employees.isEmpty) {
      await _seedEmployees(shopId, services);
    }
  }

  Future<void> _seedServices(String shopId) async {
    const defaults = [
      ('قصة شعر', 'Haircut', 40.0, 30, 'haircut'),
      ('قصة ولحية', 'Haircut & beard', 60.0, 45, 'haircut'),
      ('تشذيب لحية', 'Beard trim', 25.0, 15, 'beard'),
      ('حلاقة كلاسيكية', 'Classic shave', 50.0, 30, 'shave'),
      ('تحديد خطوط', 'Line up', 30.0, 20, 'styling'),
      ('صبغ الشعر', 'Hair coloring', 150.0, 60, 'color'),
    ];
    for (var i = 0; i < defaults.length; i++) {
      final d = defaults[i];
      await FirestoreService.instance.addService(
        shopId,
        Service(
          id: const Uuid().v4(),
          name: d.$1,
          description: d.$2,
          price: d.$3,
          durationMinutes: d.$4,
          category: d.$5,
          sortOrder: i,
          highDemand: i == 2,
        ),
      );
    }
  }

  Future<void> _seedEmployees(
      String shopId, List<Service> services) async {
    const names = [('أحمد', 'barber'), ('محمد', 'barber')];
    for (var i = 0; i < names.length; i++) {
      final hours = <int, List<WorkSlot>>{};
      for (var day = 1; day <= 7; day++) {
        if (day == 5) continue; // Friday off
        hours[day] = [
          const WorkSlot(startMinutes: 9 * 60, endMinutes: 13 * 60),
          const WorkSlot(startMinutes: 16 * 60, endMinutes: 22 * 60),
        ];
      }
      await FirestoreService.instance.addEmployee(
        shopId,
        Employee(
          id: const Uuid().v4(),
          name: names[i].$1,
          role: names[i].$2,
          workingHours: hours,
          serviceIds: services.map((s) => s.id).toList(),
        ),
      );
    }
  }
}
