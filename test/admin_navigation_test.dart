import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/models/staff_permissions.dart';
import 'package:barber_app/screens/admin/admin_navigation.dart';

void main() {
  group('adminSections', () {
    test('indices are unique and cover every admin tab', () {
      final indices = adminSections.map((s) => s.index).toList();
      expect(indices.toSet().length, indices.length);
      expect(indices.toSet(), adminTabsSet);
      expect(indices.length, 13);
    });

    test('every section is visible to an admin', () {
      for (final section in adminSections) {
        expect(
          adminTabVisible(AppRole.admin, section.index),
          isTrue,
          reason: 'section ${section.index}',
        );
      }
    });
  });

  group('primaryAdminTabs', () {
    test('admin gets dashboard, appointments, finance and inventory', () {
      expect(primaryAdminTabs(AppRole.admin), [0, 1, 11, 12]);
    });

    test('never returns more than four primary destinations', () {
      expect(
        primaryAdminTabs(AppRole.admin).length,
        lessThanOrEqualTo(kMaxPrimaryTabs),
      );
      expect(
        primaryAdminTabs(AppRole.staff, perms: StaffPermissions.all).length,
        lessThanOrEqualTo(kMaxPrimaryTabs),
      );
    });

    test('minimal accountant keeps appointments and profile', () {
      expect(primaryAdminTabs(AppRole.staff), [1, 10]);
    });

    test('accountant preset includes finance, inventory and profile', () {
      expect(
        primaryAdminTabs(AppRole.staff, perms: StaffPermissions.accountant),
        [1, 11, 12, 10],
      );
    });

    test('every primary destination is actually allowed', () {
      for (final role in AppRole.values) {
        for (final perms in [
          StaffPermissions.minimal,
          StaffPermissions.accountant,
          StaffPermissions.all,
        ]) {
          for (final index in primaryAdminTabs(role, perms: perms)) {
            expect(
              adminTabVisible(role, index, perms: perms),
              isTrue,
              reason: 'role=$role perms=${perms.toMap()} index=$index',
            );
          }
        }
      }
    });
  });

  group('adminTabVisible', () {
    test('admin matches the full tab set', () {
      for (var i = 0; i <= 12; i++) {
        expect(adminTabVisible(AppRole.admin, i), adminTabsSet.contains(i));
      }
    });

    test('staff never sees the dashboard and always keeps profile', () {
      for (final perms in [
        StaffPermissions.minimal,
        StaffPermissions.accountant,
        StaffPermissions.all,
      ]) {
        expect(adminTabVisible(AppRole.staff, 0, perms: perms), isFalse);
        expect(adminTabVisible(AppRole.staff, 10, perms: perms), isTrue);
      }
    });

    test('unknown indices are denied for staff', () {
      expect(adminTabVisible(AppRole.staff, -1), isFalse);
      expect(adminTabVisible(AppRole.staff, 99), isFalse);
    });
  });

  group('AdminNavigationController', () {
    test('forwards selections to the shell callback', () {
      final picked = <int>[];
      final controller = AdminNavigationController(picked.add);
      controller.select(11);
      controller.select(12);
      expect(picked, [11, 12]);
    });
  });
}
