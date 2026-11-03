# BarberBook — Owner & Accountant Authorization Report

## A. Executive Summary

**Status: PASS WITH LIMITATIONS**

### Fixed in this cycle
1. **AuthProvider name collision** with `firebase_auth` (`hide AuthProvider` + disabled public signUp).
2. **Public self-registration removed** from the login screen (owner provisions only).
3. **Manual UID linking removed** (client-supplied UID is not identity proof).
4. **`updateMemberPermissions`** no longer creates incomplete membership via merge `set`; requires existing doc and blocks owner membership edits.
5. **Accountant provisioning** forces role `staff`, generates disposable temp password, sends password-reset email after membership write.
6. Owner email remains `mohammad93zza@gmail.com` (`lib/config/owner.dart` + rules).

### Remaining limitations (client-only Firebase)
- Cannot securely claim an *existing* third-party Auth account without Admin SDK / Cloud Functions.
- Password-reset email delivery depends on Firebase Auth email configuration.
- Full rules emulator suite: **NOT RUN** in this environment.

## B. Root Cause (original “not linked to shop”)

1. Session resolve used paths that rules blocked or indexes missed.
2. Membership was not always written when Auth account was created.
3. Manual UID linking was unsafe and error-prone.
4. Public sign-up created Auth users without membership → lock screen.

## C. Authorization Model

| Role | Storage | Access |
|------|---------|--------|
| **Owner** | `shops/{id}.ownerId == uid` | Full app; only provisioner of accountants |
| **Accountant** | `shops/{id}/members/{uid}` with `role: staff`, `active: true`, `permissions` map | Only explicit permission keys |

Source of truth: canonical `members/{uid}` under the shop. Pointer `memberships/{uid}` is lookup only.

## D. Permission catalog (accountant)

Keys in `StaffPermissions`: appointments, services, staff, discounts, expenses, feedback, reports, settings, businessTools, outOfHours, payments, finance.

- Missing / unknown key → **denied**
- Owner → all true via `StaffPermissions.all`
- UI and Firestore rules both check permissions

## E. Provisioning flow (owner)

1. Owner saves employee with email.
2. Owner taps create login → secondary Firebase App creates Auth user (owner session preserved).
3. Membership written as `role: staff` + permissions + pointer.
4. Password-reset email sent; accountant sets password and signs in.

## F. Deploy

```bash
git pull origin main
firebase deploy --only firestore:rules
flutter analyze
flutter test
```

## G. Manual QA

1. Owner sign-in
2. Create accountant from staff screen (no UID field flow)
3. Confirm owner remains signed in
4. Accountant receives reset email, sets password, signs in
5. Accountant cannot open settings/staff provisioning
6. Deactivate member → access revoked
7. Unknown account → no-access screen
