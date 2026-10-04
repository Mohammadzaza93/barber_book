'use strict';

const assert = require('assert');
const {
  computeSubtotal,
  computeTotalDuration,
  computeDiscountAmount,
  computeDepositAmount,
  computePricing,
  derivePaymentStatus,
  round2,
} = require('../../src/lib/pricing');

const settingsOn = {
  depositsEnabled: true,
  depositHighDemandOnly: true,
  depositPercent: 20,
};

describe('pricing', () => {
  it('sums server-side prices from Firestore documents', () => {
    const subtotal = computeSubtotal([
      { price: 50 },
      { price: 30.5 },
      { price: 0 },
    ]);
    assert.strictEqual(subtotal, 80.5);
  });

  it('sums durations and never returns zero minutes', () => {
    assert.strictEqual(computeTotalDuration([{ durationMinutes: 30 }, { durationMinutes: 15 }]), 45);
    assert.strictEqual(computeTotalDuration([{ durationMinutes: 0 }, {}]), 60);
  });

  it('applies percent coupons and clamps them to the order total', () => {
    assert.strictEqual(computeDiscountAmount({ type: 'percent', value: 10 }, 200), 20);
    assert.strictEqual(computeDiscountAmount({ type: 'percent', value: 150 }, 100), 100);
  });

  it('applies fixed coupons and honours maxDiscount', () => {
    assert.strictEqual(computeDiscountAmount({ type: 'fixed', value: 25 }, 200), 25);
    assert.strictEqual(computeDiscountAmount({ type: 'fixed', value: 90, maxDiscount: 40 }, 200), 40);
  });

  it('never returns a negative discount', () => {
    assert.strictEqual(computeDiscountAmount({ type: 'fixed', value: -50 }, 200), 0);
  });

  it('returns no deposit when deposits are disabled', () => {
    const deposit = computeDepositAmount({ depositsEnabled: false, depositPercent: 20 }, [{ highDemand: true }], 100);
    assert.strictEqual(deposit, 0);
  });

  it('returns no deposit when only high demand services require one', () => {
    const deposit = computeDepositAmount(settingsOn, [{ highDemand: false, price: 100 }], 100);
    assert.strictEqual(deposit, 0);
  });

  it('uses the fixed deposit of high demand services when present', () => {
    const deposit = computeDepositAmount(
      settingsOn,
      [{ highDemand: true, depositAmount: 20, price: 100 }, { highDemand: true, depositAmount: 15, price: 50 }],
      150,
    );
    assert.strictEqual(deposit, 35);
  });

  it('falls back to the shop percentage for high demand services without a fixed deposit', () => {
    const deposit = computeDepositAmount(settingsOn, [{ highDemand: true, depositAmount: 0, price: 200 }], 200);
    assert.strictEqual(deposit, 40);
  });

  it('computes the percentage of the payable amount after discount', () => {
    const pricing = computePricing({
      services: [{ price: 100, durationMinutes: 30, highDemand: true, depositAmount: 0 }],
      discount: { type: 'percent', value: 10 },
      settings: settingsOn,
    });
    assert.strictEqual(pricing.subtotal, 100);
    assert.strictEqual(pricing.discountAmount, 10);
    assert.strictEqual(pricing.totalAmount, 90);
    assert.strictEqual(pricing.depositAmount, 18);
    assert.strictEqual(pricing.paymentStatus, 'depositPaid');
  });

  it('never sets depositPaid when no deposit is required', () => {
    const pricing = computePricing({
      services: [{ price: 100, durationMinutes: 30 }],
      discount: null,
      settings: settingsOn,
    });
    assert.strictEqual(pricing.depositAmount, 0);
    assert.strictEqual(pricing.paymentStatus, 'unpaid');
  });

  it('caps the deposit at the payable amount', () => {
    const pricing = computePricing({
      services: [{ price: 30, durationMinutes: 30, highDemand: true, depositAmount: 100 }],
      discount: null,
      settings: settingsOn,
    });
    assert.strictEqual(pricing.depositAmount, 30);
  });

  it('rounds money to two decimals', () => {
    assert.strictEqual(round2(10.005), 10.01);
    assert.strictEqual(round2(0.1 + 0.2), 0.3);
  });

  it('derives payment status from the collected amount', () => {
    assert.strictEqual(derivePaymentStatus(100, 0), 'unpaid');
    assert.strictEqual(derivePaymentStatus(100, 20), 'depositPaid');
    assert.strictEqual(derivePaymentStatus(100, 100), 'paid');
    assert.strictEqual(derivePaymentStatus(100, 140), 'paid');
    assert.strictEqual(derivePaymentStatus(0, 0), 'unpaid');
  });

  it('ignores a discount document that was not provided', () => {
    const pricing = computePricing({ services: [{ price: 100 }], discount: null, settings: {} });
    assert.strictEqual(pricing.discountAmount, 0);
    assert.strictEqual(pricing.totalAmount, 100);
  });
});
