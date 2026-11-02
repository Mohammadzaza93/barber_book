# PHASE 1.3 — Runtime Compatibility & Final Release Gate

**Date:** 2026-10-05
**Branch:** `main`
**Verified commit:** `ab215594d34ceea21009aa99324cf050d5ea7e32` (`ab21559`)
**Authoritative runtime:** Node.js **22.23.3** (npm 10.9.9)
**Mode:** VERIFY ONLY — no feature work, no refactoring
**Verdict:** **PASS**, conditional on committing the two-file portability fix (see §11)

---

## 1. Verdict summary

Every PHASE 0 / 1.1 / 1.2 security and functional fix is intact and green on the
authoritative Node 22 runtime. Node 22 produces results identical to Node 26, so the
`engines.node: "22"` contract holds and nothing in the codebase is Node-26-only.

The release gate did its job: it surfaced **two machine-bound paths committed in the
initial commit `00ba85f`** that would break the Android build on any other machine or
CI runner. Both were fixed and the build was re-verified.

No commit, push, or deploy was performed in this phase.

| Gate | Result |
| --- | --- |
| Node 22 runtime authenticity | PASS |
| Clean deliverable tree (`git archive`, no `.git`) | PASS |
| `npm ci` / `npm ls` / `npm audit` (prod + full) | PASS — 0 vulnerabilities |
| Functions unit tests | PASS — 68 passing |
| Firestore rules tests | PASS — 33 passing |
| Functions integration tests | PASS — 75 passing |
| Full emulator suite | PASS — 108 passing |
| PHASE 0 security regressions (by name) | PASS |
| Java 21 preflight (positive + negative) | PASS |
| Predeploy gates (both) + controlled failure | PASS |
| Flutter `pub get` / `analyze` / `test` | PASS — 51 passing, 0 errors |
| Release APK build | PASS — 59.0 MB, unsigned by design |
| Release signing path | PASS — proven with throwaway key |
| Secrets / debug-signing / CRLF / hygiene | PASS |
| Release config portability | **2 defects found → fixed (uncommitted)** |

---

## 2. Runtime environment (measured, not assumed)

| Component | Value |
| --- | --- |
| OS | Windows x64 |
| **Node (authoritative)** | **v22.23.3**, npm 10.9.9 |
| Node provenance | Official portable zip, unpacked outside the repo |
| Node archive SHA-256 | `2b0ff57b049cda1bbcea2240eec20467018713c1efe1f7360c2681859b90ed71` (verified) |
| Node comparison runtime | v26.1.0, npm 11.13.0 (`C:\Program Files\nodejs\node.exe`) |
| JDK | OpenJDK 21.0.7 (Android Studio JBR), supplied on `PATH` |
| Flutter | 3.27.2 stable, revision `68415ad1d9` |
| Dart | 3.6.1 (DevTools 2.40.2) |
| Firebase CLI | 15.25.1 |
| Gradle | 8.5 (Kotlin 1.9.20), JVM 21.0.7 |
| Android build-tools | 36.0.0 (`apksigner`) |

### 2.1 Runtime authenticity evidence

```
node --version      -> v22.23.3
npm --version       -> 10.9.9
node -p process.execPath
   -> C:\Users\HP\AppData\Local\Temp\opencode\node22\dist\node-v22.23.3-win-x64\node.exe
```

The portable Node 22 directory was prepended to `PATH` for **every** Functions
command in this phase, so `npm`, `mocha` and the `firebase` CLI all resolved to the
Node 22 binary rather than the system Node 26.

`npm config get node-version` returned `undefined`. That is expected: no version
manager is installed and none is required — the portable binary is the mechanism.

Because a machine without any Node version manager could previously have been
reported as a partial environment, this is now closed: Node 22 is a real, verified
runtime, and no `PARTIAL` downgrade is warranted on that basis.

---

## 3. Git state

