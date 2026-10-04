'use strict';

process.env.FIRESTORE_EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8080';
process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT || 'demo-barberbook';
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: 'demo-barberbook' });

const fs = require('fs');
const path = require('path');

const PROJECT_ID = 'demo-barberbook';
const RULES_PATH = path.resolve(__dirname, '..', '..', '..', 'firestore.rules');
const rules = fs.readFileSync(RULES_PATH, 'utf8');

const UIDS = {
  owner: 'owner-1',
  manager: 'manager-1',
  staff: 'staff-1',
  otherStaff: 'staff-2',
  stranger: 'stranger-1',
  otherOwner: 'owner-2',
};

const SHOP = 'shop-1';
const OTHER_SHOP = 'shop-2';
const JOIN_CODE = 'ABC234';

const WORKDAY = {
  1: [{ start: 540, end: 1020 }],
  2: [{ start: 540, end: 1020 }],
  3: [{ start: 540, end: 1020 }],
  4: [{ start: 540, end: 1020 }],
  5: [{ start: 540, end: 1020 }],
  6: [{ start: 540, end: 1020 }],
  7: [{ start: 540, end: 1020 }],
};

function seedDocuments(now) {
  return [
    {
      path: `shops/${SHOP}`,
      data: {
        ownerId: UIDS.owner,
        joinCode: JOIN_CODE,
        shopName: 'Shop One',
        currency: 'SAR',
        autoConfirm: false,
        allowOutOfHours: true,
        cancelFreeHours: 6,
        maxAdvanceDays: 60,
        depositsEnabled: false,
        depositPercent: 20,
        depositHighDemandOnly: true,
        workingHours: WORKDAY,
        createdAt: now,
        updatedAt: now,
      },
    },
    {
      path: `shops/${OTHER_SHOP}`,
      data: {
        ownerId: UIDS.otherOwner,
        joinCode: 'ZZZ999',
        shopName: 'Shop Two',
        currency: 'SAR',
        autoConfirm: true,
        maxAdvanceDays: 60,
        workingHours: WORKDAY,
        createdAt: now,
        updatedAt: now,
      },
    },
    { path: `shops/${SHOP}/members/${UIDS.manager}`, data: { uid: UIDS.manager, email: 'm@x.com', name: 'Manager', role: 'manager', createdAt: now } },
    { path: `shops/${SHOP}/members/${UIDS.staff}`, data: { uid: UIDS.staff, email: 's@x.com', name: 'Staff', role: 'staff', createdAt: now } },
    { path: `shops/${SHOP}/members/${UIDS.otherStaff}`, data: { uid: UIDS.otherStaff, email: 's2@x.com', name: 'Staff Two', role: 'staff', createdAt: now } },
    { path: `shops/${OTHER_SHOP}/members/${UIDS.otherOwner}`, data: { uid: UIDS.otherOwner, email: 'o2@x.com', name: 'Other Owner', role: 'manager', createdAt: now } },

    { path: `shops/${SHOP}/services/service-cut`, data: { name: 'Cut', price: 50, durationMinutes: 30, active: true, highDemand: false, depositAmount: 0, sortOrder: 0 } },
    { path: `shops/${SHOP}/services/service-shave`, data: { name: 'Shave', price: 30, durationMinutes: 30, active: true, highDemand: true, depositAmount: 15, sortOrder: 1 } },
    { path: `shops/${SHOP}/services/service-old`, data: { name: 'Retired', price: 999, durationMinutes: 30, active: false, highDemand: false, depositAmount: 0, sortOrder: 2 } },
    { path: `shops/${SHOP}/services/service-bad`, data: { name: 'Broken', price: -5, durationMinutes: 30, active: true, sortOrder: 3 } },
    { path: `shops/${OTHER_SHOP}/services/other-service`, data: { name: 'Other', price: 10, durationMinutes: 30, active: true } },

    { path: `shops/${SHOP}/employees/employee-1`, data: { name: 'Barber One', role: 'barber', active: true, serviceIds: ['service-cut', 'service-shave'], workingHours: WORKDAY } },
    { path: `shops/${SHOP}/employees/employee-2`, data: { name: 'Barber Two', role: 'barber', active: true, serviceIds: ['service-cut'], workingHours: WORKDAY } },
    { path: `shops/${SHOP}/employees/employee-off`, data: { name: 'Barber Off', role: 'barber', active: false, serviceIds: ['service-cut'], workingHours: WORKDAY } },
    { path: `shops/${SHOP}/chairs/chair-1`, data: { name: 'Chair', number: '1', active: true } },
    { path: `shops/${SHOP}/chairs/chair-off`, data: { name: 'Retired chair', number: '9', active: false } },

    { path: `shops/${SHOP}/discounts/discount-percent`, data: { code: 'SAVE10', title: 'Ten percent', type: 'percent', value: 10, minValue: 0, maxDiscount: 0, active: true, usageLimit: 5, usageCount: 0, serviceIds: [] } },
    { path: `shops/${SHOP}/discounts/discount-expired`, data: { code: 'OLDONE', title: 'Expired', type: 'percent', value: 50, minValue: 0, maxDiscount: 0, active: true, usageLimit: 0, usageCount: 0, serviceIds: [], validTo: new Date('2020-01-01T00:00:00Z') } },
    { path: `shops/${SHOP}/discounts/discount-used-up`, data: { code: 'GONE', title: 'Used up', type: 'percent', value: 50, minValue: 0, maxDiscount: 0, active: true, usageLimit: 1, usageCount: 1, serviceIds: [] } },
    { path: `shops/${SHOP}/discounts/discount-min`, data: { code: 'BIGSPEND', title: 'Minimum spend', type: 'fixed', value: 20, minValue: 200, maxDiscount: 0, active: true, usageLimit: 0, usageCount: 0, serviceIds: [] } },
    { path: `shops/${SHOP}/discounts/discount-scoped`, data: { code: 'CUTONLY', title: 'Cut only', type: 'fixed', value: 5, minValue: 0, maxDiscount: 0, active: true, usageLimit: 0, usageCount: 0, serviceIds: ['service-cut'] } },

    { path: `shops/${SHOP}/payments/payment-seed`, data: { appointmentId: 'seed', amount: 10, method: 'cash', paidAt: now } },
    { path: `shops/${SHOP}/expenses/expense-seed`, data: { category: 'rent', amount: 100, date: now } },
    { path: `shops/${SHOP}/requests/request-seed`, data: { kind: 'unavailability', status: 'pending' } },

    { path: `users/${UIDS.owner}`, data: { email: 'owner@x.com', displayName: 'Owner' } },
    { path: `users/${UIDS.manager}`, data: { email: 'm@x.com', displayName: 'Manager' } },
    { path: `users/${UIDS.staff}`, data: { email: 's@x.com', displayName: 'Staff' } },
    { path: `users/${UIDS.stranger}`, data: { email: 'n@x.com', displayName: 'Stranger' } },
  ];
}

module.exports = { PROJECT_ID, RULES_PATH, rules, UIDS, SHOP, OTHER_SHOP, JOIN_CODE, WORKDAY, seedDocuments };
