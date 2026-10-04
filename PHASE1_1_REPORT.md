# PHASE 1.1 — Repository, Backend & Release Integrity Report

**Date:** 2026-10-03
**Scope:** Prove `SOURCE → GIT → CLEAN COPY → TEST → BUILD` for source, backend, and release.
**Hard constraints honoured:** no `git commit`, no `git push`, no `firebase deploy`, no production data mutation.

## Overall status: **PASS** (with 3 documented advisories)

All blocking integrity defects are fixed and verified from a clean copy of the **staged** tree.
Everything is staged in the Git index and **left uncommitted**, as instructed.

---

## 1. Headline finding: the committed tree was broken

`386afb5` is not merely incomplete — it **does not compile**. A fresh clone fails:

```
error - Target of URI doesn't exist: '../services/secure_api.dart'
       lib/providers/appointment_provider.dart:10:8
error - Undefined name 'SecureApi'  (dozens of occurrences)
error - Undefined name 'SecureApi'  - lib/providers/auth_provider.dart:107:13
```

Three **tracked** providers import an **untracked** file:

| Tracked file | Line | Imports |
|---|---|---|
| `lib/providers/appointment_provider.dart` | 10 | `../services/secure_api.dart` |
| `lib/providers/auth_provider.dart` | 9 | `../services/secure_api.dart` |
| `lib/providers/business_tools_provider.dart` | 10 | `../services/secure_api.dart` |

Missing from a clone of `386afb5`: the entire `functions/` backend (4 callables + 176 tests),
`firestore.indexes.json`, `lib/services/secure_api.dart`, and the Phase 0/1 tests.

The repository was in a **split-brain** state: `firestore.rules` and `firebase.json` were
committed, but `firebase.json` declared `functions.source = "functions"`, a directory that did
not exist in the clone.

### Root cause

Not a `.gitignore` problem. Evidence:

- `git check-ignore` confirms backend source, tests, and package files were **never ignored**.
- `git ls-files functions` returns **empty** at `386afb5`.
- The commit contains `firestore.rules` and `firebase.json` but zero `functions/` entries.

The direct cause is that `functions/` never entered the Git index. The exact human action
(commit scope / command) is **not reconstructible** from Git history, and this report does not
assert one.

---

## 2. Per-file classification

| File / group | Decision | Reason |
|---|---|---|
| `functions/src/index.js` + `src/lib/*.js` (10) | **TRACK** | Backend source — the core defect |
| `functions/test/unit/*.js` (5) | **TRACK** | 68 unit tests |
| `functions/test/emulator/*` (5) | **TRACK** | 108 security/rules tests |
| `functions/package.json`, `package-lock.json`, `.gitignore` | **TRACK** | Reproducible backend install |
| `firestore.indexes.json` | **TRACK** | Required by `firebase.json` composite queries |
| `lib/services/secure_api.dart` | **TRACK** | Only client path to callables |
| `lib/services/secure_error_text.dart` | **TRACK** | Typed error mapping |
| `lib/models/firestore_date.dart`, `shop_time.dart` | **TRACK** | Phase 1 date/timezone core |
| `test/*.dart` (5 new + tracked) | **TRACK** | Phase 0/1 regression coverage |
| `.firebaserc` | **TRACK (created)** | Pins deploy target; was missing |
| `assets/brand/*`, Android/iOS launcher icons, `res/values/colors.xml` | **TRACK** | Source brand assets |
| `android/app/google-services.json`, `lib/firebase_options.dart` | **TRACK (already)** | Public Firebase client config, not secrets |
| `functions/node_modules/`, `build/`, `.dart_tool/` | **IGNORE** | Generated |
| `functions/firebase-debug.log`, `firestore-debug.log` | **IGNORE** | Generated |
| `android/app/src/main/java/…/GeneratedPluginRegistrant.java` | **IGNORE** | Generated (Flutter template) |
| `android/gradlew`, `gradlew.bat`, `gradle-wrapper.jar`, `local.properties` | **IGNORE** | Standard Flutter `android/.gitignore` |
| `ios/Runner/GoogleService-Info.plist` | **ABSENT** | Never present; iOS not buildable on Windows |
| `key.properties`, `*.jks`, `*.keystore`, `*serviceAccount*.json`, `*.pem` | **IGNORE (added)** | Credential material — new rules |

**Staged: 81 files (55 added, 26 modified). Working tree fully staged, nothing left unstaged.**

`android/app/src/main/kotlin/.../MainActivity.kt` was confirmed **already tracked**, so the
`java/` directory in `--ignored` output is only Git collapsing a single generated file.

---

## 3. Fixes applied (index only — nothing committed)

1. **Staged all missing source** — resolves the compile-blocking split-brain.
2. **Release signing — removed debug signing** (`android/app/build.gradle`).
   - Release is now credential-driven via an ignored `android/key.properties`.
   - Absent credentials ⇒ release builds **UNSIGNED**. There is no debug fallback.
   - A partial `key.properties` now throws a `GradleException` instead of silently degrading.
   - Proven by certificate comparison:

     | Build | Result |
     |---|---|
     | Phase 1 APK | `Signer #1 certificate DN: C=US, O=Android, CN=Android Debug` — **debug key shipped** |
     | Phase 1.1 APK | `DOES NOT VERIFY` / no `META-INF` signature — **unsigned, correct** |

