'use strict';

const assert = require('assert');
const { UIDS, SHOP, OTHER_SHOP } = require('./helper');
const { db, booking, call, codeOf, seed, clearAll, lockCount, Timestamp } = require('./support');

describe('updateAppointment', () => {
  let created;

  beforeEach(async () => {
    await clearAll();
    await seed();
    created = (await call('createAppointment', UIDS.staff, booking())).appointments[0];
  });

  it('lets a manager change the status', async () => {
    const result = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'confirmed',
    });
    assert.strictEqual(result.status, 'confirmed');
    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(stored.data().status, 'confirmed');
  });

  it('stops a staff member from changing the status', async () => {
    const code = await codeOf('updateAppointment', UIDS.staff, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'confirmed',
    });
    assert.strictEqual(code, 'permission-denied');
  });

  it('marks a late cancellation when the free window has passed', async () => {
    await db.doc(`shops/${SHOP}`).update({ cancelFreeHours: 24 * 30 });
    const result = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'cancelled',
    });
    assert.strictEqual(result.lateCancellation, true);
    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(stored.data().lateCancellation, true);
  });

  it('refuses to reopen a closed appointment', async () => {
    await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'cancelled',
    });
    const code = await codeOf('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'confirmed',
    });
    assert.strictEqual(code, 'invalid-transition');
  });

  it('rejects an unknown status and an unknown action', async () => {
    assert.strictEqual(
      await codeOf('updateAppointment', UIDS.manager, { shopId: SHOP, appointmentId: created.id, action: 'status', status: 'archived' }),
      'invalid-input',
    );
    assert.strictEqual(
      await codeOf('updateAppointment', UIDS.manager, { shopId: SHOP, appointmentId: created.id, action: 'grantRole' }),
      'invalid-input',
    );
  });

  it('rejects an unknown appointment', async () => {
    const code = await codeOf('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: 'does-not-exist',
      action: 'status',
      status: 'confirmed',
    });
    assert.strictEqual(code, 'appointment-not-found');
  });

  it('rejects a cross shop update', async () => {
    const code = await codeOf('updateAppointment', UIDS.staff, {
      shopId: OTHER_SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'confirmed',
    });
    assert.strictEqual(code, 'not-a-member');
  });

  it('records payments and derives the status from the collected total', async () => {
    const partial = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'cash',
      amount: 20,
    });
    assert.strictEqual(partial.paymentStatus, 'depositPaid');
    assert.strictEqual(partial.collectedAmount, 20);

    const rest = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'card',
      amount: 30,
    });
    assert.strictEqual(rest.paymentStatus, 'paid');
    assert.strictEqual(rest.collectedAmount, 50);

    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(stored.data().paymentStatus, 'paid');
    const payments = await db.collection(`shops/${SHOP}/payments`).where('appointmentId', '==', created.id).get();
    assert.strictEqual(payments.size, 2);
  });

  it('never marks a booking as paid from a negative amount', async () => {
    const code = await codeOf('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'cash',
      amount: -50,
    });
    assert.strictEqual(code, 'invalid-input');
    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(stored.data().paymentStatus, 'unpaid');
  });

  it('rejects an unsupported payment method', async () => {
    const code = await codeOf('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'crypto',
      amount: 10,
    });
    assert.strictEqual(code, 'invalid-payment-method');
  });

  it('stops a staff member from recording a payment', async () => {
    const code = await codeOf('updateAppointment', UIDS.staff, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'cash',
      amount: 10,
    });
    assert.strictEqual(code, 'permission-denied');
  });

  it('records a standalone sale without an appointment', async () => {
    const result = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      action: 'payment',
      method: 'transfer',
      amount: 75,
    });
    assert.strictEqual(result.appointmentId, null);
    const payment = await db.doc(`shops/${SHOP}/payments/${result.paymentId}`).get();
    assert.strictEqual(payment.data().amount, 75);
    assert.strictEqual(payment.data().method, 'transfer');
  });

  it('deletes a payment and recomputes the appointment status', async () => {
    const first = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'cash',
      amount: 50,
    });
    assert.strictEqual(first.paymentStatus, 'paid');

    const removed = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      action: 'delete_payment',
      paymentId: first.paymentId,
    });
    assert.strictEqual(removed.appointmentId, created.id);
    assert.strictEqual(removed.paymentStatus, 'unpaid');
    assert.strictEqual(removed.collectedAmount, 0);

    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(stored.data().paymentStatus, 'unpaid');
    assert.strictEqual(stored.data().collectedAmount, 0);
    const payment = await db.doc(`shops/${SHOP}/payments/${first.paymentId}`).get();
    assert.strictEqual(payment.exists, false);
  });

  it('keeps the remaining total when one of two payments is deleted', async () => {
    const partial = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'cash',
      amount: 20,
    });
    const full = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'card',
      amount: 30,
    });
    assert.strictEqual(full.paymentStatus, 'paid');

    const removed = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      action: 'delete_payment',
      paymentId: full.paymentId,
    });
    assert.strictEqual(removed.collectedAmount, 20);
    assert.strictEqual(removed.paymentStatus, 'depositPaid');
  });

  it('deletes a standalone sale without touching any appointment', async () => {
    const sale = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      action: 'payment',
      method: 'cash',
      amount: 75,
    });
    const removed = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      action: 'delete_payment',
      paymentId: sale.paymentId,
    });
    assert.strictEqual(removed.appointmentId, null);
    const payment = await db.doc(`shops/${SHOP}/payments/${sale.paymentId}`).get();
    assert.strictEqual(payment.exists, false);
  });

  it('stops a staff member from deleting a payment and rejects an unknown one', async () => {
    const created2 = await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'payment',
      method: 'cash',
      amount: 10,
    });
    assert.strictEqual(
      await codeOf('updateAppointment', UIDS.staff, { shopId: SHOP, action: 'delete_payment', paymentId: created2.paymentId }),
      'permission-denied',
    );
    assert.strictEqual(
      await codeOf('updateAppointment', UIDS.manager, { shopId: SHOP, action: 'delete_payment', paymentId: 'missing' }),
      'payment-not-found',
    );
  });

  it('only rates a completed appointment', async () => {
    const early = await codeOf('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'rating',
      rating: 5,
    });
    assert.strictEqual(early, 'invalid-transition');

    await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'completed',
    });
    const rated = await call('updateAppointment', UIDS.staff, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'rating',
      rating: 4,
    });
    assert.strictEqual(rated.rating, 4);
  });

  it('rejects an out of range rating', async () => {
    await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'completed',
    });
    const code = await codeOf('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'rating',
      rating: 9,
    });
    assert.strictEqual(code, 'invalid-rating');
  });

  it('stops a staff member from rating an appointment they did not create', async () => {
    await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'status',
      status: 'completed',
    });
    const code = await codeOf('updateAppointment', UIDS.otherStaff, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'rating',
      rating: 1,
    });
    assert.strictEqual(code, 'permission-denied');
  });

  it('lets staff mark their own reminder and not someone else', async () => {
    const own = await call('updateAppointment', UIDS.staff, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'reminder',
    });
    assert.strictEqual(own.reminderSent, true);

    const other = await call('createAppointment', UIDS.manager, booking({ employeeId: 'employee-2', chairId: null }));
    const code = await codeOf('updateAppointment', UIDS.staff, {
      shopId: SHOP,
      appointmentId: other.appointments[0].id,
      action: 'reminder',
    });
    assert.strictEqual(code, 'permission-denied');
  });

  it('limits staff contact edits to their own appointment', async () => {
    const mine = await call('updateAppointment', UIDS.staff, {
      shopId: SHOP,
      appointmentId: created.id,
      action: 'contact',
      customerPhone: '+966511111111',
    });
    assert.deepStrictEqual(mine.updated, ['customerPhone']);

    const theirs = await call('createAppointment', UIDS.manager, booking({ employeeId: 'employee-2', chairId: null }));
    const code = await codeOf('updateAppointment', UIDS.staff, {
      shopId: SHOP,
      appointmentId: theirs.appointments[0].id,
      action: 'contact',
      customerPhone: '+966522222222',
    });
    assert.strictEqual(code, 'permission-denied');
  });
});

