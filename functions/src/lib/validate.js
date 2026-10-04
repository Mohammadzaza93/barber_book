'use strict';

const { CODES, fail } = require('./errors');

const SAFE_ID = /^[A-Za-z0-9_.:-]{1,128}$/;
const JOIN_CODE = /^[A-Z0-9]{4,12}$/;
const DISCOUNT_CODE = /^[A-Z0-9_-]{2,32}$/;
const EMAIL = /^[^\s@]{1,64}@[^\s@]{1,96}\.[A-Za-z]{2,}$/;
const PHONE = /^[0-9+]{0,32}$/;
const MAX_SERVICES = 10;
const MAX_OCCURRENCES = 4;

const STATUSES = new Set(['requested', 'confirmed', 'completed', 'cancelled', 'noShow']);
const PAYMENT_STATUSES = new Set(['unpaid', 'depositPaid', 'paid']);
const PAYMENT_METHODS = new Set(['cash', 'card', 'transfer']);
const ROLES = new Set(['owner', 'manager', 'staff']);
const ACTIONS = new Set(['status', 'payment', 'delete_payment', 'rating', 'reminder', 'contact']);

function requireObject(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)) {
    fail(CODES.INVALID_INPUT, 'payload must be an object');
  }
  return data;
}

function optionalString(value, field, { max = 512, pattern = null, allowEmpty = true } = {}) {
  if (value === null || value === undefined) {
    if (!allowEmpty) fail(CODES.INVALID_INPUT, `${field} is required`);
    return '';
  }
  if (typeof value !== 'string') fail(CODES.INVALID_INPUT, `${field} must be a string`);
  const trimmed = value.trim();
  if (!allowEmpty && trimmed.length === 0) fail(CODES.INVALID_INPUT, `${field} is required`);
  if (trimmed.length > max) fail(CODES.INVALID_INPUT, `${field} is too long`);
  if (trimmed.length > 0 && pattern && !pattern.test(trimmed)) {
    fail(CODES.INVALID_INPUT, `${field} has an invalid format`);
  }
  return trimmed;
}

function requireId(value, field) {
  const out = optionalString(value, field, { max: 128, pattern: SAFE_ID, allowEmpty: false });
  return out;
}

function optionalId(value, field) {
  if (value === null || value === undefined || value === '') return null;
  return requireId(value, field);
}

function optionalBoolean(value, field) {
  if (value === null || value === undefined) return false;
  if (typeof value !== 'boolean') fail(CODES.INVALID_INPUT, `${field} must be a boolean`);
  return value;
}

function optionalEmail(value, field) {
  const out = optionalString(value, field, { max: 160 });
  if (out.length > 0 && !EMAIL.test(out)) fail(CODES.INVALID_INPUT, `${field} is invalid`);
  return out;
}

function optionalPhone(value, field) {
  const out = optionalString(value, field, { max: 32 });
  if (out.length > 0 && !PHONE.test(out)) fail(CODES.INVALID_INPUT, `${field} is invalid`);
  return out;
}

function normalizePhone(value) {
  return String(value || '').replace(/[^0-9+]/g, '');
}

function parseStartTimes(value) {
  const list = Array.isArray(value) ? value : value === undefined || value === null ? [] : [value];
  if (list.length === 0) fail(CODES.INVALID_INPUT, 'startTimes is required');
  if (list.length > MAX_OCCURRENCES) {
    fail(CODES.INVALID_INPUT, `at most ${MAX_OCCURRENCES} startTimes are allowed`);
  }
  const out = [];
  for (const raw of list) {
    if (typeof raw !== 'string' && typeof raw !== 'number') {
      fail(CODES.INVALID_INPUT, 'startTimes entries must be ISO timestamps');
    }
    const date = new Date(raw);
    if (Number.isNaN(date.getTime())) fail(CODES.INVALID_INPUT, 'startTimes entry is not a valid date');
    out.push(date);
  }
  for (let i = 1; i < out.length; i += 1) {
    if (out[i] <= out[i - 1]) fail(CODES.INVALID_INPUT, 'startTimes must be strictly increasing');
  }
  return out;
}

function parseServiceIds(value) {
  if (!Array.isArray(value)) fail(CODES.INVALID_INPUT, 'serviceIds must be an array');
  if (value.length === 0) fail(CODES.INVALID_INPUT, 'serviceIds is required');
  if (value.length > MAX_SERVICES) fail(CODES.INVALID_INPUT, 'too many services');
  const out = [];
  for (const entry of value) {
    const id = requireId(entry, 'serviceIds entry');
    if (!out.includes(id)) out.push(id);
  }
  return out;
}

function parseDiscountCode(value) {
  if (value === null || value === undefined || value === '') return null;
  const code = String(value).trim().toUpperCase();
  if (!DISCOUNT_CODE.test(code)) fail(CODES.INVALID_INPUT, 'discountCode has an invalid format');
  return code;
}

function parseJoinCode(value) {
  const code = optionalString(value, 'code', { max: 64, allowEmpty: false }).toUpperCase();
  if (!JOIN_CODE.test(code)) fail(CODES.INVALID_JOIN_CODE, 'join code has an invalid format');
  return code;
}

function parseStatus(value) {
  const status = optionalString(value, 'status', { max: 16, allowEmpty: false });
  if (!STATUSES.has(status)) fail(CODES.INVALID_INPUT, 'status is not supported');
  return status;
}

function parseAction(value) {
  const action = optionalString(value, 'action', { max: 24, allowEmpty: false });
  if (!ACTIONS.has(action)) fail(CODES.INVALID_INPUT, 'action is not supported');
  return action;
}

function parsePaymentMethod(value) {
  const method = optionalString(value, 'method', { max: 16, allowEmpty: false }).toLowerCase();
  if (!PAYMENT_METHODS.has(method)) fail(CODES.INVALID_PAYMENT_METHOD, 'payment method is not supported');
  return method;
}

function parseAmount(value, field, { min = 0.01, max = 1000000 } = {}) {
  const amount = Number(value);
  if (!Number.isFinite(amount)) fail(CODES.INVALID_INPUT, `${field} must be a number`);
  if (amount < min || amount > max) fail(CODES.INVALID_INPUT, `${field} is out of range`);
  return Math.round(amount * 100) / 100;
}

function parseRating(value) {
  const rating = Number(value);
  if (!Number.isInteger(rating) || rating < 1 || rating > 5) {
    fail(CODES.INVALID_RATING, 'rating must be an integer between 1 and 5');
  }
  return rating;
}

function parseRole(value) {
  const role = optionalString(value, 'role', { max: 16, allowEmpty: false });
  if (!ROLES.has(role)) fail(CODES.INVALID_INPUT, 'role is not supported');
  return role;
}

module.exports = {
  SAFE_ID,
  MAX_SERVICES,
  MAX_OCCURRENCES,
  STATUSES,
  PAYMENT_STATUSES,
  PAYMENT_METHODS,
  ROLES,
  ACTIONS,
  requireObject,
  requireId,
  optionalId,
  optionalString,
  optionalBoolean,
  optionalEmail,
  optionalPhone,
  normalizePhone,
  parseStartTimes,
  parseServiceIds,
  parseDiscountCode,
  parseJoinCode,
  parseStatus,
  parseAction,
  parsePaymentMethod,
  parseAmount,
  parseRating,
  parseRole,
};
