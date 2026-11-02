'use strict';
// Run from this folder:  npm install && npm test
// Needs Java (for the Firestore emulator). Everything runs locally and is free.

const fs = require('fs');
const path = require('path');
const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require('@firebase/rules-unit-testing');
const { Timestamp, serverTimestamp, setDoc, getDoc, updateDoc, deleteDoc, doc } =
  require('firebase/firestore');

const SHOP = 'shop1';
const ALL = {
  appointments: true, services: true, staff: true, discounts: true,
  expenses: true, feedback: true, reports: true, settings: true,
  businessTools: true, outOfHours: true, payments: true, finance: true,
};
const MINIMAL = { appointments: true, payments: true, finance: false };

let env;

function db(uid) {
  return env.authenticatedContext(uid, { email: `${uid}@example.com` }).firestore();
}

function newAppointment(over = {}) {
  const start = Timestamp.fromDate(new Date(Date.now() + 3600e3));
  const end = Timestamp.fromDate(new Date(Date.now() + 5400e3));
  return {
    shopId: SHOP, customerName: 'Ali', customerPhone: '1', employeeId: 'b1',
    serviceIds: ['s1'], startTime: start, endTime: end, status: 'confirmed',
    paymentStatus: 'unpaid', totalAmount: 50, collectedAmount: 0,
    createdById: 'staff1', createdAt: serverTimestamp(), ...over,
  };
}

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-barberbook',
    firestore: { rules: fs.readFileSync(path.join(__dirname, '..', 'firestore.rules'), 'utf8') },
  });
});
after(async () => { await env.cleanup(); });

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const d = ctx.firestore();
    await setDoc(doc(d, `shops/${SHOP}`), { ownerId: 'owner1', createdAt: Timestamp.now() });
    const member = (uid, role, permissions, extra = {}) =>
      setDoc(doc(d, `shops/${SHOP}/members/${uid}`), { uid, role, permissions, ...extra });
    await member('admin1', 'admin', ALL);
    await member('admin2', 'admin', ALL);
    await member('staff1', 'staff', MINIMAL);
    await member('staff2', 'staff', MINIMAL);
    await member('off1', 'staff', MINIMAL, { active: false });
    await setDoc(doc(d, `shops/${SHOP}/appointments/a1`), {
      ...newAppointment({ createdAt: Timestamp.now() }), createdById: 'staff1',
    });
    await setDoc(doc(d, `shops/${SHOP}/payments/p1`), { appointmentId: 'a1', amount: 10 });
    await setDoc(doc(d, `shops/${SHOP}/day_closes/2026-01-01`), { net: 1 });
    await setDoc(doc(d, `shops/${SHOP}/inventoryMovements/m1`), { itemId: 'i1', quantity: 1 });
  });
});

describe('deactivated members', () => {
  it('lose access to shop data', async () => {
    await assertFails(getDoc(doc(db('off1'), `shops/${SHOP}/appointments/a1`)));
    await assertSucceeds(getDoc(doc(db('staff1'), `shops/${SHOP}/appointments/a1`)));
  });
  it('can still read their own membership doc (needed to show "no access")', async () => {
    await assertSucceeds(getDoc(doc(db('off1'), `shops/${SHOP}/members/off1`)));
  });
});

describe('appointments', () => {
  it('staff can create a normal booking', async () => {
    await assertSucceeds(setDoc(doc(db('staff1'), `shops/${SHOP}/appointments/n1`), newAppointment()));
  });
  it('staff cannot create a booking that is already completed or paid', async () => {
    const col = (id) => doc(db('staff1'), `shops/${SHOP}/appointments/${id}`);
    await assertFails(setDoc(col('n2'), newAppointment({ status: 'completed' })));
    await assertFails(setDoc(col('n3'), newAppointment({ paymentStatus: 'paid' })));
    await assertFails(setDoc(col('n4'), newAppointment({ collectedAmount: 50 })));
    await assertFails(setDoc(col('n5'), newAppointment({ totalAmount: -5 })));
    await assertFails(setDoc(col('n6'), newAppointment({ createdById: 'someone-else' })));
  });
  it('staff can change status and contact notes but not time or price', async () => {
    const ref = doc(db('staff1'), `shops/${SHOP}/appointments/a1`);
    await assertSucceeds(updateDoc(ref, { status: 'completed' }));
    await assertSucceeds(updateDoc(ref, { notes: 'hi' }));
    await assertFails(updateDoc(ref, { totalAmount: 1 }));
    await assertFails(updateDoc(ref, { startTime: Timestamp.now() }));
    await assertFails(updateDoc(ref, { status: 'bogus' }));
  });
  it('payment capability cannot collect more than the total', async () => {
    const ref = doc(db('staff1'), `shops/${SHOP}/appointments/a1`);
    await assertSucceeds(updateDoc(ref, { collectedAmount: 50, paymentStatus: 'paid' }));
    await assertFails(updateDoc(ref, { collectedAmount: 500, paymentStatus: 'paid' }));
  });
  it('only admins delete appointments', async () => {
    await assertFails(deleteDoc(doc(db('staff1'), `shops/${SHOP}/appointments/a1`)));
    await assertSucceeds(deleteDoc(doc(db('admin1'), `shops/${SHOP}/appointments/a1`)));
  });
});

