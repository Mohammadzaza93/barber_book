'use strict';

const crypto = require('crypto');
const { CODES, fail } = require('./errors');

const REFERENCE_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const REFERENCE_LENGTH = 8;

function shopRef(db, shopId) {
  return db.collection('shops').doc(shopId);
}

function appointmentsCol(db, shopId) {
  return shopRef(db, shopId).collection('appointments');
}

function servicesCol(db, shopId) {
  return shopRef(db, shopId).collection('services');
}

function employeesCol(db, shopId) {
  return shopRef(db, shopId).collection('employees');
}

function chairsCol(db, shopId) {
  return shopRef(db, shopId).collection('chairs');
}

function discountsCol(db, shopId) {
  return shopRef(db, shopId).collection('discounts');
}

function membersCol(db, shopId) {
  return shopRef(db, shopId).collection('members');
}

function paymentsCol(db, shopId) {
  return shopRef(db, shopId).collection('payments');
}

function bookingRequestsCol(db, shopId) {
  return shopRef(db, shopId).collection('bookingRequests');
}

function locksCol(db, shopId) {
  return shopRef(db, shopId).collection('bookingLocks');
}

function randomReference() {
  const bytes = crypto.randomBytes(REFERENCE_LENGTH);
  let out = '';
  for (let i = 0; i < REFERENCE_LENGTH; i += 1) {
    out += REFERENCE_ALPHABET[bytes[i] % REFERENCE_ALPHABET.length];
  }
  return out;
}

async function generateUniqueReference(db, shopId, attempts = 5) {
  for (let i = 0; i < attempts; i += 1) {
    const reference = randomReference();
    const snap = await appointmentsCol(db, shopId).where('reference', '==', reference).limit(1).get();
    if (snap.empty) return reference;
  }
  fail(CODES.INTERNAL, 'could not allocate a booking reference');
  return '';
}

async function findShopIdByJoinCode(db, code) {
  const snap = await db.collection('shops').where('joinCode', '==', code).limit(1).get();
  if (snap.empty) fail(CODES.INVALID_JOIN_CODE, 'join code does not match any shop');
  return snap.docs[0].id;
}

function appointmentStatusFor(settings) {
  return settings.autoConfirm === true ? 'confirmed' : 'requested';
}

function paymentDataFor({ method, amount, collectedAmount, appointment }) {
  return {
    appointmentId: appointment ? appointment.id : '',
    customerName: appointment ? appointment.customerName : '',
    customerPhone: appointment ? appointment.customerPhone : '',
    chairId: appointment ? appointment.chairId || null : null,
    employeeId: appointment ? appointment.employeeId || null : null,
    amount,
    materialCost: 0,
    method,
    notes: '',
  };
}

module.exports = {
  shopRef,
  appointmentsCol,
  servicesCol,
  employeesCol,
  chairsCol,
  discountsCol,
  membersCol,
  paymentsCol,
  bookingRequestsCol,
  locksCol,
  randomReference,
  generateUniqueReference,
  findShopIdByJoinCode,
  appointmentStatusFor,
  paymentDataFor,
};
