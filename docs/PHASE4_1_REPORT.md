# PHASE 4.1 REPORT — Authorization Alignment (O-2) & Session Isolation (O-4)

> Additive report. This file does not replace or modify `PHASE4_REPORT.md` or any
> earlier phase report. All statements below are backed by commands that were run
> in this session; results are copied verbatim from their output.

**Verdict: `PASS WITH OPEN ISSUES — INTERNAL TESTING ONLY`**

- **O-2 (UI ↔ authorization alignment):** DONE and regression-tested.
- **O-4 (session/provider reset):** DONE and regression-tested.
- **Open items:** O-1 (localization debt), iOS not verifiable on Windows, and no
  production deployment was performed (by policy).

---

## 1. Environment & Baseline

| Item | Value |
| --- | --- |
| OS | Windows (win32), PowerShell 5.1 |
| Repo | `C:\Users\HP\Desktop\barber` |
| Flutter | 3.27.2 |
| Dart | 3.6.1 |
| Node | v26.1.0 |
| npm | 11.13.0 |
| firebase-tools | 15.25.1 |
| Java (emulator gate) | `[gate] java preflight OK (25.0, resolved from PATH)`, JDK from `C:\Program Files\Android\Android Studio\jbr` |
| State management | `provider` (ChangeNotifier) |
| Branch | `main` |
| HEAD at start & end | `699cb632defa0f4b91b4fed36f49f0c76857d296` ("Flutter Client Quality, Architecture & Production Readiness Audit") |
| Working tree at start | clean (post-PHASE-4) |
| Stash | `stash@{0}` intact (not touched) |

Notes: `c73e286` is an ancestor of HEAD; the 12 PHASE 4 fixes are already
committed. No commit, amend, push, tag, deploy, or stash operation was performed
in PHASE 4.1. iOS verification is impossible on this host; emulator tests require
`java` on `PATH` for each shell invocation (not persisted in any repo file).

## 2. Git Status

### 2.1 Initial (PHASE 4.1 baseline)

Clean working tree at `699cb63` (as recorded at the start of the phase).

### 2.2 Final (`git status --short`)

```
 M lib/screens/admin/discounts_screen.dart
 M lib/screens/admin/services_screen.dart
 M lib/screens/admin/settings_screen.dart
 M lib/screens/admin/staff_screen.dart
 M lib/screens/admin/unavailability_screen.dart
 M lib/screens/admin/business_tools_screen.dart
 M lib/screens/admin/business_management_tabs.dart
 M lib/screens/admin/appointment_edit_screen.dart
 M lib/screens/root_gate.dart
 M lib/providers/auth_provider.dart
?? PHASE1_3_REPORT.md
?? PHASE2_1_REPORT.md
?? PHASE2_1_SUMMARY.md
?? PHASE2_REPORT.md
?? PHASE3_1_REPORT.md
?? PHASE3_2_REPORT.md
?? PHASE3_3_REPORT.md
?? PHASE3_REPORT.md
?? PHASE4_REPORT.md
?? build_report.py
?? lib/widgets/data_state_view.dart
?? test/admin_authorization_test.dart
?? test/data_state_view_test.dart
?? test/phase4_1_authorization_test.dart
?? test/phase4_client_fixes_test.dart
```

`git diff --stat` for the ten modified files:

```
10 files changed, 257 insertions(+), 121 deletions(-)
```

Only the ten intended implementation files changed; no unrelated file was
touched. The `??` entries are prior-phase reports, pre-existing untracked test
files, and the new PHASE 4.1 test file (see §13).

## 3. Verified Authorization Matrix (source of truth)

Derived from `firestore.rules` and `functions/src/lib/access.js`
(`OPERATIONS_ROLES = {owner, manager}`, `RULES_ROLES = {owner}`,
`MEMBER_ROLES = {manager, staff}`). `AppRoleX` (`lib/models/app_role.dart`)
mirrors these sets exactly: `canManageRules` = owner-only,
`canManageOperations` = non-staff, `canEnterData` = all.

