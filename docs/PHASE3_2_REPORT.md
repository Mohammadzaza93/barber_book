# PHASE 3.2 REPORT - FINAL DEFECT CLOSURE & REPRODUCIBILITY

Date: Fri Oct 09 2026
Baseline commit: `2f11122` (RELEASE INTEGRITY & FINAL REGRESSION GATE)
Prior phase report: `PHASE3_1_REPORT.md` (verdict: PASS WITH OPEN RELEASE-INTEGRITY NOTES)

## A. Executive Summary

PHASE 3.2 closed the two defects that PHASE 3.1 left open and eliminated the
analyzer policy gap, without touching the server-authoritative security model.

- **P0 (permission-denied UI) - CLOSED.** Manager-only financials no longer leak
  into staff-visible UI as misleading values, and manager-only screens now render
  an explicit access state instead of an empty list when Firestore denies the read.
- **P1 (analyzer policy) - CLOSED.** All 20 `flutter analyze` infos fixed;
  plain `flutter analyze` now exits 0 with **No issues found**. The
  `--no-fatal-infos` workaround is no longer required.
- **P1 (test integrity) - DOCUMENTED, NOT CLOSED.** Two essential test files
  remain untracked; a clean clone still loses coverage. No commit was made
  (forbidden by phase constraints), so this remains an open release-integrity note.
- **P1 (role/session isolation) - RECONFIRMED** at unit level, extended with new
  provider denial/reset coverage.
- **P2 (regression gates) - GREEN.** Backend 68 unit + 108 emulator (33 rules +
  75 integration); Flutter 71/71; analyzer 0 issues; audits 0 vulnerabilities.
- **Android artifact - REBUILT & REPRODUCIBLE.** New unsigned APK, byte-identical
  across a clean rebuild.

**Verdict: PASS WITH OPEN RELEASE-INTEGRITY NOTES - APPROVED FOR INTERNAL TESTING;
NOT APPROVED FOR STORE SUBMISSION.** (Reason: uncommitted working tree and untracked
test coverage - see sections G and M.)

## B. Scope, Constraints & Non-Actions

Constraints honored for the entire phase:

- No `git commit`, `push`, `deploy`, `publish`, or store submission.
- No production keystore creation and no signing configuration changes.
- No `git reset --hard`, `git clean -fd`, stash apply/drop, or any destructive git.
- No reuse of the corrupt `stash@{0}`.
- No deletion/reset/hiding of user changes.
- Firestore rules and callables were not weakened to "fix" client errors; the
  server remains the sole authorization authority.
- No rescheduling or unrelated features implemented.
- No secret/key material written to any report.

## C. Repository State (captured this phase)

- `HEAD = 2f11122`; `origin/main...HEAD` = `0 0` (in sync).
- `git diff` / `git diff --cached`: intended PHASE 3.2 changes only.
- Tracked files modified this phase: **16** (see section K).
- New untracked files this phase: `lib/widgets/data_state_view.dart`,
  `test/data_state_view_test.dart`.
- Pre-existing untracked (from earlier phases, untouched except additions):
  `test/admin_authorization_test.dart`, `PHASE1_3_REPORT.md`, `PHASE2_1_REPORT.md`,
  `PHASE2_1_SUMMARY.md`, `PHASE2_REPORT.md`, `PHASE3_1_REPORT.md`,
  `PHASE3_REPORT.md`, `build_report.py`.

## D. P0 - Permission-Denied / Financial Leakage Closure

### D1. Dashboard Net Profit leaked revenue to staff - **FIXED (real defect)**

- **Finding (AUTH-004).** `DashboardScreen` (admin tab 0, visible to staff) consumed
  `ExpenseProvider.expenses` to compute `netProfit = revenue - expenses`. Expenses
  are manager-only, so for a staff viewer the stream is denied/empty and
  `netProfit` collapses to raw revenue - a misleading business figure shown to staff.
- **Root cause.** The dashboard treated "no expense data" as "zero expenses" instead
  of "not authoritative".
- **Fix.** `lib/screens/admin/dashboard_screen.dart`: added
  `expensesAuthoritative = !loading && !permissionDenied && error == null`; the Net
  Profit card renders `t(context).restrictedValue` ("Restricted"/"مقيّد") unless the
  expense data is authoritative. Access control itself is unchanged.
- **Evidence.** `grep "restrictedValue"` -> dashboard guard + ARB keys.

### D2. Manager-only screens had no loading/error/denied state - **FIXED**

- **Finding (AUTH-003).** `DiscountsScreen` and `FeedbackScreen` rendered a single
  `isEmpty ? EmptyState : List` branch. On a `permission-denied` stream error the
  provider cleared `loading` but left the list empty, so a denied read was
  indistinguishable from "no records" (grey empty state, no explanation, no retry).
  `ExpensesScreen` similarly lacked loading/error/denied handling.
