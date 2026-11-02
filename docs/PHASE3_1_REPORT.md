# PHASE 3.1 REPORT — RELEASE INTEGRITY & FINAL REGRESSION GATE

**Date:** 2026-10-09
**Repository:** `C:\Users\HP\Desktop\barber`
**Mode:** VERIFY / FIX-ONLY — no commit, no push, no deploy, no signing key generated
**Previous phase:** PHASE 3 (`PHASE3_REPORT.md`)

> Note: the PHASE 3.1 instruction text was received truncated mid-Section 12 (Task I). Tasks A–I were fully specified and are executed here. If additional sections (deliverable format / verdict taxonomy) exist beyond Task I, they were not available and may require a follow-up.

---

## A. Executive Summary

**Verdict: PASS WITH OPEN RELEASE-INTEGRITY NOTES — APPROVED FOR INTERNAL TESTING; NOT APPROVED FOR STORE SUBMISSION.**

The application code and test suites are green and the PHASE 2.1/3 security fixes are genuinely present and now **committed**. However, three facts prevent a "release-ready" classification:

1. **The release APK is intentionally unsigned** (no `android/key.properties`); store submission is impossible until a release keystore exists. No production key was created (per scope).
2. **iOS is unrunnable on this host** (Windows; no Xcode; no Podfile/CocoaPods integration).
3. **Repository integrity gap:** the PHASE 3 commit (`347c5b5`) includes the six source fixes but **not** the new regression test `test/admin_authorization_test.dart`, which remains untracked — a clean clone would lose that coverage. Historical reports are stale on this point.

Additional notable findings: the default `flutter analyze` gate is **red (exit 1)** due to 20 pre-existing info lints (0 errors, 0 warnings); and no screen actually consumes the `permissionDenied` flags (STATE-001 is only partially realized).

---

## B. Task A — True Repository State & Reconciliation

### Live git state (captured this phase)
| Command | Result |
|---|---|
| HEAD | `347c5b5 PRODUCTION READINESS & RELEASE CANDIDATE HARDENING` |
| Author / date | `mohammad93zza` — Fri Oct 9 17:45:40 2026 +0300 |
| Branch | `main...origin/main`, ahead/behind `0/0` (local `main` == `origin/main`) |
| `git status --short` | `M .gitignore` + 6 untracked paths (below) |
| `git diff` | only `.gitignore` (+5 lines) |
| `git diff --cached` | empty (nothing staged) |
| tracked files | 208 |
| `git stash list` | `stash@{0}: WIP on main: cfb6394 …` (present; **not applied/dropped**) |
| build/ tracked | 0 |

### Reconciliation inventory
| File / path | Git state | Purpose | Expected? | Risk | Recommended action |
|---|---|---|---|---|---|
| `lib/providers/{auth,business_tools,expense}_provider.dart`, `lib/screens/root_gate.dart`, `lib/screens/admin/admin_home_screen.dart`, `lib/services/shop_manager.dart` | committed in `347c5b5` | PHASE 2.1/3 security fixes | yes | none | keep |
| `test/admin_authorization_test.dart` | **untracked** | regression tests for the fixes above (8 test cases) | should be tracked | **coverage loss on clean clone** | commit with the fixes (see §M) |
| `.gitignore` | modified (unstaged) | added `.env`/`.env.*` ignore | yes | none | keep |
| `PHASE1_1/1_2/1_3/2/2_1/3*.md`, `PHASE2_1_SUMMARY.md`, `build_report.py` | untracked | audit reports + helper | yes (deliverables) | none | keep; reports intentionally not edited |
| `build/…/app-release.apk`, `functions/node_modules`, `.dart_tool` | ignored/untracked | generated artifacts | yes | none | not committed (correct) |
| `android/app/google-services.json`, `lib/firebase_options.dart` | tracked | client Firebase config (client API key only) | yes | low (by design) | keep |
| `stash@{0}` | stash | corrupt WIP from before PHASE 3 | no | low (corruption) | leave untouched |

