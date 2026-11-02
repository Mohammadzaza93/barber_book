# PHASE 4.6 — Post-Fix Review & Offline Startup Acceptance

**Scope:** Review the PHASE 4.5 changes and the offline-startup root-cause fix in the
Flutter barber app against the eight review objectives, re-run gates, and verify on a
real Android emulator.

**Reviewed tree:** working tree on branch `main`, HEAD `c1f441e`
("Firestore Offline Persistence & Reliable Data Synchronization"). The startup fix is
**uncommitted** (3 tracked files). PHASE 4.5 is committed in `c1f441e`.

**Verdict: PASS WITH LIMITATIONS** — the reported defect (app hangs on splash when
offline) is fixed and verified on-device; no auth/authz/tenant-isolation regression
was introduced. Two pre-existing, non-blocking notification-subscription gaps remain
(documented in §4).

---

## 1. Changes made

**None.** This phase is a review/acceptance pass. The existing fix was found correct
and safe; the two remaining defects (§4) are pre-existing and require a small
topic-tracking design, which is out of scope for a minimal review change.

### Working-tree inventory (unchanged from the offline-startup fix)
| Status | File | Nature |
|--------|------|--------|
| modified (uncommitted) | `lib/providers/auth_provider.dart` | `_applySession` notification subscribe made non-blocking |
| modified (uncommitted) | `lib/services/notification_service.dart` | 5s timeout + best-effort on subscribe/unsubscribe |
| modified (uncommitted) | `test/auth_startup_test.dart` | +3 regression tests |
| new (untracked) | `lib/providers/connection_provider.dart` | PHASE 4.5 |
| new (untracked) | `lib/services/connectivity_source.dart` | PHASE 4.5 |
| new (untracked) | `lib/widgets/connection_banner.dart` | PHASE 4.5 |
| new (untracked) | `OFFLINE_STARTUP_FIX_REPORT.md`, `PHASE4_6_REPORT.md` | reports |

Tracked diff (3 files) is exactly the reviewed startup fix; no unrelated files touched.

---

## 2. Code-level review against objectives

### Obj 1 — Offline startup no longer waits for FCM topic ops ✅ VERIFIED
`auth_provider.dart:91-100`: `_subscribeShopNotifications()` is now wrapped in
`unawaited(... .catchError(...))`, so `_applySession` reaches
`initializing = false; notifyListeners();` (`:111-112`) without awaiting FCM.
`RootGate` no longer strands on the splash screen.
**Device:** offline cold launch with a shop → session init **34 ms**
(`PROBE[init-real] OK 34ms initializing=false shopId=shop-A`).

### Obj 2 — Notification failures do not clear session state ✅ VERIFIED
The failure is caught by `.catchError` (`:97-99`) and cannot reach the outer
`catch` (`:101-110`) that nulls `shopId`/`role`/`ShopManager`. The device probe shows
`shopId=shop-A` preserved while the real `subscribeToTopic` timed out.
**Tests:** `auth_startup_test.dart` covers a never-completing subscribe, a throwing
subscribe (asserts `shopId`/`role` kept, `error` stays null), and an unresolvable shop.

### Obj 3 — Timeout & exception handling ✅ OK
`notification_service.dart:79-99`: each op reads `ShopManager.shopId` **once**
(synchronous capture, no `!`), then `await ....timeout(const Duration(seconds: 5))`
inside `try/catch (e)`, logged via `debugPrint`. `Future.timeout` swallows a late
completion/error, so no unhandled async error. Generic `catch` handles both
`TimeoutException` and `FirebaseException` (e.g. `SERVICE_NOT_AVAILABLE`).

### Obj 4 — Retry after connectivity returns ⚠️ NOT SATISFIED (defect D1)
There is **no in-session retry** of the FCM topic subscription. `ConnectionProvider`
(`connection_provider.dart:58-61, 95-97`) only flushes **Firestore pending writes**
via `waitForPendingWrites()`; it has no knowledge of or hook into FCM topics. If the
app starts offline, the topic subscribe times out and is only re-attempted on the next
`_applySession`/app launch.
**Device:** after re-enabling the network, **no** `subscribeToTopic` retry appeared
in logcat — only the earlier offline timeouts.

### Obj 5 — No outdated-session topic subscription ✅ (subscribe) / ⚠️ (unsubscribe, D2)
Each `subscribeToShop` call reads `ShopManager.shopId` at call time.
**Device:** rapid A→B switch logged `subscribe…shopId=shop-A` then `…shopId=shop-B`,
and landed on `shopId=shop-B` — a subscribe never targets a stale/wrong shop.
However, the **previous** topic is not unsubscribed on an account switch or an
auth-stream-driven sign-out (see D2).

### Obj 6 — Offline sign-out / local cleanup ✅ VERIFIED (with a 5s delay)
`signOut()` (`:216-233`) awaits the bounded unsubscribe, then clears local state in
`finally`. `AuthService.signOut()` is local and completes offline.
**Device:** `signOut()` offline → `OK 5059ms shopId=null ShopManager=null
initializing=false`. Local cleanup **does not depend on remote unsubscription
success** (the unsubscribe times out, is logged, and cleanup proceeds).
`applySessionForTest(null)` cleanup is immediate (**1 ms**).

### Obj 7 — Auth/authz/session-generation/tenant-isolation/rules preserved ✅
The fix touches only the best-effort notification side effect. Unchanged:
`_sessionGeneration` guard (`:62, 78, 87, 105`), `shopId`/`role` resolution,
`canManageRules`/`canManageOperations`/`canViewReports`, `ShopManager` boundaries,
`secure_api` callables, and `firestore.rules`. No auth bypass, no fabricated user.

