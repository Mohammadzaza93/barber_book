# PHASE 4.10 — Authorized FCM Environment Setup & Sender Authorization Verification

**Repository:** `C:\Users\HP\Desktop\barber`
**Branch / HEAD (verified):** `main` @ `17046963ac1fe7591604490bec44bfa84befe075`
**Starting HEAD (as given):** `17046963ac1fe7591604490bec44bfa84befe075` — matches.
**Previous phase:** PHASE 4.9 — PASS WITH LIMITATIONS
**Mode:** Security investigation and controlled non-production verification

**Overall verdict: PASS WITH LIMITATIONS — with two BLOCKED objectives** (FCM sender authorization
verification and FCM end-to-end delivery isolation). All local regression gates were re-run and pass.
The project is **NOT production-ready** while the push-delivery tenant boundary remains unverified.

---

## 1. Executive verdict

| Area | Status |
|------|--------|
| Sender discovery (Objective A) | **PASS** (evidence gathered; result: no sender in this repository) |
| Sender authorization review (Objective B) | **BLOCKED** — no authorized sender source provided |
| Non-production readiness (Objective C) | **BLOCKED** — no explicit authorization/credentials provided |
| Controlled end-to-end validation (Objective D) | **BLOCKED** — no authorized environment; not simulated |
| Regression gates (Objective E) | **PASS** — all six checks re-run, green |
| Release-gate decision (Objective F) | **PASS WITH LIMITATIONS** — critical boundary unverified |

The investigation resolved the *discovery* question with evidence but could not resolve the
*authorization* question: **no notification sender exists anywhere in this repository or any of its
branches**, and no external sender was made available for review. Per the constraints, this is
reported as **NOT VERIFIED OUTSIDE THIS REPOSITORY** — not as "no sender exists anywhere." Testing
was not simulated with unit tests or emulator results.

---

## 2. Git state — initial and final (work preserved)

| Item | Initial | Final |
|------|---------|-------|
| Branch | `main` | `main` |
| HEAD | `1704696` | `1704696` (unchanged) |
| Tracked modified | `lib/providers/auth_provider.dart` | `lib/providers/auth_provider.dart` (same) |
| Stash | `stash@{0}` (WIP on `cfb6394`) | `stash@{0}` (untouched) |
| Untracked reports/tests/widgets | full PHASE set | same set + new `PHASE4_10_REPORT.md` |

**Evidence of preservation:**
- `git diff --name-only` before and after = exactly `lib/providers/auth_provider.dart` (the
  pre-existing, uncommitted PHASE 4.8 retry change).
- `git stash list` unchanged (one stash, never touched).
- `git rev-parse HEAD` unchanged; no commit, merge, tag, push, deploy, or release-sign was performed.
- All PHASE reports (`PHASE4_1`…`PHASE4_9`, `PHASE4_REPORT`) remain present and were not overwritten.
- The only new artifact is `PHASE4_10_REPORT.md`; the only side effect is the git-ignored
  `firestore-debug.log` from the emulator runs.

No `git reset --hard`, no `git clean`, no broad checkout/restore was used.

---

## 3. Sender discovery evidence and unresolved ownership (Objective A)

### 3.1 Evidence gathered (all VERIFIED)

| Probe | Command | Result |
|-------|---------|--------|
| Sender primitives in all branch histories | `git log --all -S"sendToTopic"` / `-S"sendMulticast"` / `-S"admin.messaging"` / `-S"messaging().send"` | **empty** (0 commits each) |
| Sender primitives across every ref | `git grep -i -E "firebase-admin/messaging\|sendToTopic\|sendMulticast\|admin\.messaging\|messaging\(\)"` over all heads/remotes | **no matches** |
| External service endpoints | grep `cloudfunctions.net\|run.app\|.webhook\|https://hooks\|sendgrid\|twilio\|mailgun` in working tree | **no matches** |
| Backend callables | `functions/src/index.js` | exactly 4: `joinShopByCode`, `createAppointment`, `updateAppointment`, `deleteAppointment` |
| `reminder` action | `functions/src/index.js:650-660` | sets `reminderSent: true` + `reminderSentAt` only — **no send** |
| CI / containers / extensions | repo scan | none (`.github` absent; no Dockerfile; no Firebase Extensions) |
| Firebase project(s) referenced | `.firebaserc`, `android/app/google-services.json`, `lib/firebase_options.dart` | only `barber-book-lycb` (web/macos are placeholders) |
| Emulator project | `functions/package.json` | `demo-barberbook` (Firestore only) |
| Client integration point | `lib/services/notification_service.dart:83-109`; `AuthProvider` | `subscribeToTopic(shopId)` / `unsubscribeFromTopic(shopId)` |
| Platform push wiring | Android: `firebase_messaging ^15.1.5` (plugin manifest); iOS: **no** `Runner.entitlements`, **no** `aps-environment`, **no** remote-notification background mode | Android-only capability; iOS push not configured |