**Previously reported changes absent from the tree:** none of the six source fixes are missing — they are committed. The only previously-added artifact that is *not* in the tree is the new test file (untracked).

**Sensitive-file scan:** no tracked service-account JSON, private keys, keystores, `.pem`, or `.env`. `google-services.json` / `firebase_options.dart` are client config (expected). No marker (`BEGIN … PRIVATE KEY`, `private_key`, `private_key_id`) found in tracked files.

---

## C. Task B — Verification of Previously Closed Fixes

### B1. Business role authorization — **CONFIRMED**
- `adminTabVisible(role, index)` is a pure predicate (`lib/screens/admin/admin_home_screen.dart:39`): owner/manager → all 12 tabs; staff → `{0,1,2,3,7,11}`.
- Drawer entries gated with `if (_visibleFor(context, i))` (`admin_home_screen.dart:182-201`); a hidden tab cannot be activated via the drawer (`_item.onTap` only reachable from rendered entries).
- **Server authority confirmed independently:** `firestore.rules` defines `isShopOwner/isManager/isStaff` (lines 13-35) and gates financials (`isManager`, lines 80-120); callables enforce `canManageOperations`/`canManageRules` (`functions/src/lib/access.js:19`, `functions/src/index.js:346`). Hiding a tab is usability only, exactly as documented in the source comment.

### B2. Lazy screen initialization & listener isolation — **PARTIALLY CONFIRMED**
- Confirmed: lazy `IndexedStack` with `_visited` (`admin_home_screen.dart:59,109-115`) prevents manager-only **screens** (and their screen-scoped controllers) from building in a staff session.
- **Correction to the PHASE 3 claim:** it is *not* true that manager-only **provider/listener** initialization is prevented. `RootGate` binds every provider unconditionally for all roles (`lib/screens/root_gate.dart:45-50`), including `BusinessToolsProvider` (12 manager-only streams) and `ExpenseProvider` for staff. Those reads are attempted and fail with `permission-denied`, handled gracefully. Net effect: correct behavior, but the "no listeners created" wording is overstated.
- Streams are cancelled on `bind`/`reset`/`dispose` in every provider (`business_tools_provider.dart:57-60,392-423`; `expense_provider.dart:27,64-83`), so no leak.

### B3. Customer profile synchronization — **CONFIRMED**
- `canSyncCustomerProfiles(role)` returns true only for owner/manager (or unknown) (`business_tools_provider.dart:18-19`); sync early-returns for staff (`:259`).
- Only `permission-denied` is swallowed on write; all other `FirebaseException`s rethrow (`:325-331`). No rule was weakened.

### B4. Expense permission-denied handling — **PARTIAL (defect found)**
- `ExpenseProvider.permissionDenied` is set on `permission-denied`, cleared on `bind`/`reset`, and `loading` is cleared on every error path (`expense_provider.dart:34-51`). Correct.
- **Gap:** no widget anywhere reads `permissionDenied` (grep over the whole repo returns only the two provider definitions). So permission denial is **not** distinguishable from an empty list in the UI. Because staff cannot open the Expenses/Business-Tools tabs (B1), the flag is currently unreachable dead code; still, the STATE-001 claim "screens can distinguish permission-denied vs empty" is **unsupported**.

### B5. Other permission-denied UI states — **KNOWN GAP**
- `DiscountProvider` and `FeedbackProvider` clear `loading` on denial but store **no** flag (`discount_provider.dart:35-41`, `feedback_provider.dart:35-41`) — a denied manager-only read renders as an empty list. These tabs are hidden from staff, so the misleading state is not reachable by normal interaction, but it is not structurally prevented.
- `ShopProvider`/`AppointmentProvider` correctly avoid setting `error` for `permission-denied` and clear loading (`shop_provider.dart:62-70`, `appointment_provider.dart:58-66`). Their data is readable by all shop roles, so no false-empty risk observed.
- No provider converts a non-permission error into an empty list; `error` is surfaced where set.

