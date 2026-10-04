'use strict';

const REDACTED = '[redacted]';
const SECRET_KEYS = new Set([
  'code',
  'joincode',
  'password',
  'token',
  'idtoken',
  'authorization',
  'notes',
  'customeremail',
  'customerphone',
  'phone',
  'email',
  'name',
  'customername',
]);

function redact(value) {
  if (value === null || value === undefined) return value;
  if (Array.isArray(value)) return value.map(redact);
  if (typeof value !== 'object') return value;
  const out = {};
  for (const [key, val] of Object.entries(value)) {
    out[key] = SECRET_KEYS.has(key.toLowerCase()) ? REDACTED : redact(val);
  }
  return out;
}

function logEvent(logger, event, payload) {
  logger.info(JSON.stringify({ event, ...redact(payload || {}) }));
}

function logError(logger, event, error) {
  logger.error(
    JSON.stringify({
      event,
      code: error && error.code ? error.code : 'internal',
      message: error && error.message ? error.message : String(error),
    }),
  );
}

module.exports = { redact, logEvent, logError };
