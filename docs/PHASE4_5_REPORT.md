# PHASE 4.5 REPORT — Firestore Offline Persistence & Reliable Data Synchronization

**Repository:** `C:\Users\HP\Desktop\barber`
**Date:** 2026-10-14
**Branch:** `main`
**Base commit:** `ecc6edc4c0b3e1f7d6eb1fd60e1ffa08b8aed766` (unchanged)
**Author:** automated engineering session (opencode)
**Status:** working tree changes **left uncommitted**; no commit / push / deploy / signing; no production data touched.

---

## 0. One-line verdict

> **PASS WITH LIMITATIONS — OFFLINE CORE IMPLEMENTED & UNIT-TESTED, LIVE OFFLINE BEHAVIOR NOT VERIFIED**

The offline persistence configuration, connectivity monitoring, and localized
offline UX are implemented, `flutter analyze` is clean, and **all automated gates
are green** (Flutter 113, unit 68, rules 33, integration 75). The limitation is
that end-to-end offline read/write/queue/reconnect behavior **cannot be verified
on this host** (no safe backend, no authorized test account, no emulator wired to
the app) and **iOS is unverifiable on Windows**. Those scenarios are explicitly
reported as **BLOCKED**, not passed.

---

## A. Findings from repository inspection (Phase 1)

| Area | Finding |
| --- | --- |
| Platforms | Only `android/` and `ios/` exist — **no Web/desktop**. Native Firestore persistence is the relevant path; no web persistence work is required. |
| State management | `provider` (`ChangeNotifier`). Providers built in `lib/app.dart`. |
| Firestore dependency | `cloud_firestore ^5.5.1` → resolved **5.6.12** (`cloud_firestore_platform_interface 6.6.12`). `Settings` API is available. |
| Persistence config | **Absent.** No `settings`, `persistenceEnabled`, or cache-size configuration anywhere. Native persistence is Firestore's default, but the cache is unconfigured/unbounded. |
| Connectivity monitoring | **Absent.** `connectivity_plus` was not a dependency and no connectivity/persistence/`isFromCache`/`includeMetadataChanges` code existed. |
| Direct writes | All direct Firestore writes use `.set()` / `.delete()` on **stable, caller-supplied document ids** — **no `add()` anywhere** in `lib/services/firestore_service.dart`. This is what makes offline writes idempotent on retry. |
| Privileged writes | Appointments, payments, deletions, ratings, contact edits, and shop joining all go through **Cloud Functions callables** (`lib/services/secure_api.dart`). **Callables and `runTransaction` (loyalty points/gifts) are online-only** — they are *not* queued offline. |
| Reads | Existing `.snapshots()` streams and `.get()` calls already fall back to cache by default once persistence is on; provider error/loading handling and `DataStateView` already exist. |
| Firebase init | `lib/main.dart` calls `Firebase.initializeApp` and sets `firebaseReady`. `lib/firebase_options.dart` is a placeholder guarded by `requireConfigured()`. |
| Localization | `lib/l10n/app_en.arb` + `app_ar.arb` with generated accessors; `t(context)` shorthand in `lib/l10n/strings.dart`. |
| Session isolation | Strong existing guarantees (PHASE 4.2): `_sessionGeneration`, provider resets, `boundShop` guards. Cached data cannot leak across identities because providers are reset on identity change. |

**Assessment:** the app was already offline-*tolerant* for direct writes (stable
ids) and reads (cache), but had **no explicit bounded cache setting** and **no
connectivity awareness or offline UX**. The work below addresses exactly those
gaps with minimal, additive changes.

---

## B. Files changed

### Modified (tracked)

