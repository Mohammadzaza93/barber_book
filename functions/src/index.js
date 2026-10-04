'use strict';

const crypto = require('crypto');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const { onCall, HttpsError } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');

const { CODES, AppError, fail } = require('./lib/errors');
const { logEvent, logError } = require('./lib/logger');
const { readSettings } = require('./lib/settings');
const { shopOffsetMinutes, fitsWorkingHours, hasWorkingDay, minutesBetween } = require('./lib/time');
const { computePricing, computeTotalDuration, derivePaymentStatus, round2 } = require('./lib/pricing');
const {
  appointmentBlocks,
  toDate,
  buildLockPlan,
  isLockActive,
  lockDocRefData,
  releasePlan,
} = require('./lib/conflict');
const {
  loadAccess,
  requireMember,
  requireOperations,
  resolveRole,
  isMember,
  canManageOperations,
} = require('./lib/access');
const {
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
  generateUniqueReference,
  findShopIdByJoinCode,
  appointmentStatusFor,
} = require('./lib/repository');
const v = require('./lib/validate');

const MAX_OCCURRENCES = v.MAX_OCCURRENCES;
const MAX_DURATION_MINUTES = 480;
const SERIES_INTERVAL_MS = 7 * 86400000;
const CLOSED_STATUSES = new Set(['cancelled', 'noShow']);

setGlobalOptions({ region: 'us-central1', maxInstances: 10 });

initializeApp();
const db = getFirestore();

const GRPC_BY_CODE = {
  [CODES.UNAUTHENTICATED]: 'unauthenticated',
  [CODES.INVALID_JOIN_CODE]: 'not-found',
  [CODES.SHOP_NOT_FOUND]: 'not-found',
  [CODES.APPOINTMENT_NOT_FOUND]: 'not-found',
  [CODES.PAYMENT_NOT_FOUND]: 'not-found',
  [CODES.SERVICE_NOT_FOUND]: 'not-found',
  [CODES.EMPLOYEE_NOT_FOUND]: 'not-found',
  [CODES.CHAIR_NOT_FOUND]: 'not-found',
  [CODES.INVALID_COUPON]: 'not-found',
  [CODES.ALREADY_MEMBER]: 'already-exists',
  [CODES.APPOINTMENT_CONFLICT]: 'aborted',
  [CODES.PERMISSION_DENIED]: 'permission-denied',
  [CODES.NOT_A_MEMBER]: 'permission-denied',
  [CODES.INVALID_INPUT]: 'invalid-argument',
  [CODES.INVALID_RATING]: 'invalid-argument',
  [CODES.INVALID_PAYMENT_METHOD]: 'invalid-argument',
  [CODES.INVALID_TRANSITION]: 'invalid-argument',
  [CODES.OUTSIDE_WORKING_HOURS]: 'failed-precondition',
  [CODES.OUT_OF_RANGE]: 'failed-precondition',
  [CODES.OUT_OF_HOURS_NOT_ALLOWED]: 'failed-precondition',
  [CODES.APPOINTMENT_IN_PAST]: 'failed-precondition',
  [CODES.SERVICE_INACTIVE]: 'failed-precondition',
  [CODES.EMPLOYEE_INACTIVE]: 'failed-precondition',
  [CODES.CHAIR_INACTIVE]: 'failed-precondition',
  [CODES.SERVICE_MISMATCH]: 'failed-precondition',
  [CODES.INVALID_PRICING]: 'failed-precondition',
  [CODES.COUPON_EXPIRED]: 'failed-precondition',
  [CODES.COUPON_EXHAUSTED]: 'failed-precondition',
  [CODES.COUPON_NOT_APPLICABLE]: 'failed-precondition',
  [CODES.INTERNAL]: 'internal',
};

