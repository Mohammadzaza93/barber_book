'use strict';

const assert = require('assert');
const {
  shopOffsetMinutes,
  localParts,
  normalizeWorkingHours,
  fitsWorkingHours,
  hasWorkingDay,
  minutesBetween,
  DEFAULT_OFFSET_MINUTES,
} = require('../../src/lib/time');

const at = (iso) => new Date(iso);
const RIYADH = 180;

describe('shop timezone', () => {
  it('defaults to the riyadh offset when the shop has no timezone', () => {
    assert.strictEqual(shopOffsetMinutes({}), DEFAULT_OFFSET_MINUTES);
    assert.strictEqual(shopOffsetMinutes(null), 180);
  });

  it('uses a configured offset when present', () => {
    assert.strictEqual(shopOffsetMinutes({ timezoneOffsetMinutes: 120 }), 120);
  });

  it('clamps impossible offsets', () => {
    assert.strictEqual(shopOffsetMinutes({ timezoneOffsetMinutes: 5000 }), 840);
    assert.strictEqual(shopOffsetMinutes({ timezoneOffsetMinutes: -5000 }), -840);
  });

  it('maps local time to the same weekday convention as the flutter models', () => {
    const parts = localParts(at('2026-01-04T12:00:00Z'), RIYADH);
    assert.strictEqual(parts.weekday, 7);
    assert.strictEqual(parts.minutesOfDay, 900);
  });

  it('rolls the weekday forward across midnight local time', () => {
    const parts = localParts(at('2026-01-04T22:00:00Z'), RIYADH);
    assert.strictEqual(parts.weekday, 1);
    assert.strictEqual(parts.minutesOfDay, 60);
  });
});

describe('working hours validation', () => {
  const hours = {
    1: [{ start: 540, end: 1020 }],
    7: [{ start: 600, end: 720 }],
  };

  it('keeps only well formed slots', () => {
    const normalized = normalizeWorkingHours({
      1: [
        { start: 540, end: 1020 },
        { start: 1020, end: 1140 },
        { start: 700, end: 600 },
        { start: 'x', end: 1 },
        { start: 0, end: 2000 },
      ],
      9: [{ start: 1, end: 2 }],
      bad: [{ start: 1, end: 2 }],
    });
    assert.strictEqual(normalized.get(1).length, 2);
    assert.strictEqual(normalized.has(9), false);
    assert.strictEqual(normalized.has('bad'), false);
  });

  it('accepts a booking fully inside a working slot', () => {
    const start = at('2026-01-05T08:00:00Z');
    const end = at('2026-01-05T09:00:00Z');
    assert.strictEqual(fitsWorkingHours(hours, start, end, RIYADH), true);
  });

  it('rejects a booking that starts before opening time', () => {
    const start = at('2026-01-05T05:00:00Z');
    const end = at('2026-01-05T06:30:00Z');
    assert.strictEqual(fitsWorkingHours(hours, start, end, RIYADH), false);
  });

  it('rejects a booking that ends after closing time', () => {
    const start = at('2026-01-05T13:00:00Z');
    const end = at('2026-01-05T14:30:00Z');
    assert.strictEqual(fitsWorkingHours(hours, start, end, RIYADH), false);
  });

  it('rejects a booking on a day the employee does not work', () => {
    const start = at('2026-01-06T10:00:00Z');
    const end = at('2026-01-06T11:00:00Z');
    assert.strictEqual(fitsWorkingHours(hours, start, end, RIYADH), false);
    assert.strictEqual(hasWorkingDay(hours, start, RIYADH), false);
  });

  it('rejects a booking that crosses local midnight', () => {
    const start = at('2026-01-05T20:00:00Z');
    const end = at('2026-01-05T22:00:00Z');
    assert.strictEqual(fitsWorkingHours(hours, start, end, RIYADH), false);
  });

  it('allows any booking when the shop has no working hours configured', () => {
    const start = at('2026-01-06T10:00:00Z');
    const end = at('2026-01-06T11:00:00Z');
    assert.strictEqual(fitsWorkingHours({}, start, end, RIYADH), true);
    assert.strictEqual(hasWorkingDay({}, start, RIYADH), true);
  });

  it('counts advance minutes in whole minutes', () => {
    assert.strictEqual(minutesBetween(at('2026-01-01T10:00:00Z'), at('2026-01-01T09:00:00Z')), 60);
    assert.strictEqual(minutesBetween(at('2026-01-01T08:00:00Z'), at('2026-01-01T09:00:00Z')), -60);
  });
});