3. **Credential ignore rules** added to `.gitignore` (keystores, `key.properties`,
   service-account JSON, `*.pem`).
4. **`.firebaserc` created** pinning `barber-book-lycb`, matching `firebase_options.dart` and
   `google-services.json`. Without it `firebase deploy` prompts/fails on a clean machine.

---

## 4. Clean-copy verification

Because committing was forbidden, the clean copy was produced from the **index** via a tree
object — the exact bytes that a commit would contain, with no commit created:

```
git write-tree                 -> f3adfc48f48f92a613070f58d152fc3045b1d3e1
git archive --format=zip <tree>
```

| Gate | Result |
|---|---|
| `flutter pub get --offline` | OK — `pubspec.lock` honored |
| `flutter analyze` | **0 errors, 0 warnings** (20 info) |
| `flutter test` | **51 passing** |
| `npm ci` (functions) | OK — `package-lock.json` honored, no `node_modules` carried over |
| `npm run test:unit` | **68 passing** |
| `npm run test:emulator` (real emulator) | **108 passing** |
| `flutter build apk --release` | **OK — 59.0 MB**, unsigned |
| `git diff --check` | clean, no whitespace errors |
| Conflict markers | none |
| Secret scan (staged) | no private keys, no client secrets, no service-account JSON |

The earlier `git archive HEAD \| tar -x` failure was a **PowerShell binary-pipe corruption**
(`Damaged tar archive (bad header checksum)`), not a repository defect. `--format=zip` plus
`Expand-Archive` works reliably.

---

## 5. PHASE 0 security re-verified against source

Read directly from `functions/src`, not from the prior report:

- **`access.js`** — every callable resolves role server-side; `resolveRole` trusts
  `shopData.ownerId` over the client-writable `role` field.
- **`index.js`** — membership is re-verified **inside** the booking transaction (TOCTOU-safe).
  Pricing, duration, deposit, and status are derived from the DB catalog; client-supplied
  pricing fields are never read. Idempotency via `requestId` + `bookingRequests` claim.
  Coupon `usageCount` increments atomically in the same transaction.
- **`firestore.rules`** — deny-by-default catch-all; **no** client write path to
  `appointments`, `payments`, `bookingLocks`, `bookingRequests`; `discounts.usageCount` is
  immutable from the client; `users` profile is client-read-only.
- **`validate.js`** — allow-list regexes with bounded lengths; `SAFE_ID` excludes `/`
  (no path traversal).
- **`conflict.js`** — 15-minute bucket locks + transactional overlap query (two independent
  double-booking defenses); expired locks fall back to appointment state.
- **`repository.js`** — join-code lookup discloses only a shop id, behind auth.

**Emulator coverage is complete** — no new tests were needed. All required Phase 1.1 scenarios
are covered by the 108 existing tests: concurrency races, idempotent replay, cross-member
requestId isolation, server-authoritative pricing, coupon abuse (expired/exhausted/minimum/
scoped/series-overflow), cross-shop isolation, payment consistency, lock lifecycle, and the full
rules matrix.

---

## 6. Advisories (non-blocking, no change made)

1. **`npm audit`: 17 vulnerabilities — 6 high.** All highs are **devDependencies only**
   (`mocha` → `serialize-javascript`, `@firebase/rules-unit-testing` → `@grpc/grpc-js`) and never
   deploy. The production surface (`npm audit --omit=dev`) is **9 moderate, 0 high**, all in
   transitive Google-maintained `uuid` / `retry-request` / `google-gax` chains.
   Left unchanged deliberately — force-upgrading risks breaking `firebase-admin@13.10.0`.
2. **No `.gitattributes`** and `core.autocrlf=true`, so Git warned that LF will be converted to
   CRLF for 50+ files. Adding normalization now would churn every file in this staging pass;
   recommended as a focused follow-up before the next real commit.
3. **`firebase.json` predeploy runs only `npm run test:unit`.** The 108 emulator/rules tests are
   **not** enforced at deploy time (they need a running emulator). Recommend a CI gate that runs
   `test:emulator` before any release deploy.

## 7. Out of scope / environment-bound

- `INSTALL_FAILED_USER_RESTRICTED: Install canceled by user` on the MIUI device — device policy.
- iOS build and `GoogleService-Info.plist` need macOS/Xcode; unavailable on Windows.
- Java is not on `PATH`; emulator tests require
  `JAVA_HOME=C:\Program Files\Android\Android Studio\jbr` (OpenJDK 21.0.7).

---

## 8. Repository state on exit

```
branch: main
HEAD:   386afb5 (unchanged — nothing committed, nothing pushed)
staged: 81 files in the index, ready for review and commit by the owner
```

The staged tree builds, tests, and analyzes clean from a pristine copy. **Stop here — do not
begin Phase 2.**