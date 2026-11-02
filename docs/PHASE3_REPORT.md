# PHASE 3 REPORT — PRODUCTION READINESS & RELEASE CANDIDATE HARDENING

Scope: VERIFY / FIX-ONLY hardening pass on top of PHASE 1.3, PHASE 2 and PHASE 2.1.
No `git commit` / `git push` / `firebase deploy` / store submission was performed.

## A. Executive Summary
**Verdict:** PASS WITH LOW-RISK ENVIRONMENT NOTES

- **Security / backend invariants:** preserved. Pricing, coupons, conflict locks, timezone bucketing and booking idempotency remain server-authoritative; role enforcement stays in callables + `firestore.rules` + `storage.rules`, not in the client.
- **PHASE 2.1 fixes:** were found to be **absent from the working tree** at PHASE 3 baseline (see §J). They were re-applied cleanly and are now backed by regression tests.
- **Tests:** Functions unit `68`, rules `33`, integration `75`, full emulator `68+108` — all green on Node 22.23.3 + JDK 25. Flutter `60/60` passing (was 51; +9 new regression tests). Analyzer: `0 errors / 0 warnings / 20 infos` (baseline).
- **Android release build:** **VERIFIED (unsigned candidate produced)** using a JDK 17 toolchain. The machine's default JBR is now Java 25.0.3, which Gradle 8.5 cannot use; this is an environment constraint, documented, not a code defect.
- **iOS:** NOT VERIFIED (non-macOS host; `ios/Runner.xcodeproj` present, pods not installed).
- **Deployment:** NO (explicitly not performed).

**Recommendation: APPROVED FOR INTERNAL TESTING.**
**NOT APPROVED FOR STORE SUBMISSION** until a signed release (release keystore + `android/key.properties`) is produced and iOS is built/verified on macOS.

## B. Baseline & Environment
- HEAD: `cfb6394` (branch `main`). `git diff --check` clean; no machine-bound paths in tracked source.
- Working-tree changes: 6 tracked files modified + 1 new test file (see §J). Untracked reports: `PHASE1_3_REPORT.md`, `PHASE2_REPORT.md`, `PHASE2_1_REPORT.md`, `PHASE2_1_SUMMARY.md`, `PHASE3_REPORT.md`, `build_report.py`.
- Node: `v22.23.3` (portable), npm `10.9.9`. `functions/package.json` engines = `22`.
- Flutter `3.27.2` / Dart `3.6.1`.
- Java: default JBR `java 25.0.3` at `C:\Program Files\Android\Android Studio\jbr`. Release APK built with Temurin `17.0.8`. Emulator gate `functions/scripts/require-java.js` `REQUIRED_MAJOR = 21`; satisfied by JDK 25 (`[gate] java preflight OK (25.0, resolved from PATH)`).
- Firebase CLI `15.25.1`. Emulator ports: firestore `8080`, functions `5001`.
- Dependency audit: `npm --prefix functions audit` (prod + full) = `found 0 vulnerabilities`. `npm ci` clean. No `npm audit fix --force`.
- Signing: no keystore committed; `android/key.properties` absent. Release build config is credential-driven; no debug-signing fallback introduced.

## C. Security Findings
No new P0/P1 findings in PHASE 3. Prior P0/P1 items (AUTH-001, AUTH-002) are now closed with test coverage. Remaining items are P2/P3 product or environment notes (§K).

## D. Auth / Role / Session
- Admin shell capability map is a pure, unit-tested predicate `adminTabVisible(role, index)` (`lib/screens/admin/admin_home_screen.dart`): owner/manager → all 12 tabs; staff → `{dashboard, appointments, services, staff, out-of-hours, profile}`.
- Drawer entries are gated with `if (_visibleFor(...))`; a lazy `IndexedStack` (`_visited`) prevents manager-only screens/listeners from initializing in a staff session (defense-in-depth for the UX layer, not a security boundary).
- `RootGate` binds the resolved role: `BusinessToolsProvider.bind(shopId, auth.role)` (`lib/screens/root_gate.dart`).
- `BusinessToolsProvider` gates customer-profile sync via `canSyncCustomerProfiles(role)` (owner/manager only) and swallows only `permission-denied` on `saveCustomer`.
- Logout/session transition: `AuthProvider._clearSession()` resets in-memory state via `ShopManager.reset()` (id, name, timezone) and best-effort unsubscribes the FCM topic (failure cannot block sign-out).
- `ExpenseProvider` exposes `permissionDenied` so limited roles render an access state instead of an empty list, and clears `loading` on error.

