# PHASE 4.7 — FCM Topic Lifecycle & Tenant Isolation Hardening

**Repository:** `C:\Users\HP\Desktop\barber`
**Branch / base:** `main`, HEAD `c1f441e` ("Firestore Offline Persistence & Reliable Data Synchronization")
**Reviewed tree:** working tree with the uncommitted PHASE 4.6 offline-startup fix **preserved** and extended.
**Verdict: PASS WITH LIMITATIONS**

Client-side FCM topic lifecycle, reconnect recovery, and the documented races are fixed and
covered by deterministic tests. Tenant isolation is **partially** hardened: the client can no
longer leak a *previous* tenant's topic across a shop switch or sign-out **within a running
process**, but (a) a client that is offline cannot guarantee immediate server-side topic
removal, and (b) there is **no server-side notification dispatch in this repository**, so
server-side tenant authorization could not be verified at all (see §D).

---

## A. Executive summary

- **Verdict:** **PASS WITH LIMITATIONS.**
- **Main findings:** All three PHASE 4.6 defects were reproduced at the code level and fixed:
  - **D2** (previous shop topic never unsubscribed on switch / auth-stream sign-out) — root cause
    confirmed: `_clearSession()` reset `ShopManager` *before* the unsubscribe, and the unsubscribe
    read `ShopManager.shopId` implicitly, so it always saw `null` and no-op'd; the switch path
    never unsubscribed at all. Fixed with explicit topic arguments and a serialized reconcile queue.
  - **D1** (no subscription recovery after reconnect) — fixed by a `ConnectionProvider`
    offline→online hook routed through the auth/session layer.
  - **D3** (offline sign-out blocked ~5 s on FCM) — fixed by decoupling local sign-out from the
    best-effort remote unsubscribe.
- **Implementation outcome:** `NotificationService` now takes the topic explicitly and reports
  success; `AuthProvider` owns a single confirmed-topic record and a FIFO transition queue with
  session-generation guards; `ConnectionProvider` exposes one `onReconnected` callback.
- **Tenant isolation:** **partially met.** Client-side cross-tenant leakage across a running
  process is fixed and verified by tests. Server-side isolation is **unverified** because no FCM
  sender exists in the repo. FCM topic membership is not an authorization boundary.

---

## B. Baseline findings

All findings were established against the pre-fix code at **HEAD `c1f441e`**, where
`NotificationService.subscribeToShop()/unsubscribeFromShop()` read `ShopManager.shopId`
implicitly and `AuthProvider._clearSession()` reset `ShopManager` **before** calling the
unsubscribe.

### Finding A — Previous topic remains subscribed (D2) — CONFIRMED

- **Evidence (pre-fix source, `git show HEAD:lib/providers/auth_provider.dart`):**
  - `_clearSession()` order: `shopId = null; role = ...; ShopManager.reset();` **then**
    `_unsubscribeShopNotifications()` → `NotificationService.unsubscribeFromShop()` read
    `ShopManager.shopId == null` → early `return` → **no-op**.
  - `_applySession()` on an account/shop change (non-null uid) only called
    `_subscribeShopNotifications()`; **no unsubscribe of the previous topic anywhere**.
- **Consequence:** After A→B or a stream sign-out (`_onAuthChanged(null)` → `_applySession(null)`
  → `_clearSession()`), the device could remain subscribed to Shop A's topic → cross-tenant push
  leakage. Explicit `signOut()` was unaffected because it unsubscribed *before* `_clearSession()`
  (but only while online).
- **Reproduction:** The new tests reproduce the pre-fix behavior by construction — see §E
  (A2/A3/A4 assert the unsubscribe that the old code never issued).

### Finding B — No subscription recovery on reconnect (D1) — CONFIRMED

- **Evidence:** `ConnectionProvider` (`lib/providers/connection_provider.dart`) handled only
  connectivity state and `FirebaseFirestore.instance.waitForPendingWrites()`. It had no FCM hook;
  nothing re-issued `subscribeToShop` on the offline→online edge.
- **Consequence:** A user who started offline received no shop pushes until the next app launch.
- **Reproduction:** Covered by B1/B5/B6 in §E (and PHASE 4.6 on-device evidence: no retry after
  airplane-off).

### Finding C — Pending subscription races — CONFIRMED