describe('ledgers', () => {
  it('payments are append-only; only admins delete', async () => {
    await assertSucceeds(setDoc(doc(db('staff1'), `shops/${SHOP}/payments/p2`), { amount: 5 }));
    await assertFails(setDoc(doc(db('staff1'), `shops/${SHOP}/payments/p3`), { amount: -5 }));
    await assertFails(updateDoc(doc(db('staff1'), `shops/${SHOP}/payments/p1`), { amount: 1 }));
    await assertFails(updateDoc(doc(db('admin1'), `shops/${SHOP}/payments/p1`), { amount: 1 }));
    await assertFails(deleteDoc(doc(db('staff1'), `shops/${SHOP}/payments/p1`)));
    await assertSucceeds(deleteDoc(doc(db('admin1'), `shops/${SHOP}/payments/p1`)));
  });
  it('day closes cannot be deleted by staff', async () => {
    await assertFails(deleteDoc(doc(db('staff1'), `shops/${SHOP}/day_closes/2026-01-01`)));
    await assertSucceeds(deleteDoc(doc(db('admin1'), `shops/${SHOP}/day_closes/2026-01-01`)));
  });
  it('inventory movements are append-only for everyone', async () => {
    await assertSucceeds(setDoc(doc(db('staff1'), `shops/${SHOP}/inventoryMovements/m2`), { itemId: 'i1', quantity: 2 }));
    await assertFails(updateDoc(doc(db('admin1'), `shops/${SHOP}/inventoryMovements/m1`), { quantity: 9 }));
    await assertFails(deleteDoc(doc(db('admin1'), `shops/${SHOP}/inventoryMovements/m1`)));
  });
});

describe('members', () => {
  it('an admin can adjust a staff member but not roles or other admins', async () => {
    const staff = doc(db('admin1'), `shops/${SHOP}/members/staff2`);
    await assertSucceeds(updateDoc(staff, { active: false }));
    await assertSucceeds(updateDoc(staff, { permissions: { appointments: true, payments: false } }));
    await assertFails(updateDoc(staff, { role: 'admin' }));
    await assertFails(updateDoc(doc(db('admin1'), `shops/${SHOP}/members/admin2`), { active: false }));
    await assertFails(updateDoc(doc(db('admin1'), `shops/${SHOP}/members/admin1`), { active: false }));
  });
  it('staff cannot edit memberships or create their own', async () => {
    await assertFails(updateDoc(doc(db('staff1'), `shops/${SHOP}/members/staff1`), { role: 'admin' }));
    await assertFails(setDoc(doc(db('stranger'), `shops/${SHOP}/members/stranger`),
      { uid: 'stranger', role: 'admin', permissions: ALL }));
  });
  it('only the owner creates members', async () => {
    await assertSucceeds(setDoc(doc(db('owner1'), `shops/${SHOP}/members/new1`),
      { uid: 'new1', role: 'staff', permissions: MINIMAL }));
    await assertFails(setDoc(doc(db('admin1'), `shops/${SHOP}/members/new2`),
      { uid: 'new2', role: 'staff', permissions: MINIMAL }));
  });
});

describe('appConfig pointer', () => {
  it('any signed-in user can read it, only the owner can write it', async () => {
    await assertSucceeds(setDoc(doc(db('owner1'), 'appConfig/primaryShop'), { shopId: SHOP, updatedAt: serverTimestamp() }));
    await assertSucceeds(getDoc(doc(db('stranger'), 'appConfig/primaryShop')));
    await assertFails(setDoc(doc(db('admin1'), 'appConfig/primaryShop'), { shopId: SHOP, updatedAt: serverTimestamp() }));
    await assertFails(setDoc(doc(db('stranger'), 'appConfig/primaryShop'), { shopId: SHOP, updatedAt: serverTimestamp() }));
  });
});

describe('memberships pointer', () => {
  const pointer = (uid) => ({
    uid, shopId: SHOP, role: 'staff', active: true,
    email: `${uid}@example.com`, name: uid,
    permissions: MINIMAL,
  });

  it('the owner writes it and the member reads only their own pointer', async () => {
    await assertSucceeds(setDoc(doc(db('owner1'), 'memberships/staff1'), pointer('staff1')));
    await assertSucceeds(getDoc(doc(db('staff1'), 'memberships/staff1')));
    await assertFails(getDoc(doc(db('staff2'), 'memberships/staff1')));
    await assertFails(getDoc(doc(db('stranger'), 'memberships/staff1')));
  });

  it('non-owners cannot create or change a pointer', async () => {
    await assertFails(setDoc(doc(db('staff1'), 'memberships/staff1'), pointer('staff1')));
    await assertFails(setDoc(doc(db('admin1'), 'memberships/staff1'), pointer('staff1')));
    await assertSucceeds(setDoc(doc(db('owner1'), 'memberships/staff1'), pointer('staff1')));
    await assertFails(setDoc(doc(db('admin1'), 'memberships/staff1'), { active: false }));
    await assertSucceeds(setDoc(doc(db('owner1'), 'memberships/staff1'), { active: false }));
  });
});
