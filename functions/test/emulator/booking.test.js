'use strict';

const assert = require('assert');
const { UIDS, SHOP, OTHER_SHOP, JOIN_CODE } = require('./helper');
const { db, booking, call, codeOf, seed, clearAll, appointmentCount, slotAt } = require('./support');

describe('joinShopByCode', () => {
  beforeEach(async () => {
    await clearAll();
    await seed();
  });

  it('creates a staff membership and binds the user profile', async () => {
    const result = await call('joinShopByCode', UIDS.stranger, { code: JOIN_CODE });
    assert.strictEqual(result.shopId, SHOP);
    assert.strictEqual(result.role, 'staff');

    const member = await db.doc(`shops/${SHOP}/members/${UIDS.stranger}`).get();
    assert.ok(member.exists);
    assert.strictEqual(member.data().role, 'staff');
    assert.strictEqual(member.data().uid, UIDS.stranger);

    const profile = await db.doc(`users/${UIDS.stranger}`).get();
    assert.strictEqual(profile.data().joinedShopId, SHOP);
  });

  it('accepts a lower case code', async () => {
    const result = await call('joinShopByCode', UIDS.stranger, { code: ' abc234 ' });
    assert.strictEqual(result.shopId, SHOP);
  });

  it('rejects an unknown code', async () => {
    assert.strictEqual(await codeOf('joinShopByCode', UIDS.stranger, { code: 'ZZZZZZ' }), 'invalid-join-code');
  });

  it('rejects an existing member', async () => {
    assert.strictEqual(await codeOf('joinShopByCode', UIDS.staff, { code: JOIN_CODE }), 'already-member');
  });

  it('rejects the owner joining through a code', async () => {
    assert.strictEqual(await codeOf('joinShopByCode', UIDS.owner, { code: JOIN_CODE }), 'already-member');
  });

  it('rejects an anonymous caller', async () => {
    assert.strictEqual(await codeOf('joinShopByCode', null, { code: JOIN_CODE }), 'unauthenticated');
  });
});