- **Evidence:** In the PHASE 4.6 fix, `_applySession` fired `unawaited(_subscribeShopNotifications())`
  while `_clearSession()`/`signOut()` issued an independent unsubscribe. There was **no ordering**
  between them, so a late-completing subscribe for the previous tenant could land *after* the
  unsubscribe and silently re-subscribe it.
- **Reproduction:** C1–C7 in §E hold operations open with `Completer`s and assert ordering and
  final state.

**Root cause (common to A/C):** topic identity was read from mutable global state
(`ShopManager.shopId`) instead of being an explicit, validated argument, and no component tracked
the topic *actually* subscribed to or serialized transitions.

---

## C. Implementation summary

### Files changed
| File | Status | Change |
|------|--------|--------|
| `lib/services/notification_service.dart` | tracked, modified | `subscribeToShop(String)` / `unsubscribeFromShop(String)` now take the topic explicitly and return `Future<bool>` (success); `ShopManager` dependency removed; 5 s bound retained |
| `lib/providers/auth_provider.dart` | tracked, modified | Confirmed-topic tracking, FIFO transition queue, session-generation guards, unguarded sign-out cleanup, `reconcileShopTopic()`, `signOut()` decoupled from FCM |
| `lib/providers/connection_provider.dart` | untracked (PHASE 4.5), modified | Added `onReconnected` callback invoked on the offline/sync-error → online edge |
| `lib/app.dart` | tracked, modified | Wires `ConnectionProvider(onReconnected: auth.reconcileShopTopic)` |
| `test/auth_startup_test.dart` | tracked, modified | Updated injection signatures to the new `Future<bool> Function(String)` type (PHASE 4.6 tests preserved) |
| `test/fcm_topic_lifecycle_test.dart` | **new**, untracked | 23 deterministic lifecycle/reconnect/race/regression tests |
| `PHASE4_7_REPORT.md` | **new**, untracked | this report |

### Design decisions and state ownership
- **One owner of tenant identity:** `AuthProvider` (session owner). `NotificationService` is a
  thin transport that never reads global state.
- **One source of truth for subscription state:** `AuthProvider._confirmedTopic` — the topic the
  device is *confirmed* subscribed to. It is set only after `subscribeToShop` returns success and
  cleared only after `unsubscribeFromShop` returns success. `null` = unknown (fresh start).
- **One serialization mechanism:** `AuthProvider._topicQueue`, a FIFO chain. Every transition
  appends a reconcile-to-a-target operation; because operations are ordered, a late subscribe for
  a previous tenant can never survive a later sign-out/switch.
- **No second mutable source of truth** for the topic: `ShopManager.shopId` is still used for
  data-scoping, but it is no longer consulted to decide which topic to (un)subscribe.

### Topic tracking strategy (Objective 1)
- Confirmed topic is tracked **independently of `ShopManager`**, updated only on operation
  success, never on "operation started".
- On startup the state is **unknown** (`null`); the first reconcile subscribes the current
  validated shop (idempotent), which is the safe convergence.
- Topic ids are derived from `resolveShopForUser(uid)`, i.e. the server-authorized shop
  membership (`firestore.rules`), never from user input.
- No tokens, payloads, or PII are logged; only the topic id and error text on failure.

### Tenant-switch behavior (Objective 2)
- A→B enqueues `reconcileTo(B)`: it first unsubscribes the confirmed previous topic `A`
  (best-effort) and only then subscribes `B`.
- If the unsubscribe does **not** complete, subscribing `B` is **deferred** — the code prefers
  "still subscribed to old tenant" over "subscribed to two tenants at once" (cross-tenant
  delivery). A later reconcile retries the whole step.
- The old topic is never guessed from `ShopManager`; it is the recorded confirmed topic.

### Sign-out & auth-stream cleanup (Objective 3)
- Both explicit `signOut()` and stream `_onAuthChanged(null)` funnel through `_applySession(null)`
  → `_clearSession()`, which enqueues `reconcileTo(null)` **without** a generation guard so it
  always runs, and always after any in-flight subscribe.
- Local session cleanup (shopId/role/ShopManager) is synchronous and does not wait on FCM.
- **Decoupling limitation (documented):** local sign-out completes immediately; the remote
  unsubscribe is best-effort and may fail while offline. On the next reconnect the app retries it
  (because `_confirmedTopic` is retained in memory). FCM membership is **not** removed by the
  local sign-out alone.

