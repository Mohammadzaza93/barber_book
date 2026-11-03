import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter_test/flutter_test.dart';

import 'package:barber_app/models/app_role.dart';
import 'package:barber_app/models/shop_invite.dart';
import 'package:barber_app/models/staff_permissions.dart';
import 'package:barber_app/providers/auth_provider.dart';
import 'package:barber_app/services/firebase_status.dart';
import 'package:barber_app/services/shop_manager.dart';

/// Regression tests for the owner-only staff-account lifecycle.
///
/// The important ordering is:
///   1. verify ownership *before* creating an Auth account,
///   2. create the Auth user,
///   3. write `members/{uid}`,
///   4. if step 3 fails, surface the uid so the owner can finish the link
///      without creating a duplicate account.
void main() {
  const uid = 'AbCdEfGhIjKlMnOpQrStUvWx1234';

  setUp(() {
    firebaseReady = false;
    ShopManager.reset();
  });

  AuthProvider build({
    ShopResolver? resolveShop,
    Future<bool> Function(String shopId)? isShopOwner,
    Future<String> Function(String email, String password)? createStaffAuth,
    MembershipWriter? writeMembership,
    StaffInviteCreator? createStaffInvite,
    InviteClaimer? claimInvite,
    MemberPermissionsLoader? loadMemberPermissions,
  }) {
    return AuthProvider(
      resolveShop:
          resolveShop ?? (_) async => (shopId: 'shop-A', role: AppRole.admin),
      subscribeShopNotifications: (_) async => true,
      unsubscribeShopNotifications: (_) async => true,
      isShopOwner: isShopOwner ?? (_) async => true,
      createStaffAuth: createStaffAuth ?? (_, __) async => uid,
      loadMemberPermissions:
          loadMemberPermissions ?? (_, __) async => StaffPermissions.minimal,
      writeMembership: writeMembership ??
          (shopId, memberUid,
              {required email,
              required name,
              required role,
              required permissions}) async {},
      createStaffInvite: createStaffInvite ??
          (shopId,
                  {required email,
                  required name,
                  required role,
                  required permissions}) async =>
              ShopInvite(
                code: 'CODE1234',
                shopId: shopId,
                email: email,
                name: name,
                role: role,
                permissions: permissions,
                expiresAt: DateTime.now().add(const Duration(days: 7)),
              ),
      claimInvite: claimInvite ?? (_) async => 'shop-A',
    );
  }

  test('membership write failure after account creation exposes the uid',
      () async {
    final auth = build(
      writeMembership: (shopId, memberUid,
          {required email,
          required name,
          required role,
          required permissions}) async {
        throw Exception('permission-denied');
      },
    );
    await auth.applySessionForTest('owner-uid');

    await expectLater(
      auth.addStaffAccount(
        email: 'barber@example.com',
        name: 'Barber',
        role: AppRole.staff,
        permissions: StaffPermissions.minimal,
        password: 'secret123',
      ),
      throwsA(
        isA<MembershipWriteException>()
            .having((e) => e.uid, 'uid', uid)
            .having((e) => e.toString(), 'message', contains(uid)),
      ),
    );
  });

  test('ownership is checked before the Auth account is created', () async {
    var created = false;
    final auth = build(
      isShopOwner: (_) async => false,
      createStaffAuth: (_, __) async {
        created = true;
        return uid;
      },
    );
    await auth.applySessionForTest('owner-uid');

    await expectLater(
      auth.addStaffAccount(
        email: 'barber@example.com',
        name: 'Barber',
        role: AppRole.staff,
        permissions: StaffPermissions.minimal,
        password: 'secret123',
      ),
      throwsA(isA<StateError>()),
    );
    expect(created, isFalse,
        reason: 'no Auth account may exist if the owner check fails');
  });

  test('email-already-in-use is reported as a linkable account', () async {
    final auth = build(
      createStaffAuth: (_, __) async => throw FirebaseAuthException(
        code: 'email-already-in-use',
        message: 'already exists',
      ),
    );
    await auth.applySessionForTest('owner-uid');

    await expectLater(
      auth.addStaffAccount(
        email: 'barber@example.com',
        name: 'Barber',
        role: AppRole.staff,
        permissions: StaffPermissions.minimal,
        password: 'secret123',
      ),
      throwsA(isA<StaffAccountAlreadyExists>()),
    );
  });

  test('manual uid linking is refused: only the pairing code is trusted',
      () async {
    var writes = 0;
    final auth = build(
      writeMembership: (shopId, memberUid,
          {required email,
          required name,
          required role,
          required permissions}) async {
        writes++;
      },
    );
    await auth.applySessionForTest('owner-uid');

    await expectLater(
      auth.linkStaffAccount(
        uid: uid,
        email: 'barber@example.com',
        name: 'Barber',
        role: AppRole.staff,
        permissions: StaffPermissions.minimal,
      ),
      throwsA(isA<UnsupportedError>()),
    );
    expect(writes, 0,
        reason: 'a typed uid is never proof of account ownership');
  });

  test('an owner-created pairing code is bound to the invited email/role',
      () async {
    String? createdFor;
    final auth = build(
      createStaffInvite: (shopId,
          {required email,
          required name,
          required role,
          required permissions}) async {
        createdFor = email;
        expect(shopId, 'shop-A');
        expect(role, AppRole.staff);
        return ShopInvite(
          code: 'PAIR1234',
          shopId: shopId,
          email: email,
          name: name,
          role: role,
          permissions: permissions,
          expiresAt: DateTime.now().add(const Duration(days: 7)),
        );
      },
    );
    await auth.applySessionForTest('owner-uid');

    final invite = await auth.createStaffInvite(
      email: 'barber@example.com',
      name: 'Barber',
      role: AppRole.staff,
      permissions: StaffPermissions.accountant,
    );

    expect(createdFor, 'barber@example.com');
    expect(invite.code, 'PAIR1234');
  });

  test('a non-owner cannot create a pairing code', () async {
    var called = false;
    final auth = build(
      isShopOwner: (_) async => false,
      createStaffInvite: (shopId,
          {required email,
          required name,
          required role,
          required permissions}) async {
        called = true;
        throw StateError('unreachable');
      },
    );
    await auth.applySessionForTest('owner-uid');

    await expectLater(
      auth.createStaffInvite(
        email: 'barber@example.com',
        name: 'Barber',
        role: AppRole.staff,
        permissions: StaffPermissions.accountant,
      ),
      throwsA(isA<StateError>()),
    );
    expect(called, isFalse);
  });

  test('claiming a pairing code refreshes the session into the shop', () async {
    var claimed = false;
    final auth = build(
      resolveShop: (_) async => claimed
          ? (shopId: 'shop-A', role: AppRole.staff)
          : (shopId: null, role: AppRole.staff),
      loadMemberPermissions: (_, __) async => StaffPermissions.accountant,
      claimInvite: (code) async {
        expect(code, 'PAIR1234');
        claimed = true;
        return 'shop-A';
      },
    );
    await auth.applySessionForTest('staff-uid');
    expect(auth.shopId, isNull);

    final shopId = await auth.claimInvite('PAIR1234');

    expect(shopId, 'shop-A');
    expect(auth.shopId, 'shop-A');
    await pumpEventQueue();
    expect(auth.permissions.finance, isTrue);
  });

  test('successful creation writes the membership with the new uid', () async {
    String? writtenUid;
    final auth = build(
      writeMembership: (shopId, memberUid,
          {required email,
          required name,
          required role,
          required permissions}) async {
        writtenUid = memberUid;
        expect(email, 'barber@example.com');
        expect(name, 'Barber');
      },
    );
    await auth.applySessionForTest('owner-uid');

    final result = await auth.addStaffAccount(
      email: ' Barber@Example.com ',
      name: 'Barber',
      role: AppRole.staff,
      permissions: StaffPermissions.minimal,
      password: 'secret123',
    );

    expect(result, uid);
    expect(writtenUid, uid);
  });

  test('a restored staff session loads the membership permission map',
      () async {
    final auth = build(
      resolveShop: (_) async => (shopId: 'shop-A', role: AppRole.staff),
      loadMemberPermissions: (shopId, uid) async {
        expect(shopId, 'shop-A');
        expect(uid, 'staff-uid');
        return StaffPermissions.all;
      },
    );

    await auth.applySessionForTest('staff-uid');
    await pumpEventQueue();

    expect(auth.shopId, 'shop-A');
    expect(auth.permissions.services, isTrue);
    expect(auth.permissions.finance, isTrue);
  });

  test('owner session always has full permissions', () async {
    final auth = build(
      loadMemberPermissions: (_, __) async => StaffPermissions.minimal,
    );

    await auth.applySessionForTest('owner-uid');

    expect(auth.permissions.finance, isTrue);
  });

  test('sign-out clears the staff permission map', () async {
    final auth = build(
      resolveShop: (_) async => (shopId: 'shop-A', role: AppRole.staff),
      loadMemberPermissions: (_, __) async => StaffPermissions.all,
    );
    await auth.applySessionForTest('staff-uid');
    await pumpEventQueue();
    expect(auth.permissions.services, isTrue);

    await auth.applySessionForTest(null);

    expect(auth.shopId, isNull);
    expect(auth.permissions.services, isFalse);
  });

  test('a late permission read cannot grant capabilities after sign-out',
      () async {
    final completer = Completer<StaffPermissions>();
    final auth = build(
      resolveShop: (_) async => (shopId: 'shop-A', role: AppRole.staff),
      loadMemberPermissions: (_, __) => completer.future,
    );

    await auth.applySessionForTest('staff-uid');
    await auth.applySessionForTest(null);
    completer.complete(StaffPermissions.all);
    await pumpEventQueue();

    expect(auth.shopId, isNull);
    expect(auth.permissions.services, isFalse);
  });
}