function wrap(name, handler) {
  return onCall(async (request) => {
    if (!request.auth || !request.auth.uid) {
      throw new HttpsError('unauthenticated', CODES.UNAUTHENTICATED);
    }
    try {
      return await handler(request);
    } catch (error) {
      if (error instanceof AppError) {
        logEvent(logger, `${name}.denied`, { code: error.code, uid: request.auth.uid, reason: error.message });
        throw new HttpsError(GRPC_BY_CODE[error.code] || 'internal', error.code, error.message);
      }
      if (error && error.code === 6) {
        logEvent(logger, `${name}.conflict`, { uid: request.auth.uid });
        throw new HttpsError('aborted', CODES.APPOINTMENT_CONFLICT);
      }
      logError(logger, `${name}.error`, error);
      throw new HttpsError('internal', CODES.INTERNAL);
    }
  });
}

function toIso(value) {
  const date = toDate(value);
  return date ? date.toISOString() : null;
}

function serializeAppointment(id, data) {
  return {
    id,
    shopId: data.shopId || '',
    reference: data.reference || '',
    customerId: data.customerId || null,
    customerName: data.customerName || '',
    customerPhone: data.customerPhone || '',
    customerEmail: data.customerEmail || '',
    employeeId: data.employeeId || '',
    chairId: data.chairId || null,
    serviceIds: Array.isArray(data.serviceIds) ? data.serviceIds : [],
    startTime: toIso(data.startTime),
    endTime: toIso(data.endTime),
    status: data.status || 'requested',
    paymentStatus: data.paymentStatus || 'unpaid',
    totalAmount: Number(data.totalAmount || 0),
    depositAmount: Number(data.depositAmount || 0),
    discountCode: data.discountCode || null,
    discountAmount: Number(data.discountAmount || 0),
    notes: data.notes || '',
    recurring: data.recurring === true,
    seriesId: data.seriesId || null,
    outOfHours: data.outOfHours === true,
    createdById: data.createdById || null,
    createdAt: toIso(data.createdAt),
    reminderSent: data.reminderSent === true,
    rating: typeof data.rating === 'number' ? data.rating : null,
    collectedAmount: Number(data.collectedAmount || 0),
    lateCancellation: data.lateCancellation === true,
  };
}

async function loadDiscountInTransaction(tx, shopId, code) {
  const candidates = Array.from(new Set([code, code.toUpperCase(), code.toLowerCase()]));
  for (const candidate of candidates) {
    const snap = await tx.get(discountsCol(db, shopId).where('code', '==', candidate).limit(1));
    if (!snap.empty) return { id: snap.docs[0].id, data: snap.docs[0].data() || {} };
  }
  return null;
}

function assertCouponUsable(discount, { serviceIds, subtotal, now }) {
  if (!discount) fail(CODES.INVALID_COUPON, 'coupon code not found');
  if (discount.active === false) fail(CODES.INVALID_COUPON, 'coupon is inactive');
  const usageLimit = Number(discount.usageLimit || 0);
  const usageCount = Number(discount.usageCount || 0);
  if (usageLimit > 0 && usageCount >= usageLimit) {
    fail(CODES.COUPON_EXHAUSTED, 'coupon reached its usage limit');
  }
  const validFrom = toDate(discount.validFrom);
  const validTo = toDate(discount.validTo);
  if (validFrom && now < validFrom) fail(CODES.COUPON_EXPIRED, 'coupon is not active yet');
  if (validTo && now > validTo) fail(CODES.COUPON_EXPIRED, 'coupon expired');
  const minValue = Number(discount.minValue || 0);
  if (minValue > 0 && subtotal < minValue) {
    fail(CODES.COUPON_NOT_APPLICABLE, 'order total is below the coupon minimum');
  }
  const scoped = Array.isArray(discount.serviceIds) ? discount.serviceIds.filter((id) => id) : [];
  if (scoped.length > 0 && !scoped.some((id) => serviceIds.includes(id))) {
    fail(CODES.COUPON_NOT_APPLICABLE, 'coupon does not apply to the selected services');
  }
}

