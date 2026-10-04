'use strict';

const SETTINGS_DEFAULTS = {
  currency: 'SAR',
  cancelFreeHours: 6,
  cancelFeePercent: 20,
  whoPaysFees: 'customer',
  depositsEnabled: false,
  depositPercent: 20,
  depositHighDemandOnly: true,
  allowOutOfHours: true,
  maxAdvanceDays: 60,
  autoConfirm: false,
  showRatings: true,
  remindersEnabled: true,
  workingHours: {},
};

function readSettings(shopData) {
  const data = shopData || {};
  const settings = { ...SETTINGS_DEFAULTS };
  for (const [key, fallback] of Object.entries(SETTINGS_DEFAULTS)) {
    const value = data[key];
    if (value === undefined || value === null) continue;
    if (typeof fallback === 'boolean') {
      if (typeof value === 'boolean') settings[key] = value;
    } else if (typeof fallback === 'number') {
      const num = Number(value);
      if (Number.isFinite(num)) settings[key] = num;
    } else if (typeof fallback === 'object') {
      if (typeof value === 'object' && !Array.isArray(value)) settings[key] = value;
    } else if (typeof value === 'string') {
      settings[key] = value;
    }
  }
  return settings;
}

module.exports = { SETTINGS_DEFAULTS, readSettings };
