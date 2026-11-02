# Offline Startup Failure — Root-Cause Investigation & Fix

**Scope:** Flutter app (`barber_app`) fails to open when the device has no internet
connection. Investigate, find the exact code-level root cause, apply the smallest
safe fix, verify (device + gates), and report.

**Result:** `PASS` — root cause found and proven on a real Android emulator with a
before/after device experiment. Fix is 2 source files + 1 regression test file.
All gates green. Session/authorization logic is untouched (no bypass, no faked user).

---

## 1. Symptom

Reported: *the application does not open when the device has no internet.*

"Does not open" = the app shows the splash spinner and never advances to any screen.

---

## 2. Investigation method

Because the bug is runtime/network dependent, static reading was not treated as
proof. A real Android emulator (`Medium_Phone_API_36`, x86_64) was booted headless
and the app was driven in **airplane mode** with `adb` + `logcat`, and the live
widget tree was read over the Flutter VM service (`ext.flutter.debugDumpApp`).

Two throwaway diagnostic entrypoints were built (`-t`) and removed afterwards:

1. A raw Firestore/FCM probe (measures `.get()`, `getToken`, `subscribeToTopic`).
2. An **AuthProvider** probe that runs the *real* production startup path
   (`AuthProvider._applySession` → real `NotificationService.subscribeToShop`)
   offline and reports whether session init completes or hangs.

---

## 3. Root cause (proven)

**Exact failing call / state transition**

```
AuthProvider._applySession(uid)                      lib/providers/auth_provider.dart
  └─ await _resolveShop(uid)                         (Firestore .get() — OK offline)
  └─ ShopManager.shopId = shopId
  └─ await _subscribeShopNotifications()             ← HANGS offline
        └─ NotificationService.subscribeToShop()
              └─ await FirebaseMessaging.instance.subscribeToTopic(shopId)   ← never completes offline
  └─ initializing = false; notifyListeners();        ← never reached
```

`RootGate` shows `SplashScreen` while `auth.initializing == true` (`splash_screen.dart`).
Because the awaited FCM call never completes offline, `initializing` stays `true`
forever → **the app is stuck on the splash screen**. That is "the app does not open".

**Key correction to the initial assumption:** Firestore was *not* the cause.
`FirestoreService.resolveShopForUser` only issues `.get()` reads, which were measured
completing offline in ~1.5 s. The blocking call is `FirebaseMessaging.subscribeToTopic`.

### Device evidence — raw probe (airplane mode ON)

| Operation (offline)            | Result                          |
|--------------------------------|---------------------------------|
| `Firestore .get()` (serverAndCache) | COMPLETED 1528 ms, 0 docs ✅ |
| `Firestore .get(Source.cache)` | COMPLETED 30 ms ✅              |
| `FCM requestPermission`        | OK 21 ms ✅                     |
| `FCM getToken`                 | THREW fast (`SERVICE_NOT_AVAILABLE`) ✅ |
| **`FCM subscribeToTopic`**     | **TIMED OUT at 12 007 ms ❌**   |
| **`FCM unsubscribeFromTopic`** | **TIMED OUT at 12 002 ms ❌**   |

### Device evidence — AuthProvider probe (real `NotificationService`, airplane mode ON)

| Build        | Session init result                                                        |
|--------------|----------------------------------------------------------------------------|
| BEFORE fix   | `HUNG (>15s)` — `applySessionForTest` never returned                       |
| AFTER fix    | `COMPLETED in 26 ms` (`shopId=probe-shop`); background log 5 s later: `NotificationService: subscribeToTopic(probe-shop) failed: TimeoutException after 0:00:05` |

### Cross-checks that fit the theory
- Cold launch offline **with no session** → `RootGate` → **`LoginScreen`** (opens
  fine), because with no shop the subscribe step is skipped. Measured on device.
- Cold launch offline **with a session + shop** → enters the subscribe step → hangs.
  This is the reported failure.

---

## 4. Fix (smallest safe change)

Notifications are a **best-effort side effect**; they must never gate a session
transition. Two minimal, defense-in-depth edits:

