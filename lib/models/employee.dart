import 'staff_permissions.dart';

class WorkSlot {
  final int startMinutes;
  final int endMinutes;

  const WorkSlot({required this.startMinutes, required this.endMinutes});

  Map<String, dynamic> toMap() => {
        'start': startMinutes,
        'end': endMinutes,
      };

  factory WorkSlot.fromMap(Map<String, dynamic> m) => WorkSlot(
        startMinutes: (m['start'] as num?)?.toInt() ?? 0,
        endMinutes: (m['end'] as num?)?.toInt() ?? 0,
      );

  static int timeToMinutes(int h, int m) => h * 60 + m;
}

class Employee {
  final String id;
  final String name;
  final String role;
  final String phone;
  final String? email;
  final String? avatarUrl;
  final String? authUid;
  final Map<int, List<WorkSlot>> workingHours;
  final List<String> serviceIds;
  final bool active;
  final int colorValue;
  final StaffPermissions permissions;

  Employee({
    required this.id,
    required this.name,
    this.role = 'barber',
    this.phone = '',
    this.email,
    this.avatarUrl,
    this.authUid,
    required this.workingHours,
    required this.serviceIds,
    this.active = true,
    this.colorValue = 0xFF26A69A,
    StaffPermissions? permissions,
  }) : permissions = permissions ?? StaffPermissions.minimal;

  Employee copyWith({
    String? name,
    String? role,
    String? phone,
    String? email,
    String? avatarUrl,
    String? authUid,
    Map<int, List<WorkSlot>>? workingHours,
    List<String>? serviceIds,
    bool? active,
    int? colorValue,
    StaffPermissions? permissions,
  }) {
    return Employee(
      id: id,
      name: name ?? this.name,
      role: role ?? this.role,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      authUid: authUid ?? this.authUid,
      workingHours: workingHours ?? this.workingHours,
      serviceIds: serviceIds ?? this.serviceIds,
      active: active ?? this.active,
      colorValue: colorValue ?? this.colorValue,
      permissions: permissions ?? this.permissions,
    );
  }

  bool worksOn(DateTime day) {
    final slots = workingHours[day.weekday];
    return slots != null && slots.isNotEmpty;
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'role': role,
        'phone': phone,
        'email': email,
        'avatarUrl': avatarUrl,
        'authUid': authUid,
        'workingHours': workingHours.map((k, v) =>
            MapEntry(k.toString(), v.map((s) => s.toMap()).toList())),
        'serviceIds': serviceIds,
        'active': active,
        'colorValue': colorValue,
        'permissions': permissions.toMap(),
      };

  factory Employee.fromMap(String id, Map<String, dynamic> m) {
    final whRaw = (m['workingHours'] as Map<String, dynamic>?) ?? {};
    final wh = <int, List<WorkSlot>>{};
    whRaw.forEach((k, v) {
      final day = int.tryParse(k);
      if (day != null) {
        wh[day] = (v as List<dynamic>)
            .map((e) => WorkSlot.fromMap((e as Map).cast<String, dynamic>()))
            .toList();
      }
    });
    return Employee(
      id: id,
      name: (m['name'] as String?) ?? '',
      role: (m['role'] as String?) ?? 'barber',
      phone: (m['phone'] as String?) ?? '',
      email: m['email'] as String?,
      avatarUrl: m['avatarUrl'] as String?,
      authUid: m['authUid'] as String?,
      workingHours: wh,
      serviceIds: (m['serviceIds'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      active: (m['active'] as bool?) ?? true,
      colorValue: (m['colorValue'] as num?)?.toInt() ?? 0xFF26A69A,
      permissions:
          StaffPermissions.fromMap(m['permissions'] as Map<String, dynamic>?),
    );
  }
}