### 3.2 Conclusion

- **VERIFIED:** this repository (all branches + history) contains **no FCM sender** and references no
  external notification service.
- **NOT VERIFIED OUTSIDE THIS REPOSITORY:** whether a sender exists in another repository/cloud
  project. Nothing in the evidence rules this out; it was simply not observable.
- **INTENDED but absent:** the README states (Arabic) that *"Firebase Cloud Messaging remains
  available for notifications coming from the server"* — i.e. a server sender is anticipated, but
  none is implemented or documented here.

### 3.3 Unresolved ownership questions

- Which service/repository (if any) sends push notifications?
- Which cloud project does it run in, and who owns it?
- How does that sender authenticate, and does it authorize each tenant before sending?
- Does it target shared topics (`shopId`), individual device tokens, or something else?
- Which cloud project holds production data (is `barber-book-lycb` production)?

### 3.4 Minimum human-provided information required

1. **Yes/no:** is any notification sender deployed anywhere for this app?
2. If yes: its **repository**, **cloud project id**, and **owner/team**.
3. If yes: confirmation that its source may be reviewed read-only (Objective B).

---

## 4. Sender authorization findings (Objective B)

**Status: BLOCKED.** No sender source was made available, so none of the required checks could be
performed:

| Required check | Status |
|----------------|--------|
| Trace authenticated caller / trusted event → recipient selection → FCM send | BLOCKED |
| Tenant authorization enforced **on the server** before sending | BLOCKED |
| Caller cannot select arbitrary tenant topics/tokens without server authorization | BLOCKED |
| Payload review for cross-tenant data exposure | BLOCKED |

No claim is made that the sender is secure or insecure. **FCM topic membership, client UI checks, and
knowledge of a shop ID are explicitly not treated as authorization.** The client-side topic pipeline
remains a *receiver* concern only.

---

## 5. Non-production environment authorization and readiness (Objective C)

**Status: BLOCKED.** No explicit authorization was provided for any of the required items:

| Required authorization | Provided? |
|------------------------|-----------|
| Dedicated non-production Firebase project | ✗ not provided |
| Test-only flavor/config that cannot silently point to production | ✗ not provided |
| Two synthetic test accounts + two isolated test shops | ✗ not provided |
| Permitted sender / approved test mechanism | ✗ not provided (creating/deploying one is forbidden here) |
| Project permissions + test devices/emulators | ✗ not provided |

The only configured project is `barber-book-lycb`, whose production status is **NOT VERIFIED**; per
constraint 4 it was not used for any testing. The Firestore emulator (`demo-barberbook`) verified
rules/business logic only and **cannot** verify FCM (no Cloud Messaging emulator exists).

### Proposed change plan (awaiting explicit approval — not executed)

1. Create a **new** Firebase project, e.g. `barberbook-fcm-dev` (Blaze only if a Functions sender is
   required).
2. Register an Android app with a **test-only applicationId** (e.g. `…barberbook.dev`) and a
   **test flavor** in `android/app/build.gradle`; add a `google-services.json`/`firebase_options`
   for that flavor. **Never overwrite** the production config.
3. Create two Email/Password test users and two shops; obtain shop ids (`shop-A`, `shop-B`).
4. Provide an **approved sender**: a minimal authenticated callable publishing only to an authorized
   topic (or use the FCM console for receiver-side checks).
5. Grant Owner/Editor access, devices/emulators, and FCM delivery-report visibility.
6. Only then run the Objective D matrix.

