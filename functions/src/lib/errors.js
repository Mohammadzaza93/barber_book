'use strict';

const CODES = {
  UNAUTHENTICATED: 'unauthenticated',
  INVALID_JOIN_CODE: 'invalid-join-code',
  ALREADY_MEMBER: 'already-member',
  NOT_A_MEMBER: 'not-a-member',
  SHOP_NOT_FOUND: 'shop-not-found',
  INVALID_INPUT: 'invalid-input',
  EMPLOYEE_NOT_FOUND: 'employee-not-found',
  EMPLOYEE_INACTIVE: 'employee-inactive',
  SERVICE_MISMATCH: 'service-mismatch',
  CHAIR_NOT_FOUND: 'chair-not-found',
  CHAIR_INACTIVE: 'chair-inactive',
  INVALID_PRICING: 'invalid-pricing',
  SERVICE_NOT_FOUND: 'service-not-found',
  SERVICE_INACTIVE: 'service-inactive',
  APPOINTMENT_NOT_FOUND: 'appointment-not-found',
  PAYMENT_NOT_FOUND: 'payment-not-found',
  APPOINTMENT_CONFLICT: 'appointment-conflict',
  OUTSIDE_WORKING_HOURS: 'outside-working-hours',
  OUT_OF_RANGE: 'out-of-range',
  INVALID_COUPON: 'invalid-coupon',
  COUPON_EXPIRED: 'coupon-expired',
  COUPON_EXHAUSTED: 'coupon-exhausted',
  COUPON_NOT_APPLICABLE: 'coupon-not-applicable',
  OUT_OF_HOURS_NOT_ALLOWED: 'out-of-hours-not-allowed',
  PERMISSION_DENIED: 'permission-denied',
  INVALID_TRANSITION: 'invalid-transition',
  INVALID_PAYMENT_METHOD: 'invalid-payment-method',
  INVALID_RATING: 'invalid-rating',
  APPOINTMENT_IN_PAST: 'appointment-in-past',
  INTERNAL: 'internal',
};

class AppError extends Error {
  constructor(code, message) {
    super(message || code);
    this.name = 'AppError';
    this.code = code;
  }
}

function fail(code, message) {
  throw new AppError(code, message);
}

module.exports = { CODES, AppError, fail };
