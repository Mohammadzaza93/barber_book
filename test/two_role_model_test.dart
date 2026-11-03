import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/models/staff_permissions.dart';
import 'package:barber_app/models/team/team_models.dart';

/// The app has exactly two team roles: أدمن (full) and محاسب (limited, edited
/// by the admin). Legacy stored role ids must keep working without a data
/// migration.
void main() {
  group('team role presets', () {
    test('only admin and accountant are offered', () {
      expect(TeamRolePreset.all.map((r) => r.id), ['admin', 'accountant']);
      expect(TeamRolePreset.all.map((r) => r.labelAr), ['أدمن', 'محاسب']);
      expect(TeamRolePreset.fromId(null).id, 'accountant');
    });

    test('legacy ids map to one of the two roles', () {
      for (final legacy in ['owner', 'manager', 'admin']) {
        expect(TeamRolePreset.fromId(legacy).id, 'admin', reason: legacy);
      }
      for (final legacy in ['barber', 'admin_staff', 'accountant', '']) {
        expect(
          TeamRolePreset.fromId(legacy).id,
          'accountant',
          reason: legacy,
        );
      }
    });

    test('admin is a full AppRole, accountant is limited staff', () {
      expect(AppRoleX.fromTeamRole('admin'), AppRole.admin);
      expect(AppRoleX.fromTeamRole('owner'), AppRole.admin);
      expect(AppRoleX.fromTeamRole('manager'), AppRole.admin);
      expect(AppRoleX.fromTeamRole('accountant'), AppRole.staff);
      expect(AppRoleX.fromTeamRole('barber'), AppRole.staff);
      expect(AppRoleX.fromTeamRole(null), AppRole.staff);
    });
  });

  group('permission presets', () {
    test('admin role always gets every capability', () {
      for (final id in ['admin', 'owner', 'manager']) {
        final p = StaffPermissions.forRole(id);
        expect(p.toMap().values.every((v) => v == true), isTrue, reason: id);
      }
    });

    test('accountant role is limited to money/booking work by default', () {
      final p = StaffPermissions.forRole('accountant');
      expect(p.appointments, isTrue);
      expect(p.payments, isTrue);
      expect(p.reports, isTrue);
      expect(p.finance, isTrue);
      expect(p.staff, isFalse);
      expect(p.settings, isFalse);
      expect(p.services, isFalse);
      expect(p.businessTools, isFalse);
    });

    test('legacy limited ids keep least privilege', () {
      for (final id in ['barber', 'admin_staff', 'unknown']) {
        final p = StaffPermissions.forRole(id);
        expect(p.settings, isFalse, reason: id);
        expect(p.staff, isFalse, reason: id);
        expect(p.finance, isFalse, reason: id);
        expect(p.reports, isFalse, reason: id);
      }
    });

    test('admin can still customise the accountant map', () {
      final p = StaffPermissions.forRole('accountant').copyWith(
        services: true,
        expenses: false,
      );
      expect(p.services, isTrue);
      expect(p.expenses, isFalse);
      expect(p.settings, isFalse);
    });
  });
}