## E. Data Integrity & Recovery
- Booking creation: `requestId` + `bookingRequests/{uid}_{requestId}` claim + `existingByRequestId` → replay returns `duplicated: true` with no re-charge; conflict locks + overlap protection; nullable pricing stays server-derived; coupon usage is transactional. Concurrent retry proven idempotent by emulator test.
- Payments: status is server-derived; `delete_payment` is **not** idempotent (repeat returns `payment-not-found`) — documented P2, no client destructive one-click path added.
- Recovery: transport errors normalized to a stable "network unavailable" surface; streams recover on next snapshot; idempotent create path exists. Rollback procedures are not verifiable from this repo (no deployment scripts) — documented limitation.

## F. Dependency / Privacy / Config / Git Hygiene
- No private keys / service-account files tracked. Client Firebase config is intentionally present (`android/app/google-services.json`, `lib/firebase_options.dart` — client API key only) and is **not** a server secret.
- `lib/firebase_options.dart` detects placeholder values via `isPlaceholder` / `requireConfigured` and fails loudly instead of an opaque platform crash.
- APK inspected: 574 entries, **no** `.jks` / `.keystore` / `key.properties` / `service-account` / `.pem` entries.
- Tracked server code uses redacted stable error codes; no secrets logged.
- `firebase.json` predeploy hooks enforce quality gates: firestore → `npm --prefix functions run test:rules`; functions → `npm ci` + `npm run test:all`.

## G. Runtime / UX
- Subscriptions are cancelled on `bind`/`reset`/`dispose` (Auth, BusinessTools providers). Stream errors are mapped; `permission-denied` no longer leaves `loading` stuck.
- Timezone/shop offset is server-authoritative; the client mirrors it via `ShopManager.timezoneOffsetMinutes`, reset on session change.
- Empty states remain distinct from permission-denied where a flag exists (`ExpenseProvider.permissionDenied`).

## H. Test Results (fresh, PHASE 3)
| Suite | Command | Result |
|---|---|---|
| Functions unit | `npm --prefix functions run test:unit` | **68 passing** (exit 0) |
| Functions rules | `npm --prefix functions run test:rules` | **33 passing** (exit 0) |
| Functions integration | `npm --prefix functions run test:integration` | **75 passing** (exit 0) |
| Functions full (unit + emulator) | `npm --prefix functions run test:all` | **68 + 108 passing** (exit 0) |
| Flutter analyze | `flutter analyze --no-fatal-infos` | **0 errors / 0 warnings / 20 infos** |
| Flutter test | `flutter test` | **60/60 passing** (exit 0) |
| Controlled gate failure | temp failing unit test | `test:unit` → `1 failing`, `exit=1`, probe removed |

Flutter tests increased from 51 to 60 via `test/admin_authorization_test.dart` (role matrix + customer-sync gate + `ShopManager.reset` isolation).

## I. Release Artifact
- **Android:** `build\app\outputs\flutter-apk\app-release.apk`
  - Size: **59.01 MB (61,877,466 bytes)**
  - SHA-256: **`F41B53B93499287D69F69D05A091082E75AE8D355E3038D24805CDC5B4A0DEA6`**
  - Package: `com.barberbook.barberbook`, versionCode `1`, versionName `1.0.0`, minSdk `23`, compileSdk `35`.
  - Signature: `apksigner verify` → **DOES NOT VERIFY** (`Missing META-INF/MANIFEST.MF`) — **unsigned**, built with the credentials-driven release config; no debug-signing fallback.
  - Permissions: `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` (+ FCM/notification-plugin transitive `WAKE_LOCK`, `ACCESS_NETWORK_STATE`, `VIBRATE`, `c2dm.RECEIVE`).
