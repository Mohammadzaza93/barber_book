'use strict';

const assert = require('assert');
const {
  resolveRole,
  isMember,
  canManageOperations,
  canManageRules,
  canEnterData,
} = require('../../src/lib/access');
const { readSettings } = require('../../src/lib/settings');

describe('role resolution', () => {
  it('treats the shop owner as owner even without a member document', () => {
    const role = resolveRole({ uid: 'u1', shopData: { ownerId: 'u1' }, memberData: null });
    assert.strictEqual(role, 'owner');
  });

  it('reads the role from the member document', () => {
    const role = resolveRole({ uid: 'u2', shopData: { ownerId: 'u1' }, memberData: { role: 'manager' } });
    assert.strictEqual(role, 'manager');
  });

  it('returns null for a non member', () => {
    const role = resolveRole({ uid: 'u3', shopData: { ownerId: 'u1' }, memberData: null });
    assert.strictEqual(role, null);
    assert.strictEqual(isMember(role), false);
  });

  it('cannot be tricked into owner by a member document', () => {
    const role = resolveRole({ uid: 'u3', shopData: { ownerId: 'u1' }, memberData: { role: 'owner' } });
    assert.strictEqual(role, null);
    assert.strictEqual(canManageRules(role), false);
    assert.strictEqual(canManageOperations(role), false);
  });

  it('ignores unknown role strings', () => {
    const role = resolveRole({ uid: 'u4', shopData: { ownerId: 'u1' }, memberData: { role: 'admin' } });
    assert.strictEqual(role, null);
  });

  it('restricts operations to owners and managers', () => {
    assert.strictEqual(canManageOperations('owner'), true);
    assert.strictEqual(canManageOperations('manager'), true);
    assert.strictEqual(canManageOperations('staff'), false);
    assert.strictEqual(canManageOperations(null), false);
  });

  it('restricts rule management to the owner', () => {
    assert.strictEqual(canManageRules('owner'), true);
    assert.strictEqual(canManageRules('manager'), false);
    assert.strictEqual(canManageRules('staff'), false);
  });

  it('allows every member to enter data', () => {
    assert.strictEqual(canEnterData('staff'), true);
    assert.strictEqual(canEnterData(null), false);
  });
});

describe('settings defaults', () => {
  it('mirrors the flutter model defaults when fields are missing', () => {
    const settings = readSettings({});
    assert.strictEqual(settings.depositsEnabled, false);
    assert.strictEqual(settings.depositPercent, 20);
    assert.strictEqual(settings.depositHighDemandOnly, true);
    assert.strictEqual(settings.maxAdvanceDays, 60);
    assert.strictEqual(settings.cancelFreeHours, 6);
    assert.strictEqual(settings.autoConfirm, false);
    assert.strictEqual(settings.allowOutOfHours, true);
    assert.strictEqual(settings.currency, 'SAR');
  });

  it('prefers stored values over defaults', () => {
    const settings = readSettings({ depositsEnabled: true, depositPercent: 50, autoConfirm: true, maxAdvanceDays: 10 });
    assert.strictEqual(settings.depositsEnabled, true);
    assert.strictEqual(settings.depositPercent, 50);
    assert.strictEqual(settings.autoConfirm, true);
    assert.strictEqual(settings.maxAdvanceDays, 10);
  });

  it('ignores values of the wrong type', () => {
    const settings = readSettings({ depositsEnabled: 'yes', depositPercent: 'half', autoConfirm: 1 });
    assert.strictEqual(settings.depositsEnabled, false);
    assert.strictEqual(settings.depositPercent, 20);
    assert.strictEqual(settings.autoConfirm, false);
  });
});
