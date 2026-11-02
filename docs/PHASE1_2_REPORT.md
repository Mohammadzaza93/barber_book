# PHASE 1.2 — Dependency Security, Git Hygiene & Deployment Quality Gates

**Repository:** BarberBook (`barber-book-lycb`)
**Branch:** `main` — `HEAD` unchanged at `386afb5` (`CRITICAL SECURITY & SERVER-SIDE BUSINESS LOGIC HARDENING`)
**Files staged (not committed):** 87
**Final status:** **READY FOR REVIEW**

All verification in §5 was run against a clean tree extracted from the staged index via `git archive`. The exact final tree hash is deliberately not recorded here: these two report files are themselves part of that tree, so embedding the hash would invalidate itself. Reproduce it with `git write-tree` on the staged index.

> No commit, no push, and no `firebase deploy` were performed in this phase, by instruction.

---

## 1. Summary

| Area | Outcome |
|---|---|
| Production dependency vulnerabilities | **8 moderate → 0** |
| Full dependency tree vulnerabilities | **17 (6 high / 10 moderate / 1 low) → 0** |
| Direct dependency majors changed | **none** |
| Git line-ending policy | `.gitattributes` added; **zero renormalization churn** |
| Deployment quality gates | `firebase.json` predeploy gates on **both** Functions and Firestore |
| Gate failure behaviour | **verified blocking** (test failure and install failure) |
| Clean staged-tree verification | **PASS** (51 Flutter / 68 unit / 108 emulator) |
| Release build | **PASS** — 59.0 MB, confirmed **unsigned** |

Dependency detail and exploitability analysis: [`DEPENDENCY_SECURITY_REPORT.md`](DEPENDENCY_SECURITY_REPORT.md).

## 2. Dependency security

Full analysis, dependency chains, per-advisory exploitability and the rationale for rejecting npm's suggested major upgrades are in `DEPENDENCY_SECURITY_REPORT.md`. Summary of the outcome:

- Baseline: **8 moderate** production findings, all one root cause — [GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq) (`uuid <11.1.1`) — fanning out across `firebase-admin`, `@google-cloud/{firestore,storage}`, `google-gax`, `retry-request`, `teeny-request`, `gaxios`.
- Development: **6 high / 1 low** from `@grpc/grpc-js` (2), `serialize-javascript` (2) and `diff` (1).
- Remediated with four npm `overrides` (`uuid@11.1.1`, `@grpc/grpc-js@1.14.5`, `serialize-javascript@7.1.2`, `diff@8.0.3`) — every advisory cleared **at its root**, avoiding the `firebase-admin` 13→14 / `firebase-functions` 6→7 / `@firebase/rules-unit-testing` 5→2 / `mocha` 11→12 majors that npm proposed.
- `npm audit fix --force` was **not** used. No test was removed, skipped or weakened; no lint or analysis rule was suppressed.
- Each override was trialled in an isolated sandbox with the full suite re-run before being applied.
- Flutter: `flutter pub outdated` shows every package `Upgradable == Current`; all updates require breaking majors.

## 3. Git hygiene

### 3.1 Line-ending policy

`.gitattributes` was added encoding the required policy: LF for source and config, CRLF only for `.bat`, binaries never touched.

- **Audit finding:** at the point the policy was adopted, **every text blob already in the Git index was LF-only**, so the policy required **no renormalization commit and caused zero content churn**.
- Verified after the fact: `git ls-files --eol` reports **0 index blobs containing CRLF**, and **0 working-tree files contradicting the declared `eol` attributes**.
- Coverage was extended to the remaining source/config types that were previously falling through to `core.autocrlf=true` (`*.kt`, `*.swift`, `*.h`, `*.plist`, `*.pbxproj`, `*.xcconfig`, `*.xcscheme`, `*.xcsettings`, `*.storyboard`, `*.xcworkspacedata`, `*.txt`, `*.csv`, `*.toml`, `.gitignore`, `.gitattributes`, plus `gradlew`/`gradlew.bat`). Because the stored blobs were already LF, this added **no churn**.
- Final repository-wide state: **0 CRLF** in index, **0 CRLF** in working tree.