| File | Change |
| --- | --- |
| `pubspec.yaml` | Added `connectivity_plus: ^6.1.5` (see §C.0 for the version decision). |
| `pubspec.lock` | connectivity_plus 6.1.5 + platform interface and transitive. |
| `lib/services/firestore_service.dart` | Added `configureOfflinePersistence()` + `offlineCacheSizeBytes` (40 MB), applied once before first use. |
| `lib/main.dart` | Calls `FirestoreService.instance.configureOfflinePersistence()` after Firebase init, guarded so a failure never blocks startup. |
| `lib/app.dart` | Registered `ConnectionProvider()..start()` in the provider tree. |
| `lib/screens/admin/admin_home_screen.dart` | Wrapped the authenticated body in a `Column` with `ConnectionBanner` above the existing `IndexedStack`. |
| `lib/l10n/app_en.arb` | +3 keys: `offlineBannerMessage`, `syncingMessage`, `syncErrorBanner`. |
| `lib/l10n/app_ar.arb` | +3 matching Arabic keys (parity preserved). |

### Added (new files)

| File | Purpose |
| --- | --- |
| `lib/services/connectivity_source.dart` | `ConnectivitySource` abstraction + `ConnectivityPlusSource` (production) + `hasConnection()` helper. Injectable for tests. |
| `lib/providers/connection_provider.dart` | `SyncStatus` enum + `ConnectionProvider` state machine (offline / syncing / online / syncError). |
| `lib/widgets/connection_banner.dart` | Localized, RTL-aware status strip; renders nothing when online. |
| `test/connectivity_offline_test.dart` | 8 tests (provider state machine + banner widget). |
| `PHASE4_5_REPORT.md` | This report. |

**Unchanged by design:** `firestore.rules`, `functions/`, all providers, all read
methods, all write call sites, schemas, collections, roles, and policies. No
existing test was modified, removed, or weakened.

---

## C. Implementation details

### C.0 Dependency version decision (Android toolchain compatibility)

`connectivity_plus` was first added at the latest release (`7.3.1`), which then
failed the Android build:

```
:app:checkDebugAarMetadata ... Dependency 'androidx.core:core-ktx:1.18.0'
requires ... compile against version 36 ... and Android Gradle plugin 8.9.1+
```

Cause: per its changelog, **connectivity_plus 7.0.0** is a breaking release that
requires **AGP ≥ 8.12.1, Gradle ≥ 8.13, Kotlin 2.2.0**, and its Android module
hard-pins `androidx.core:core:1.18.0` (compileSdk 36). This project is on **AGP
8.3.0 / Gradle 8.5 / compileSdk 35**.

Fix: pin to the last 6.x release, **`connectivity_plus: ^6.1.5`**, whose Android
module uses **AGP 8.3.1, compileSdk 34** and declares **no `androidx.core` pin**.
The Dart API used here (`Connectivity`, `checkConnectivity()`,
`onConnectivityChanged`, `ConnectivityResult`) is **identical** in 6.x, so no code
change was required. This is a compatible *downgrade of a newly added dependency*,
not an upgrade of any existing package. Verified by a successful
`flutter build apk --debug` (see §D.1).

### C.1 Offline persistence (Phase 2)

`FirestoreService.configureOfflinePersistence()` sets:

```dart
_db.settings = const Settings(
  persistenceEnabled: true,
  cacheSizeBytes: offlineCacheSizeBytes, // 40 MB (within Firestore's 1 MB..100 MB range)
);
```

- **Idempotent** (`_offlineConfigured` guard) and called **once**, after
  `Firebase.initializeApp` and **before any Firestore operation** (Firestore
  throws `failed-precondition` if `settings` is set after use).
- A **bounded 40 MB** cache is chosen deliberately over
  `Settings.CACHE_SIZE_UNLIMITED` to avoid unbounded storage growth on low-end or
  shared devices. The bound is a documented constant.