describe('createAppointment', () => {
  beforeEach(async () => {
    await clearAll();
    await seed();
  });

  it('prices the booking from the server catalog', async () => {
    const result = await call('createAppointment', UIDS.staff, booking());
    assert.strictEqual(result.appointments.length, 1);
    assert.strictEqual(result.pricing.totalAmount, 50);
    assert.strictEqual(result.pricing.discountAmount, 0);
    assert.strictEqual(result.pricing.depositAmount, 0);
    assert.strictEqual(result.pricing.paymentStatus, 'unpaid');
    assert.match(result.reference, /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/);
  });

  it('ignores pricing and payment fields sent by the client', async () => {
    const result = await call(
      'createAppointment',
      UIDS.staff,
      booking({
        totalAmount: 0,
        depositAmount: 0,
        discountAmount: 999,
        paymentStatus: 'paid',
        createdById: UIDS.manager,
        status: 'completed',
        endTime: '2030-01-01T00:00:00Z',
      }),
    );
    const created = result.appointments[0];
    assert.strictEqual(created.totalAmount, 50);
    assert.strictEqual(created.paymentStatus, 'unpaid');
    assert.strictEqual(created.discountAmount, 0);
    assert.strictEqual(created.status, 'requested');
    assert.strictEqual(created.createdById, UIDS.staff);

    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(stored.data().paymentStatus, 'unpaid');
    assert.strictEqual(stored.data().totalAmount, 50);
  });

  it('derives the duration from the service catalog', async () => {
    const result = await call(
      'createAppointment',
      UIDS.staff,
      booking({ serviceIds: ['service-cut', 'service-shave'], startTimes: [slotAt(4).toISOString()] }),
    );
    const created = result.appointments[0];
    const start = new Date(created.startTime).getTime();
    const end = new Date(created.endTime).getTime();
    assert.strictEqual(end - start, 60 * 60000);
    assert.strictEqual(result.pricing.totalAmount, 80);
  });

  it('applies the server deposit policy', async () => {
    await db.doc(`shops/${SHOP}`).update({ depositsEnabled: true, depositPercent: 20, depositHighDemandOnly: true });
    const start = new Date();
    start.setUTCDate(start.getUTCDate() + 5);
    start.setUTCHours(7, 0, 0, 0);
    const result = await call('createAppointment', UIDS.staff, booking({ serviceIds: ['service-shave'], startTimes: [start.toISOString()] }));
    assert.strictEqual(result.pricing.depositAmount, 15);
    assert.strictEqual(result.pricing.paymentStatus, 'depositPaid');
  });

  it('rejects a second booking for the same employee and slot', async () => {
    await call('createAppointment', UIDS.staff, booking());
    assert.strictEqual(await codeOf('createAppointment', UIDS.otherStaff, booking()), 'appointment-conflict');
  });

  it('allows two different employees at the same time', async () => {
    await call('createAppointment', UIDS.staff, booking());
    const result = await call('createAppointment', UIDS.staff, booking({ employeeId: 'employee-2', chairId: null }));
    assert.strictEqual(result.appointments.length, 1);
  });

  it('rejects a different employee who shares the chair', async () => {
    await call('createAppointment', UIDS.staff, booking());
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ employeeId: 'employee-2' })),
      'appointment-conflict',
    );
  });

  it('allows back to back bookings', async () => {
    await call('createAppointment', UIDS.staff, booking());
    const start = new Date();
    start.setUTCDate(start.getUTCDate() + 3);
    start.setUTCHours(7, 30, 0, 0);
    const result = await call('createAppointment', UIDS.staff, booking({ startTimes: [start.toISOString()] }));
    assert.strictEqual(result.appointments.length, 1);
  });

  it('allows the slot again once the previous booking is cancelled', async () => {
    const created = await call('createAppointment', UIDS.staff, booking());
    await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.appointments[0].id,
      action: 'status',
      status: 'cancelled',
    });
    const again = await call('createAppointment', UIDS.otherStaff, booking());
    assert.strictEqual(again.appointments.length, 1);
  });

  it('lets exactly one of two concurrent bookings win the slot', async () => {
    const results = await Promise.allSettled([
      call('createAppointment', UIDS.staff, booking()),
      call('createAppointment', UIDS.otherStaff, booking()),
    ]);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    const rejected = results.filter((r) => r.status === 'rejected');
    assert.strictEqual(fulfilled.length, 1, 'exactly one booking must succeed');
    assert.strictEqual(rejected.length, 1, 'exactly one booking must fail');
    assert.strictEqual(rejected[0].reason.message, 'appointment-conflict');
    assert.strictEqual(await appointmentCount(), 1);
  });

  it('expands a recurring series into four weekly appointments', async () => {
    const result = await call('createAppointment', UIDS.staff, booking({ recurring: true }));
    assert.strictEqual(result.appointments.length, 4);
    assert.notStrictEqual(result.seriesId, null);
    const references = new Set(result.appointments.map((a) => a.reference));
    assert.strictEqual(references.size, 1);
    const starts = result.appointments.map((a) => new Date(a.startTime).getTime());
    for (let i = 1; i < starts.length; i += 1) {
      assert.strictEqual(starts[i] - starts[i - 1], 7 * 86400000);
    }
    assert.strictEqual(await appointmentCount(), 4);
  });

  it('treats a repeated requestId as the same booking', async () => {
    const requestId = 'retry-0001';
    const first = await call('createAppointment', UIDS.staff, booking({ requestId }));
    const second = await call('createAppointment', UIDS.staff, booking({ requestId }));
    assert.strictEqual(second.duplicated, true);
    assert.deepStrictEqual(
      second.appointments.map((a) => a.id).sort(),
      first.appointments.map((a) => a.id).sort(),
    );
    assert.strictEqual(await appointmentCount(), 1);
  });

  it('keeps a concurrent retry idempotent instead of failing as a conflict', async () => {
    const requestId = 'retry-race-1';
    const results = await Promise.allSettled([
      call('createAppointment', UIDS.staff, booking({ requestId })),
      call('createAppointment', UIDS.staff, booking({ requestId })),
    ]);
    const fulfilled = results.filter((r) => r.status === 'fulfilled');
    assert.strictEqual(fulfilled.length, 2, 'both retries must resolve');
    const ids = fulfilled.map((r) => r.value.appointments.map((a) => a.id).sort().join(','));
    assert.strictEqual(ids[0], ids[1], 'both retries must return the same booking');
    assert.strictEqual(await appointmentCount(), 1);
  });

  it('does not let another member replay someone else requestId', async () => {
    const requestId = 'retry-owned-1';
    await call('createAppointment', UIDS.staff, booking({ requestId }));
    const stolen = await call('createAppointment', UIDS.otherStaff, booking({ requestId, employeeId: 'employee-2', chairId: null }));
    assert.strictEqual(stolen.duplicated, undefined);
    assert.strictEqual(stolen.appointments[0].createdById, UIDS.otherStaff);
    assert.strictEqual(await appointmentCount(), 2);
  });

  it('writes an idempotency claim that clients cannot touch', async () => {
    const requestId = 'retry-claim-1';
    await call('createAppointment', UIDS.staff, booking({ requestId }));
    const claim = await db.doc(`shops/${SHOP}/bookingRequests/${UIDS.staff}_${requestId}`).get();
    assert.ok(claim.exists);
    assert.strictEqual(claim.data().createdById, UIDS.staff);
    assert.strictEqual(claim.data().appointmentIds.length, 1);
  });

  it('rejects a booking in the past', async () => {
    const past = new Date(Date.now() - 3600000).toISOString();
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ startTimes: [past] })), 'appointment-in-past');
  });

  it('rejects a booking beyond the advance window', async () => {
    const far = new Date();
    far.setUTCDate(far.getUTCDate() + 90);
    far.setUTCHours(7, 0, 0, 0);
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ startTimes: [far.toISOString()] })), 'out-of-range');
  });

  it('rejects a booking outside working hours', async () => {
    const early = new Date();
    early.setUTCDate(early.getUTCDate() + 3);
    early.setUTCHours(2, 0, 0, 0);
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ startTimes: [early.toISOString()] })), 'outside-working-hours');
  });

  it('lets a manager book outside working hours when the shop allows it', async () => {
    const early = new Date();
    early.setUTCDate(early.getUTCDate() + 3);
    early.setUTCHours(2, 0, 0, 0);
    const result = await call('createAppointment', UIDS.manager, booking({ startTimes: [early.toISOString()], outOfHours: true }));
    assert.strictEqual(result.appointments[0].outOfHours, true);
  });

  it('stops a staff member from booking outside working hours', async () => {
    const early = new Date();
    early.setUTCDate(early.getUTCDate() + 3);
    early.setUTCHours(2, 0, 0, 0);
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ startTimes: [early.toISOString()], outOfHours: true })),
      'out-of-hours-not-allowed',
    );
  });

  it('rejects an unknown service, an inactive service and a bad employee', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ serviceIds: ['service-missing'] })),
      'service-not-found',
    );
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ serviceIds: ['service-old'] })),
      'service-inactive',
    );
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ employeeId: 'employee-missing' })),
      'employee-not-found',
    );
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ employeeId: 'employee-off' })),
      'employee-inactive',
    );
  });

  it('rejects an employee who does not offer the selected service', async () => {
    const code = await codeOf(
      'createAppointment',
      UIDS.staff,
      booking({ employeeId: 'employee-2', chairId: null, serviceIds: ['service-shave'] }),
    );
    assert.strictEqual(code, 'service-mismatch');
  });

  it('rejects an unknown or inactive chair', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ chairId: 'chair-missing' })),
      'chair-not-found',
    );
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ chairId: 'chair-off' })),
      'chair-inactive',
    );
  });

  it('rejects a service with a broken price or duration', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ serviceIds: ['service-bad'] })),
      'invalid-pricing',
    );
  });

  it('returns a createdAt that matches what was stored', async () => {
    const result = await call('createAppointment', UIDS.staff, booking());
    const created = result.appointments[0];
    assert.ok(created.createdAt, 'createdAt must be returned to the client');
    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(new Date(created.createdAt).toISOString(), stored.data().createdAt.toDate().toISOString());
  });

  it('rejects a caller who is not a member of the shop', async () => {
    assert.strictEqual(await codeOf('createAppointment', UIDS.stranger, booking()), 'not-a-member');
  });

  it('rejects a member of another shop', async () => {
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ shopId: OTHER_SHOP })), 'not-a-member');
  });

  it('rejects malformed input', async () => {
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ shopId: '../etc' })), 'invalid-input');
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ serviceIds: [] })), 'invalid-input');
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ customerName: '' })), 'invalid-input');
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ customerEmail: 'bad' })), 'invalid-input');
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ startTimes: ['nope'] })), 'invalid-input');
    assert.strictEqual(await codeOf('createAppointment', UIDS.staff, booking({ startTimes: [] })), 'invalid-input');
  });

  it('requires an authenticated caller', async () => {
    assert.strictEqual(await codeOf('createAppointment', null, booking()), 'unauthenticated');
  });
});