async function existingByRequestId(shopId, requestId, uid) {
  if (!requestId) return null;
  const snap = await appointmentsCol(db, shopId)
    .where('requestId', '==', requestId)
    .where('createdById', '==', uid)
    .limit(MAX_OCCURRENCES)
    .get();
  if (snap.empty) return null;
  return snap.docs.map((docSnap) => serializeAppointment(docSnap.id, docSnap.data() || {}));
}

exports.joinShopByCode = wrap('joinShopByCode', async (request) => {
  const data = v.requireObject(request.data);
  const code = v.parseJoinCode(data.code);
  const uid = request.auth.uid;
  const shopId = await findShopIdByJoinCode(db, code);
  const access = await loadAccess(db, shopId, uid);
  if (access.shopData.ownerId === uid) fail(CODES.ALREADY_MEMBER, 'owner cannot join through a code');
  if (isMember(access.role)) fail(CODES.ALREADY_MEMBER, 'user is already a member of this shop');
  const memberRef = membersCol(db, shopId).doc(uid);
  const userRef = db.collection('users').doc(uid);
  await db.runTransaction(async (tx) => {
    const memberSnap = await tx.get(memberRef);
    if (memberSnap.exists) fail(CODES.ALREADY_MEMBER, 'user is already a member of this shop');
    const userSnap = await tx.get(userRef);
    const profile = userSnap.exists ? userSnap.data() || {} : {};
    tx.set(memberRef, {
      uid,
      email: profile.email || '',
      name: profile.displayName || '',
      role: 'staff',
      createdAt: FieldValue.serverTimestamp(),
      joinedVia: 'joinCode',
    });
    tx.set(userRef, { joinedShopId: shopId, updatedAt: FieldValue.serverTimestamp() }, { merge: true });
  });
  logEvent(logger, 'joinShopByCode.ok', { shopId, uid, role: 'staff' });
  return { shopId, role: 'staff' };
});