- Failure to set settings is caught and logged in `main.dart`; the app still
  starts (offline cache simply stays at Firestore's default behavior).

### C.2 Reads/writes preserved (Phase 3)

- No read method or write call site was changed. Existing `.snapshots()` / `.get()`
  reads now transparently serve from the on-disk cache when offline.
- Existing direct `.set()`/`.delete()` writes on **stable ids** are queued by
  Firestore and replayed on reconnect — idempotent by construction (no `add()`).
- **Callables and transactions remain online-only** and are intentionally not
  wrapped in an offline queue. This is documented rather than "fixed", because
  blindly retrying a server-authoritative operation would risk duplicate or
  invalid financial/booking records, which the task explicitly forbids.

### C.3 Connectivity monitoring (Phase 4)

- `ConnectionProvider` abstracts the plugin behind `ConnectivitySource` so the
  state machine is unit-testable without the platform channel.
- On start it reads the current interface state; it re-flushes pending writes via
  the **injectable** `flushPendingWrites` (production default:
  `FirebaseFirestore.instance.waitForPendingWrites()`, skipped when
  `firebaseReady` is false).
- A monotonically increasing `_flushToken` prevents a stale, slower flush from
  overwriting a newer connectivity verdict; `_disposed` guards all post-dispose
  notifications.
- Connectivity is treated only as a **hint to attempt a flush** — it is never
  used to decide authorization or business outcomes.

### C.4 Offline UX (Phase 5)

- `ConnectionBanner` shows three honest states and renders **nothing** when online
  (no wasted vertical space): offline (amber, `cloud_off`), syncing (green,
  `sync`), sync-error (red, `error_outline`).
- All text is localized in both locales; the layout is RTL-safe (icon + `Expanded`
  text inside the app's `Directionality`). It is placed on the `AdminHomeScreen`
  body so it appears across the authenticated area.

### C.5 Auth / data integrity (Phase 6)

- No change to auth, providers, rules, or role gating. Because cached data is
  tenant-scoped by existing provider resets + `boundShop` guards (PHASE 4.2), the
  offline cache does not create a new cross-session leak path.
- The banner is a UI affordance only; server rules and callables remain
  authoritative.

### C.6 Error handling & observability (Phase 7)

- Existing typed error handling is retained: `SecureApiException`/`SecureErrorKind`
  for callables, provider error fields + `DataStateView` retry for reads.
- New: a distinct **`syncError`** state surfaces a rejected/blocked flush, with the
  queue retained for automatic retry — instead of silently looking "online".

---

## D. Test results (Phase 8)

### D.1 Automated gates (all run after the final code state)

| # | Command | Working dir | Exit | Result |
| --- | --- | --- | --- | --- |
| 1 | `flutter pub get` | repo root | 0 | Got dependencies |
| 2 | `flutter gen-l10n` | repo root | 0 | regenerated accessors |
| 3 | `flutter analyze` | repo root | 0 | **No issues found** |
| 4 | `flutter test` | repo root | 0 | **113 passing** (105 → 113, +8 new) |
| 5 | `npm run test:unit` | `functions/` | 0 | **68 passing** |
| 6 | `npm run test:rules` | `functions/` | 0 | **33 passing** |
| 7 | `npm run test:integration` | `functions/` | 0 | **75 passing** |
| 8 | `flutter build apk --debug` | repo root | 0 | **Build `app-debug.apk` succeeded** (Android compile/AGP gate) |

Java preflight: Android Studio JBR (`OpenJDK 25.0.3`) added to `PATH` **per shell
only** for the emulator gates; no machine/repo config was changed. `PERMISSION_DENIED`
lines in the rules run are expected negative-test output.

New coverage in `test/connectivity_offline_test.dart` (8 tests, all passing):
`hasConnection` none/any logic; start-offline; offline→syncing→online on reconnect;
flush failure → `syncError` then recovery; no re-flush on unrelated interface
change; ignore events after dispose; banner renders the offline icon; banner
renders nothing when online.

### D.2 Requested scenarios (TC-01 … TC-12)

| TC | Scenario | Method used | Result |
| --- | --- | --- | --- |
| TC-01 | Initialization / persistence applied before first use | Source inspection + compile/analyze | **Implemented**; runtime confirmation not available → **BLOCKED** |
| TC-02 | Read cached data while offline | Requires device/emulator + seeded cache | **BLOCKED** (no safe backend) |
| TC-03 | Read with empty cache while offline | Requires device/emulator | **BLOCKED** |
| TC-04 | Create while offline (direct write queued) | Requires device/emulator | **BLOCKED** |
| TC-05 | Update while offline | Requires device/emulator | **BLOCKED** |
| TC-06 | Delete while offline | Requires device/emulator | **BLOCKED** |
| TC-07 | Reconnection flushes without duplicates | Design review (stable ids, no `add()`) + provider sync transition unit test | **PARTIAL** — sync transition automated; duplicate-freeness not runtime-verified |
| TC-08 | Server rejection / permission-denied during sync | `syncError` state covered by unit test; end-to-end rejection | **PARTIAL / BLOCKED** |
| TC-09 | Auth/identity change isolation with cache present | Existing `phase4_2_session_isolation_test.dart` | **PASS** (automated) |
| TC-10 | Network status indicator reflects offline/online | 8 new unit + widget tests | **PASS** (automated) |
| TC-11 | Persistence survives app restart | Requires device/emulator | **BLOCKED** |
| TC-12 | Regression of existing behavior | Flutter 113 + backend 68/33/75 | **PASS** (automated) |

No result above is fabricated; device-dependent scenarios were not marked PASS
from inspection alone.

---

## E. Remaining risks / limitations

1. **Live offline behavior unverified** (TC-02…TC-06, TC-11): the code path relies
   on Firestore's native cache, which is enabled correctly, but no device/emulator
   run against a safe backend was possible on this host.
2. **Callables and transactions are not offline-capable** by design. Offline
   appointment/payment/loyalty operations will fail with a typed network error and
   must be retried by the user once online. This is intentional and documented.
3. **Connectivity ≠ reachability:** `connectivity_plus` reports interface state
   only; the `syncing`/`syncError` states plus `waitForPendingWrites()` are what
   actually reflect server reachability.
4. **iOS unverified** (Windows host).
5. **`connectivity_plus 6.1.5` is a new dependency** (additive; no existing
   package was upgraded). The 6.x line was chosen over 7.x because 7.x requires
   AGP ≥ 8.12.1 / compileSdk 36, which this project's toolchain does not use
   (§C.0). `flutter pub get` reports the usual "newer versions available"
   notices for pre-existing packages; none were forced. The debug APK builds
   successfully on the pinned version.
6. **Uncommitted work:** all changes for this phase remain uncommitted and the new
   test/file addenda are untracked — a loss risk until a human commits them.

---

## F. Final status

> **PASS WITH LIMITATIONS**

Offline persistence configuration, connectivity monitoring, and the localized
offline UX are complete, additive, and covered by automated tests; every automated
gate is green. The stated limitation is that end-to-end offline/reconnect/restart
behavior (TC-02…TC-06, TC-11) could not be exercised on this host and is reported
as **BLOCKED** rather than passed.

### Integrity confirmation

- **No commit, amend, rebase, reset, cherry-pick, push, tag, deploy, or production
  signing occurred.** Nothing was staged.
- **No production data was mutated;** no live environment was contacted.
- **No authorization rules were weakened; no test was removed or weakened.**
- **No existing user change, untracked report/test, or `stash@{0}` was discarded
  or modified.**
- All prior reports (`PHASE1_1`…`PHASE4_4`) and regression tests remain present.

### Recommended next steps (require a human / an environment I do not have)

1. Provide a safe Firebase project (or wire the app to the local emulators) and an
   authorized non-production test account, then run TC-01…TC-08 and TC-11 on a
   real Android device/emulator (airplane-mode toggling) and, separately, iOS.
2. Commit the PHASE 4.5 source changes and the untracked regression tests/reports
   when approved.
3. Product decision: confirm the 40 MB cache bound and the intentional
   "callables/transactions are online-only" policy.