### B6. Session reset & cross-shop isolation — **CONFIRMED (unit-level)**
- `_clearSession()` calls `ShopManager.reset()` and wraps the FCM unsubscribe in try/catch so failure cannot block cleanup (`auth_provider.dart:76-87`); `signOut()` clears local state in a `finally` (`:171-188`).
- `ShopManager.reset()` clears `shopId`, `shopName`, `timezoneOffsetMinutes` (`shop_manager.dart:17-21`). Note: `ShopManager.shopName` is never assigned anywhere in the codebase (dead field) — reset is still correct.
- Added regression tests cover a Shop A→Shop B transition at the state-holder level and provider `reset()` clearing cached collections/denial flags (`test/admin_authorization_test.dart`, group "provider reset clears cached shop state").

---

## D. Task C — Report-to-Code Consistency

| Claim (report) | Source of truth | Verification | Status |
|---|---|---|---|
| PHASE 2.1: 4 primary findings CLOSED and applied | `PHASE2_1_REPORT.md` §3-6 | PHASE 3 proved they were **absent** at the time; they now exist and are committed | **STALE at publication; now CONFIRMED** |
| PHASE 2.1: "Other providers already had `permissionDenied`" | `PHASE2_1_REPORT.md` §5 | Only `BusinessToolsProvider` has it; discount/feedback/shop/appointment do not | **UNSUPPORTED** |
| PHASE 2.1: "screens can distinguish permission-denied vs empty" | `PHASE2_1_REPORT.md` §5 | No widget reads `permissionDenied` | **PARTIAL / UNSUPPORTED** |
| PHASE 3: "Files changed: 6 + new test" | `PHASE3_REPORT.md` §J | Commit `347c5b5` contains **6 files only**; `test/admin_authorization_test.dart` is untracked | **PARTIAL (test not committed)** |
| PHASE 3: "Flutter 60/60" | `PHASE3_REPORT.md` §H | True only with the untracked test present; a clean clone runs 51 | **STALE for a clean clone** |
| PHASE 3: lazy IndexedStack prevents manager-only "providers/listeners" init | `PHASE3_REPORT.md` §D | `RootGate` binds all providers for all roles | **OVERSTATED** |
| PHASE 1.3/2/3 test counts (68/33/75/108) | §H below | Reproduced exactly | **CONFIRMED** |
| PHASE 3: Android APK 61,877,466 B, SHA `F41B53B9…A0DEA6`, unsigned | §G below | Rebuilt: identical size **and** identical SHA-256 | **CONFIRMED** |
| PHASE 3: npm audit 0 vulns | §E below | prod + full = 0 | **CONFIRMED** |
| PHASE 3: Node 22 / emulator gate Java 21 / build Java 17 | §E, §F below | Reproduced | **CONFIRMED** |
| Predeploy hooks | `firebase.json` | `test:rules` and `ci`+`test:all` present | **CONFIRMED** |
| No machine-specific paths | tracked files | grep found none | **CONFIRMED** |

Historical reports were **not** edited (preserved) in line with scope.

---

## E. Task D — Build Toolchain & Java Runtime Pinning

| Item | Value | Evidence |
|---|---|---|
| Gradle wrapper | `gradle-8.5-all.zip` | `android/gradle/wrapper/gradle-wrapper.properties` |
| Android Gradle Plugin | `8.3.0` | `android/settings.gradle:24` |
| Kotlin plugin | `1.8.22` | `android/settings.gradle:25` |
| Java `sourceCompatibility` | `1.8` | `android/app/build.gradle:32-33` |
| Flutter default JBR | **Java 25.0.3** | Android Studio JBR |
| Emulator gate | `REQUIRED_MAJOR = 21` (Firestore emulator / firebase-tools only) | `functions/scripts/require-java.js:18` |
| **Android build JDK (verified)** | **Temurin 17.0.8** | build log; `flutter config --jdk-dir` |