describe('coupon handling', () => {
  beforeEach(async () => {
    await clearAll();
    await seed();
  });

  it('applies a percent coupon and counts the redemption', async () => {
    const result = await call('createAppointment', UIDS.staff, booking({ discountCode: 'SAVE10' }));
    assert.strictEqual(result.pricing.discountAmount, 5);
    assert.strictEqual(result.pricing.totalAmount, 45);
    assert.strictEqual(result.appointments[0].discountCode, 'SAVE10');

    const discount = await db.doc(`shops/${SHOP}/discounts/discount-percent`).get();
    assert.strictEqual(discount.data().usageCount, 1);
  });

  it('counts one redemption per recurring occurrence', async () => {
    await call('createAppointment', UIDS.staff, booking({ discountCode: 'SAVE10', recurring: true }));
    const discount = await db.doc(`shops/${SHOP}/discounts/discount-percent`).get();
    assert.strictEqual(discount.data().usageCount, 4);
  });

  it('does not count a redemption for a rejected booking', async () => {
    await codeOf('createAppointment', UIDS.staff, booking({ discountCode: 'SAVE10' }));
    await codeOf('createAppointment', UIDS.staff, booking({ discountCode: 'SAVE10' }));
    const discount = await db.doc(`shops/${SHOP}/discounts/discount-percent`).get();
    assert.strictEqual(discount.data().usageCount, 1);
  });

  it('rejects an expired coupon', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ discountCode: 'OLDONE' })),
      'coupon-expired',
    );
  });

  it('rejects a coupon that reached its usage limit', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ discountCode: 'GONE' })),
      'coupon-exhausted',
    );
  });

  it('rejects a coupon below its minimum spend', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ discountCode: 'BIGSPEND' })),
      'coupon-not-applicable',
    );
  });

  it('rejects a coupon scoped to other services', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ discountCode: 'CUTONLY', serviceIds: ['service-shave'] })),
      'coupon-not-applicable',
    );
  });

  it('rejects an unknown coupon code', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ discountCode: 'NOSUCH' })),
      'invalid-coupon',
    );
  });

  it('rejects a series that would exceed the coupon limit', async () => {
    assert.strictEqual(
      await codeOf('createAppointment', UIDS.staff, booking({ discountCode: 'GONE', recurring: true })),
      'coupon-exhausted',
    );
  });
});
