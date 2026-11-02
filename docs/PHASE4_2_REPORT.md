# PHASE 4.2 REPORT — Adversarial Session Isolation & Authorization Verification

> Additive report. This file does not replace or modify `PHASE4_REPORT.md`,
> `PHASE4_1_REPORT.md`, or any earlier phase report. Every statement below is
> backed by a command that was run in this session; results are copied verbatim
> (or faithfully summarized with counts) from their output.

**Verdict: `PASS WITH OPEN ISSUES — INTERNAL TESTING ONLY`**

- **O-2 (UI ↔ authorization alignment):** independently re-verified. No defect
  found; alternate navigation paths are covered.
- **O-4 (session/provider isolation):** one real race defect found and fixed;
  now regression-tested.
- **Open items:** O-1 (localization debt), iOS not verifiable on Windows, and no
  production deployment was performed (by policy). **This phase does not, on its
  own, approve a production release.**

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
| Working tree at start | 4.1 was already applied but uncommitted (12 modified tracked files) |
| Stash | `stash@{0}` intact (not touched) |

Notes: `c73e286` is an ancestor of HEAD. No commit, amend, rebase, reset,
cherry-pick, push, tag, deploy, production signing, or stash operation was
performed in PHASE 4.2. `firestore.rules`, `functions/src/index.js`, and
`functions/src/lib/access.js` were **not modified**. iOS verification is
impossible on this host; emulator tests require `java` on `PATH` for each shell
invocation (not persisted in any repo file).

## 2. Git Status

### 2.1 Initial (PHASE 4.2 baseline)

`main` @ `699cb63`, with the PHASE 4.1 edits present but uncommitted.

### 2.2 Final (`git status --porcelain`)

```
 M lib/providers/auth_provider.dart
 M lib/providers/business_tools_provider.dart
 M lib/providers/shop_provider.dart
 M lib/screens/admin/appointment_edit_screen.dart
 M lib/screens/admin/business_management_tabs.dart
 M lib/screens/admin/business_tools_screen.dart
 M lib/screens/admin/discounts_screen.dart
 M lib/screens/admin/services_screen.dart
 M lib/screens/admin/settings_screen.dart
 M lib/screens/admin/staff_screen.dart
 M lib/screens/admin/unavailability_screen.dart
 M lib/screens/root_gate.dart
?? PHASE1_3_REPORT.md
?? PHASE2_1_REPORT.md
?? PHASE2_1_SUMMARY.md
?? PHASE2_REPORT.md
?? PHASE3_1_REPORT.md
?? PHASE3_2_REPORT.md
?? PHASE3_3_REPORT.md
?? PHASE3_REPORT.md
?? PHASE4_1_REPORT.md
?? PHASE4_REPORT.md
?? build_report.py
?? lib/widgets/data_state_view.dart
?? test/admin_authorization_test.dart
?? test/data_state_view_test.dart
?? test/phase4_1_authorization_test.dart
?? test/phase4_2_session_isolation_test.dart
?? test/phase4_client_fixes_test.dart
```

`git diff --stat` (12 modified tracked files):

```
12 files changed, 356 insertions(+), 160 deletions(-)
```

Relative to the PHASE 4.1 baseline (10 files, `257+/121-`), PHASE 4.2 added the
adversarial session-isolation fixes to `lib/providers/auth_provider.dart`,
`lib/providers/shop_provider.dart`, and
`lib/providers/business_tools_provider.dart` (which were already part of the
4.1 working set), and added the new test file
`test/phase4_2_session_isolation_test.dart`. No unrelated file was touched.
`HEAD`, the branch, and `stash@{0}` are unchanged.

## 3. Verified Authorization Matrix (re-derived, source of truth)

Re-derived independently in 4.2 from `firestore.rules` and
`functions/src/lib/access.js` (`OPERATIONS_ROLES = {owner, manager}`,
`RULES_ROLES = {owner}`, `MEMBER_ROLES = {manager, staff}`). `AppRoleX`
(`lib/models/app_role.dart`) mirrors these sets exactly: `canManageRules` =
owner-only, `canManageOperations` = non-staff, `canViewReports` = non-staff,
`canEnterData` = all. This matches §3 of `PHASE4_1_REPORT.md`; no drift was
found.

| Collection / action | Read | Write | UI gating (verified 4.2) |
| --- | --- | --- | --- |
| `shops` | owner / member | owner | settings Save owner-only; logo upload owner-only |
| `members` | owner / self | owner | no client control exists |
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

## 4. O-2 Re-verification — Adversarial, Not a Re-Read

The goal was to break the 4.1 gating by *reaching privileged screens through
paths other than the obvious sidebar/FAB*. Findings:

1. **Direct navigation to `SettingsScreen` (owner-only writes).** A staff user
   can reach `SettingsScreen` from the admin drawer's "share booking link" tile
   (`admin_home_screen.dart` pushes `SettingsScreen(openShare: true)`). This is
   **allowed**: the `shops` document is readable by `owner|member`
   (`firestore.rules` L47 write is owner-only). All writes on the screen remain
   gated — Save is disabled and `_set` is a no-op for non-owners. **Verified by
   a widget test** (§9).
2. **`business_tools_screen.dart` → `DiscountsScreen`.** The "الترويج للخدمات"
   tile pushes `DiscountsScreen`; the screen computes its own `canManage` and
   gates its FAB, taps, and delete affordances internally. No escalation.
3. **`appointments_screen.dart` → `AppointmentEditScreen`.** Create mode is
   intentionally available to staff (`createAppointment` allows members); edit
   mode gates the actions/payment sections behind `canManageOperations` and the
   reminder section behind `canManageOperations || isOwn`; `_changeStatus` and
   `_recordPayment` carry defensive role guards. No escalation.
4. **Product catalog / staff / out-of-hours / business tools** remain gated by
   `canManageRules` / `canManageOperations` with defensive guards inside the
   write handlers (never only in the widget tree).

**Conclusion:** no O-2 defect found in 4.2. The rules/callables remain the
authority; the UI only hides affordances and never opens a new write path.

## 5. O-4 Lifecycle Map (as implemented after the 4.2 fix)

`AuthProvider` listens to `AuthService.instance.authStateChanges` via
`_onAuthChanged(User?)`, which now delegates to `_applySession(String? uid)`:

- Every call bumps `_sessionGeneration` (a monotonic token).
- **Signed out (`uid == null`)** → `_clearSession()` immediately (nulls
  `shopId`, resets `role`, `ShopManager.reset()`, best-effort notification
  unsubscribe), `initializing = false`, notify.
- **Signed in** → `await _resolveShop(uid)` → if `generation` still current, set
  `shopId`/`role`/`ShopManager.shopId`; if a shop is present,
  `await _subscribeShopNotifications()` and re-check the generation before
  applying anything further.
- **Resolve failure** → if `generation` still current: set `error`,
  `shopId = null`, `role = staff`, `ShopManager.reset()`; then `initializing =
  false`, notify. A **stale** failure is swallowed entirely so it cannot damage
  a newer session.
- **`signOut()`** → best-effort unsubscribe → `AuthService.signOut()` →
  `finally { _clearSession(); error = null; initializing = false; notify; }`.

## 6. Race Defect Found and Fixed

**Defect (confirmed).** `AuthProvider._onAuthChanged` awaited
`resolveShopForUser(uid)` with **no ordering guard**. If account A's resolve was
in flight and the user signed out (or signed into account B) before it
completed, A's late result was written unconditionally — overwriting (or, after
sign-out, planting) `shopId`, `role`, and `ShopManager.shopId`. That is a
persistent cross-tenant leak until the next successful transition.

**Fix.** Introduced `_sessionGeneration`:

```dart
final generation = ++_sessionGeneration;
if (uid == null) { _clearSession(); ... return; }
try {
  final resolved = await _resolveShop(uid);
  if (generation != _sessionGeneration) return;   // stale: drop
  ...
  await _subscribeShopNotifications();
  if (generation != _sessionGeneration) return;   // stale: drop
} catch (e) {
  if (generation != _sessionGeneration) return;   // stale failure: drop
  ...
}
```

Supporting changes (all in `lib/providers/auth_provider.dart`):

- `typedef ShopResolver = Future<({String? shopId, AppRole role})> Function(String uid);`
- Optional constructor injection: `resolveShop`,
  `subscribeShopNotifications`, `unsubscribeShopNotifications` (default to
  `FirestoreService.instance.resolveShopForUser` and
  `NotificationService.instance.subscribeToShop` / `unsubscribeFromShop`).
- `@visibleForTesting Future<void> applySessionForTest(String? uid)` driving the
  same logic without a Firebase `User` (no mock-firebase dependency exists).

**Adjacent hardening also verified:**

- `lib/providers/shop_provider.dart` — injectable `watchSettings` /
  `watchServices` / `watchEmployees` stream factories; `bind` uses the fields.
  This is a test seam and does not change production wiring.
- `lib/providers/business_tools_provider.dart` — `_syncCustomerProfiles` now
  pins `final boundShop = _shopId;` and aborts (`if (_shopId != boundShop)
  return;`) before each write, writing via `saveCustomer(boundShop, …)`, so a
  mid-sync sign-out/account switch cannot write one tenant's derived customer
  profiles into the next session's shop.

## 7. Test Scenarios and Outcomes

New file: `test/phase4_2_session_isolation_test.dart` — **11 tests, all pass.**
Deterministic: drives session logic through `applySessionForTest` and injects
`ShopProvider` streams through `StreamController`s; no Firebase is touched.