- **Root cause.** Providers exposed only a generic `error`; there was no shared
  renderer to map provider state to UI state.
- **Fix.**
  - New `lib/widgets/data_state_view.dart` (`DataStateView`): precedence
    **denied > error(>retry) > loading > content**, reusing `EmptyState`.
  - `DiscountProvider` and `FeedbackProvider` gained a `permissionDenied` flag
    (set on `permission-denied`, no longer surfacing it as a generic error).
  - `ExpenseProvider`, `DiscountProvider`, `FeedbackProvider` gained a `retry()` that
    re-subscribes to the bound shop.
  - `expenses_screen.dart`, `discounts_screen.dart`, `feedback_screen.dart` now wrap
    their body in `DataStateView` and hide the add FAB unless data is authoritative.
- **Access control.** Unchanged: screens remain unreachable for staff via
  `adminTabVisible`; `DataStateView` only chooses which state to show for an
  already-authorized screen.

## E. P1 - Flutter Analyzer Policy (20 infos -> 0)

`flutter analyze` previously exited 1 because info-level findings are fatal by
default in Flutter 3.27.2. All 20 were legitimate and non-behavioral, and all were
fixed rather than suppressed:

- `prefer_conditional_assignment` x4 -> `error ??= e.toString();`
  (`business_tools_provider.dart`, `discount_provider.dart`, `expense_provider.dart`,
  `feedback_provider.dart`).
- `use_build_context_synchronously` x5, resolved behavior-safely:
  - `booking_flow_screen.dart`: read `AppointmentProvider` **before** the
    `_saveFavoriteBarber()` await; capture the localized notification strings before
    the reminder-loop awaits, then guard with `mounted`.
  - `appointment_edit_screen.dart`: use `State.mounted` guard before using
    `context` after the awaited status call.
  - `booking_flow_screen.dart`: `const BookingSuccessScreen`.
- `prefer_const_constructors` x10 -> added `const` at the 7 widget sites and made
  the `booking_calc_test.dart` model fixtures `const`.
- `prefer_interpolation_to_compose_strings` x1 -> string interpolation in
  `dashboard_screen.dart`.

Result: **`flutter analyze` -> "No issues found!" (exit 0).** No `analysis_options`
rules were weakened or disabled.

## F. P1 - Role / Session Isolation (reconfirmed)

Reconfirmed by unit predicates and extended:

- `adminTabVisible` matrix: owner/manager see all 12 tabs; staff sees only
  `{0,1,2,3,7,11}`; staff cannot reach `{4,5,6,8,9,10}`.
- `canSyncCustomerProfiles`: owner/manager true, staff false, unknown -> legacy true.
- `ShopManager.reset` clears shop id/name/timezone; second session cannot observe
  the first shop.
- New: manager-only providers (`ExpenseProvider`, `DiscountProvider`,
  `FeedbackProvider`) default to no denial/error; `retry()` before `bind` is a safe
  no-op; `reset()` clears data + `permissionDenied` + `error`.

## G. P1 - Test Integrity & Clean-Clone Reproducibility (OPEN LIMITATION)

- `test/admin_authorization_test.dart` (pre-existing) and the new
  `test/data_state_view_test.dart` are **untracked**. A clean clone of the repository
  would not contain them, so the role matrix and the new UI-state regressions would
  be lost.
- Because the whole PHASE 3.2 change set is uncommitted (commits are forbidden in
  this phase), a clean clone cannot reproduce the current working tree at all until
  the work is committed.
- **A clean-clone pass was not run and is not claimed.** This section is the honest,
  reproducible statement of that gap. Closing it requires an explicit, separately
  authorized commit that stages the untracked test files.

## H. P2 - Regression Gates (fresh, reproducible)

Environment: Node `v22.23.3` / npm `10.9.9`; Firestore emulator on JBR `25.0`
(satisfies the `>=21` gate); Android build on Temurin `17.0.8` with Gradle `8.5`,
AGP `8.3.0`, Kotlin `1.8.22`.

| Gate | Command | Result |
| --- | --- | --- |
| Functions unit | `npm run test:unit` | **68 passing** |
| Rules (emulator) | `firebase emulators:exec` rules | **33 passing** |
| Integration (emulator) | `booking.test.js` + `mutations.test.js` | **75 passing** |
| Emulator total | `npm run test:emulator` | **108 passing** |
| `test:all` unique | `68 + 33 + 75` | **176** |
| Flutter tests | `flutter test` | **71 / 71 passing** |
| Flutter analyze | `flutter analyze` | **0 issues (exit 0)** |
| npm audit | prod + full | **0 vulnerabilities** |

