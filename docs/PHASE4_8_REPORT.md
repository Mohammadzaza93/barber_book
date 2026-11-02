# PHASE 4.8 — Notification Architecture Security Review & Topic-Lifecycle Closure

**Repository:** `C:\Users\HP\Desktop\barber`
**Branch / base:** `main`, HEAD `1704696` ("FCM Topic Lifecycle & Tenant Isolation Hardening")
**Reviewed tree:** working tree with all PHASE 4.5/4.6/4.7 untracked files **preserved**.
**Verdict: PASS WITH LIMITATIONS**

The notification surface was reviewed end to end. There is **no server-side FCM sender in this
repository**, so no demonstrated exploit exists in the reviewed code — but server-side tenant
authorization for push **cannot be verified here** and remains a latent risk (Objective A, §I).
On the client side, the one lifecycle gap left open by PHASE 4.7 (a switch that defers the new
subscription when the old unsubscribe fails, with no retry if no reconnect edge ever fires) was
**closed with a bounded in-session retry**, covered by new deterministic tests. The remaining
limitations are inherent to client-side FCM semantics and the absence of an authorized
non-production Firebase environment.

---

## A. Executive summary

- **Verdict:** **PASS WITH LIMITATIONS.**
- **Objective A (architecture / sender inventory):** **VERIFIED** that the repo contains **no FCM
  sender**. `functions/src/index.js` exports exactly four `onCall` functions
  (`joinShopByCode`, `createAppointment`, `updateAppointment`, `deleteAppointment`); none imports
  `firebase-admin/messaging` and none calls `sendToTopic`/`sendMulticast`/`admin.messaging`. No CI
  workflow, Dockerfile, Firebase Extension, or other deployable JS/TS exists in the repo.
  `.firebaserc` project = `barber-book-lycb`; `firebase.json` = firestore/functions(+2 predeploy
  gates)/storage/emulators. → **Server-side tenant authorization: NOT VERIFIED (no send path in
  repo).**
- **Objective B (client topic-lifecycle invariants):** **VERIFIED** for invariants 1–10 as
  implemented in PHASE 4.7, plus 11 (queue deadlock/growth) and 12 (dispose/lifecycle) re-checked
  this phase, with the one retry gap closed (Objective D).
- **Objective C (persist confirmed topic?):** decision — **do NOT implement.** Rationale and risk
  documented in §E.
- **Objective D (bounded retry?):** decision — **implement.** The gap is real and testable; a
  **bounded** (max attempts, linear backoff) in-session retry was added, injectable for tests,
  cancelled on dispose and superseded by any explicit transition.
- **Objective E (authorized non-production end-to-end):** **BLOCKED — SAFE ENVIRONMENT
  UNAVAILABLE.** No authorized non-production Firebase project/test accounts; production use is
  forbidden. Not attempted.
- **Objective F (gates):** all green — `flutter analyze` clean, `flutter test` **143 passed**,
  `flutter build apk --debug` **built**, `npm run test:unit` **68 passing**.

---

## B. Objective A — architecture & sender inventory

### B.1 Evidence (labels: VERIFIED)

| Check | Command | Result |
|-------|---------|--------|
| Sender primitives in backend | grep `sendToTopic\|sendMulticast\|admin.messaging\|firebase-admin/messaging` in `functions/src` | **No files found** |
| Exported callables | grep `exports.<name> =` in `functions/src/index.js` | exactly **4**: `joinShopByCode`, `createAppointment`, `updateAppointment`, `deleteAppointment` |
| Client topic ops | grep `subscribeToTopic\|unsubscribeFromTopic` in `lib` | only `lib/services/notification_service.dart:86,101` |
| CI / containers / extensions | directory/repo scan | none present |
| Firebase config | `.firebaserc`, `firebase.json` | project `barber-book-lycb`; firestore/functions/storage/emulators only (no messaging deploy target) |

`functions/src` is pure business logic (join, booking, pricing, payments, coupons). The only
`reminder`-related server action sets `reminderSent: true`; it does **not** dispatch a push.

### B.2 Interpretation

- **VERIFIED:** no in-repo producer of topic messages → **no demonstrated in-repo vulnerability**
  and no code path here to spread tenant-sensitive payloads.
- **NOT VERIFIED:** whether a sender exists elsewhere (another deploy target / external service) and
  whether it authorizes per-tenant delivery. FCM topic membership is **not** an authorization
  boundary: any client may call `subscribeToTopic("<any-shop-id>")`, and the SDK does not check
  membership. **INFERRED latent risk**, not an observed exploit.