| Scenario | Test | What it proves |
| --- | --- | --- |
| A | "a resolve that lands after sign-out cannot resurrect the session" | A late resolve after sign-out is dropped; `shopId`/`role`/`ShopManager` stay cleared. |
| A | "a late resolve cannot overwrite a newer account" | A resolves last, B keeps winning. |
| B | "a late event on the former shop stream cannot change the new state" | `reset()` cancels A's subscription (`hasListener == false`); a late A event never reaches the B session. |
| C | "a failed stale resolve cannot overwrite the newer session" | A stale **failure** is swallowed; no `error` leaks into B. |
| C | "a current resolve failure clears identity and does not hang" | A current failure clears identity, sets `error`, does not leave `initializing == true`. |
| D | "duplicate sign-out notifications stay consistent" | Repeated null transitions remain consistent. |
| D | "reset is idempotent and does not duplicate subscriptions" | Same-shop `bind` is a no-op; double `reset` cancels once. |
| D | "a disposed provider is unsubscribed and never notified" | `dispose()` cancels the subscription; post-dispose emit does not throw. |
| E | "sign-out clears shop-scoped identity but keeps the language choice" | `ShopManager` cleared and timezone offset reset; global `LanguageProvider` preference survives. |
| E | "reset clears per-session error and permission-denied flags" | `DiscountProvider.reset` clears `permissionDenied`/`error`. |
| O-2 | "staff reaching settings via the share link still cannot save" | Direct navigation to `SettingsScreen` still yields a disabled Save. |

## 8. Exact Flutter + Backend Results

| Gate | Command | Result |
| --- | --- | --- |
| Analyzer | `flutter analyze` | `No issues found!` (ran in 78.9s, exit 0) |
| Flutter tests | `flutter test` | **97 passing** (86 baseline + 11 new) |
| Backend unit | `npm run test:unit` | **68 passing** (48ms) |
| Firestore rules | `npm run test:rules` | **33 passing** (9s, uses Java gate, exit 0) |
| Backend integration | `npm run test:integration` | **75 passing** (34s, uses Java gate, exit 0) |

No gate was skipped, loosened, or re-run to force green. The baseline of 86
Flutter tests is preserved and extended to 97.

## 9. Confirmation — Server-Side Authorization Still Enforced

- `firestore.rules` — **not modified**.
- `functions/src/index.js`, `functions/src/lib/access.js` — **not modified**.
- The backend suites (§8) continue to prove the server rejects unauthorized
  writes regardless of the client: e.g. "no client can write payments, not even
  a manager", "stops a staff member from changing the status", "stops a staff
  member from recording a payment", "limits staff contact edits to their own
  appointment", "a staff member cannot read another shop", and the catalog
  owner-only rules.
- The O-4 changes only tighten client-side session handling; the O-2 changes
  only hide affordances. Neither adds a write path nor grants a privilege.

## 10. Known Limitations / Unresolved Policy

- **O-1 (open):** ~60 hardcoded Arabic strings remain in
  `business_tools_screen.dart` / `business_management_tabs.dart`; not addressed
  in 4.2 (out of scope).
- **iOS:** impossible to build/verify on this Windows host.
- **No UI join-code control exists** (grep shows `joinCode`/`rotateJoinCode` only
  in `firestore_service.dart`), so there is no client control to gate.
- **Staff-own appointment fields** (contact edit, rating, reminder) are enforced
  server-side; for legacy rows without `createdById` the client cannot always
  know ownership — the server remains authoritative and rejects disallowed
  edits.
- The 4.2 race tests exercise the generation guard through
  `applySessionForTest`; they simulate the ordering, not a live Firebase auth
  stream. Real-device verification (sign-out → sign-in → account-switch) is
  still recommended before shipping.
- Nothing was deployed, so no production/staging environment reflects these
  changes yet.

## 11. Untracked / Pre-existing Work Preserved

No files were deleted. Prior-phase reports (`PHASE1_3_REPORT.md` …
`PHASE4_1_REPORT.md`), `build_report.py`, `lib/widgets/data_state_view.dart`,
and the pre-existing test files listed in §2.2 remain exactly as they were. The
only new file in this phase is `test/phase4_2_session_isolation_test.dart`; this
report is the other new artifact. `stash@{0}` and `HEAD` are untouched.

## 12. Recommended Next Step

1. Review the O-4 race fix (`auth_provider.dart`, `shop_provider.dart`,
   `business_tools_provider.dart`) together with the 4.1 UI gating, then commit
   with explicit approval (PHASE 4.2 did not commit).
2. Address **O-1** (extract the ~60 hardcoded Arabic strings into ARB).
3. Run an on-device manual pass of sign-out → sign-in → account-switch against a
   real build to confirm O-4 behavior end-to-end.
4. Only after 1–3: consider an internal-testing build. This report does not
   authorize a production release.