### 3.2 Working-tree consistency

An intermediate step (`git checkout-index -a -f -- <paths>`) silently failed to restore 67 tracked files, temporarily removing `.gitignore` and exposing 13,717 previously-ignored files. This was detected by an explicit "tracked files missing from working tree" check and fully repaired with a pathless `git checkout-index -a -f`. Final state confirms **0 missing tracked files, 0 untracked files, 0 unstaged modifications**, and the working tree is byte-identical to the index.

### 3.3 Credential hygiene

- Signing material is **not tracked**: no `.jks`, `.keystore`, `.p12`, `.pem` or `key.properties` in the index.
- `.gitignore` was **strengthened** during this phase: service-account patterns were root-anchored (`/service-account*.json`), which let `functions/service-account.json` through. Non-anchored equivalents were added, and the pattern set was checked to confirm it does **not** over-match real project files (`functions/package.json`, `functions/package-lock.json`, `lib/firebase_options.dart`, `pubspec.yaml` all remain trackable).
- Staged tree scans: **no merge conflict markers**, **no private keys**, **no service-account credentials**.
- The `AIza…` strings in `android/app/google-services.json` and `lib/firebase_options.dart` are **Firebase client API keys**, which are public identifiers shipped inside every client build and are constrained by Firestore security rules and authorized domains — they are not secrets and were intentionally not removed.
- No debug-signing fallback exists: `signingConfigs` only defines `release` when credentials are present, and `buildTypes.release` only applies it when available. The one textual match for `signingConfigs.debug` is the comment asserting it is never used.

## 4. Deployment quality gates

### 4.1 Java preflight (`functions/scripts/require-java.js`)

The Firestore emulator requires a JDK. A cross-platform preflight was added with **no machine-specific paths**.

A real defect was found and fixed during verification: the preflight initially accepted `JAVA_HOME`, but **`firebase-tools` spawns `java` resolved from `PATH`**. With `JAVA_HOME` set but `java` absent from `PATH`, the preflight passed and the emulator then failed with `Could not spawn 'java -version'` — a confusing failure. The preflight now verifies exactly what the emulator requires:

- `java` absent everywhere → fail with an actionable install message.
- JDK found via `JAVA_HOME` but **not on `PATH`** → fail with the precise reason and the platform-specific `PATH` command.
- `java` on `PATH` but older than 21 → fail with the detected version.

### 4.2 Test scripts (`functions/package.json`)

Scripts were made **self-contained** — each emulator-backed script now owns its full lifecycle instead of assuming an already-running emulator:

| Script | Behaviour |
|---|---|
| `gate:java` | JDK preflight (above) |
| `test:unit` | 68 unit tests, no emulator needed |
| `test:rules` | preflight + emulator + **33 rules tests** |
| `test:integration` | preflight + emulator + **75 booking/mutation tests** |
| `test:emulator` | preflight + emulator + full **108** |
| `test:all` / `test` / `verify` | 68 unit then 108 emulator |

`emulators:exec` uses `--project demo-barberbook` (pinned, so the emulator can never touch a real project) and `--config ../firebase.json`.

A path bug was found and fixed during verification: `firebase emulators:exec` executes the inner command with its working directory at **`functions/`**, not the config directory, so the inner Mocha paths are relative to `functions/`.

### 4.3 Predeploy wiring (`firebase.json`)

```jsonc
"firestore": {
  "predeploy": ["npm --prefix functions run test:rules"]
},
"functions": [{
  "predeploy": [
    "npm --prefix \"$RESOURCE_DIR\" ci",
    "npm --prefix \"$RESOURCE_DIR\" run test:all"
  ]
}]
```

This is enforced by `firebase-tools` internals, which were read to confirm rather than assumed:

- `deploy/index.js` calls `lifecycleHooks(targetName, "predeploy")` for **every** target, so a `firestore` predeploy hook is genuinely honoured.
- `chain()` awaits each hook in a bare loop with no error handling, so the **first rejection aborts the deploy**, recorded as `predeploys_error`.
- `runCommand()` rejects on any non-zero exit code.
- Hook commands run with `cwd` = project root, so `npm --prefix functions` is correct for the Firestore hook; `$RESOURCE_DIR` resolves to the Functions source dir and is used only there.
- Hooks execute through `cross-env-shell` with `shell: true`, so the commands are cross-platform.

`firebase.json` was confirmed to load and to start the emulator successfully. **`firebase deploy` was never invoked**, including in dry-run form.

### 4.4 Gate blocking — controlled failure tests

Both failure modes were proven to block, not merely assumed.

**Test failure blocks the gate.** A deliberately failing test was temporarily injected into `test/emulator/rules.test.js` (a probe in a *separate* file was first tried and correctly rejected as invalid, because `test:rules` names its file explicitly and did not collect it):

```
33 passing
1 failing
1) CONTROLLED GATE FAILURE PROBE
   Error: deliberate controlled failure
EXIT CODE = 1
```

The file was restored byte-identical afterwards (`git diff` clean), and no failing test was left behind.

**Dependency-install failure blocks the gate.** A non-existent `mocha` version was temporarily injected into `package.json`:

```
npm error code ETARGET
npm error notarget No matching version found for mocha@0.0.0-does-not-exist.
EXIT CODE = 1
```

`package.json` and `node_modules` were restored, and the diff was confirmed to contain only the intended script changes.

## 5. Clean staged-tree verification

All verification was performed in a tree extracted from the **staged index** via `git archive` — no `.git`, no pre-existing `node_modules`, 206 files — so the results describe what would actually be committed, not the accumulated working directory.

| Check | Result |
|---|---|
| `flutter pub get` | PASS |
| `flutter test` | **51 passing** |
| `flutter analyze` | **0 errors, 0 warnings, 20 info** |
| `flutter build apk --release` | PASS — `app-release.apk`, **59.0 MB** |
| APK signature check | **0 signature entries → unsigned** (no debug-signing fallback) |
| `npm ci` | PASS — 364 packages from lockfile |
| `npm audit --omit=dev` | **0 vulnerabilities** |
| `npm audit` | **0 vulnerabilities** |
| `npm ls --depth=0` | PASS — no invalid/missing/extraneous |
| Functions predeploy gate (`test:rules`) | **33 passing** |
| Functions predeploy gate (`test:all`) | **68 + 108 passing** |

Source-of-truth confirmation: `firestore.rules` and `storage.rules` are each tracked exactly once, and `firebase.json` plus `functions/test/emulator/helper.js` both resolve to that same root `firestore.rules`.

The 20 `info` findings are `prefer_conditional_assignment` style suggestions that pre-date this phase; `flutter analyze` exits non-zero on `info` alone, which is why its exit code is 1 despite zero errors and zero warnings.

## 6. Known limitations

1. **Node runtime not exercised at the declared version.** Tests ran on Node `v26.1.0` while `engines.node` is `"22"`. All suites passed, but they must be re-run on Node 22 in CI before release. This is the main open item.
2. **No production deployment was performed**, by instruction. All gate verification is local.
3. **`npm ci` in the Functions predeploy hook requires network access** at deploy time. This is deliberate — it verifies the lockfile actually installs before code is shipped — but it means a network outage will block deploys (fail-closed).
4. **Emulator-based gates require a JDK 21 on `PATH`** on the deploying machine. Fail-closed with an actionable message.
5. **Dependency overrides are out-of-range pins** (see `DEPENDENCY_SECURITY_REPORT.md` §8) and should be revisited when `firebase-admin` 14 is adopted.
6. Audit results are a point-in-time snapshot and must be re-checked as the advisory database evolves.

## 7. Repository state

- **85 files staged**, no commit created, `HEAD` unmoved at `386afb5`.
- Working tree is clean and identical to the index: **0 unstaged modifications, 0 untracked files, 0 missing tracked files**.
- Line endings: **0 CRLF** in the index and **0 CRLF** in the working tree.
- No credentials, private keys, or signing material are staged.
- Nothing in this phase is pushed or deployed.