exports.createAppointment = wrap('createAppointment', async (request) => {
  const data = v.requireObject(request.data);
  const uid = request.auth.uid;
  const shopId = v.requireId(data.shopId, 'shopId');
  const employeeId = v.requireId(data.employeeId, 'employeeId');
  const chairId = v.optionalId(data.chairId, 'chairId');
  const serviceIds = v.parseServiceIds(data.serviceIds);
  const startTimes = v.parseStartTimes(data.startTimes);
  const recurring = v.optionalBoolean(data.recurring, 'recurring');
  const outOfHours = v.optionalBoolean(data.outOfHours, 'outOfHours');
  const discountCode = v.parseDiscountCode(data.discountCode);
  const requestId =
    v.optionalString(data.requestId, 'requestId', { max: 64, pattern: v.SAFE_ID }) ||
    crypto.randomUUID();
  const customerName = v.optionalString(data.customerName, 'customerName', { max: 80, allowEmpty: false });
  const customerPhone = v.optionalPhone(data.customerPhone, 'customerPhone');
  const customerEmail = v.optionalEmail(data.customerEmail, 'customerEmail');
  const notes = v.optionalString(data.notes, 'notes', { max: 500 });

  if (startTimes.length !== 1) {
    fail(CODES.INVALID_INPUT, 'a single startTime is required; recurring series are expanded by the server');
  }

  const access = requireMember(await loadAccess(db, shopId, uid));
  const duplicate = await existingByRequestId(shopId, requestId, uid);
  if (duplicate) {
    return { appointments: duplicate, duplicated: true, pricing: null, reference: duplicate[0].reference };
  }

  const claimRef = bookingRequestsCol(db, shopId).doc(`${uid}_${requestId}`);
  const settings = readSettings(access.shopData);
  const offsetMinutes = shopOffsetMinutes(access.shopData);
  const status = appointmentStatusFor(settings);
  const now = new Date();
  const firstStart = startTimes[0];
  const occurrences = recurring
    ? Array.from({ length: MAX_OCCURRENCES }, (_, i) => new Date(firstStart.getTime() + i * SERIES_INTERVAL_MS))
    : [firstStart];

  const maxAdvanceMinutes = Number(settings.maxAdvanceDays || 0) * 1440;
  for (const start of occurrences) {
    const delta = minutesBetween(start, now);
    if (delta <= 0) fail(CODES.APPOINTMENT_IN_PAST, 'booking time must be in the future');
    if (maxAdvanceMinutes > 0 && delta > maxAdvanceMinutes) {
      fail(CODES.OUT_OF_RANGE, 'booking time exceeds the allowed advance window');
    }
  }

  const reference = await generateUniqueReference(db, shopId);
  const seriesId = recurring ? crypto.randomUUID() : null;

  const prepared = await db.runTransaction(async (tx) => {
    const claimSnap = await tx.get(claimRef);
    if (claimSnap.exists) {
      const claim = claimSnap.data() || {};
      const ids = Array.isArray(claim.appointmentIds) ? claim.appointmentIds : [];
      const snaps = await tx.getAll(...ids.map((id) => appointmentsCol(db, shopId).doc(id)));
      const replay = snaps
        .filter((docSnap) => docSnap.exists)
        .map((docSnap) => serializeAppointment(docSnap.id, docSnap.data() || {}));
      if (replay.length > 0) return { pricing: null, created: replay.map((item) => ({ replay: item })) };
    }

    const shopSnap = await tx.get(shopRef(db, shopId));
    if (!shopSnap.exists) fail(CODES.SHOP_NOT_FOUND, 'shop does not exist');
    const memberSnap = await tx.get(membersCol(db, shopId).doc(uid));
    const role = resolveRole({
      uid,
      shopData: shopSnap.data() || {},
      memberData: memberSnap.exists ? memberSnap.data() : null,
    });
    if (!isMember(role)) fail(CODES.NOT_A_MEMBER, 'user is not a member of this shop');

    const serviceSnaps = await tx.getAll(...serviceIds.map((id) => servicesCol(db, shopId).doc(id)));
    const services = [];
    for (let i = 0; i < serviceSnaps.length; i += 1) {
      if (!serviceSnaps[i].exists) fail(CODES.SERVICE_NOT_FOUND, 'a selected service does not exist');
      const serviceData = serviceSnaps[i].data() || {};
      if (serviceData.active === false) fail(CODES.SERVICE_INACTIVE, 'a selected service is inactive');
      const price = Number(serviceData.price);
      if (!Number.isFinite(price) || price < 0) {
        fail(CODES.INVALID_PRICING, 'a selected service has an invalid price');
      }
      const minutes = Number(serviceData.durationMinutes);
      if (!Number.isFinite(minutes) || minutes <= 0) {
        fail(CODES.INVALID_PRICING, 'a selected service has an invalid duration');
      }
      services.push({ id: serviceIds[i], ...serviceData });
    }

    const employeeSnap = await tx.get(employeesCol(db, shopId).doc(employeeId));
    if (!employeeSnap.exists) fail(CODES.EMPLOYEE_NOT_FOUND, 'employee does not exist');
    const employeeData = employeeSnap.data() || {};
    if (employeeData.active === false) fail(CODES.EMPLOYEE_INACTIVE, 'employee is inactive');
    if (Array.isArray(employeeData.serviceIds) && employeeData.serviceIds.length > 0) {
      const provided = new Set(employeeData.serviceIds);
      const missing = serviceIds.filter((id) => !provided.has(id));
      if (missing.length > 0) {
        fail(CODES.SERVICE_MISMATCH, 'the selected employee does not offer one of these services');
      }
    }

    if (chairId) {
      const chairSnap = await tx.get(chairsCol(db, shopId).doc(chairId));
      if (!chairSnap.exists) fail(CODES.CHAIR_NOT_FOUND, 'the selected chair does not exist');
      if ((chairSnap.data() || {}).active === false) fail(CODES.CHAIR_INACTIVE, 'the selected chair is inactive');
    }

    const durationMinutes = computeTotalDuration(services);
    if (durationMinutes > MAX_DURATION_MINUTES) fail(CODES.OUT_OF_RANGE, 'booking duration is too long');
    const resolved = occurrences.map((start) => ({
      start,
      end: new Date(start.getTime() + durationMinutes * 60000),
    }));

    const employeeHours =
      employeeData.workingHours && Object.keys(employeeData.workingHours).length > 0
        ? employeeData.workingHours
        : settings.workingHours;
    const hasHours = Boolean(employeeHours) && Object.keys(employeeHours).length > 0;
    if (hasHours) {
      const fits = resolved.every((occ) => fitsWorkingHours(employeeHours, occ.start, occ.end, offsetMinutes));
      if (!fits) {
        if (!outOfHours) fail(CODES.OUTSIDE_WORKING_HOURS, 'booking is outside working hours');
        if (!canManageOperations(role)) {
          fail(CODES.OUT_OF_HOURS_NOT_ALLOWED, 'out of hours booking requires a manager');
        }
        if (settings.allowOutOfHours !== true) {
          fail(CODES.OUT_OF_HOURS_NOT_ALLOWED, 'shop does not allow out of hours bookings');
        }
      } else {
        for (const occ of resolved) {
          if (!hasWorkingDay(employeeHours, occ.start, offsetMinutes)) {
            fail(CODES.OUTSIDE_WORKING_HOURS, 'employee does not work on that day');
          }
        }
      }
    }

    const subtotal = round2(services.reduce((sum, s) => sum + Number(s.price || 0), 0));
    let discount = null;
    if (discountCode) {
      discount = await loadDiscountInTransaction(tx, shopId, discountCode);
      assertCouponUsable(discount ? discount.data : null, { serviceIds, subtotal, now });
      const usageLimit = Number(discount.data.usageLimit || 0);
      const usageCount = Number(discount.data.usageCount || 0);
      if (usageLimit > 0 && usageCount + occurrences.length > usageLimit) {
        fail(CODES.COUPON_EXHAUSTED, 'coupon does not have enough usages left for this series');
      }
    }

    const pricing = computePricing({ services, discount: discount ? discount.data : null, settings });

    const plan = buildLockPlan({ occurrences: resolved, employeeId, chairId, now });
    const lockRefs = plan.locks.map((lock) => locksCol(db, shopId).doc(lock.id));
    const lockSnaps = await tx.getAll(...lockRefs);
    for (const snap of lockSnaps) {
      if (snap.exists && isLockActive(snap.data() || {}, now)) {
        fail(CODES.APPOINTMENT_CONFLICT, 'the selected employee or chair is already booked');
      }
    }

    const resources = [
      { field: 'employeeId', value: employeeId },
      ...(chairId ? [{ field: 'chairId', value: chairId }] : []),
    ];
    for (const resource of resources) {
      const conflicting = await tx.get(
        appointmentsCol(db, shopId)
          .where(resource.field, '==', resource.value)
          .where('startTime', '>=', plan.queryStart)
          .where('startTime', '<', plan.queryEnd),
      );
      for (const docSnap of conflicting.docs) {
        const existing = docSnap.data() || {};
        if (existing.requestId === requestId) continue;
        if (resolved.some((occ) => appointmentBlocks(existing, occ.start, occ.end))) {
          fail(CODES.APPOINTMENT_CONFLICT, 'the selected employee or chair is already booked');
        }
      }
    }

    const created = [];
    for (const occ of resolved) {
      const ref = appointmentsCol(db, shopId).doc();
      const payload = {
        shopId,
        reference,
        requestId,
        customerId: v.normalizePhone(customerPhone) || null,
        customerName,
        customerPhone,
        customerEmail,
        employeeId,
        chairId,
        serviceIds,
        startTime: Timestamp.fromDate(occ.start),
        endTime: Timestamp.fromDate(occ.end),
        status,
        paymentStatus: pricing.paymentStatus,
        totalAmount: pricing.totalAmount,
        depositAmount: pricing.depositAmount,
        discountCode: discount ? discountCode : null,
        discountAmount: pricing.discountAmount,
        notes,
        recurring,
        seriesId,
        outOfHours,
        createdById: uid,
        createdAt: Timestamp.fromDate(now),
        reminderSent: false,
        rating: null,
        collectedAmount: 0,
        durationMinutes,
      };
      tx.set(ref, payload);
      created.push({ id: ref.id, payload, occ });
    }

    for (const lock of plan.locks) {
      const occ = resolved[lock.occurrenceIndex];
      tx.set(locksCol(db, shopId).doc(lock.id), {
        resource: lock.resource,
        bucketIndex: lock.bucketIndex,
        expiresAt: Timestamp.fromDate(lock.expiresAt),
        ...lockDocRefData({
          appointmentId: created[lock.occurrenceIndex].id,
          seriesId,
          start: occ.start,
          end: occ.end,
          expiresAt: lock.expiresAt,
          now,
        }),
      });
    }

    if (discount) {
      tx.update(discountsCol(db, shopId).doc(discount.id), {
        usageCount: Number(discount.data.usageCount || 0) + occurrences.length,
      });
    }

    tx.set(claimRef, {
      createdById: uid,
      appointmentIds: created.map((item) => item.id),
      reference,
      seriesId,
      createdAt: Timestamp.fromDate(now),
    });

    return { pricing, created };
  });

  if (prepared.pricing === null) {
    const replay = prepared.created.map((item) => item.replay);
    logEvent(logger, 'createAppointment.duplicate', { shopId, uid, count: replay.length });
    return {
      appointments: replay,
      pricing: null,
      reference: replay[0].reference,
      seriesId: replay[0].seriesId,
      recurring: replay[0].recurring === true,
      duplicated: true,
    };
  }

  const appointments = prepared.created.map((item) => serializeAppointment(item.id, item.payload));
  logEvent(logger, 'createAppointment.ok', {
    shopId,
    uid,
    role: access.role,
    count: appointments.length,
    totalAmount: prepared.pricing.totalAmount,
    recurring,
    hasCoupon: Boolean(discountCode),
  });
  return {
    appointments,
    pricing: prepared.pricing,
    reference,
    seriesId,
    recurring,
    offsetMinutes,
  };
});

