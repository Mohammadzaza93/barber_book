import 'app_role.dart';
import 'firestore_date.dart';
import 'staff_permissions.dart';

/// Owner-issued, single-use pairing code for an existing Firebase Auth account.
///
/// The code is a high-entropy secret. It is bound to the employee's email, so
/// the account that claims it must be signed in with that same email. The
/// server rules copy the role/permissions from this document; a claimant can
/// never choose their own capabilities.
class ShopInvite {
  final String code;
  final String shopId;
  final String email;
  final String name;
  final AppRole role;
  final StaffPermissions permissions;
  final DateTime? expiresAt;

  const ShopInvite({
    required this.code,
    required this.shopId,
    required this.email,
    required this.name,
    required this.role,
    required this.permissions,
    required this.expiresAt,
  });

  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  factory ShopInvite.fromMap(String code, Map<String, dynamic> m) => ShopInvite(
        code: (m['code'] as String?) ?? code,
        shopId: (m['shopId'] as String?) ?? '',
        email: ((m['email'] as String?) ?? '').toLowerCase(),
        name: (m['name'] as String?) ?? '',
        role: AppRoleX.fromName(m['role'] as String?),
        permissions:
            StaffPermissions.fromMap(m['permissions'] as Map<String, dynamic>?),
        expiresAt: readFirestoreDate(m['expiresAt']),
      );
}

/// A pairing code could not be claimed. The message is safe to show to the
/// user; it never includes another account's identity.
class InviteClaimException implements Exception {
  const InviteClaimException(this.message);
  final String message;

  @override
  String toString() => message;
}