- **Conclusion:** the correct place to enforce push tenant-isolation is the **send path** (server
  authorization, ideally per-token targeting behind an authenticated callable). That is
  **out of scope / not actionable** in this repo until a sender is located or added.

---

## C. Client notification flows (mapped, VERIFIED)

| Flow | Location | Nature |
|------|----------|--------|
| Local appointment reminders | `ReminderService.scheduleLocalReminders` → `NotificationService.scheduleReminder` | Device-local scheduled notification, title `'{shopName} - {customerName}'`, body = appointment/ref. **No FCM, no cross-tenant payload.** |
| Immediate in-app banner | `booking_flow_screen.dart:285` → `NotificationService.instance.show(...)` | Device-local. |
| User-initiated WhatsApp/e-mail | `ReminderService.whatsappUri` / `sendViaWhatsApp` / `sendViaEmail` | Explicit user action carrying PII they choose to send; via `url_launcher`. Not topic-based. |
| FCM topic subscription | `AuthProvider` → `NotificationService.subscribeToShop` | The only FCM membership path (hardened in PHASE 4.7, extended in §F). |
| Init | `main.dart:45` | Permission + foreground stream setup. |

**Topic provenance (VERIFIED):** topic id = `FirestoreService.resolveShopForUser(uid).shopId`
(`firestore_service.dart` → `findShopByOwner` → `getUserProfile(uid).joinedShopId` →
`getMember(joinedShopId, uid)`). It is the server-authorized shop membership, **never** user input.

---

## D. Objective B — topic-lifecycle invariants (re-verified)

| # | Invariant | Status | Where |
|---|-----------|--------|-------|
| 1 | Signed-out sessions never initiate a subscription | VERIFIED | `_applySession(null)` → `_clearSession`, no subscribe; tests A3/A4/B2 |
| 2 | Stale sessions cannot subscribe a previous tenant | VERIFIED | per-transition `generation` guard; tests C4/C5 |
| 3 | Successful switch cannot leave the old topic marked | VERIFIED | reconcile unsub-before-sub; `_confirmedTopic` set only on success; A2 |
| 4 | Duplicate reconnect events do not duplicate recovery | VERIFIED | status edge guard in `ConnectionProvider`; B4 |
| 5 | A timeout is not treated as definitive | VERIFIED | `NotificationService` returns `false` on timeout, never claims success; C6 |
| 6 | Subscription failure never blocks init or cached reads | VERIFIED | fire-and-forget queue; D, A8 |
| 7 | Tenant identity always comes from validated auth state | VERIFIED | `resolveShopForUser`; §C |
| 8 | Never subscribed to two tenants at once | VERIFIED | defer new sub when old unsub fails; A6, B6 |
| 9 | Local sign-out never waits on FCM | VERIFIED | `signOut()` decoupled; A7 |
| 10 | Late subscribe cannot survive sign-out | VERIFIED | unguarded trailing reconcile; C2 |
| 11 | Queue cannot deadlock or grow unboundedly | VERIFIED | FIFO chain; retry enqueues from a `Timer` (not from inside the awaited link) ⇒ no self-wait; growth bounded by `_maxTopicRetries` per explicit transition; E2 |
| 12 | Dispose/lifecycle is safe and cancels pending work | VERIFIED (now) | `dispose()` is idempotent, cancels `_retryTimer` + auth sub; E4 |

---

## E. Objective C — persistence of the confirmed topic: DECISION = do NOT implement

**Decision:** keep `_confirmedTopic` **in-memory**; do not persist it.

**Rationale (justified, documented):**
1. The confirmed topic is a **client belief**, not an authorization boundary. Persisting it would
   create a second source of truth whose staleness is worse than its usefulness: on relaunch we
   still cannot know the *server-side* membership, so the persisted value could be wrong.
2. The **safe convergence already exists**: a fresh start treats the state as `unknown` (`null`)
   and reconciles to the current session's shop (idempotent subscribe). Persisting adds no safety,
   only complexity.
3. Persisting a tenant id to disk adds a small data-at-rest surface for no security benefit.
4. The brief says: no automatic persistence unless justified **and testable**. There is no test
   that demonstrates a concrete harm that persistence fixes (the offline-kill case cannot be
   repaired by the client anyway).

**Documented residual risk (unchanged from 4.7 §G1):** if the process is killed while offline after
a switch/sign-out whose unsubscribe failed, a future process cannot identify the stale
subscription; it is cleared by FCM token lifecycle / reinstall. Accepted.

---

## F. Objective D — bounded retry: DECISION = IMPLEMENT (gap closed)

### F.1 The gap (demonstrated)