### Reconnect recovery (Objective 4)
- `ConnectionProvider` invokes `onReconnected` exactly once per offline/sync-error → online edge
  (its existing status guard prevents duplicate firings), then proceeds with its Firestore flush.
- The callback is `AuthProvider.reconcileShopTopic()`, which re-reads `shopId` and the current
  session generation at execution time. Signed-out / unknown-shop / stale-generation calls are
  no-ops or reconcile to `null`.
- Already-subscribed sessions are a no-op (confirmed-topic check), so reconnect does not
  re-subscribe on every connectivity event.
- Retry policy: **bounded by reconnect edges**, no periodic timer (avoids retry storms). A single
  timed-out subscribe is retried on the next reconnect.

### Concurrency and timeout strategy (Objective 5)
- FIFO queue + per-session generation guard + `desired`→`confirmed` reconciliation.
- `Future.timeout(5s)` in `NotificationService` is a **client-side** bound only. The implementation
  is explicit that a timeout is **not** proof the underlying Firebase op failed: a timed-out
  subscribe leaves `_confirmedTopic == null` and is retried, and a timed-out unsubscribe leaves the
  topic confirmed so a future reconcile retries it (the SDK provides no cancellation here).
- Invariants enforced: signed-out sessions never initiate a subscription; stale sessions cannot
  subscribe a previous tenant; a successful B transition cannot leave A marked; duplicate
  reconnect events do not create duplicate calls; a timeout is not treated as definitive;
  subscription failure never blocks init or cached reads; tenant identity always comes from
  validated auth state.

### Responsive offline sign-out (Objective 6)
- `signOut()` now calls `AuthService.signOut()` and then `_applySession(null)`; it **does not**
  await the FCM unsubscribe. The generation is bumped immediately (invalidating pending
  transitions) and the unsubscribe runs on the background queue.
- Unavoidable limitation (documented): with no network, server-side topic removal cannot be
  guaranteed at sign-out time; it is retried on the next reconnect.

---

## D. Security assessment

### Verified
- **Topic ids come from validated authorization.** The topic string is the shop document id
  returned by `FirestoreService.instance.resolveShopForUser(uid)`; membership is derived
  server-side by `firestore.rules`. The client does not accept a topic from user input.
- **No sensitive data in the client's logging.** `NotificationService` logs only the topic id and
  the error string on failure. `getToken()` exists but is not logged. No payloads/tokens/PII.
- **No in-repo server-side sender to spread sensitive payloads.** `functions/src` contains
  business logic (join, booking, pricing, coupons, payments) with **no** `firebase-admin`
  messaging, no `sendToTopic`/`sendMulticast`, no topic publish. (Grep across the repo for
  `sendToTopic|subscribeToTopic|admin.messaging|firebase-admin/messaging` finds matches only in
  the Flutter client and reports.)

### Theoretical / unresolved (NOT verifiable from this repo)
- **FCM topic membership is not an authorization boundary.** Any client can call
  `subscribeToTopic("<any-shop-id>")`; the SDK does not check tenant membership. Therefore, *if*
  a sender outside this repository publishes tenant-sensitive payloads to `shopId` topics, a
  malicious client that knows a shop id could receive them. This **cannot** be fixed by the
  client-side unsubscribe work in this phase; it requires server-side authorization on the send
  path (per-tenant recipient selection, e.g. targeted device tokens behind an authorized
  callable) or a non-topic design.
- **Whether a sender exists elsewhere** (another deploy target / external service) is unknown. If
  it exists, its payload sensitivity and tenant-authorization were **not** reviewed.
- **No verified vulnerability in this repo** was found, because there is no send path here.
  Distinguishing honestly: this is an **unresolved question + latent risk**, not a demonstrated
  exploit in the reviewed code.

### Remaining security limitations
- While offline after a shop switch or sign-out, the device may remain subscribed to the previous
  topic until it next reaches the network (client cannot unsubscribe offline).
- If the process is killed while offline after such a transition, `_confirmedTopic` (in-memory) is
  lost, so a *future* process cannot identify and clean up a stale prior-process subscription
  (see §G).
- Backend notification delivery was **not** redesigned (out of scope per the brief).

**Proposed separately-scoped backend remediation:** implement/locate the sender, ensure it only
publishes to a topic it is authorized to target, ensure payloads contain no more than a
non-sensitive reference (and are fetched under rules by the client), and prefer per-user/per-token
targeting behind an authenticated callable over shared topic strings for sensitive data.

---

## E. Test evidence