| Collection / action | Read | Write | UI gating (after O-2) |
| --- | --- | --- | --- |
| `shops` | owner / member | owner | settings Save owner-only |
| `members` | owner / self | owner | (no UI control exists) |
| `services` | members | owner | Add/edit/delete owner-only |
| `employees` | members | owner | Add/edit/delete owner-only |
| `discounts` | members | owner | Add/edit/delete owner-only |
| `portfolio` | all | owner | Add/delete owner-only |
| `chairs` | all | owner | Add/edit/delete owner-only |
| `chairSupplies`, `chairWeeklyProfits` | manager | owner | Add/edit owner-only |
| `loyaltyRules`, `loyaltyGifts` | all | owner | Add/edit owner-only |
| `loyalty` ledger | — | manager | manager-scoped UI retained |
| `expenses`, `customers`, `queue`, `inventory` | — | manager | operational |
| `inventoryMovements` | manager | create manager | manager |
| `payments` | manager | `false` (server only) | no client write |
| `appointments`, `bookingLocks`, `bookingRequests` | — | server only | via callables |
| `requests` | manager/staff | update/delete manager | approve/reject manager-only |
| `feedback` | manager | create member, update/delete manager | manager |
| `users` | self | `false` | — |

Callables (`functions/src/index.js`): `createAppointment` requires member
(staff allowed); `updateAppointment` `status`/`payment`/`delete_payment` require
operations; contact edit → staff only for own appointment (`createdById === uid`)
else operations; rating/reminder → own staff else operations;
`deleteAppointment` requires operations; `joinShopByCode` always writes staff.

## 4. O-2 Findings, Fixes, Evidence

**Finding.** Several admin screens rendered write affordances (FABs, edit
taps, delete icons, Save buttons, decision buttons) to roles the backend
rejects, producing dead-end actions and confusing errors. The rules/callables
remain the authority; the gap was purely client UX.

**Fixes (10 files):**

1. `lib/screens/admin/services_screen.dart` — import `auth_provider`;
   `canManage = canManageRules`; gated EmptyState action, ListTile `onTap`,
   delete `IconButton`, FAB.
2. `lib/screens/admin/staff_screen.dart` — import `auth_provider`; `canManage`;
   gated EmptyState action, `onTap`, delete `IconButton`, FAB; defensive guard
   at the top of `_save()` (`if (!context.read<AuthProvider>().canManageRules) return;`).
3. `lib/screens/admin/discounts_screen.dart` — import `auth_provider`;
   `canManage`; gated EmptyState action, `onTap`, delete `IconButton`; FAB now
   `(canManage && !discounts.permissionDenied && discounts.error == null) ? … : null`.
4. `lib/screens/admin/settings_screen.dart` — import `auth_provider`; build
   `canManage`; `_set` no-ops for non-owner; `_save` + `_uploadLogo` guards;
   logo `IconButton` gated; Save `FilledButton(onPressed: (canManage && !_busy) ? _save : null)`.
5. `lib/screens/admin/unavailability_screen.dart` — import `auth_provider`;
   `canDecide = canManageOperations`; `_decide` guard; `_RequestCard` gained a
   `canDecide` field; decision block now `if (r.status == 'pending' && canDecide)`.
6. `lib/screens/admin/business_tools_screen.dart` — import `auth_provider`;
   `_PortfolioTab` `canManage`; gated FAB and delete `IconButton`.
7. `lib/screens/admin/business_management_tabs.dart` — import `auth_provider`;
   `LoyaltyProgramTab` `canManage` (gated rule header, rule `Switch`, rule
   `PopupMenuButton`, gift header, gift `PopupMenuButton`; kept manager-scoped
   loyalty ledger controls); `ChairOperationsTab` `canManage` (gated chair
   header, chair menu, supply header, supply menu, "تعديل الربح" profit button).
