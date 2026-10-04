'use strict';

function round2(value) {
  return Math.round((value + Number.EPSILON) * 100) / 100;
}

function computeSubtotal(services) {
  return round2(services.reduce((sum, s) => sum + Number(s.price || 0), 0));
}

function computeTotalDuration(services) {
  return services.reduce((sum, s) => sum + Math.max(1, Math.trunc(Number(s.durationMinutes) || 30)), 0);
}

function computeDiscountAmount(discount, subtotal) {
  if (!discount) return 0;
  const type = String(discount.type || 'percent');
  const value = Number(discount.value || 0);
  let amount = type === 'fixed' ? value : (subtotal * value) / 100;
  const maxDiscount = Number(discount.maxDiscount || 0);
  if (maxDiscount > 0 && amount > maxDiscount) amount = maxDiscount;
  if (!Number.isFinite(amount) || amount < 0) amount = 0;
  if (amount > subtotal) amount = subtotal;
  return round2(amount);
}

function computeDepositAmount(settings, services, payable) {
  const depositsEnabled = settings && settings.depositsEnabled === true;
  if (!depositsEnabled) return 0;
  const highDemandOnly = settings.depositHighDemandOnly !== false;
  const percent = Number(settings.depositPercent || 0);
  if (highDemandOnly) {
    const highDemand = services.filter((s) => s.highDemand === true);
    if (highDemand.length === 0) return 0;
    const fixed = highDemand.filter((s) => Number(s.depositAmount || 0) > 0);
    if (fixed.length > 0) {
      return round2(fixed.reduce((sum, s) => sum + Number(s.depositAmount || 0), 0));
    }
  }
  if (!Number.isFinite(percent) || percent <= 0) return 0;
  const ratio = Math.min(100, percent) / 100;
  return round2(payable * ratio);
}

function computePricing({ services, discount, settings }) {
  const subtotal = computeSubtotal(services);
  const discountAmount = computeDiscountAmount(discount, subtotal);
  const payable = round2(Math.max(0, subtotal - discountAmount));
  const depositAmount = computeDepositAmount(settings, services, payable);
  const clampedDeposit = Math.min(depositAmount, payable);
  return {
    subtotal,
    discountAmount,
    totalAmount: payable,
    depositAmount: round2(clampedDeposit),
    paymentStatus: clampedDeposit > 0 ? 'depositPaid' : 'unpaid',
  };
}

function derivePaymentStatus(totalAmount, collectedAmount) {
  const total = Number(totalAmount || 0);
  const collected = Number(collectedAmount || 0);
  if (total > 0 && collected >= total) return 'paid';
  if (collected > 0) return 'depositPaid';
  return 'unpaid';
}

module.exports = {
  round2,
  computeSubtotal,
  computeTotalDuration,
  computeDiscountAmount,
  computeDepositAmount,
  computePricing,
  derivePaymentStatus,
};
