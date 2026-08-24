import 'app_role.dart';

/// عضو فريق المحل (حساب مستخدم مرتبط بالمحل بدور وصلاحيات محددة).
class Member {
  final String uid;
  final String email;
  final String name;
  final AppRole role;
  final DateTime? createdAt;

  const Member({
    required this.uid,
    required this.email,
    this.name = '',
    this.role = AppRole.staff,
    this.createdAt,
  });

  Member copyWith({String? name, AppRole? role}) => Member(
        uid: uid,
        email: email,
        name: name ?? this.name,
        role: role ?? this.role,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'name': name,
        'role': role.name,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory Member.fromMap(String uid, Map<String, dynamic> m) => Member(
        uid: (m['uid'] as String?) ?? uid,
        email: (m['email'] as String?) ?? '',
        name: (m['name'] as String?) ?? '',
        role: AppRoleX.fromName(m['role'] as String?),
      );
}