`_reconcileTopic` defers the new subscription when the previous unsubscribe fails (isolation over
delivery). PHASE 4.7 retried only on **connectivity edges**. If the device stays *online* while an
FCM op transiently fails (e.g. a 5 s timeout on a slow backend, `connectivity_plus` still reports
wifi), **no edge fires** → the new tenant's topic is never subscribed until the next session change
or relaunch. **Demonstrated** by construction; **testable** — both satisfied.

### F.2 Implementation

`lib/providers/auth_provider.dart` (tracked, +88/−6):

- `_reconcileTopic` now returns `Future<bool>` — `true` = converged, `false` = still unsettled.
- New `_enqueueReconcile(...)` runs the transition and, if **unsettled** and still on the
  **current generation**, calls `_scheduleRetry()`.
- `_scheduleRetry()`: **bounded** by `_maxTopicRetries` (default **3**), linear backoff
  `_topicRetryDelay × attempt` (default base **5 s** → 5/10/15 s). Re-reads `shopId` and the
  generation when the timer fires, so a retry can never target a previous tenant.
- `_scheduleTopicReconcile` (the **explicit** entry point: session transition, `createShop`,
  `joinShopByCode`, reconnect) **cancels** any pending retry and **resets** the retry budget.
- **Only guarded (current-session) transitions retry.** The unguarded sign-out reconcile is left to
  the next session / reconnect edge (it must not be cancelled by, nor interfere with, a newer
  session).
- `dispose()` cancels the retry timer and is now **idempotent** (`_disposed` guard).
- Config is injectable (`topicRetryDelay`, `maxTopicRetries`) so tests use real short timers; the
  production defaults leave existing tests unaffected (a 5 s timer never fires during a test).

### F.3 Why a timer is safe here (invariants #11/#12)

- The retry enqueues a **new** link onto the FIFO queue from a `Timer` callback; it never awaits the
  queue from inside an awaited link → **no deadlock**.
- Retries are bounded per explicit transition → **no unbounded growth / no periodic loop**.
- `dispose()` + explicit-schedule cancellation → **no work after teardown** (test E4).

---

## G. Test evidence

### G.1 New tests — `test/fcm_topic_lifecycle_test.dart` (now **27** tests)

PHASE 4.7's 23 tests are preserved. **Group E — bounded in-session retry (4 new):**

- **E1** a deferred tenant switch converges via the retry alone (no reconnect edge).
- **E2** a persistently failing reconcile retries exactly `maxTopicRetries` times, then gives up
  (verified stable after further waiting).
- **E3** a transient subscribe failure is retried and then confirmed.
- **E4** `dispose()` cancels a pending retry (no ops after teardown).

The `_auth` helper now registers `addTearDown(auth.dispose)`, guaranteeing every retry timer is
cancelled at test end (no leaked timers).

### G.2 Commands executed (actual results)

| Command | Result | Localisation |
|---------|--------|--------------|
| `flutter analyze` | **No issues found!** | repo root |
| `flutter test` | **143 passed** (116 prior + 23 PHASE 4.7 + 4 new) | repo root |
| `flutter test test/fcm_topic_lifecycle_test.dart` | **27 passed** | repo root |
| `flutter build apk --debug` | **Built** `build\app\outputs\flutter-apk\app-debug.apk` | repo root |
| `npm run test:unit` | **68 passing** | `functions/` |

Negative evidence (grep): no `sendToTopic`/`sendMulticast`/`admin.messaging`/`firebase-admin/messaging`
in `functions/src` (§B).

### G.3 Tests NOT performed (and why)

- **Real Firebase topic membership** (online login → subscribe → switch → observe server-side
  removal): requires an **authorized non-production** project + accounts. Not available; production
  forbidden. **BLOCKED.**
- **Server-side membership / send-path authorization:** no sender in-repo and no authorized
  environment → **NOT VERIFIED**.
- **iOS:** impossible on this Windows host.
- **`test:rules`/`test:integration`** (functions): require Java + emulator; **no backend code
  changed** this phase → not run.

---

## H. Objective E — end-to-end (BLOCKED)

**Status: BLOCKED — SAFE ENVIRONMENT UNAVAILABLE.** Performing a genuine end-to-end topic test
would require (a) an authorized **non-production** Firebase project, (b) a second test account able
to join a second shop, and (c) a sender able to publish to a topic to observe delivery — none
exist, and using production is forbidden by the brief. A client-side log assertion would not prove
*server-side* membership, and a mock is not end-to-end. No attempt was made.

---

## I. Security assessment

