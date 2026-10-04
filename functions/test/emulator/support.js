'use strict';

const assert = require('assert');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const { initializeApp, getApps } = require('firebase-admin/app');

const { UIDS, SHOP, OTHER_SHOP, JOIN_CODE, seedDocuments } = require('./helper');

if (getApps().length === 0) initializeApp();
const db = getFirestore();
const functions = require('../../src/index');

const functionsRef = {
  joinShopByCode: functions.joinShopByCode,
  createAppointment: functions.createAppointment,
  updateAppointment: functions.updateAppointment,
  deleteAppointment: functions.deleteAppointment,
};

function slotAt(daysFromNow, hourUtc = 7) {
  const date = new Date();
  date.setUTCDate(date.getUTCDate() + daysFromNow);
  date.setUTCHours(hourUtc, 0, 0, 0);
  return date;
}

function booking(overrides = {}) {
  return {
    shopId: SHOP,
    employeeId: 'employee-1',
    chairId: 'chair-1',
    serviceIds: ['service-cut'],
    startTimes: [slotAt(3).toISOString()],
    customerName: 'Walk In',
    customerPhone: '+966500000000',
    customerEmail: 'walkin@example.com',
    notes: '',
    ...overrides,
  };
}

async function call(name, uid, data) {
  const fn = functionsRef[name];
  assert.ok(fn, `missing callable ${name}`);
  assert.strictEqual(typeof fn.run, 'function', `${name} is not invocable`);
  return fn.run({ data, auth: uid ? { uid } : undefined, rawRequest: {} });
}

async function codeOf(name, uid, data) {
  try {
    await call(name, uid, data);
    return null;
  } catch (error) {
    return error.message;
  }
}

async function seed() {
  const batch = db.batch();
  for (const entry of seedDocuments(new Date())) {
    batch.set(db.doc(entry.path), entry.data);
  }
  await batch.commit();
}

async function clearAll() {
  const shops = await db.collection('shops').get();
  for (const shop of shops.docs) {
    await db.recursiveDelete(shop.ref);
  }
  const users = await db.collection('users').get();
  for (const user of users.docs) {
    await user.ref.delete();
  }
}

function appointmentDoc(id, shopId = SHOP) {
  return db.doc(`shops/${shopId}/appointments/${id}`);
}

async function lockCount(shopId = SHOP) {
  const snap = await db.collection(`shops/${shopId}/bookingLocks`).get();
  return snap.size;
}

async function appointmentCount(shopId = SHOP) {
  const snap = await db.collection(`shops/${shopId}/appointments`).get();
  return snap.size;
}

module.exports = { db, functionsRef, slotAt, booking, call, codeOf, seed, clearAll, appointmentDoc, lockCount, appointmentCount, Timestamp };