describe('deleteAppointment', () => {
  let created;

  beforeEach(async () => {
    await clearAll();
    await seed();
    created = (await call('createAppointment', UIDS.staff, booking())).appointments[0];
  });

  it('lets a manager delete a booking and release the slot', async () => {
    assert.strictEqual(await lockCount(), 4);
    const result = await call('deleteAppointment', UIDS.manager, { shopId: SHOP, appointmentId: created.id });
    assert.strictEqual(result.deleted, true);
    assert.strictEqual(await lockCount(), 0);
    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(stored.exists, false);
  });

  it('stops a staff member from deleting a booking', async () => {
    const code = await codeOf('deleteAppointment', UIDS.staff, { shopId: SHOP, appointmentId: created.id });
    assert.strictEqual(code, 'permission-denied');
    const stored = await db.doc(`shops/${SHOP}/appointments/${created.id}`).get();
    assert.strictEqual(stored.exists, true);
  });

  it('rejects an unknown appointment', async () => {
    const code = await codeOf('deleteAppointment', UIDS.manager, { shopId: SHOP, appointmentId: 'missing' });
    assert.strictEqual(code, 'appointment-not-found');
  });

  it('rejects a cross shop delete', async () => {
    const code = await codeOf('deleteAppointment', UIDS.staff, { shopId: OTHER_SHOP, appointmentId: created.id });
    assert.strictEqual(code, 'not-a-member');
  });
});