- **iOS:** NOT VERIFIED (non-macOS host).

## J. Changes Made (this phase)
> Critical discovery: PHASE 2.1's report described fixes that were **not present** in the working tree (they had been lost via `git stash`; the stash is corrupted — flattening `admin_home_screen.dart` and injecting literal `\n`). The stash was **not applied**. Instead the fixes were re-applied cleanly and covered by tests.

| File | Change |
|---|---|
| `lib/providers/expense_provider.dart` | added `permissionDenied` flag (set on `permission-denied`, cleared on bind/reset, `loading=false` on error) |
| `lib/providers/business_tools_provider.dart` | added `canSyncCustomerProfiles(role)` gate; owner/manager-only customer sync; `saveCustomer` swallows only `permission-denied` |
| `lib/providers/auth_provider.dart` | `_clearSession()` now calls `ShopManager.reset()` + best-effort FCM unsubscribe |
| `lib/screens/root_gate.dart` | `BusinessToolsProvider.bind(shopId, auth.role)` |
| `lib/screens/admin/admin_home_screen.dart` | `adminTabVisible` capability map, role-gated drawer, lazy `IndexedStack` (`_visited`) |
| `lib/services/shop_manager.dart` | added `ShopManager.reset()` |
| `test/admin_authorization_test.dart` (new) | 9 tests: admin tab matrix (owner/manager/staff), customer-sync gate, `ShopManager.reset` session isolation |

No backend/security-rule changes were required or made. `git diff --check` clean; no absolute machine paths introduced.

## K. Deferred Findings
- **PAY-002** `delete_payment` not idempotent — DEFERRED (P2). Server recomputes excluding deleted rows; UI should treat an already-gone payment as success. Product decision.
- **RES-001** reschedule not implemented (cancel + recreate only) — OUT OF SCOPE (product).
- **PAY-001 / PAY-003 / META-001** — deferred / product decisions (unchanged from PHASE 2).
- **TOOL-001** emulator teardown flake — KNOWN (tooling), does not affect assertions.
- **Environment:** default JBR Java 25.0.3 is incompatible with Gradle 8.5 (AGP 8.3.0); release builds require JDK 17 (used here). Not a code defect.
- **iOS** and **signed release** are unverifiable in this environment.

## L. Final Acceptance Matrix
| Gate | Status | Evidence |
|---|---|---|
| A — Security | PASS | Backend rules/callables authoritative; 33 rules + 75 integration + 108 emulator green; no P0/P1 open |
| B — Auth / Role / Session | PASS | `adminTabVisible` test matrix; sync gate; `ShopManager.reset` isolation; role bound at `RootGate` |
| C — Data Integrity / Recovery | PASS | Idempotency/locks/coupons tested; concurrent retry idempotent; P2 documented |
| D — Privacy / Config / Supply Chain | PASS | 574-entry APK with no secrets; audits 0 vulns (prod+full); no tracked private keys |
| E — Runtime / UX | PASS | Listener lifecycle, permission states, 0 analyzer errors/warnings |
| F — Release Candidate Build | PASS (unsigned) / PARTIAL | Android release APK produced & inspected; unsigned; iOS + signed build NOT VERIFIED |
| G — Regression Suite | PASS | unit 68, rules 33, integration 75, all 68+108, Flutter 60/60, controlled gate failure exit 1 |
| H — Failure / Operational Readiness | PASS | Transport mapping, idempotency, distinct permission states; operational limits documented |

## M. Release Recommendation
**APPROVED FOR INTERNAL TESTING.**
**NOT APPROVED FOR SIGNED RELEASE CANDIDATE / STORE SUBMISSION.**

Reason: no P0/P1 security or data-integrity blocker remains and all quality gates pass; however the Android artifact is **unsigned** and iOS/signed-release verification is impossible on this host. Produce a release keystore + `android/key.properties`, build/verify the signed APK, and build/verify iOS on macOS to reach store-submission readiness.

## Final Note
No `git commit` / `git push` / `firebase deploy` / store upload was performed. Only local source/test edits and a local release build were made.