### New tests — `test/fcm_topic_lifecycle_test.dart` (23 tests, all passing)
Deterministic: FCM is replaced by a recording fake with controllable `Completer`s; connectivity by
a hand-driven `ConnectivitySource`. No Firebase, no network, no arbitrary real-time delays.

**Group A — topic lifecycle (9):** A1 initial subscribe+confirm; A2 A→B unsub-then-sub; A3
sign-out unsubscribes A; A4 auth-stream sign-out path; A5 re-auth same shop; A6 offline switch
keeps old topic until removed (no double subscription); A7 unsubscribe failure does not clear the
local session; A8 subscribe failure non-fatal; A9 unknown initial state converges.

**Group B — reconnect recovery (6):** B1 offline→online reconciles current shop; B2 reconnect
while signed out → no subscription; B3 reconnect with unknown shop → no subscription; B4 duplicate
connectivity events do not duplicate recovery; B5 failed subscription retried; B6 reconnect after
an offline switch targets only the current shop.

**Group C — races (7):** C1 pending A subscribe cannot survive a switch to B; C2 pending subscribe
cleaned up by sign-out; C3 new subscribe does not begin until the unsubscribe completes; C4 late A
subscribe corrected by a re-login to C; C5 a stale callback cannot change the active topic; C6 a
timed-out subscribe is retried (not treated as definitive); C7 duplicate reconciles do not
double-subscribe.

**Group D — regression (1):** a never-completing subscribe does not stall session init (the
offline-startup guard remains intact with the new queue).

Each test asserts both the **calls made to the notification service** (`subscribeCalls` /
`unsubscribeCalls` / interleaved `events`) and the **final confirmed/session state**
(`confirmedTopic`, `shopId`, `initializing`).

### Regression tests preserved and run
`test/auth_startup_test.dart` (offline startup; injection signatures updated to the new
`Future<bool> Function(String)` type), `test/phase4_2_session_isolation_test.dart`,
`test/phase4_1_authorization_test.dart`, `test/connectivity_offline_test.dart`, and the rest of
the suite.

### Commands executed (actual results)
| Command | Result |
|---------|--------|
| `flutter analyze` | **No issues found!** (exit 0) |
| `flutter test` | **139 passed** (exit 0) — 116 prior + 23 new |
| `flutter build apk --debug` | **Built** `build\app\outputs\flutter-apk\app-debug.apk` (exit 0) |
| `npm run test:unit` (functions/) | **68 passing** (exit 0) — run for completeness; no backend code changed |

### Device verification (partial — no authorized non-production Firebase project)
- Built/installed the debug APK on AVD `Medium_Phone_API_36` (x86_64) and launched it in
  **airplane mode**.
- Widget-tree dump via the Dart VM service (`ext.flutter.debugDumpApp`):
  `RootGate → LoginScreen`, with `_InheritedProviderScope<AuthProvider?>` and
  `_InheritedProviderScope<ConnectionProvider?>` present. **No Dart exception** — confirms the new
  `app.dart` `context.read<AuthProvider>()` wiring works at runtime and the offline-startup fix is
  not regressed.
- The app was stopped and the emulator shut down afterwards.

### Tests NOT performed (and why)
- **Real Firebase topic membership** (online login to Shop A → subscribe → switch → verify old
  topic removed): requires an **authorized non-production** Firebase project and test accounts,
  which are not available. The brief forbids testing this against production. Not attempted.
- **Server-side membership verification:** no way to observe server-side topic membership without
  an authorized environment; and there is no sender in-repo.
- **iOS:** not possible on this Windows host.
- **Backend rules/integration emulator suites** (`test:rules`, `test:integration`): not run —
  require Java + emulator and no backend code was changed this phase. Only `test:unit` was run.

---

## F. Changed-file inventory

### Tracked files modified (PHASE 4.7 + preserved uncommitted PHASE 4.6)
| File | Notes |
|------|-------|
| `lib/services/notification_service.dart` | PHASE 4.6 fix preserved; API changed to explicit topic + `Future<bool>` |
| `lib/providers/auth_provider.dart` | PHASE 4.6 fix preserved; topic queue/confirmed-topic/reconcile/sign-out added |
| `lib/app.dart` | `ConnectionProvider(onReconnected: …)` wiring |
| `test/auth_startup_test.dart` | PHASE 4.6 tests preserved; signatures updated |

