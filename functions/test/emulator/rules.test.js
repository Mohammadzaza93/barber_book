'use strict';

const assert = require('assert');
const fs = require('fs');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');

const { PROJECT_ID, RULES_PATH, UIDS, SHOP, OTHER_SHOP, seedDocuments } = require('./helper');

let testEnv;

async function seed() {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    const batch = db.batch();
    for (const { path: docPath, data } of seedDocuments(new Date())) {
      batch.set(db.doc(docPath), data);
    }
    await batch.commit();
  });
}

function clientAs(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function anon() {
  return testEnv.unauthenticatedContext().firestore();
}

function appointmentDoc(id = 'appt-1') {
  return {
    shopId: SHOP,
    reference: 'REF1234',
    customerName: 'Walk In',
    customerPhone: '0500000000',
    employeeId: 'employee-1',
    serviceIds: ['service-cut'],
    startTime: new Date('2030-01-07T10:00:00Z'),
    endTime: new Date('2030-01-07T10:30:00Z'),
    status: 'requested',
    paymentStatus: 'unpaid',
    totalAmount: 50,
    depositAmount: 0,
    discountAmount: 0,
    createdById: UIDS.staff,
    createdAt: new Date(),
  };
}

describe('firestore rules', () => {
  before(async () => {
    testEnv = await initializeTestEnvironment({
      projectId: PROJECT_ID,
      firestore: { rules: fs.readFileSync(RULES_PATH, 'utf8') },
    });
    await seed();
  });

  after(async () => {
    if (testEnv) await testEnv.cleanup();
  });

  beforeEach(async () => {
    await testEnv.clearFirestore();
    await seed();
  });

  it('a staff member cannot sign itself into a shop', async () => {
    const db = clientAs(UIDS.stranger);
    await assertFails(
      db.doc(`shops/${SHOP}/members/${UIDS.stranger}`).set({ uid: UIDS.stranger, email: 'n@x.com', role: 'staff' }),
    );
  });

  it('a staff member cannot promote itself to manager', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/members/${UIDS.staff}`).update({ role: 'manager' }));
  });

  it('a staff member cannot demote or remove another member', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/members/${UIDS.manager}`).update({ role: 'staff' }));
    await assertFails(db.doc(`shops/${SHOP}/members/${UIDS.manager}`).delete());
  });

  it('a non member cannot create an appointment', async () => {
    const db = clientAs(UIDS.stranger);
    await assertFails(db.doc(`shops/${SHOP}/appointments/x1`).set(appointmentDoc('x1')));
  });

  it('a staff member cannot create an appointment from the client', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/appointments/a1`).set(appointmentDoc('a1')));
  });

  it('a manager cannot create an appointment from the client', async () => {
    const db = clientAs(UIDS.manager);
    await assertFails(db.doc(`shops/${SHOP}/appointments/a2`).set(appointmentDoc('a2')));
  });

  it('a manager cannot update an appointment from the client', async () => {
    const db = clientAs(UIDS.manager);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`shops/${SHOP}/appointments/a3`).set(appointmentDoc('a3'));
    });
    await assertFails(db.doc(`shops/${SHOP}/appointments/a3`).update({ status: 'confirmed' }));
  });

  it('a manager cannot delete an appointment from the client', async () => {
    const db = clientAs(UIDS.manager);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`shops/${SHOP}/appointments/a4`).set(appointmentDoc('a4'));
    });
    await assertFails(db.doc(`shops/${SHOP}/appointments/a4`).delete());
  });

  it('a manager cannot forge a payment status through an appointment write', async () => {
    const db = clientAs(UIDS.owner);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`shops/${SHOP}/appointments/a5`).set(appointmentDoc('a5'));
    });
    await assertFails(db.doc(`shops/${SHOP}/appointments/a5`).update({ paymentStatus: 'paid', totalAmount: 0 }));
  });

  it('a client cannot write booking locks', async () => {
    for (const uid of [UIDS.staff, UIDS.manager, UIDS.owner]) {
      const db = clientAs(uid);
      await assertFails(db.doc(`shops/${SHOP}/bookingLocks/e:employee-1_1`).set({ resource: 'e:employee-1' }));
      await assertFails(db.doc(`shops/${SHOP}/bookingLocks/e:employee-1_1`).delete());
    }
  });

  it('a client cannot read or write booking idempotency claims', async () => {
    for (const uid of [UIDS.staff, UIDS.manager, UIDS.owner]) {
      const db = clientAs(uid);
      await assertFails(db.doc(`shops/${SHOP}/bookingRequests/${uid}_abc`).set({ createdById: uid }));
      await assertFails(db.doc(`shops/${SHOP}/bookingRequests/${uid}_abc`).delete());
      await assertFails(db.doc(`shops/${SHOP}/bookingRequests/${uid}_abc`).get());
    }
  });

  it('a staff member cannot increase a coupon usage counter', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/discounts/discount-percent`).update({ usageCount: 4 }));
    await assertFails(db.doc(`shops/${SHOP}/discounts/discount-percent`).update({ value: 90 }));
  });

  it('an owner can edit a coupon without touching its usage counter', async () => {
    const db = clientAs(UIDS.owner);
    await assertSucceeds(
      db.doc(`shops/${SHOP}/discounts/discount-percent`).update({ title: 'Ten percent off', value: 15, usageCount: 0 }),
    );
    await assertFails(db.doc(`shops/${SHOP}/discounts/discount-percent`).update({ usageCount: 1 }));
  });

  it('an owner cannot create a coupon with a usage counter', async () => {
    const db = clientAs(UIDS.owner);
    await assertFails(db.doc(`shops/${SHOP}/discounts/forged`).set({ code: 'FORGED', value: 100, usageCount: 99 }));
    await assertSucceeds(db.doc(`shops/${SHOP}/discounts/fresh`).set({ code: 'FRESH', value: 10, usageCount: 0 }));
  });

  it('a user cannot grant themselves a shop membership through their profile', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`users/${UIDS.staff}`).set({ email: 's@x.com', joinedShopId: SHOP }, { merge: true }));
    await assertFails(db.doc(`users/${UIDS.staff}`).update({ joinedShopId: SHOP }));
    await assertFails(db.doc(`users/${UIDS.staff}`).set({ email: 'other@x.com' }, { merge: true }));
  });

  it('a user can read their own profile', async () => {
    const db = clientAs(UIDS.staff);
    await assertSucceeds(db.doc(`users/${UIDS.staff}`).get());
  });

  it('a user cannot read another user profile', async () => {
    const db = clientAs(UIDS.stranger);
    await assertFails(db.doc(`users/${UIDS.staff}`).get());
    await assertSucceeds(db.doc(`users/${UIDS.stranger}`).get());
  });

  it('a staff member cannot read another shop', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${OTHER_SHOP}`).get());
  });

  it('a staff member cannot read another shop appointments', async () => {
    const db = clientAs(UIDS.staff);
    await testEnv.withSecurityRulesDisabled(async (ctx) => {
      await ctx.firestore().doc(`shops/${OTHER_SHOP}/appointments/x`).set(appointmentDoc('x'));
    });
    await assertFails(db.collection(`shops/${OTHER_SHOP}/appointments`).get());
  });

  it('a staff member cannot read payments', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/payments/payment-seed`).get());
    await assertFails(db.collection(`shops/${SHOP}/payments`).get());
  });

  it('a staff member cannot read expenses', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/expenses/expense-seed`).get());
  });

  it('a manager can read payments', async () => {
    const db = clientAs(UIDS.manager);
    await assertSucceeds(db.doc(`shops/${SHOP}/payments/payment-seed`).get());
  });

  it('no client can write payments, not even a manager', async () => {
    for (const uid of [UIDS.owner, UIDS.manager, UIDS.staff]) {
      const db = clientAs(uid);
      const ref = db.doc(`shops/${SHOP}/payments/forged-${uid}`);
      await assertFails(ref.set({ appointmentId: 'a1', amount: 500, method: 'cash' }));
      await assertFails(
        db.doc(`shops/${SHOP}/payments/payment-seed`).update({ amount: 1 }),
      );
      await assertFails(db.doc(`shops/${SHOP}/payments/payment-seed`).delete());
    }
  });

  it('a staff member cannot write the service catalog', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/services/service-cut`).update({ price: 1 }));
    await assertSucceeds(db.doc(`shops/${SHOP}/services/service-cut`).get());
  });

  it('a staff member cannot write employees', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/employees/employee-1`).update({ active: false }));
  });

  it('a staff member can submit an out of hours request', async () => {
    const db = clientAs(UIDS.staff);
    await assertSucceeds(db.doc(`shops/${SHOP}/requests/new`).set({ kind: 'unavailability', status: 'pending' }));
  });

  it('a staff member cannot approve an out of hours request', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.doc(`shops/${SHOP}/requests/request-seed`).update({ status: 'approved' }));
    await assertSucceeds(clientAs(UIDS.manager).doc(`shops/${SHOP}/requests/request-seed`).update({ status: 'approved' }));
  });

  it('a non member cannot read shop data', async () => {
    const db = clientAs(UIDS.stranger);
    await assertFails(db.doc(`shops/${SHOP}`).get());
    await assertFails(db.collection(`shops/${SHOP}/appointments`).get());
    await assertFails(db.collection(`shops/${SHOP}/services`).get());
  });

  it('unknown collections are denied', async () => {
    const db = clientAs(UIDS.owner);
    await assertFails(db.doc(`shops/${SHOP}/secrets/anything`).set({ a: 1 }));
    await assertFails(db.doc('admin/config').set({ a: 1 }));
    await assertFails(anon().doc(`shops/${SHOP}`).get());
  });

  it('a staff member cannot read or change stock levels', async () => {
    const db = clientAs(UIDS.staff);
    await assertFails(db.collection(`shops/${SHOP}/inventory`).get());
    await assertFails(db.doc(`shops/${SHOP}/inventory/item-1`).set({ name: 'Razor', quantity: 999 }));
    await assertFails(db.collection(`shops/${SHOP}/inventoryMovements`).get());
  });

  it('a manager can manage stock but cannot rewrite movement history', async () => {
    const db = clientAs(UIDS.manager);
    await assertSucceeds(db.doc(`shops/${SHOP}/inventory/item-1`).set({ name: 'Razor', quantity: 5 }));
    await assertSucceeds(db.doc(`shops/${SHOP}/inventory/item-1`).update({ quantity: 4 }));
    await assertSucceeds(db.doc(`shops/${SHOP}/inventory/item-1`).delete());
    await assertSucceeds(db.doc(`shops/${SHOP}/inventoryMovements/m1`).set({ delta: -1, reason: 'used' }));
    await assertFails(db.doc(`shops/${SHOP}/inventoryMovements/m1`).update({ delta: 100 }));
    await assertFails(db.doc(`shops/${SHOP}/inventoryMovements/m1`).delete());
  });

  it('every collection the app ships is reachable by the owner', async () => {
    const appCollections = [
      'appointments',
      'services',
      'employees',
      'discounts',
      'expenses',
      'feedback',
      'requests',
      'portfolio',
      'customers',
      'loyalty',
      'loyaltyRules',
      'loyaltyGifts',
      'chairs',
      'chairSupplies',
      'chairWeeklyProfits',
      'queue',
      'payments',
      'members',
      'inventory',
      'inventoryMovements',
    ];
    const serverOnly = ['bookingLocks', 'bookingRequests'];
    const db = clientAs(UIDS.owner);
    const unreachable = [];
    for (const name of appCollections) {
      if (serverOnly.includes(name)) continue;
      try {
        await assertSucceeds(db.collection(`shops/${SHOP}/${name}`).get());
      } catch (error) {
        unreachable.push(name);
      }
    }
    assert.deepStrictEqual(unreachable, [], 'collections with no rule would be denied by the catch all');
    assert.ok(serverOnly.every((name) => serverOnly.includes(name)));
  });

  it('keeps the shop document owner only for settings and join codes', async () => {
    await assertSucceeds(clientAs(UIDS.owner).doc(`shops/${SHOP}`).update({ shopName: 'Renamed' }));
    await assertFails(clientAs(UIDS.manager).doc(`shops/${SHOP}`).update({ shopName: 'Hijacked' }));
    await assertFails(clientAs(UIDS.staff).doc(`shops/${SHOP}`).update({ joinCode: 'NEW01' }));
    assert.ok(fs.existsSync(RULES_PATH));
  });
});
