'use strict';

const DEFAULT_OFFSET_MINUTES = 180;

function shopOffsetMinutes(shopData) {
  const raw = shopData && shopData.timezoneOffsetMinutes;
  if (raw === null || raw === undefined || raw === '') return DEFAULT_OFFSET_MINUTES;
  const value = Number(raw);
  if (!Number.isFinite(value)) return DEFAULT_OFFSET_MINUTES;
  const clamped = Math.max(-840, Math.min(840, Math.round(value)));
  return clamped;
}

function localParts(date, offsetMinutes) {
  const shifted = new Date(date.getTime() + offsetMinutes * 60000);
  return {
    weekday: ((shifted.getUTCDay() + 6) % 7) + 1,
    minutesOfDay: shifted.getUTCHours() * 60 + shifted.getUTCMinutes(),
  };
}

function normalizeWorkingHours(workingHours) {
  const out = new Map();
  if (!workingHours || typeof workingHours !== 'object') return out;
  for (const [key, value] of Object.entries(workingHours)) {
    const day = Number(key);
    if (!Number.isInteger(day) || day < 1 || day > 7) continue;
    if (!Array.isArray(value)) continue;
    const slots = [];
    for (const slot of value) {
      const start = Number(slot && slot.start);
      const end = Number(slot && slot.end);
      if (!Number.isFinite(start) || !Number.isFinite(end)) continue;
      if (start < 0 || end > 1440 || end <= start) continue;
      slots.push({ start, end });
    }
    out.set(day, slots);
  }
  return out;
}

function fitsWorkingHours(workingHours, start, end, offsetMinutes) {
  const hours = normalizeWorkingHours(workingHours);
  if (hours.size === 0) return true;
  const from = localParts(start, offsetMinutes);
  const to = localParts(end, offsetMinutes);
  if (from.weekday !== to.weekday) return false;
  const slots = hours.get(from.weekday) || [];
  return slots.some((slot) => from.minutesOfDay >= slot.start && to.minutesOfDay <= slot.end);
}

function hasWorkingDay(workingHours, start, offsetMinutes) {
  const hours = normalizeWorkingHours(workingHours);
  if (hours.size === 0) return true;
  const from = localParts(start, offsetMinutes);
  return (hours.get(from.weekday) || []).length > 0;
}

function addDays(date, days) {
  return new Date(date.getTime() + days * 86400000);
}

function minutesBetween(a, b) {
  return Math.round((a.getTime() - b.getTime()) / 60000);
}

module.exports = {
  DEFAULT_OFFSET_MINUTES,
  shopOffsetMinutes,
  localParts,
  normalizeWorkingHours,
  fitsWorkingHours,
  hasWorkingDay,
  addDays,
  minutesBetween,
};