8. `lib/screens/admin/appointment_edit_screen.dart` — import `auth_provider`;
   `_buildView` computes `canManage = canManageOperations` and
   `isOwn = a.createdById != null && a.createdById == auth.user?.uid`; gated the
   actions section and paymentStatus section (`if (canManage)`), reminder section
   (`if (canManage || isOwn)`), bottom cancel `OutlinedButton` (`if (canManage)`);
   defensive guards added to `_changeStatus` and `_recordPayment`.

**Evidence.** Static: `flutter analyze` → `No issues found!`. Behavioral:
`test/phase4_1_authorization_test.dart` (see §9).

## 5. O-4 Auth Lifecycle Map

`AuthProvider` listens to `AuthService.instance.authStateChanges` via
`_onAuthChanged(User?)`.

- **Signed in** → `resolveShopForUser(uid)` → sets `shopId`, `role`,
  `ShopManager.shopId`, subscribes to shop notifications.
- **Resolve failure** → `error` set, `shopId = null`, `role = AppRole.staff`,
  **`ShopManager.reset()`** (changed in 4.1 from leaking a stale `shopId`).
- **Signed out / no user** → `_clearSession()`: `shopId = null`,
  `role = AppRole.staff`, `ShopManager.reset()`, best-effort
  `NotificationService.unsubscribeFromShop()`.
- **`signOut()`** → unsubscribe (best-effort) → `AuthService.signOut()` →
  `finally { _clearSession(); error = null; initializing = false; notifyListeners(); }`.

## 6. Provider / Session State Inventory

Six shop-scoped `ChangeNotifier` providers each expose `bind(shopId[, role])`
(idempotent by `_boundShopId`) and `reset()` (cancels subscriptions and clears
tenant state):

| Provider | Reset clears |
| --- | --- |
| `ShopProvider` | settings + catalog (services/employees/…) |
| `AppointmentProvider` | appointments + requests, `loading = true` |
| `BusinessToolsProvider` | every cached collection |
| `DiscountProvider` | discounts + denial state |
| `ExpenseProvider` | expenses + denial state |
| `FeedbackProvider` | feedback + denial state |
| `ShopManager` (singleton) | shop-scoped scalar identity |

## 7. Session-Reset Implementation

`lib/screens/root_gate.dart` was rewritten from `StatelessWidget` to
`StatefulWidget` (`_RootGateState`):

- Reads `AuthProvider` and remembers the current owner uid.
- Registers `_onAuthChanged` as an `AuthProvider` listener (added in
  `initState`, removed in `dispose`).
- On any uid change (including → `null`): calls `_resetDataProviders()` which
  invokes `reset()` on all six data providers, then rebuilds and re-`bind()`s
  the providers for the new session.
- `bind()` remains in `build`, so a healthy session still subscribes correctly.

Result: no shop-scoped provider can carry the previous account's / shop's data
into the next session.

## 8. Race Handling

- `AuthProvider._onAuthChanged` guards the resolve path so a network/Firestore
  failure cannot leave `initializing == true` (app would hang on splash) — it
  clears state and notifies.
- The resolve `catch` now calls `ShopManager.reset()` instead of only nulling
  `shopId`, removing a stale-shop window.
- `RootGate` resets providers on *every* uid transition, including sign-out, so
  a fast sign-out → sign-in sequence cannot interleave the previous shop's
  streamed data with the new session.
- `bind()` idempotency (per `_boundShopId`) prevents duplicate subscriptions on
  repeated rebuilds.

## 9. Tests Added / Updated

**Added:** `test/phase4_1_authorization_test.dart` — 10 tests.

- O-2 catalog writes owner-only: services (owner vs manager), staff
  (owner vs staff), discounts (owner vs manager) — FAB presence.
- O-2 shop settings owner-only: owner Save enabled, manager Save disabled.
- O-2 out-of-hours decisions are manager-only: manager sees approve/reject,
  staff keeps a read-only card.