### Verified
- **No in-repo FCM sender** (Objective A) → no in-repo path to leak tenant-sensitive push payloads.
- **Topic ids derive from server-validated membership** (`resolveShopForUser`), never user input.
- **No secrets/PII in logs:** only topic ids and error strings; `getToken()` is not logged.
- **Client cross-tenant leakage within a running process is prevented** by unsub-before-sub, the
  deferral policy, and the generation-guarded FIFO queue (tests A2/A6/C1–C5).

### Not verified / residual risk
- **Server-side tenant authorization for push is unverified** (no sender in-repo; external sender
  existence unknown). Push could leak across tenants **only if** such a sender exists and does not
  authorize per-tenant delivery. **Latent risk — not a demonstrated in-repo exploit.**
- **Offline transitions:** a device offline at switch/sign-out may remain on the old topic until it
  reconnects (client cannot unsubscribe offline); a process killed offline may leave an
  unidentifiable stale subscription (accepted, §E).
- **FCM membership is not an authorization boundary** — the durable fix belongs on the send path.

**Recommended (separately scoped) backend remediation:** locate/author the sender; publish only to
topics it is authorized to target; keep payloads to a non-sensitive reference fetched under rules;
prefer per-token targeting behind an authenticated callable for sensitive data.

---

## J. Changed-file inventory

### Tracked (modified this phase)
| File | Δ |
|------|---|
| `lib/providers/auth_provider.dart` | +88 / −6 — bounded retry, `_reconcileTopic → Future<bool>`, retry config, idempotent `dispose` |

### Untracked (new / edited, preserved)
- `test/fcm_topic_lifecycle_test.dart` — Group E added (23 → 27 tests); helper disposes providers.
- `PHASE4_8_REPORT.md` — this report.
- All prior untracked PHASE 4.5/4.6/4.7 files and reports: **untouched**.

`git diff --stat` vs HEAD `1704696`: **1 file changed, 88 insertions(+), 6 deletions(-)**.

No pre-existing user change was reset, discarded, overwritten, or reformatted.

---

## K. Remaining issues / follow-up

1. **Server-side send-path authorization unverified** — requires locating/adding the sender and a
   scoped backend review (§I).
2. **End-to-end topic verification on an authorized non-production project** remains **BLOCKED**
   (Objective E).
3. **Offline sign-out cannot guarantee server-side removal** (documented behavior).
4. **No persistence of the confirmed topic** — decision made deliberately (§E).
5. Retry is **bounded** (3 attempts, 5/10/15 s) and restarts on the next session/connectivity
   change; if a longer outage outlasts it, recovery waits for that edge. Accepted by design.

Nothing here blocks merging the client lifecycle work; the limitations are inherent to client-side
FCM semantics and the missing authorized environment.

---

## L. Final safety statement

This phase **did not**:
- commit, push, deploy, or sign a release build (working tree left uncommitted);
- change Firebase production config or `firestore.rules`;
- create, edit, or delete any production record;
- send any real push notification or alter production topic membership;
- subscribe to any unauthorized production topic;
- run any destructive Git command (`reset --hard`, `clean`, indiscriminate checkout/restore);
- print any token/key/service-account JSON/FCM registration token;
- modify any pre-existing user change outside §J.

Only a debug build was produced; **no device run** occurred this phase (no runtime execution).
Manual Firebase topic-membership verification was **not** performed (no authorized non-production
project; production deliberately avoided).

---

## Final response summary

1. **Verdict:** PASS WITH LIMITATIONS.
2. **Objective A:** VERIFIED no in-repo FCM sender (4 callables, no messaging import); server-side
   send-path authorization **NOT VERIFIED** (latent, not a demonstrated exploit).
3. **Objective B:** invariants 1–12 re-verified; the retry gap is the only change required.
4. **Objective C:** decision — **no persistence** (documented rationale + accepted risk).
5. **Objective D:** decision — **implement bounded retry** (default 3 attempts, 5/10/15 s),
   injectable, cancelled on dispose, restart on explicit transition.
6. **Objective E:** **BLOCKED** (no authorized non-production Firebase).
7. **Objective F gates:** `flutter analyze` clean; `flutter test` **143 passed**;
   `flutter build apk --debug` built; `npm run test:unit` **68 passing**.
8. **Files changed:** `lib/providers/auth_provider.dart` (+88/−6);
   `test/fcm_topic_lifecycle_test.dart` (27 tests); new `PHASE4_8_REPORT.md`.
9. **Production environment/data touched:** **none.**
10. **Report path:** `C:\Users\HP\Desktop\barber\PHASE4_8_REPORT.md`.