Overrides verified installed: `uuid@11.1.1`, `@grpc/grpc-js@1.14.5`,
`serialize-javascript@7.1.2`, `diff@8.0.3`.

Flutter tests grew from 62 (PHASE 3.1) to **71**: +5 `DataStateView` widget tests and
+4 provider denial/reset tests.

## I. Android Release Artifact & Reproducibility

- `android/app/build.gradle` remains credential-driven and fail-safe; with
  `android/key.properties` absent (as on this machine) the release variant builds
  **UNSIGNED** and never falls back to the debug key.
- Rebuilt after the P0/P1 source changes:
  - Path: `build\app\outputs\flutter-apk\app-release.apk`
  - Size: **61,893,958 bytes (59.0 MB)**
  - SHA-256: **`F72A221BE1D29FED54412A45445701438A37A93B54283A67332E71D24DFE4A3E`**
  - Signed manifest present: **No**; signature entries: **0**
  - Zip entries: **574**; no secret-like entries (the two
    `META-INF/androidx.credentials*.version` hits are AndroidX library markers).
- **Reproducibility:** a full `flutter clean` + `flutter pub get` + rebuild produced
  the **exact same** SHA-256 and size -> deterministic, byte-identical.
- Supersedes the PHASE 3.1 APK
  (`F41B53B9...`), which predates these UI changes and is now stale.

## J. Deferred / Residual Risks

- **Release integrity (open):** uncommitted working tree + untracked tests
  (section G). Not a code defect; an intentional consequence of the no-commit rule.
- **Signing (out of scope):** release APK is unsigned by design; store submission
  requires a real keystore, which this phase was forbidden to create.
- **Toolchain warning (low):** the Android build prints an
  "incompatible Kotlin metadata (2.1.0 vs 1.9.0)" note from the Firebase Auth AAR
  and a benign SDK-XML-version-4 note. Both are pre-existing warnings; build exits 0.
- No new `functions/` or `firestore.rules` changes were made, so backend gates
  should not regress from this phase's diff.

## K. Changes Made This Phase

Modified tracked files (16): `lib/l10n/app_ar.arb`, `lib/l10n/app_en.arb`,
`lib/providers/business_tools_provider.dart`, `lib/providers/discount_provider.dart`,
`lib/providers/expense_provider.dart`, `lib/providers/feedback_provider.dart`,
`lib/screens/admin/appointment_edit_screen.dart`,
`lib/screens/admin/business_management_tabs.dart`,
`lib/screens/admin/business_tools_screen.dart`,
`lib/screens/admin/dashboard_screen.dart`,
`lib/screens/admin/discounts_screen.dart`,
`lib/screens/admin/expenses_screen.dart`,
`lib/screens/admin/feedback_screen.dart`,
`lib/screens/customer/booking_flow_screen.dart`, `lib/theme/app_theme.dart`,
`test/booking_calc_test.dart`.

New untracked files (2): `lib/widgets/data_state_view.dart`,
`test/data_state_view_test.dart`.

No commit, push, tag, signing, or deployment was performed.

## L. Final Acceptance Matrix

| Area | Status | Evidence |
| --- | --- | --- |
| P0 financial leakage (dashboard) | PASS | `expensesAuthoritative` guard + ARB |
| P0 permission-denied UI states | PASS | `DataStateView` + provider flags + FAB gating |
| P0 server authority preserved | PASS | no rules/callable changes |
| P1 analyzer policy | PASS | `flutter analyze` 0 issues, exit 0 |
| P1 untracked test integrity | OPEN | section G |
| P1 role/session isolation | PASS | unit matrix + provider tests |
| P2 backend gates | PASS | 68 unit + 108 emulator (176 unique) |
| P2 Flutter tests | PASS | 71/71 |
| P2 dependency audit | PASS | 0 vulnerabilities |
| Android artifact | PASS (unsigned) | reproducible SHA-256 recorded |
| Store submission readiness | NOT APPROVED | uncommitted + untracked + unsigned |

## M. Release Recommendation

**APPROVED FOR INTERNAL TESTING.** The application is functionally complete and the
PHASE 3.1 open defects are closed. Regression gates are fully green and the Android
artifact is reproducible.

**NOT APPROVED FOR STORE SUBMISSION.** Two governance items remain and are outside
this phase's authority:
1. The work is uncommitted and two essential test files are untracked (section G);
   the repository does not yet reproduce this verified state from a clean clone.
2. No production signing configuration exists (section I).

Recommended next step (requires explicit authorization): commit the PHASE 3.2 change
set including the untracked test files, then perform a true clean-clone verification
before any signed release build.