describe('booking locks', () => {
  beforeEach(async () => {
    await clearAll();
    await seed();
  });

  it('writes one lock per resource bucket', async () => {
    const result = await call('createAppointment', UIDS.staff, booking());
    const locks = await db.collection(`shops/${SHOP}/bookingLocks`).get();
    assert.strictEqual(locks.size, 4);
    const resources = locks.docs.map((doc) => doc.data().resource).sort();
    assert.deepStrictEqual(resources, ['c:chair-1', 'c:chair-1', 'e:employee-1', 'e:employee-1']);
    assert.strictEqual(new Set(locks.docs.map((doc) => doc.id)).size, 4);
    for (const doc of locks.docs) {
      const data = doc.data();
      assert.ok(data.expiresAt instanceof Timestamp);
      assert.strictEqual(data.appointmentId, result.appointments[0].id);
      assert.ok(data.startTime instanceof Timestamp);
      assert.ok(data.endTime instanceof Timestamp);
    }
  });

  it('writes four buckets for a one hour booking', async () => {
    const start = new Date();
    start.setUTCDate(start.getUTCDate() + 6);
    start.setUTCHours(7, 0, 0, 0);
    await call('createAppointment', UIDS.staff, booking({
      serviceIds: ['service-cut', 'service-shave'],
      startTimes: [start.toISOString()],
    }));
    const locks = await db.collection(`shops/${SHOP}/bookingLocks`).get();
    assert.strictEqual(locks.size, 8);
  });

  it('releases the locks when the appointment is cancelled', async () => {
    const result = await call('createAppointment', UIDS.staff, booking());
    assert.strictEqual(await lockCount(), 4);
    await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: result.appointments[0].id,
      action: 'status',
      status: 'cancelled',
    });
    assert.strictEqual(await lockCount(), 0);
  });

  it('keeps the locks for a noShow appointment released as well', async () => {
    const result = await call('createAppointment', UIDS.staff, booking());
    await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: result.appointments[0].id,
      action: 'status',
      status: 'noShow',
    });
    assert.strictEqual(await lockCount(), 0);
  });

  it('still blocks on the appointment when the lock has expired', async () => {
    await call('createAppointment', UIDS.staff, booking());
    const locks = await db.collection(`shops/${SHOP}/bookingLocks`).get();
    const batch = db.batch();
    for (const doc of locks.docs) {
      batch.update(doc.ref, { expiresAt: new Date(Date.now() - 1000) });
    }
    await batch.commit();
    const code = await codeOf('createAppointment', UIDS.otherStaff, booking());
    assert.strictEqual(code, 'appointment-conflict');
  });

  it('ignores expired locks once the appointment itself was cancelled', async () => {
    const result = await call('createAppointment', UIDS.staff, booking());
    await call('updateAppointment', UIDS.manager, {
      shopId: SHOP,
      appointmentId: result.appointments[0].id,
      action: 'status',
      status: 'cancelled',
    });
    const again = await call('createAppointment', UIDS.otherStaff, booking());
    assert.strictEqual(again.appointments.length, 1);
    assert.strictEqual(await lockCount(), 4);
  });
});