```
HEAD                : ab215594d34ceea21009aa99324cf050d5ea7e32  (main)
tracked files       : 208
git diff --check    : clean
CRLF blobs in index : 0
tracked build output: none
largest tracked file: 438.6 KB (assets/brand/icon_full.png)
```

At the start of this phase the repository was completely clean with an empty index,
and `main` was level with `origin/main` (0 commits ahead). The 87-file PHASE 1.1 /
1.2 changeset plus the business-tools mojibake repair are contained in `ab21559`.

Note for the record: the phase brief expected 87 staged files at `386afb5`. That
state had already been committed and pushed to `origin/main` before this phase
began. No attempt was made to reconstruct, reset or re-stage that older state; the
verification ran against the actual current `HEAD`.

### 3.1 Working-tree line endings

Six tracked files differ byte-wise between the checkout and the exported tree:

| File | Index | Checkout |
| --- | --- | --- |
| `android/app/build.gradle` | LF | mixed |
| `android/settings.gradle` | LF | mixed |
| `functions/src/index.js` | LF | mixed |
| `functions/src/lib/repository.js` | LF | mixed |
| `.firebaserc` | CRLF | LF |
| `.metadata` | CRLF | LF |

After normalising CRLF to LF, **all six hash identically** — the difference is line
ending representation only, never content. The index is the authority and it stores
LF for source files, so what was committed and what was tested are the same bytes.
`.metadata` and `.firebaserc` are Flutter/tooling metadata that Git does not
classify as text; harmless.

---

## 4. Clean deliverable tree

The deliverable was exported with `git archive` (index identical to `HEAD`), which
guarantees no `.git` directory and no stray local state:

```
git archive --format=zip HEAD -> expand -> <temp>/clean
.git present                    : False
functions/package.json          : present
functions/package-lock.json     : present
functions/src/index.js          : present
firebase.json                   : present
firestore.rules                 : present
lib/services/secure_api.dart    : present
lib/screens/admin/business_tools_screen.dart : present
android/app/build.gradle        : present
pubspec.yaml                    : present
```

All **208/208** tracked files were present. The six files listed in §3.1 matched
after EOL normalisation. This is what makes the results below representative of a
fresh clone rather than of a developer's working directory.

---

## 5. Dependency verification on Node 22

```
npm ci        -> added 364 packages, audited 365 packages in 16s
                 found 0 vulnerabilities          exit 0
npm ls --depth=0 -> exit 0 (no invalid, no missing)
npm audit --omit=dev -> found 0 vulnerabilities  exit 0
npm audit            -> found 0 vulnerabilities  exit 0
EBADENGINE warnings : 0
```

Resolved direct dependencies:

| Package | Resolved |
| --- | --- |
| `firebase-admin` | 13.10.0 |
| `firebase-functions` | 6.6.0 |
| `@firebase/rules-unit-testing` | 5.0.2 |
| `mocha` | 11.8.0 |

All four `overrides` from `functions/package.json` are applied, confirmed by
`npm ls`:

```
@grpc/grpc-js@1.14.5      overridden
uuid@11.1.1               overridden
diff@8.0.3                overridden
serialize-javascript@7.1.2 overridden
```

The PHASE 0 `uuid` advisory is closed: every `uuid` in the tree resolves to
`11.1.1` (single deduped copy under `google-gax`, `gaxios` and `teeny-request`).

`engines.node: "22"` is satisfied — `npm ci` emitted no `EBADENGINE` warning under
Node 22, which is the concrete compatibility proof the brief asked for.

---

## 6. Test suites on Node 22 (authoritative)

| Suite | Command | Result | Exit |
| --- | --- | --- | --- |
| Unit | `npm run test:unit` | **68 passing** (19 ms) | 0 |
| Rules | `npm run test:rules` | **33 passing** (5 s) | 0 |
| Integration | `npm run test:integration` | **75 passing** (32 s) | 0 |
| Full | `npm run test:all` | **68 passing** + **108 passing** (38 s) | 0 |

Across every run: **0 failing, 0 pending**.