### `lib/services/notification_service.dart`
Make `subscribeToShop` / `unsubscribeFromShop` bounded and non-fatal: capture the
shop id once, `await ...timeout(5s)`, and `debugPrint` on failure instead of throwing.

### `lib/providers/auth_provider.dart`
In `_applySession`, stop *awaiting* the notification subscribe; fire it off and
swallow failures:

```dart
if (shopId != null) {
  unawaited(_subscribeShopNotifications().catchError((Object e) {
    debugPrint('_applySession: shop notification subscribe failed: $e');
  }));
}
```

`initializing = false; notifyListeners();` now runs immediately after the shop is
resolved, so startup can never be stranded — regardless of the subscribe
implementation or connectivity. A notification failure no longer clears the
session (previously it fell into the outer `catch` and nulled `shopId`/`role`).

**Not changed:** `_resolveShop`, the auth stream, `shopId`/`role` resolution, the
`_sessionGeneration` guard, `ShopManager`, Firestore rules, sign-in/sign-out
semantics. No auth or authorization path was bypassed; no user was fabricated.

---

## 5. Regression tests (`test/auth_startup_test.dart`, +3)

Drive `_applySession` directly (with `firebaseReady = false`, so the auth stream
cannot mask a hang):

1. a **never-completing** notification subscribe does not strand init —
   `initializing` is `false`, `shopId`/`role`/`ShopManager` preserved.
2. a **throwing** notification subscribe does not clear the session or set `error`.
3. an **unresolvable shop** still finishes init with a null session.

Tests are bounded with `.timeout(2s)`; each fails on the pre-fix code (hang / session
cleared) and passes after.

---

## 6. Gate results (executed)

| Gate                                   | Result |
|----------------------------------------|--------|
| `flutter analyze`                      | **No issues found** |
| `flutter test`                         | **116 passed** (113 → +3) |
| `flutter build apk --debug`            | **Built `app-debug.apk`** |
| Device: cold launch offline, no session| `RootGate` → `LoginScreen` (opens) |
| Device: AuthProvider real path offline | BEFORE `HUNG>15s` → AFTER `COMPLETED 26ms` |

Backend Node suites (`test:unit`/`test:rules`/`test:integration`) are unaffected by
this client-only change and were not re-run.

---

## 7. Device scenario matrix

| # | Scenario                                   | Status |
|---|--------------------------------------------|--------|
| 1 | Cold launch, online                        | Not run (no authorized test account) |
| 2 | Cold launch, offline, no session           | **PASS** (LoginScreen) |
| 3 | Offline after an online login (session+shop)| **PASS via AuthProvider device probe** (before-fix hang reproduced; after-fix resolves) |
| 4 | Offline, no cached session                 | **PASS** (LoginScreen) |
| 5 | Existing session + cached shop/profile     | Covered by scenario 3 (subscribe was the blocker) |
| 6 | Expired/invalid credentials offline        | Not run (no account) |
| 7 | Offline → reconnect                        | Not run (no account) |
| 8 | Callable failure offline                   | Not run (host-dependent) |
| 9 | Pending writes offline                     | Covered by PHASE 4.5 / `connection_provider` |
| 10| Auth/session-isolation regression          | **PASS** (`phase4_2` + `auth_startup` tests) |

Scenarios requiring a real account on the production Firebase project
(`barber-book-lycb`) were not executed — creating one would mutate production data.

---

## 8. Remaining limitations

- Session-with-shop was verified at the AuthProvider level on-device with the **real**
  `NotificationService` (before/after), not by signing into a real account end-to-end.
- Offline `signOut()` still awaits `unsubscribeFromShop`, now bounded to ~5 s.
  It is not on the startup path and does not block the app from opening.
- Pre-existing (out of scope): `_clearSession()` resets `ShopManager.shopId` *before*
  calling unsubscribe, so sign-out does not actually unsubscribe the FCM topic, and
  a rapid session switch may leave the old topic subscribed. Unchanged by this fix.