`git diff --stat` (vs HEAD `c1f441e`): 4 files changed, 213 insertions(+), 38 deletions(-).

### New files (untracked)
- `test/fcm_topic_lifecycle_test.dart` (PHASE 4.7)
- `PHASE4_7_REPORT.md` (this report)
- `lib/providers/connection_provider.dart` was created in PHASE 4.5 (untracked) and **modified**
  this phase (added `onReconnected`).

### Pre-existing changes preserved
All PHASE 4.5 / 4.6 untracked files (reports, `connectivity_source.dart`,
`connection_banner.dart`, `data_state_view.dart`, other test files) are **untouched** apart from
`connection_provider.dart`. No pre-existing user change was reset, discarded, overwritten, or
reformatted. No unrelated file was modified.

---

## G. Remaining issues / follow-up

1. **No persistence of the confirmed topic.** `_confirmedTopic` is in-memory. If the app is killed
   while offline after a switch/sign-out whose unsubscribe failed, a future process cannot identify
   the stale subscription. (Within a running process, reconnect retries the unsubscribe.)
   *Follow-up:* persist the confirmed topic (e.g. `SharedPreferences`) and reconcile it on startup,
   or accept that FCM token lifecycle / uninstall eventually clears it. Not implemented to avoid a
   second source of truth in this phase.
2. **No periodic retry.** Recovery is driven by connectivity edges only; if the OS does not emit a
   connectivity transition when connectivity actually returns (e.g. captive portal), a subscribe
   could wait until the next in-session transition. *Follow-up:* optionally add a bounded,
   backoff-scheduled retry owned by the auth/session layer.
3. **Offline sign-out cannot guarantee server-side removal** (documented behavior).
4. **Backend send-path authorization is unverified** — requires locating/adding the sender and
   scoping a backend remediation (§D).
5. **Manual end-to-end topic verification** on an authorized non-production Firebase project
   remains to be done (Objective 7 steps 1–10).

Nothing in this phase is a blocker for merging the *client* lifecycle fix; the limitations above
are inherent to client-side FCM semantics and to the absence of an authorized test environment.

---

## H. Final safety statement

This phase **did not**:
- commit, push, deploy, or sign a release build (working tree left uncommitted as required);
- change any Firebase production configuration or `firestore.rules`;
- create, edit, or delete any production customer, appointment, payment, shop, or other operational
  record;
- send any real push notification or alter any Firebase production topic membership;
- run any destructive Git command (`reset --hard`, `clean`, indiscriminate checkout/restore);
- modify any pre-existing user change outside the files listed in §F.

The only runtime execution on a device was a debug build launched in **airplane mode with no
authenticated session**, which performs **no** FCM topic subscription (verified: tree reached
`LoginScreen`, no subscribe call, no session). The emulator was shut down afterwards.

Manual Firebase topic-membership verification was **not** performed because no explicitly
authorized non-production Firebase project/account is available; testing against production was
deliberately avoided.

---

## Final response summary

1. **Verdict:** PASS WITH LIMITATIONS.
2. **Root causes addressed:** implicit topic-from-`ShopManager` + reset-before-unsubscribe (D2);
   no reconnect hook (D1); unbounded/blocking sign-out (D3); unordered subscribe/unsubscribe races.
3. **Files changed:** `notification_service.dart`, `auth_provider.dart`, `connection_provider.dart`,
   `app.dart`, `test/auth_startup_test.dart`; new `test/fcm_topic_lifecycle_test.dart` and
   `PHASE4_7_REPORT.md`.
4. **Tests executed:** `flutter analyze` (clean), `flutter test` (**139 passed**),
   `flutter build apk --debug` (built), `npm run test:unit` (**68 passing**); device smoke
   (offline `RootGate → LoginScreen`). Real topic-membership device tests **not** run (no authorized
   non-prod project).
5. **Tenant-isolation risks remaining:** yes — client-side leakage is fixed within a process, but
   offline sign-out cannot guarantee server-side removal, and the server-side send-path
   authorization is unverified (no sender in-repo).
6. **Production environment/data touched:** **none.**
7. **Report path:** `C:\Users\HP\Desktop\barber\PHASE4_7_REPORT.md`.
8. **Blocking issue requiring human approval:** decide whether to (a) persist the confirmed topic,
   (b) add a bounded scheduled retry, and (c) scope the backend send-path authorization review;
   and provide an authorized non-production Firebase project to complete Objective 7.