Counts match the PHASE 1.2 baseline exactly (68 / 33 / 75 / 108).

The `PERMISSION_DENIED` and `evaluation error` lines in the emulator logs are
**expected output**, not failures: they are the Firestore emulator reporting that
the negative security tests were correctly denied.

Emulator lifecycle behaved correctly under Node 22: start on the Firestore emulator
for `demo-barberbook` with `firestore.rules` loaded from `../firebase.json`, run, then
clean shutdown on SIGINT.

---

## 7. PHASE 0 security regressions verified by name

Each item below was located in the passing output by test title, not inferred from a
suite exit code.

**Privilege escalation — blocked**
- a staff member cannot sign itself into a shop
- a staff member cannot promote itself to manager
- a staff member cannot demote or remove another member
- a user cannot grant themselves a shop membership through their profile
- a staff member cannot approve an out of hours request

**Trusted field forgery — blocked**
- a staff member cannot create an appointment from the client
- a manager cannot create an appointment from the client
- a manager cannot update an appointment from the client
- a manager cannot delete an appointment from the client
- a manager cannot forge a payment status through an appointment write
- a staff member cannot increase a coupon usage counter
- an owner cannot create a coupon with a usage counter
- an owner can edit a coupon without touching its usage counter
- no client can write payments, not even a manager
- a staff member cannot write the service catalog / employees

**Cross-shop isolation**
- a staff member cannot read another shop
- a staff member cannot read another shop appointments
- a staff member cannot read payments / expenses
- a manager can read payments
- every collection the app ships is reachable by the owner

**`joinShopByCode` is server-authoritative**
- creates a staff membership and binds the user profile
- rejects the owner joining through a code
- denies an unknown code (`join code does not match any shop`)
- denies an existing member (`user is already a member of this shop`)
- join codes in logs are emitted as `"[redacted]"`

**Server-side pricing and booking integrity**
- prices the booking from the server catalog (`totalAmount` recomputed server-side)
- denies when the selected employee or chair is already booked (conflict prevention)
- keeps a concurrent retry idempotent instead of failing as a conflict
  (`createAppointment.duplicate`)
- rejects a booking time in the past

**Coupons**
- applies a percent coupon and counts the redemption
- rejects an expired coupon / a coupon that reached its usage limit
- rejects a coupon below its minimum spend / scoped to other services
- rejects an unknown coupon code

**Working hours and timezone**
- rejects a booking outside working hours
- lets a manager book outside working hours when the shop allows it
- stops a staff member from booking outside working hours

**Coupon rollback — verified structurally**

There is no standalone "rolls back the coupon" test. The guarantee is structural
rather than test-named, and was confirmed by reading the write path in
`functions/src/index.js`:

| Line | Write | Transaction |
| --- | --- | --- |
| 437 | appointment document | same `tx` |
| 443 | conflict locks | same `tx` |
| 459 | coupon `usageCount` increment | same `tx` |
| 464 | idempotency claim | same `tx` |

Because the redemption increment is committed inside the same Firestore transaction
that creates the appointment, a failed booking rolls the counter back atomically. No
manual compensation logic exists or is needed. The denial tests above confirm the
request is rejected before the counter moves.

---

## 8. Deployment gates

### 8.1 Java preflight

| Scenario | Output | Exit |
| --- | --- | --- |
| JDK 21 on `PATH` | `[gate] java preflight OK (21.0, resolved from PATH)` | 0 |
| No `java` on `PATH` | `[gate] FATAL: could not run java -version` / `spawnSync java ENOENT` | 1 |

The failure message explicitly instructs the operator to set `JAVA_HOME` in their own
environment and **not** to hardcode a machine-specific path. No machine path is
embedded in the repository.

### 8.2 Predeploy hooks executed verbatim

`firebase.json` hooks, run exactly as the Firebase CLI would run them:

| Hook | Command | Result | Exit |
| --- | --- | --- | --- |
| `firestore.predeploy` | `npm --prefix functions run test:rules` | 33 passing | 0 |
| `functions.predeploy[0]` | `npm --prefix "$RESOURCE_DIR" ci` | 364 packages, 0 vulnerabilities | 0 |
| `functions.predeploy[1]` | `npm --prefix "$RESOURCE_DIR" run test:all` | 68 + 108 passing | 0 |

### 8.3 Controlled failure — the gate really blocks

Performed only inside the temporary exported tree, never in the repository.

**Probe A — functions gate.** A deliberately failing unit test was added.

```
npm exit = 1
68 passing, 1 failing
emulator stage executed = False
```

The `&&` chain short-circuited: the emulator stage never ran, so a failing unit test
cannot be masked by a later green stage.

**Probe B — firestore gate.** A deliberately failing test was appended to
`rules.test.js`.

```
npm exit = 1
33 passing, 1 failing
```

**Restoration.** `rules.test.js` was restored and its SHA-256 is byte-identical to the
repository version (`564C341C0BEFD398A1B7A3DE85C112A48037CB003628399F91157DAC184E296D`).
Both probe files are gone (grep for probe text: 0 matches) and the suite returned to
`33 passing`, exit 0. The gate blocks, and the repository is left untouched.

### 8.4 Emulator teardown flake (LOW, open)

One run out of seven returned a non-zero exit despite a green suite:

```
+ Script exited successfully (code 0)      <- mocha passed
! Firestore Emulator has exited upon receiving signal: SIGINT
Error: An unexpected error has occurred.  <- firebase-tools teardown
npm exit = 2
```

Six subsequent runs (three from `functions/`, three using the exact `--prefix` form)
were clean. This is a teardown race in `firebase-tools` 15.25.1, not a Node 22 issue.

Direction of failure is **safe**: it can block a legitimate deploy, but it can never
let failing code through. No fix applied — see §12.

---

## 9. Flutter verification from the clean tree

```
flutter --version   -> 3.27.2 stable
flutter pub get     -> Got dependencies!            exit 0
flutter analyze     -> 20 issues found              exit 1 (info only)
                       0 errors / 0 warnings / 20 info
flutter analyze --no-fatal-infos -> exit 0
flutter test        -> +51: All tests passed!        exit 0
```

**The `SecureApi` regression guard holds.** `lib/services/secure_api.dart` exists in
the exported tree and the analyzer reports zero occurrences of
`Undefined name 'SecureApi'`.

**About the `flutter analyze` exit code.** Plain `flutter analyze` exits 1 purely
because Dart treats info-level lints as fatal. There are **0 errors and 0 warnings**.
The 20 lints are identical to the PHASE 1.2 baseline and break down as:

| Lint | Count |
| --- | --- |
| `prefer_const_constructors` | 10 |
| `use_build_context_synchronously` | 5 |
| `prefer_conditional_assignment` | 4 |
| `prefer_interpolation_to_compose_strings` | 1 |

None are correctness or security issues. This is a pre-existing style baseline, not
a regression, and it was deliberately not "fixed" in a VERIFY phase.

---

## 10. Release APK and signing

```
flutter build apk --release -> Built app-release.apk (59.0 MB)   exit 0
ABIs                        -> arm64-v8a, armeabi-v7a, x86, x86
```

A Gradle warning appears during compilation about Kotlin metadata `2.1.0` vs expected
`1.9.0` originating from the third-party `firebase-auth-23.2.1` AAR. It is a warning,
not an error, and the build succeeds.

### 10.1 The artifact is unsigned, by design

`android/app/build.gradle` reads `android/key.properties`, and only defines a
`signingConfigs.release` entry when that file exists. There is **no**
`signingConfigs.debug` fallback anywhere in the release build type.

With no `key.properties` present:

```
META-INF signature entries : none
apksigner verify           -> DOES NOT VERIFY
                              ERROR: Missing META-INF/MANIFEST.MF   exit 1
```

So the release APK is genuinely unsigned and definitively **not** debug-signed.

### 10.2 The signed path was proven to work

