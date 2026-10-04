'use strict';

const { CODES, fail } = require('./errors');

const OPERATIONS_ROLES = new Set(['owner', 'manager']);
const RULES_ROLES = new Set(['owner']);
const MEMBER_ROLES = new Set(['manager', 'staff']);

function resolveRole({ uid, shopData, memberData }) {
  if (shopData && shopData.ownerId === uid) return 'owner';
  const claimed = memberData && typeof memberData.role === 'string' ? memberData.role : null;
  return MEMBER_ROLES.has(claimed) ? claimed : null;
}

function isMember(role) {
  return role === 'owner' || role === 'manager' || role === 'staff';
}

function canManageOperations(role) {
  return OPERATIONS_ROLES.has(role);
}

function canManageRules(role) {
  return RULES_ROLES.has(role);
}

function canEnterData(role) {
  return isMember(role);
}

async function loadAccess(db, shopId, uid) {
  const shopRef = db.collection('shops').doc(shopId);
  const shopSnap = await shopRef.get();
  if (!shopSnap.exists) fail(CODES.SHOP_NOT_FOUND, 'shop does not exist');
  const shopData = shopSnap.data() || {};
  const memberSnap = await shopRef.collection('members').doc(uid).get();
  const role = resolveRole({ uid, shopData, memberData: memberSnap.exists ? memberSnap.data() : null });
  return { uid, role, shopRef, shopData, memberSnap };
}

function requireMember(access) {
  if (!isMember(access.role)) fail(CODES.NOT_A_MEMBER, 'user is not a member of this shop');
  return access;
}

function requireOperations(access) {
  if (!canManageOperations(access.role)) fail(CODES.PERMISSION_DENIED, 'manager role is required');
  return access;
}

function requireRules(access) {
  if (!canManageRules(access.role)) fail(CODES.PERMISSION_DENIED, 'owner role is required');
  return access;
}

module.exports = {
  resolveRole,
  isMember,
  canManageOperations,
  canManageRules,
  canEnterData,
  loadAccess,
  requireMember,
  requireOperations,
  requireRules,
};
