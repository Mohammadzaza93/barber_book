'use strict';

const LOCK_BUCKET_MINUTES = 15;
const LOCK_GRACE_MINUTES = 120;
const QUERY_PADDING_MINUTES = 1440;
const FREE_STATUSES = new Set(['cancelled', 'noShow']);

function overlaps(aStart, aEnd, bStart, bEnd) {
  return aStart < bEnd && bStart < aEnd;
}

function isBlockingStatus(status) {
  return !FREE_STATUSES.has(String(status || 'requested'));
}

function appointmentBlocks(appointment, windowStart, windowEnd) {
  if (!isBlockingStatus(appointment.status)) return false;
  const start = toDate(appointment.startTime);
  const end = toDate(appointment.endTime);
  if (!start || !end) return false;
  return overlaps(windowStart, windowEnd, start, end);
}

function toDate(value) {
  if (value === null || value === undefined) return null;
  if (value instanceof Date) return value;
  if (typeof value === 'object' && typeof value.toDate === 'function') return value.toDate();
  if (typeof value === 'string' || typeof value === 'number') {
    const parsed = new Date(value);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  return null;
}

function resourceKeys(employeeId, chairId) {
  const keys = [];
  if (employeeId) keys.push(`e:${employeeId}`);
  if (chairId) keys.push(`c:${chairId}`);
  return keys;
}

function bucketIndexes(start, end, bucketMinutes) {
  const size = bucketMinutes * 60000;
  const first = Math.floor(start.getTime() / size);
  const last = Math.ceil(end.getTime() / size);
  const out = [];
  for (let i = first; i < last; i += 1) out.push(i);
  return out;
}

function lockId(resource, bucketIndex) {
  return `${resource.replace(/[^a-zA-Z0-9:_-]/g, '_')}_${bucketIndex}`;
}

function buildLockPlan({ occurrences, employeeId, chairId, now, bucketMinutes }) {
  const bucket = bucketMinutes || LOCK_BUCKET_MINUTES;
  const locks = new Map();
  let earliest = null;
  let latest = null;
  occurrences.forEach((occ, occurrenceIndex) => {
    const { start, end } = occ;
    if (!earliest || start < earliest) earliest = start;
    if (!latest || end > latest) latest = end;
    const expiresAt = new Date(end.getTime() + LOCK_GRACE_MINUTES * 60000);
    for (const resource of resourceKeys(employeeId, chairId)) {
      for (const index of bucketIndexes(start, end, bucket)) {
        const id = lockId(resource, index);
        if (!locks.has(id)) {
          locks.set(id, { resource, bucketIndex: index, expiresAt, occurrenceIndex });
        }
      }
    }
  });
  const padding = QUERY_PADDING_MINUTES * 60000;
  return {
    locks: Array.from(locks.entries()).map(([id, value]) => ({ id, ...value })),
    queryStart: earliest ? new Date(earliest.getTime() - padding) : new Date(now.getTime()),
    queryEnd: latest ? new Date(latest.getTime() + padding) : new Date(now.getTime()),
  };
}

function isLockActive(lock, now) {
  if (!lock) return false;
  const expiresAt = toDate(lock.expiresAt);
  if (!expiresAt) return true;
  return expiresAt.getTime() > now.getTime();
}

function lockDocRefData({ appointmentId, seriesId, start, end, expiresAt, now }) {
  return {
    appointmentId,
    seriesId: seriesId || null,
    startTime: start,
    endTime: end,
    expiresAt,
    createdAt: now,
  };
}

function releasePlan(appointment) {
  const start = toDate(appointment.startTime);
  const end = toDate(appointment.endTime);
  if (!start || !end) return [];
  return buildLockPlan({
    occurrences: [{ start, end }],
    employeeId: appointment.employeeId || '',
    chairId: appointment.chairId || '',
    now: new Date(),
  }).locks;
}

module.exports = {
  LOCK_BUCKET_MINUTES,
  LOCK_GRACE_MINUTES,
  FREE_STATUSES,
  overlaps,
  isBlockingStatus,
  appointmentBlocks,
  toDate,
  resourceKeys,
  bucketIndexes,
  lockId,
  buildLockPlan,
  isLockActive,
  lockDocRefData,
  releasePlan,
};