An unsigned-only test would leave the signing wiring unproven, so it was exercised
with a throwaway RSA-2048 key created **outside** the repository:

```
keytool -genkeypair ... CN=Phase13 Probe        (temp only)
android/key.properties written to the temp exported tree only
flutter build apk --release -> app-release.apk (59.1 MB)   exit 0
apksigner verify --print-certs -> exit 0
   Signer #1 certificate DN: CN=Phase13 Probe, OU=VerifyOnly, O=TempOnly, C=US
   SHA-256: 384e3ad1e740f817ba1c935e80d99aa4b334402818be5fd47d55e3431e814294
```

`apksigner` also emits standard v1-scope warnings about
`META-INF/com/android/build/gradle/app-metadata.properties` and AndroidX
`*.version` entries; these are normal for AGP v2/v3-signed builds.

Both the throwaway keystore and `key.properties` were deleted afterwards. Verified
afterwards: temp keystore absent, temp `key.properties` absent, repository `git
status` clean, repository has no signing material.

`.gitignore` already protects signing material:
`/android/key.properties`, `/android/keystore.properties`, `/key.properties`,
`/keystore.properties`, `*.jks`, `*.keystore`. The repository contains none of them.

---

## 11. Release configuration: two defects found and fixed

The release-config scan is what produced this phase's only substantive findings. Both
defects were introduced in the **initial commit `00ba85f`**, i.e. they predate the
PHASE 0/1.1/1.2 work and were not regressions from it.

### FIXED-1 (HIGH) — Gradle wrapper pinned to a local machine path

`android/gradle/wrapper/gradle-wrapper.properties`

```diff
-distributionUrl=file\:///C:/Users/HP/.gradle/wrapper/dists/gradle-8.5-all/3zlzzgtsutfj0pbojr50n2l7z/gradle-8.5-all.zip
+distributionUrl=https\://services.gradle.org/distributions/gradle-8.5-all.zip
```

**Impact.** A `file:///` distribution URL cannot be downloaded. On any machine or CI
runner other than this one, `./gradlew` would fail to obtain Gradle and the Android
build would break entirely. The repository was not buildable off this machine.

**Verification of the fix.** `services.gradle.org` was confirmed reachable before
changing anything (`HTTP 200`, `Content-Length: 218636663`). After the change the
wrapper resolved a different cache directory — the hash is derived from the URL —
and the build succeeded:

```
build exit = 0
Built build\app\outputs\flutter-apk\app-release.apk (59.0 MB)
new dist dir : .gradle\wrapper\dists\gradle-8.5-all\42kln3cd7cnoizdl6j25sb5gs
   gradle-8.5-all.zip   208.5 MB
   gradle-8.5-all.zip.ok           (unpack verified complete)
   gradle-8.5\bin\gradle.bat       present
gradle --version -> Gradle 8.5, Kotlin 1.9.20, JVM 21.0.7 JetBrains
```

Honest caveat: the local build reused a cache directory for the canonical URL that
had already been created on 2026-08-09 during environment setup, which is why the
build completed in 7.7 s rather than after a 208 MB download. The download itself was
independently confirmed available via the `HTTP 200` check above, so a clean machine
can obtain the distribution.

### FIXED-2 (MEDIUM) — dead machine-local Maven repository

`android/build.gradle` referenced a local repository three times:

```diff
-        maven { url = uri("file:///C:/Users/HP/AppData/Local/Temp/opencode/maven-local") }
```

**Impact.** Low but real. The referenced directory **does not exist** on this machine,
so the entries were pure noise that Gradle silently skipped; more importantly they
leaked an absolute developer path into a committed build file. Removed from all three
repository blocks (`buildscript`, `allprojects`, `subprojects.buildscript`).

Dependency resolution was unaffected — the release APK rebuilt successfully at
59.0 MB after removal.

### Post-fix confirmation

A repeat scan of tracked files returns zero hits:

| Pattern | Hits |
| --- | --- |
| `C:[/\\]+Users[/\\]` | 0 |
| `AppData` | 0 |
| `opencode[/\\]maven-local` | 0 |
| `opencode[/\\]node22` | 0 |
| `\.gradle[/\\]wrapper` | 0 |

The only remaining absolute paths in the repository are inside the PHASE report
markdown files, where they are documentation of these findings.

Net change: **2 files, 1 insertion, 4 deletions.**

```
 M android/build.gradle
 M android/gradle/wrapper/gradle-wrapper.properties
```

> **These two fixes are intentionally left uncommitted.** This phase is not permitted
> to commit. `HEAD` (`ab21559`) therefore still contains both defects. See §13.

---

## 12. Open items

| ID | Severity | Item | Recommendation |
| --- | --- | --- | --- |
| OPEN-1 | LOW | `firebase emulators:exec` teardown flake, 1 in 7 runs exits 2 after the inner script succeeded (§8.4) | Monitor. If it recurs in CI, retry once in the hook or pin a newer `firebase-tools`. Fails safe, so no urgency. |
| OPEN-2 | INFO | `maven.aliyun.com` mirrors are listed **before** `google()` / `mavenCentral()` in `android/build.gradle` and `android/settings.gradle` | Not a defect and machine-independent. But a third-party mirror currently takes priority for dependency resolution. Consider ordering the canonical repositories first for supply-chain clarity. |
| OPEN-3 | INFO | 20 info-level Dart lints (0 errors, 0 warnings) | Pre-existing style baseline, unchanged from PHASE 1.2. Address in a dedicated cleanup phase, not here. |
| OPEN-4 | INFO | Firebase client API keys (`AIza…`) are committed in `android/app/google-services.json` and `lib/firebase_options.dart` | Expected: these are public client identifiers, not secrets, and are constrained by Firestore Security Rules and App Check. Apply API-key restrictions and App Check enforcement for defence in depth. |
| OPEN-5 | INFO | Release APK is unsigned until `android/key.properties` is supplied | By design and verified working (§10.2). The release engineer must provide the keystore; it must never enter the repository. |
| OPEN-6 | INFO | `gradle-wrapper.properties` has no `distributionSha256Sum` | Pinning the SHA-256 of `gradle-8.5-all.zip` would add distribution integrity checking. Deliberately not added, to keep this fix minimal. |

### Secrets scan

No private keys, no service-account JSON, no AWS keys, no hardcoded credential
assignments. The only matches were the Firebase client API keys in OPEN-4 and one
false positive (a `TextEditingController` named `_password`).

### Mojibake / encoding scan

Zero occurrences of U+FFFD, zero UTF-8-as-CP1256 mojibake sequences, zero stray
mid-file BOMs across tracked files. The PHASE 1.1 repair of
`lib/screens/admin/business_tools_screen.dart` remains clean in the committed file.

---

## 13. Acceptance criteria and the conditional verdict

| Criterion | Result |
| --- | --- |
| Tests run on authoritative Node 22, all green | PASS |
| All PHASE 0 security fixes still enforced | PASS |
| Dependency install clean, 0 vulnerabilities | PASS |
| Deploy gates block a failing build | PASS |
| Release APK builds and is not debug-signed | PASS |
| No secrets in the repository | PASS |
| Repository buildable outside this machine | PASS **only after committing FIXED-1 / FIXED-2** |

**Verdict: PASS**, on the verified working tree.

The single caveat is procedural rather than technical. Because this phase may not
commit, `HEAD` still carries the HIGH-severity Gradle wrapper defect from §11. If
the tree is evaluated at `ab21559` rather than in the working directory, the
correct verdict for that snapshot is **PARTIAL** — everything functional passes, but
the Android build is not reproducible off this machine.

Recommended owner action, outside this phase:

```powershell
git add android/build.gradle android/gradle/wrapper/gradle-wrapper.properties
git commit -m "fix(android): make the Gradle wrapper and repositories machine independent"
```

No commit, push, or deploy was performed by this phase.