### Obj 8 — PHASE 4.5 regression review ✅
- `firestore_service.configureOfflinePersistence()` (`:25-51`) is idempotent
  (`_offlineConfigured`), 40 MB bound (within 1–100 MB), and called in `main.dart:35`
  **after** `Firebase.initializeApp` and **before** `runApp`, so `Settings` are set
  before the first Firestore read. Failures are caught and cannot block startup.
- `ConnectionProvider` is created with `..start()` in `app.dart:33`; `start()` is
  guarded by `firebaseReady` and swallows source errors. It never decides
  authorization or business outcomes.
- `admin_home_screen.dart:111-124` wraps the body in `Column([ConnectionBanner(),
  Expanded(IndexedStack)])` — layout-only, no state change.
- Test suites for the state machine and banner are present and green
  (`connectivity_offline_test.dart`).

---

## 3. Remaining defects

### D1 — No in-session retry of the shop topic after reconnect (Obj 4)
- **Impact:** A user who opens the app offline does not receive that shop's push
  notifications until the next app launch (or next session transition).
- **Cause:** `ConnectionProvider` only reconciles Firestore writes; nothing invokes
  `subscribeToShop` on the offline→online edge.
- **Recommended fix:** on the offline→online transition, ask the auth/session layer
  to re-fire `subscribeToShop()` (a single idempotent call; FCM topic subscribe is
  idempotent, so no duplicate listeners/overlaps). Keep the decision out of
  `ConnectionProvider` to preserve its "indicator only" separation of concerns.

### D2 — Previous shop topic is not unsubscribed on switch / stream sign-out (Obj 5)
- **Impact:** After an account switch (A→B) or an auth-stream-driven sign-out
  (token revoked → `_onAuthChanged(null)` → `_clearSession`), the device can remain
  subscribed to the **previous** shop's FCM topic → cross-tenant push leakage.
  Explicit `signOut()` is unaffected because it unsubscribes *before* `_clearSession`.
- **Cause:** `_clearSession` (`:122-133`) resets `ShopManager` **before** calling
  `_unsubscribeShopNotifications()`, so `unsubscribeFromShop` sees `shopId == null`
  and returns immediately (a no-op). A switch path never unsubscribes at all.
- **Note:** Pre-existing (both orderings predate PHASE 4.5). The fire-and-forget
  change removes the serialization the old `await` provided, so a late-completing
  subscribe can now also land after a subsequent unsubscribe.
- **Recommended fix:** track the last subscribed topic (e.g. `_subscribedTopic`);
  when switching, fire an unsubscribe for the old topic **while `ShopManager` still
  points at it** (or pass the topic explicitly), then subscribe the new one. Requires
  a small `NotificationService` API change (topic argument); not a one-liner, hence
  deferred rather than half-implemented here.

### D3 — Offline sign-out is delayed ~5s (minor)
`signOut()` awaits the bounded unsubscribe before clearing local state. Not a failure
(cleanup is guaranteed within the bound), but offline sign-out blocks the UI ~5 s.
Optional improvement: clear local state first, then best-effort unsubscribe.

---

## 4. Test requirements — scenarios

| Scenario | How tested | Result |
|---|---|---|
| Offline cold launch, no session | Emulator, airplane mode, real app, widget-tree dump | **PASS** — `RootGate` → `LoginScreen` |
| Offline restore of a session + shop | Emulator, real `NotificationService`, AuthProvider path | **PASS** — init 34 ms, `shopId` set |
| Failed notification sub then reconnect | Emulator: airplane off after timeout | **FAIL (D1)** — no retry observed |
| Sign-out / switch during pending sub | Emulator: rapid A→B switch + `signOut()` | **PASS** — correct topic target, bounded sign-out |
| Rejected / timed-out notification ops | Emulator + unit tests | **PASS** — 5s timeouts logged, non-fatal |
| Auth & session-isolation regression | `phase4_2_session_isolation_test`, `phase4_1_authorization_test` | **PASS** |

**Scenarios not run (no authorized non-production test account; must not use or
create production accounts/data):** offline launch with a real persisted Firebase
session, expired/invalid credentials offline, full end-to-end screen review while
logged in offline. Session-with-shop was therefore verified at the AuthProvider +
real-`NotificationService` level on-device, **not** by signing into a real account.

No production data was read or mutated. The emulator was configured in airplane mode
for all negative tests; no production Firebase project was touched.

---

## 5. Executed gate results

| Gate | Result |
|------|--------|
| `flutter analyze` | **No issues found** (10.7s) |
| `flutter test` | **116 passed** (113 prior + 3 new) |
| `flutter build apk --debug` | **Built `app-debug.apk`** |

Device: `flutter build apk --debug --target-platform android-x64` also builds/runs on
the emulator; throwaway diagnostic entrypoint was removed afterwards (working tree
clean of it).

---

## 6. Final verdict

**PASS WITH LIMITATIONS**

The reported bug — the app failing to open offline — is **fixed and verified on a real
device**: offline startup no longer waits on Firebase Messaging topic operations, and
notification failures cannot clear a valid session's `shopId`/`role`. All auth,
authorization, session-generation, tenant-isolation, and Firestore security
protections are preserved, and no regression was introduced by PHASE 4.5 or the fix.

Limitations (pre-existing, non-blocking, documented with recommended fixes):
- **D1** no in-session FCM topic re-subscribe after reconnect (pushes resume on relaunch),
- **D2** previous shop topic not unsubscribed on account switch / stream sign-out
  (potential cross-tenant push leak),
- **D3** offline sign-out delayed ~5 s.

Complete offline application functionality is **not** claimed: only the startup and
session-transition paths were device-tested; full logged-in offline screens/operations
were not exercised.