async function loadAppointmentForUpdate(tx, shopId, appointmentId) {
  const ref = appointmentsCol(db, shopId).doc(appointmentId);
  const snap = await tx.get(ref);
  if (!snap.exists) fail(CODES.APPOINTMENT_NOT_FOUND, 'appointment does not exist');
  return { ref, data: snap.data() || {} };
}

exports.updateAppointment = wrap('updateAppointment', async (request) => {
  const data = v.requireObject(request.data);
  const uid = request.auth.uid;
  const shopId = v.requireId(data.shopId, 'shopId');
  const action = v.parseAction(data.action);
  const access = await loadAccess(db, shopId, uid);
  if (!isMember(access.role)) fail(CODES.NOT_A_MEMBER, 'user is not a member of this shop');

  if (action === 'payment') {
    requireOperations(access);
    const method = v.parsePaymentMethod(data.method);
    const amount = v.parseAmount(data.amount, 'amount');
    const appointmentId = v.optionalId(data.appointmentId, 'appointmentId');
    if (!appointmentId) {
      const ref = paymentsCol(db, shopId).doc();
      await ref.set({
        appointmentId: '',
        customerName: '',
        customerPhone: '',
        chairId: null,
        employeeId: null,
        amount,
        materialCost: 0,
        method,
        notes: '',
        paidAt: FieldValue.serverTimestamp(),
        recordedById: uid,
      });
      logEvent(logger, 'updateAppointment.payment.manual', { shopId, uid, amount, method });
      return { paymentId: ref.id, appointmentId: null, paymentStatus: null, collectedAmount: amount };
    }
    const result = await db.runTransaction(async (tx) => {
      const { ref, data: appointment } = await loadAppointmentForUpdate(tx, shopId, appointmentId);
      const existing = await tx.get(paymentsCol(db, shopId).where('appointmentId', '==', appointmentId));
      const collected = existing.docs.reduce(
        (sum, docSnap) => sum + Number((docSnap.data() || {}).amount || 0),
        0,
      );
      const nextCollected = round2(collected + amount);
      const paymentStatus = derivePaymentStatus(Number(appointment.totalAmount || 0), nextCollected);
      const paymentRef = paymentsCol(db, shopId).doc();
      tx.set(paymentRef, {
        appointmentId,
        customerName: appointment.customerName || '',
        customerPhone: appointment.customerPhone || '',
        chairId: appointment.chairId || null,
        employeeId: appointment.employeeId || null,
        amount,
        materialCost: 0,
        method,
        notes: '',
        paidAt: FieldValue.serverTimestamp(),
        recordedById: uid,
      });
      tx.update(ref, { paymentStatus, collectedAmount: nextCollected });
      return { paymentId: paymentRef.id, paymentStatus, collectedAmount: nextCollected };
    });
    logEvent(logger, 'updateAppointment.payment.ok', { shopId, uid, appointmentId, amount, method });
    return { ...result, appointmentId };
  }

  if (action === 'delete_payment') {
    requireOperations(access);
    const paymentId = v.requireId(data.paymentId, 'paymentId');
    const result = await db.runTransaction(async (tx) => {
      const paymentRef = paymentsCol(db, shopId).doc(paymentId);
      const paymentSnap = await tx.get(paymentRef);
      if (!paymentSnap.exists) fail(CODES.PAYMENT_NOT_FOUND, 'payment does not exist');
      const payment = paymentSnap.data() || {};
      const appointmentId = String(payment.appointmentId || '');
      if (!appointmentId) {
        tx.delete(paymentRef);
        return { paymentId, appointmentId: null, paymentStatus: null, collectedAmount: null };
      }
      const { ref, data: appointment } = await loadAppointmentForUpdate(tx, shopId, appointmentId);
      const existing = await tx.get(paymentsCol(db, shopId).where('appointmentId', '==', appointmentId));
      const collected = round2(
        existing.docs
          .filter((docSnap) => docSnap.id !== paymentId)
          .reduce((sum, docSnap) => sum + Number((docSnap.data() || {}).amount || 0), 0),
      );
      const paymentStatus = derivePaymentStatus(Number(appointment.totalAmount || 0), collected);
      tx.delete(paymentRef);
      tx.update(ref, { paymentStatus, collectedAmount: collected });
      return { paymentId, appointmentId, paymentStatus, collectedAmount: collected };
    });
    logEvent(logger, 'updateAppointment.payment.deleted', { shopId, uid, ...result });
    return result;
  }

  const appointmentId = v.requireId(data.appointmentId, 'appointmentId');

  if (action === 'contact') {
    const patch = {};
    if (data.customerName !== undefined) {
      patch.customerName = v.optionalString(data.customerName, 'customerName', { max: 80, allowEmpty: false });
    }
    if (data.customerPhone !== undefined) {
      patch.customerPhone = v.optionalPhone(data.customerPhone, 'customerPhone');
    }
    if (data.customerEmail !== undefined) {
      patch.customerEmail = v.optionalEmail(data.customerEmail, 'customerEmail');
    }
    if (data.notes !== undefined) {
      patch.notes = v.optionalString(data.notes, 'notes', { max: 500 });
    }
    if (Object.keys(patch).length === 0) fail(CODES.INVALID_INPUT, 'no contact fields to update');
    await db.runTransaction(async (tx) => {
      const { ref, data: appointment } = await loadAppointmentForUpdate(tx, shopId, appointmentId);
      if (access.role === 'staff' && appointment.createdById !== uid) {
        fail(CODES.PERMISSION_DENIED, 'staff can only edit appointments they created');
      }
      tx.update(ref, patch);
    });
    logEvent(logger, 'updateAppointment.contact.ok', { shopId, uid, appointmentId });
    return { appointmentId, updated: Object.keys(patch) };
  }

  if (action === 'rating') {
    const rating = v.parseRating(data.rating);
    const result = await db.runTransaction(async (tx) => {
      const { ref, data: appointment } = await loadAppointmentForUpdate(tx, shopId, appointmentId);
      if (!canManageOperations(access.role) && appointment.createdById !== uid) {
        fail(CODES.PERMISSION_DENIED, 'not allowed');
      }
      if (appointment.status !== 'completed') {
        fail(CODES.INVALID_TRANSITION, 'only completed appointments can be rated');
      }
      tx.update(ref, { rating });
      return rating;
    });
    logEvent(logger, 'updateAppointment.rating.ok', { shopId, uid, appointmentId, rating: result });
    return { appointmentId, rating: result };
  }

  if (action === 'reminder') {
    await db.runTransaction(async (tx) => {
      const { ref, data: appointment } = await loadAppointmentForUpdate(tx, shopId, appointmentId);
      if (!canManageOperations(access.role) && appointment.createdById !== uid) {
        fail(CODES.PERMISSION_DENIED, 'not allowed');
      }
      tx.update(ref, { reminderSent: true, reminderSentAt: FieldValue.serverTimestamp() });
    });
    logEvent(logger, 'updateAppointment.reminder.ok', { shopId, uid, appointmentId });
    return { appointmentId, reminderSent: true };
  }

  requireOperations(access);
  const status = v.parseStatus(data.status);
  const cancelFreeHours = Number(readSettings(access.shopData).cancelFreeHours || 0);
  const result = await db.runTransaction(async (tx) => {
    const { ref, data: appointment } = await loadAppointmentForUpdate(tx, shopId, appointmentId);
    if (appointment.status === status) return { status, releasedLocks: 0, unchanged: true };
    if (CLOSED_STATUSES.has(appointment.status) || appointment.status === 'completed') {
      fail(CODES.INVALID_TRANSITION, 'appointment is already closed');
    }
    const patch = { status };
    let releasedLocks = 0;
    let lateCancellation = false;
    if (CLOSED_STATUSES.has(status)) {
      const start = toDate(appointment.startTime);
      lateCancellation = Boolean(start) && start.getTime() - Date.now() < cancelFreeHours * 3600000;
      patch.lateCancellation = lateCancellation;
      patch.closedAt = FieldValue.serverTimestamp();
      patch.closedById = uid;
      for (const lock of releasePlan(appointment)) {
        tx.delete(locksCol(db, shopId).doc(lock.id));
        releasedLocks += 1;
      }
    }
    tx.update(ref, patch);
    return { status, releasedLocks, lateCancellation };
  });
  logEvent(logger, 'updateAppointment.status.ok', { shopId, uid, appointmentId, status: result.status });
  return { appointmentId, ...result };
});

exports.deleteAppointment = wrap('deleteAppointment', async (request) => {
  const data = v.requireObject(request.data);
  const uid = request.auth.uid;
  const shopId = v.requireId(data.shopId, 'shopId');
  const appointmentId = v.requireId(data.appointmentId, 'appointmentId');
  const access = requireOperations(requireMember(await loadAccess(db, shopId, uid)));
  const result = await db.runTransaction(async (tx) => {
    const { ref, data: appointment } = await loadAppointmentForUpdate(tx, shopId, appointmentId);
    const locks = releasePlan(appointment);
    for (const lock of locks) {
      tx.delete(locksCol(db, shopId).doc(lock.id));
    }
    tx.delete(ref);
    return { releasedLocks: locks.length };
  });
  logEvent(logger, 'deleteAppointment.ok', { shopId, uid, role: access.role, appointmentId });
  return { appointmentId, deleted: true, ...result };
});