**Distinction (explicit):** the two Java checks serve different purposes. `require-java.js` guards the **Firestore emulator** (a Java subprocess spawned by firebase-tools) and requires ≥21; it deliberately hardcodes no path and does not claim any Java is suitable for Gradle. The **Android build** requires a Gradle-supported runtime: Gradle 8.5 does not support Java 25, while AGP 8.3.0 targets JDK 17. **JDK 17 is the verified compatible runtime** for the Android build and was used for the successful build. No Gradle/AGP/Kotlin/Flutter/SDK upgrade was attempted, and no system-wide Java config was changed (process-scoped `JAVA_HOME`/PATH + Flutter's local `jdk-dir` only). The emulator gate script needs no correction — its scope is already stated in its header.

---

## F. Task E — Security, Dependencies, Configuration

- **Node/Functions:** Node `v22.23.3`, npm `10.9.9`; `functions/package.json` engines `{"node":"22"}`; `npm --prefix functions ci` → exit 0.
- **Lockfile:** `functions/package-lock.json` tracked and consistent (`npm ci` succeeds).
- **Safe overrides still effective (installed versions verified):** `uuid@11.1.1`, `@grpc/grpc-js@1.14.5`, `serialize-javascript@7.1.2`, `diff@8.0.3`.
- **Audits:** `npm audit --omit=dev` → 0 vulnerabilities; `npm audit` (full) → 0 vulnerabilities. No `--force` used.
- **Predeploy gates:** firestore → `npm --prefix functions run test:rules`; functions → `npm --prefix functions run ci` + `run test:all` (`firebase.json`).
- **Gate failure propagation:** a deliberately failing **Mocha-style** unit test produced `1 failing`, **exit 1**, then was removed. (Methodology note: a `node:test`-style file does **not** fail under Mocha and would give a false green — the probe was corrected before drawing the conclusion.)
- **Secrets/hygiene:** no service-account JSON, private keys, keystores, `.pem`, or `.env` tracked; marker scan clean. Ignore rules cover signing material and service-account JSON at any depth (`git check-ignore` verified for root and nested paths). **Added** `.env` / `.env.*` (with `!.env.example`) to `.gitignore` (+5 lines) — previously uncovered; no `.env` was tracked.
- **Machine-specific absolute paths:** none in tracked source.
- **Flutter:** `flutter pub get` exit 0; `flutter test` 62/62 exit 0; `flutter analyze --no-fatal-infos` exit 0 with **0 errors / 0 warnings / 20 infos**. Plain `flutter analyze` **exits 1** (in Flutter 3.27 the info level is fatal by default). Info breakdown: `prefer_const_constructors` ×10, `use_build_context_synchronously` ×5, `prefer_conditional_assignment` ×4, `prefer_interpolation_to_compose_strings` ×1. No errors or warnings are hidden.

---

## G. Task F — Final Regression Gate (fresh run, reproducible)

**Suite structure (important):** `test:all` = `test:unit` **+** `test:emulator`; and `test:emulator` runs the rules file and the two integration files together (33 + 75 = 108). The suites therefore **overlap**; counts must not be summed as independent tests.

| # | Suite | Command | Result | Exit |
|---|---|---|---|---|
| 1 | Functions unit | `npm --prefix functions run test:unit` | **68 passing** | 0 |
| 2 | Firestore rules | `npm --prefix functions run test:rules` | **33 passing** | 0 |
| 3 | Integration | `npm --prefix functions run test:integration` | **75 passing** | 0 |
| 4 | Full emulator | `npm --prefix functions run test:all` | **68 + 108 passing** (108 = 33 rules + 75 integration) | 0 |
| 5 | Flutter unit/widget | `flutter test` | **62/62 passing** | 0 |
| 6 | Flutter analyze | `flutter analyze` (plain) | 0 errors / 0 warnings / 20 infos | **1** (infos fatal by default) |
| 6b | Flutter analyze | `flutter analyze --no-fatal-infos` | 0 errors / 0 warnings / 20 infos | 0 |
| 7 | Dependency audit | `npm audit` (prod + full) | 0 vulnerabilities | 0 |
| 8 | Android release build | `flutter build apk --release` (JDK 17) | Built 59.0 MB | 0 |
| 9 | APK metadata/signature | `aapt` / `apksigner` | see §H | n/a |
| 10 | Repo hygiene | `git grep`, `git check-ignore` | clean | n/a |

**Unique backend test cases:** 68 + 33 + 75 = **176** (the "68+108" figure is the same set expressed differently). Emulator project is `demo-barberbook` (no production data touched).

---

## H. Task G — Android Release Artifact Verification

| Property | Value |
|---|---|
| Path | `build\app\outputs\flutter-apk\app-release.apk` |
| Size | **61,877,466 bytes (59.011 MB)** |
| SHA-256 | **`F41B53B93499287D69F69D05A091082E75AE8D355E3038D24805CDC5B4A0DEA6`** |
| Package / namespace | `com.barberbook.barberbook` |
| Version code / name | `1` / `1.0.0` |
| minSdk / targetSdk / compileSdk | `23` / `35` / `35` |
| `apksigner verify` | **DOES NOT VERIFY** (`Missing META-INF/MANIFEST.MF`) — exit 1 |
| Signing state | **UNSIGNED** (no debug-signing fallback) |
| Unexpected secrets in APK | **none** (0 key/keystore/pem/service-account entries of 574) |

The rebuild produced a **byte-identical hash** to the PHASE 3 artifact, i.e. a reproducible output (no source changes affect the APK this phase). Classification: **unsigned internal-verification build artifact** — not a signed release candidate.

### Signing-readiness checklist (for later; NOT performed now)
- [ ] Create a release keystore **outside** the repository, e.g. `keytool -genkeypair -keystore <secure path>` (do not commit).
- [ ] Create `android/key.properties` (git-ignored) with `storeFile`, `storePassword`, `keyAlias`, `keyPassword`.
- [ ] Confirm `android/app/build.gradle` fails safely: it throws `GradleException` if `key.properties` is incomplete (`:19-23`) and **never** falls back to `signingConfigs.debug` (`:64-71`). **Verified by code inspection + unsigned artifact.**
- [ ] Build and verify: `flutter build appbundle --release` (or `apk`), then `apksigner verify --print-certs`.
- [ ] Configure Play App Signing / upload-key handling as per release policy.
- [x] No production keystore or credential was created in this phase.

---

## I. Task H — Deferred Issues Classification

| Issue | Classification | Reasoning (evidence-based) |
|---|---|---|
| `delete_payment` non-idempotent (`payment-not-found` on repeat) | **POST-RELEASE IMPROVEMENT / INTERNAL-TESTING RISK — not a blocker** | `functions/src/index.js:576-602`: operations-only, fully transactional, and it recomputes `collectedAmount` from the **remaining** payments excluding the deleted id. A repeat call finds no document and fails **before any mutation** → no duplicate financial effect, no double-decrement, no record corruption. Only the API contract (error vs no-op) is imperfect; UI should treat `payment-not-found` as already-deleted. |
| Appointment rescheduling not implemented | **KNOWN DEFERRED PRODUCT DECISION (out of scope)** | No occurrence of "reschedul" in `lib/**` or `functions/src/**`. Cancel + recreate exists; no regression. |
| Payment consistency / over-collection policy (PAY-001/003) | **KNOWN DEFERRED PRODUCT DECISION** | Server derives status/pricing authoritatively; policy question is product-owned. |
| Cancellation metadata display (`lateCancellation`, `closedAt`, `closedById`) (META-001) | **POST-RELEASE IMPROVEMENT** | Stored server-side; only UI display deferred. |
| Rollback procedures | **NOT VERIFIABLE in this repo** | No deployment/rollback scripts present; no deploy was performed. |
| Emulator teardown flake (TOOL-001) | **INTERNAL-TESTING RISK (tooling only)** | All suites returned exit 0 this run; flake does not alter assertions. |
| iOS build/signing | **NOT VERIFIABLE on this host** | See §J. |

No deferred item blocks the intended **internal-testing** scope. A signed release remains gated on §H; iOS on §J.

---

## J. Task I — iOS & Environment Limitations

- iOS project **exists**: `ios/Runner.xcodeproj`, `ios/Runner.xcworkspace`, `ios/Runner/`, `ios/Flutter/`.
- **CocoaPods not integrated:** `ios/Podfile`, `ios/Podfile.lock`, and `ios/Pods/` are **absent**. `ios/Flutter/Generated.xcconfig` exists.
- **No macOS/Xcode:** `xcodebuild` is not available (Windows host). Therefore compilation, signing, and TestFlight/story validation are **NOT VERIFIED**.
- **Required on macOS:** generate/restore a `Podfile`, run `pod install`, configure signing (team/bundle id), then `flutter build ipa` + Xcode archive, and verify on a device/simulator.

---

## K. Changes Made This Phase (narrowly scoped)
| File | Change | Verified |
|---|---|---|
| `test/admin_authorization_test.dart` (untracked) | +2 provider-`reset()`/denial-state regression tests (Runs with `flutter test` 62/62) | `flutter test` exit 0 |
| `.gitignore` | +`.env`, `.env.*`, `!.env.example` (credential hygiene) | `git check-ignore` verified |

No source/business logic changed; no historical report edited; no stash applied/dropped; no `git reset --hard` / `git clean -fd`; no commit/push/deploy; no signing key created.

---

## L. Final Acceptance Matrix
| Gate | Status | Evidence |
|---|---|---|
| A — Repository integrity | **ATTENTION** | Fixes committed in `347c5b5`; regression test untracked (coverage/process risk) |
| B — Auth/role/session | PASS (with B4/B5 notes) | `adminTabVisible` tests; rules + callables authoritative; session reset tests |
| C — Data integrity/recovery | PASS | Idempotency/locks recomputed transactionally; `delete_payment` impact analyzed |
| D — Privacy/config/supply chain | PASS | No secrets tracked; audits 0; ignore coverage verified |
| E — Runtime/UX | **ATTENTION** | 0 errors/0 warnings; 20 infos; plain `flutter analyze` exits 1 |
| F — Regression suite | PASS | 68 / 33 / 75 / 68+108 / 62 — all exit 0; failure gate exit 1 |
| G — Release build | PASS (unsigned) | APK rebuilt, hash re-computed and stable; signature verified as unsigned |
| H — Operational readiness | PASS | Failure propagation, rollback limitation, deferred items classified |
| I — iOS | **NOT VERIFIED** | No macOS/Xcode/CocoaPods |

---

## M. Release Recommendation

**APPROVED FOR INTERNAL TESTING.**
**NOT APPROVED FOR SIGNED RELEASE CANDIDATE / STORE SUBMISSION.**

To reach the next milestone:
1. **Commit `test/admin_authorization_test.dart` together with the PHASE 3 source fixes** so a clean clone keeps its regression coverage (and rerun the gate from a clean checkout).
2. **Signing:** create a release keystore + `android/key.properties`, build the signed AAB/APK, and run `apksigner verify`.
3. **iOS:** perform a macOS build/sign/archive with CocoaPods restored.
4. **Analyzer gate:** fix the 20 info lints (esp. the 5 `use_build_context_synchronously`) or explicitly document the gate as `flutter analyze --no-fatal-infos`.
5. **STATE-001 follow-through:** consume `permissionDenied` (or remove it) and add distinct access-denied states where manager-only reads can reach a UI surface.

**No commit, push, deploy, or store upload was performed.**