---

## 6. End-to-end tests performed / blocked (Objective D)

**Status: BLOCKED.** No E2E test was performed. No authorized non-production environment or sender
was available, and creating/deploying a sender is prohibited without authorization.

Explicitly **not** performed (and not simulated):

| Test | Status |
|------|--------|
| Shop A / Shop B separate authenticated instances | BLOCKED |
| A→B and B→A delivery-isolation assertion | BLOCKED |
| Sign-out while offline + reconnect recovery (on device, with real FCM) | BLOCKED (client lifecycle is unit-tested, not E2E) |
| Shop switching with real topic delivery | BLOCKED |
| Process termination during a transition | BLOCKED |
| Server-side authorization proof (independent of client logs) | BLOCKED |

No device/iOS/FCM end-to-end coverage is claimed. Emulator rules/integration results are **not**
substituted for E2E.

---

## 7. Regression commands, results, exit statuses (Objective E)

All commands re-run this phase on the local declared toolchain (Flutter 3.27.2 / Dart 3.6.1;
Node v26.1.0; npm 11.13.0; Firebase CLI 15.25.1; Firebase emulator JDK resolved from Android Studio
JBR OpenJDK 25 — the preflight accepts JDK ≥21).

| # | Command | Localisation | Actual result | Exit |
|---|---------|--------------|---------------|------|
| 1 | `flutter analyze` | repo root | **No issues found!** | 0 |
| 2 | `flutter test` | repo root | **143 passed** | 0 |
| 3 | `flutter build apk --debug` | repo root | **Built** `build\app\outputs\flutter-apk\app-debug.apk` | 0 |
| 4 | `npm run test:unit` | `functions/` | **68 passing** | 0 |
| 5 | `npm run test:rules` | `functions/` (Firestore emulator, `demo-barberbook`) | **33 passing** | 0 |
| 6 | `npm run test:integration` | `functions/` (same emulator) | **75 passing** | 0 |

**Skipped / not applicable:** iOS build & device tests (Windows host, no iOS toolchain); real FCM
end-to-end (no environment).

**Harness note (for transparency):** one earlier attempt ran commands #5 and #6 **concurrently**; both
start a Firestore emulator on the same port, so #6 failed with a port/hub collision (non-zero exit, no
test failures reported). Re-run **sequentially**, #6 passed **75 passing (36s), exit 0**. The failure
was an environment/harness artifact, not a test regression.

---

## 8. Risk register (severity, evidence, remediation owner)

| ID | Severity | Risk | Evidence | Remediation owner |
|----|----------|------|----------|-------------------|
| R1 | **HIGH (conditional)** | If an external sender publishes tenant-sensitive payloads to `shopId` topics, any client knowing a shop id can subscribe and receive them (topic membership is not an authZ boundary) | `notification_service.dart:83-109`; FCM semantics | Sender owner (unknown) — **needs identification first** |
| R2 | **MEDIUM** | Push feature incomplete/unverified: no in-repo sender; delivery cannot be demonstrated | §3 | App owner |
| R3 | **MEDIUM** | Offline sign-out or process-kill after a failed unsubscribe can leave a stale subscription (no persistence by design) | `auth_provider.dart`; PHASE 4.8 §E | App developer |
| R4 | **LOW** | Bounded retry exhaustion leaves the current topic unsubscribed until the next session/connectivity edge | PHASE 4.8 §F | App developer |
| R5 | **LOW** | Real Firebase client config for `barber-book-lycb` committed in a public repo (client API keys are public identifiers, not secrets, but project metadata is exposed) | `google-services.json`, `firebase_options.dart` | App owner |
| R6 | **LOW** | iOS push capability not configured (no entitlements/APS/background mode) → server push would not work on iOS | iOS `Runner` config | App owner |
| R7 | **LOW** | Local Node v26 vs declared engine `node: "22"` (functions run on Firebase Node 22; local only affects tests) | `functions/package.json` | App developer |

Production-readiness blocker: **R1/R2** (push-delivery tenant boundary unverified).

---

## 9. Five-perspective assessment

- **QA Tester:** All six local suites pass (143 / 68 / 33 / 75; analyze clean; APK built). Coverage
  gap is FCM end-to-end — no environment, no sender → **BLOCKED**, not "passed". Watch the emulator
  port-collision artifact when parallelizing.