- O-2 appointment status/payment manager-only: staff sees neither section,
  manager sees both.
- O-2 owner-only business tools: portfolio add affordance owner-only.
- O-4 provider reset: `ShopProvider.reset`, `AppointmentProvider.reset`, and a
  combined check that every provider purges together and `ShopManager` is
  cleared.

Harness note: the tests force a remount per `pumpWidget` (a fresh `KeyedSubtree`
key in the `_app` helper) because re-pumping the same `const` screen widget
reuses the element; this was confirmed with a throwaway probe (fresh
manager-only pump correctly hides the FAB) before the helper change.

**Not modified:** `test/admin_authorization_test.dart`,
`test/phase4_client_fixes_test.dart`, `test/data_state_view_test.dart`, and all
other pre-existing tests. Baseline of 76 tests is preserved and extended to 86.

## 10. Exact Flutter + Backend Results

| Gate | Command | Result |
| --- | --- | --- |
| Analyzer | `flutter analyze` | `No issues found!` (exit 0) |
| Flutter tests | `flutter test` | **86 passing** (76 baseline + 10 new) |
| Backend unit | `npm run test:unit` | **68 passing** |
| Firestore rules | `npm run test:rules` | **33 passing** (uses Java gate) |
| Backend integration | `npm run test:integration` | **75 passing** (uses Java gate) |

No gate was skipped, loosened, or re-run to force green.

## 11. Confirmation — Server-Side Authorization Still Enforced

- `firestore.rules` was **not modified**.
- `functions/src/index.js` / `functions/src/lib/access.js` were **not modified**.
- The backend test suites (§10) continue to prove the server rejects
  unauthorized writes regardless of the client: e.g. "no client can write
  payments, not even a manager", "stops a staff member from changing the
  status", "stops a staff member from recording a payment", "limits staff
  contact edits to their own appointment", and the catalog owner-only rules.
- O-2 changes only *hide* affordances; they add no new write paths and grant no
  privilege. Defensive re-checks were added inside handlers, never removed.

## 12. Known Limitations / Unresolved Policy

- **O-1 (open):** ~60 hardcoded Arabic strings remain in
  `business_tools_screen.dart` / `business_management_tabs.dart`; not addressed
  in 4.1 (out of scope).
- **iOS:** impossible to build/verify on this Windows host.
- **No UI join-code control exists** (grep shows `joinCode`/`rotateJoinCode` only
  in `firestore_service.dart`; `watchMembers`/`updateMemberRole`/`removeMember`
  are not called from any screen), so there is no client control to gate.
- **Staff-own appointment fields** (contact edit, rating, reminder) are enforced
  server-side; the UI exposes them only when `canManageOperations || isOwn`, but
  the client cannot always know `createdById` for legacy rows — the server
  remains authoritative and rejects disallowed edits.
- Nothing was deployed, so no production/staging environment reflects these
  changes yet.

## 13. Untracked / Pre-existing Work Preserved

No files were deleted. Prior-phase reports (`PHASE1_3_REPORT.md` …
`PHASE4_REPORT.md`), `build_report.py`, `lib/widgets/data_state_view.dart`, and
the pre-existing test files listed in §2.2 remain exactly as they were. Only
`test/phase4_1_authorization_test.dart` is new in this phase.

## 14. Recommended Next Step

1. Review the ten O-2 edits and the `root_gate`/`auth_provider` O-4 changes,
   then commit them (explicit approval required; PHASE 4.1 did not commit).
2. Address **O-1** (extract the ~60 hardcoded Arabic strings in
   `business_tools_screen.dart` / `business_management_tabs.dart` into ARB).
3. Optionally build an internal-testing APK (record path, size, SHA-256, signing)
   — not produced in this phase.
4. Run an on-device manual pass of sign-out → sign-in → account-switch to
   confirm O-4 behavior in a real build (emulator/device).
