'use strict';

const assert = require('assert');
const {
  overlaps,
  isBlockingStatus,
  appointmentBlocks,
  toDate,
  bucketIndexes,
  lockId,
  buildLockPlan,
  isLockActive,
  releasePlan,
  LOCK_BUCKET_MINUTES,
} = require('../../src/lib/conflict');

const at = (iso) => new Date(iso);

describe('conflict detection', () => {
  it('treats touching intervals as free', () => {
    assert.strictEqual(overlaps(at('2026-01-01T10:00:00Z'), at('2026-01-01T11:00:00Z'), at('2026-01-01T11:00:00Z'), at('2026-01-01T12:00:00Z')), false);
  });

  it('detects partial overlap in both directions', () => {
    assert.strictEqual(overlaps(at('2026-01-01T10:00:00Z'), at('2026-01-01T11:00:00Z'), at('2026-01-01T10:30:00Z'), at('2026-01-01T11:30:00Z')), true);
    assert.strictEqual(overlaps(at('2026-01-01T10:30:00Z'), at('2026-01-01T11:30:00Z'), at('2026-01-01T10:00:00Z'), at('2026-01-01T11:00:00Z')), true);
  });

  it('detects full containment', () => {
    assert.strictEqual(overlaps(at('2026-01-01T10:00:00Z'), at('2026-01-01T12:00:00Z'), at('2026-01-01T10:30:00Z'), at('2026-01-01T11:00:00Z')), true);
  });

  it('releases cancelled and noShow appointments', () => {
    assert.strictEqual(isBlockingStatus('cancelled'), false);
    assert.strictEqual(isBlockingStatus('noShow'), false);
    assert.strictEqual(isBlockingStatus('requested'), true);
    assert.strictEqual(isBlockingStatus('confirmed'), true);
    assert.strictEqual(isBlockingStatus('completed'), true);
  });

  it('ignores cancelled appointments in the overlap check', () => {
    const appointment = {
      status: 'cancelled',
      startTime: at('2026-01-01T10:00:00Z'),
      endTime: at('2026-01-01T11:00:00Z'),
    };
    assert.strictEqual(appointmentBlocks(appointment, at('2026-01-01T10:30:00Z'), at('2026-01-01T11:30:00Z')), false);
  });

  it('blocks a confirmed appointment even when it was created by the caller', () => {
    const appointment = {
      status: 'confirmed',
      startTime: at('2026-01-01T10:00:00Z'),
      endTime: at('2026-01-01T11:00:00Z'),
    };
    assert.strictEqual(appointmentBlocks(appointment, at('2026-01-01T10:30:00Z'), at('2026-01-01T11:30:00Z')), true);
  });

  it('parses firestore timestamps, dates and strings', () => {
    assert.strictEqual(toDate({ toDate: () => at('2026-01-01T10:00:00Z') }).toISOString(), '2026-01-01T10:00:00.000Z');
    assert.strictEqual(toDate('2026-01-01T10:00:00Z').toISOString(), '2026-01-01T10:00:00.000Z');
    assert.strictEqual(toDate(null), null);
    assert.strictEqual(toDate('not-a-date'), null);
  });
});

describe('booking locks', () => {
  it('splits a booking into quarter hour buckets', () => {
    const buckets = bucketIndexes(at('2026-01-01T10:00:00Z'), at('2026-01-01T11:00:00Z'), LOCK_BUCKET_MINUTES);
    assert.strictEqual(buckets.length, 4);
  });

  it('does not share a bucket between back to back bookings', () => {
    const first = bucketIndexes(at('2026-01-01T10:00:00Z'), at('2026-01-01T10:45:00Z'), LOCK_BUCKET_MINUTES);
    const second = bucketIndexes(at('2026-01-01T10:45:00Z'), at('2026-01-01T11:30:00Z'), LOCK_BUCKET_MINUTES);
    assert.strictEqual(first.some((index) => second.includes(index)), false);
  });

  it('shares a bucket between overlapping bookings', () => {
    const first = bucketIndexes(at('2026-01-01T10:00:00Z'), at('2026-01-01T10:20:00Z'), LOCK_BUCKET_MINUTES);
    const second = bucketIndexes(at('2026-01-01T10:10:00Z'), at('2026-01-01T10:30:00Z'), LOCK_BUCKET_MINUTES);
    assert.strictEqual(first.some((index) => second.includes(index)), true);
  });

  it('locks the employee and the chair under distinct resources', () => {
    const plan = buildLockPlan({
      occurrences: [{ start: at('2026-01-01T10:00:00Z'), end: at('2026-01-01T10:30:00Z') }],
      employeeId: 'emp-1',
      chairId: 'chair-1',
      now: at('2026-01-01T09:00:00Z'),
    });
    const resources = new Set(plan.locks.map((lock) => lock.resource));
    assert.deepStrictEqual(Array.from(resources).sort(), ['c:chair-1', 'e:emp-1']);
  });

  it('deduplicates locks for a recurring series and keeps the occurrence index', () => {
    const plan = buildLockPlan({
      occurrences: [
        { start: at('2026-01-05T10:00:00Z'), end: at('2026-01-05T10:30:00Z') },
        { start: at('2026-01-05T10:30:00Z'), end: at('2026-01-05T11:00:00Z') },
        { start: at('2026-01-12T10:00:00Z'), end: at('2026-01-12T10:30:00Z') },
      ],
      employeeId: 'emp-1',
      chairId: null,
      now: at('2026-01-01T09:00:00Z'),
    });
    assert.strictEqual(plan.locks.length, 6);
    const indexes = new Set(plan.locks.map((lock) => lock.occurrenceIndex));
    assert.deepStrictEqual(Array.from(indexes).sort(), [0, 1, 2]);
  });

  it('widens the conflict query beyond the booked window', () => {
    const plan = buildLockPlan({
      occurrences: [{ start: at('2026-01-05T10:00:00Z'), end: at('2026-01-05T10:30:00Z') }],
      employeeId: 'emp-1',
      chairId: null,
      now: at('2026-01-01T09:00:00Z'),
    });
    assert.ok(plan.queryStart < at('2026-01-05T10:00:00Z'));
    assert.ok(plan.queryEnd > at('2026-01-05T10:30:00Z'));
  });

  it('treats a lock as active until it expires', () => {
    const now = at('2026-01-01T09:00:00Z');
    assert.strictEqual(isLockActive({ expiresAt: at('2026-01-01T10:00:00Z') }, now), true);
    assert.strictEqual(isLockActive({ expiresAt: at('2026-01-01T08:00:00Z') }, now), false);
    assert.strictEqual(isLockActive({ expiresAt: null }, now), true);
  });

  it('rebuilds the exact lock ids of a stored appointment for release', () => {
    const appointment = {
      employeeId: 'emp-1',
      chairId: 'chair-1',
      startTime: at('2026-01-05T10:00:00Z'),
      endTime: at('2026-01-05T10:30:00Z'),
    };
    const plan = buildLockPlan({
      occurrences: [{ start: at('2026-01-05T10:00:00Z'), end: at('2026-01-05T10:30:00Z') }],
      employeeId: 'emp-1',
      chairId: 'chair-1',
      now: at('2026-01-01T09:00:00Z'),
    });
    const released = releasePlan(appointment).map((lock) => lock.id).sort();
    assert.deepStrictEqual(released, plan.locks.map((lock) => lock.id).sort());
  });

  it('produces deterministic document ids', () => {
    assert.strictEqual(lockId('e:emp-1', 1234), 'e:emp-1_1234');
  });
});