- **Flutter/Firebase Developer:** Client receiver pipeline is hardened (PHASE 4.7/4.8) and unit-tested;
  config points at `barber-book-lycb`; iOS push is unconfigured; the Firestore emulator cannot test
  FCM; rules/integration suites require a JDK on PATH (JBR 25 works).
- **End User:** Local reminders work, device-scoped. Server-sent push is unverified; if an
  unauthorized sender exists, a device could receive another tenant's pushes (R1). On iOS, server push
  would not currently arrive (R6).
- **App Administrator:** Data-plane roles are rule-enforced and emulator-verified; membership is only
  granted by `joinShopByCode` at the lowest role; clients cannot forge/promote. Good.
- **Project Manager:** Code quality and data authorization are release-grade; **two blockers** remain
  before broader testing: (a) identify/authorize the notification sender, (b) provide an authorized
  non-production Firebase project. Do **not** treat green tests as production readiness.

---

## 10. Explicit human decisions still required

1. **Sender:** confirm whether any push sender is deployed; if so, provide its repo/project/owner for
   a read-only authorization review (Objective B). If none, decide to remove/disable FCM topic
   subscription or authorize building a sender.
2. **Non-production environment:** approve the §5 change plan (project, test flavor, accounts, shops,
   sender, permissions, devices) so Objective D can proceed.
3. **Production status of `barber-book-lycb`:** confirm whether it holds real data (blocker for any
   test use).
4. **Uncommitted change:** decide whether to commit the PHASE 4.8 `lib/providers/auth_provider.dart`
   retry change (intentionally left uncommitted).
5. **Hardening (separate scope):** API-key restrictions / App Check; and whether to replace
   shared-topic delivery with per-token targeting behind an authenticated callable.
6. **iOS:** decide whether to configure push entitlements, or formally scope the app to Android push.
7. **Report approval:** approve this BLOCKED/limited verdict and the mandated stop on Objectives B/D
   pending the above.

---

## 11. Release-gate decision matrix (Objective F)

| Dimension | Status | Basis |
|-----------|--------|-------|
| Flutter / code quality | **PASS** | analyze clean; 143 tests; debug APK builds |
| Firestore data authorization | **PASS** | 33 rules + 75 integration tests (emulator) |
| FCM sender authorization | **BLOCKED** | no sender source available |
| Actual push-delivery isolation | **BLOCKED** | no authorized environment |
| Offline / session recovery | **PASS WITH LIMITATIONS** | deterministic unit tests; no device/FCM E2E |
| Android device validation | **NOT PERFORMED** | no device run this phase |
| iOS device validation | **BLOCKED** | no iOS toolchain/host; push unconfigured |
| Non-production environment readiness | **BLOCKED** | not authorized/provided |
| **Production readiness** | **NOT READY** | critical tenant-isolation boundary (push delivery) unverified; passing tests are not sufficient |

**Overall phase status: PASS WITH LIMITATIONS.** The discover/report/gate deliverables are complete
and green; the security objective (sender authorization + delivery isolation) is **BLOCKED** and was
not guessed or simulated.

---

## 12. Final response summary

- **Verdict:** PASS WITH LIMITATIONS; Objectives B and D **BLOCKED**.
- **Objective A:** sender discovery complete — **no sender in this repo or any branch**; result is
  **NOT VERIFIED OUTSIDE THIS REPOSITORY**; minimum human inputs requested (§3.4).
- **Objective B:** BLOCKED (no sender source).
- **Objective C:** BLOCKED (no authorization); proposed change plan only, nothing executed.
- **Objective D:** BLOCKED; no E2E performed or simulated.
- **Objective E:** all six gates re-run green (143 / 68 / 33 / 75; analyze clean; APK built; one
  concurrent-run port collision noted and resolved by sequential re-run).
- **Objective F:** matrix above; **production readiness NOT established**.
- **Safety:** no production data/config/rules changed; no secrets printed; no Git history/deployment
  modified; all pre-existing work and the stash preserved.
- **Report path:** `C:\Users\HP\Desktop\barber\PHASE4_10_REPORT.md`.
