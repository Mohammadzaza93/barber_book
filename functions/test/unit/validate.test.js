'use strict';

const assert = require('assert');
const v = require('../../src/lib/validate');
const { randomReference } = require('../../src/lib/repository');

const codeOf = (fn) => {
  try {
    fn();
  } catch (error) {
    return error.code;
  }
  return null;
};

describe('input validation', () => {
  it('rejects non object payloads', () => {
    assert.strictEqual(codeOf(() => v.requireObject(null)), 'invalid-input');
    assert.strictEqual(codeOf(() => v.requireObject([])), 'invalid-input');
    assert.strictEqual(codeOf(() => v.requireObject('x')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.requireObject({})), null);
  });

  it('rejects ids that could escape a document path', () => {
    assert.strictEqual(codeOf(() => v.requireId('../users', 'shopId')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.requireId('a/b', 'shopId')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.requireId('', 'shopId')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.requireId(null, 'shopId')), 'invalid-input');
    assert.strictEqual(v.requireId('550e8400-e29b-41d4-a716-446655440000', 'shopId'), '550e8400-e29b-41d4-a716-446655440000');
  });

  it('treats empty optional ids as null', () => {
    assert.strictEqual(v.optionalId('', 'chairId'), null);
    assert.strictEqual(v.optionalId(null, 'chairId'), null);
    assert.strictEqual(v.optionalId('chair-1', 'chairId'), 'chair-1');
  });

  it('requires at least one service and caps the list', () => {
    assert.strictEqual(codeOf(() => v.parseServiceIds([])), 'invalid-input');
    assert.strictEqual(codeOf(() => v.parseServiceIds('a')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.parseServiceIds(new Array(11).fill('s1'))), 'invalid-input');
    assert.deepStrictEqual(v.parseServiceIds(['s1', 's1', 's2']), ['s1', 's2']);
  });

  it('accepts at most four start times and rejects unsorted input', () => {
    assert.strictEqual(codeOf(() => v.parseStartTimes(new Array(5).fill('2026-01-01T10:00:00Z'))), 'invalid-input');
    assert.strictEqual(
      codeOf(() => v.parseStartTimes(['2026-01-02T10:00:00Z', '2026-01-01T10:00:00Z'])),
      'invalid-input',
    );
    assert.strictEqual(
      codeOf(() => v.parseStartTimes(['2026-01-02T10:00:00Z', '2026-01-02T10:00:00Z'])),
      'invalid-input',
    );
    const parsed = v.parseStartTimes(['2026-01-02T10:00:00Z']);
    assert.strictEqual(parsed.length, 1);
    assert.ok(parsed[0] instanceof Date);
  });

  it('normalises join codes and rejects malformed ones', () => {
    assert.strictEqual(v.parseJoinCode(' ab12cd '), 'AB12CD');
    assert.strictEqual(codeOf(() => v.parseJoinCode('')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.parseJoinCode('  ')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.parseJoinCode('!!')), 'invalid-join-code');
    assert.strictEqual(codeOf(() => v.parseJoinCode('TOOLONGCODE123')), 'invalid-join-code');
  });

  it('normalises discount codes and rejects malformed ones', () => {
    assert.strictEqual(v.parseDiscountCode(' summer '), 'SUMMER');
    assert.strictEqual(v.parseDiscountCode(''), null);
    assert.strictEqual(codeOf(() => v.parseDiscountCode('a b')), 'invalid-input');
  });

  it('validates customer contact fields', () => {
    assert.strictEqual(codeOf(() => v.optionalEmail('not-an-email', 'customerEmail')), 'invalid-input');
    assert.strictEqual(v.optionalEmail('a@b.co', 'customerEmail'), 'a@b.co');
    assert.strictEqual(codeOf(() => v.optionalPhone('123-456', 'customerPhone')), 'invalid-input');
    assert.strictEqual(v.optionalPhone('+966501234567', 'customerPhone'), '+966501234567');
    assert.strictEqual(codeOf(() => v.optionalString('', 'customerName', { allowEmpty: false })), 'invalid-input');
    assert.strictEqual(v.optionalString('x', 'customerName', { allowEmpty: false }), 'x');
  });

  it('normalises the customer id from the phone number', () => {
    assert.strictEqual(v.normalizePhone('+966 50 123 4567'), '+966501234567');
    assert.strictEqual(v.normalizePhone(''), '');
  });

  it('restricts status, action, payment method and rating to known values', () => {
    assert.strictEqual(v.parseStatus('confirmed'), 'confirmed');
    assert.strictEqual(codeOf(() => v.parseStatus('archived')), 'invalid-input');
    assert.strictEqual(v.parseAction('payment'), 'payment');
    assert.strictEqual(codeOf(() => v.parseAction('dropDatabase')), 'invalid-input');
    assert.strictEqual(v.parsePaymentMethod('CASH'), 'cash');
    assert.strictEqual(codeOf(() => v.parsePaymentMethod('crypto')), 'invalid-payment-method');
    assert.strictEqual(v.parseRating(5), 5);
    assert.strictEqual(codeOf(() => v.parseRating(6)), 'invalid-rating');
    assert.strictEqual(codeOf(() => v.parseRating(0)), 'invalid-rating');
    assert.strictEqual(codeOf(() => v.parseRating(4.5)), 'invalid-rating');
  });

  it('bounds payment amounts', () => {
    assert.strictEqual(v.parseAmount('10.005', 'amount'), 10.01);
    assert.strictEqual(codeOf(() => v.parseAmount(0, 'amount')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.parseAmount(-5, 'amount')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.parseAmount(1e9, 'amount')), 'invalid-input');
    assert.strictEqual(codeOf(() => v.parseAmount('abc', 'amount')), 'invalid-input');
  });
});

describe('booking references', () => {
  it('uses an unambiguous alphabet', () => {
    for (let i = 0; i < 200; i += 1) {
      assert.match(randomReference(), /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{8}$/);
    }
  });

  it('does not repeat itself across many samples', () => {
    const set = new Set();
    for (let i = 0; i < 2000; i += 1) set.add(randomReference());
    assert.strictEqual(set.size, 2000);
  });
});
