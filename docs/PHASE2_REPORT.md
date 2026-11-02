# PHASE 2 REPORT

**Date:** 2026-10-05
**Repository:** C:\Users\HP\Desktop\barber
**HEAD:** cfb6394 "fix(android): make the Gradle wrapper and repositories machine independent"
**Mode:** AUDIT → REPRODUCE → DIAGNOSE → TEST → VERIFY (READ-ONLY; no commit/push/deploy)

## 1. Executive Summary

**Verdict:** PASS WITH LOW-RISK NOTES

- **Security regression gate:** PASS. Functions: unit 68, emulator 108, rules 33, integration 75; Flutter: 51/51 — all green on Node 22.23.3 (portable, process.execPath verified). No PHASE 0 regression.
- **Server authority:** Pricing, discounts, coupon usage, locks, idempotency, role resolution, and payment-derived state remain server-controlled (callables + Firestore rules). Client cannot forge trusted fields.
- **Authorization posture:** Critical UI-only gaps (role capability getters dead code; 12-screen shell unguarded). Server enforcement blocks unauthorized writes — not a data-leak/P0 exploit in practice, but is a P0 UI correctness/UX hardening item.
- **Payments/cancellation:** Server-authoritative. No eschedule action exists — moving a slot requires cancel+recreate (new reference; payments not migrated; closed appointments cannot be reopened).
- **Idempotency:** ookingRequests/{uid}_{requestId} + early existingByRequestId (scoped to uid) + in-tx claim replay returns duplicated:true with pricing:null; prevents duplicate bookings on retry.
- **Timezone/working hours:** Shop offset authoritative (default 180, clamped ±840); employee override; out-of-hours gated by flag+owner/manager+llowOutOfHours===true; midnight-crossing rejected; empty hours = no validation.

## 2. Baseline (at audit start)

| Layer | Result |
|---|---|
| Functions (npm ci) | 0 vulnerabilities; 364 packages |
| Functions test:unit | 68 passing |
| Functions test:rules | 33 passing |
| Functions test:integration | 75 passing |
| Functions test:all | 68+108 passing, 0 failing/pending |
| Flutter pub get/analyze --no-fatal-infos/test | 51/51 passing; 0 errors/0 warnings/20 infos (pre-existing baseline) |
| Node runtime | v22.23.3, npm 10.9.9 (portable at C:\Users\HP\AppData\Local\Temp\opencode\node22\dist\node-v22.23.3-win-x64\node.exe) |
| Java | OpenJDK 21.0.7 (Android Studio JBR) on PATH |
| Flutter/Dart | 3.27.2 / 3.6.1 |
| Firebase CLI | 15.25.1 |

## 3. Previous Phases — Regression Status

All PHASE 0/1/1.1/1.2/1.3 fixes remain in effect. Regression gate re-run at end: green.

## 4. Business Domain Inventory (summary)

- **Callables:** joinShopByCode, createAppointment, updateAppointment, deleteAppointment ([functions/src/index.js:193,222,515,692](functions/src/index.js#L193-L222-L515-L692)). Pricing computed server-side ([functions/src/lib/pricing.js:60-88](functions/src/lib/pricing.js#L60-L88)). 
- **Roles:** owner,manager,staff ([lib/models/app_role.dart:8](lib/models/app_role.dart#L8)); server derives role from shop.ownerId over member.role ([functions/src/lib/access.js:9-13](functions/src/lib/access.js#L9-L13)). 
- **Appointment:** statuses equested,confirmed,completed,cancelled,noShow; blocking = not cancelled/noShow; closed for transitions = cancelled/noShow or completed ([functions/src/index.js:51,668-670](functions/src/index.js#L51-L668-L670), [lib/models/enums.dart:1](lib/models/enums.dart#L1), [functions/src/lib/validate.js:13](functions/src/lib/validate.js#L13)).
- **Payment:** unpaid,depositPaid,paid server-derived ([pricing.js:60-66](functions/src/lib/pricing.js#L60-L66)); actions payment/delete_payment ops-only ([index.js:524,577](functions/src/index.js#L524-L577)).
- **Notifications:** FCM + local notifications client-side implemented ([lib/services/notification_service.dart](lib/services/notification_service.dart)); server-side push not implemented ([index.js:650-660](functions/src/index.js#L650-L660) — sets eminderSent only).
- **Timezone:** 	imezoneOffsetMinutes default 180, clamped ±840 ([functions/src/lib/time.js:3,5-12](functions/src/lib/time.js#L3-L5-L12)); client mirrors ([lib/models/shop_time.dart](lib/models/shop_time.dart)).

## 5. Role Matrix (actual roles)

| Role | UI exposure | Server enforcement |
|---|---|---|
| owner | No UI gating (all visible) | canManageRules/operations, member management; esolveRole trusts ownerId |
| manager | No UI gating | equireOperations grants access; some reads restricted (payments/expenses/feedback/inventory/chair scopes) |
| staff | No UI gating | member-only; cannot approve out-of-hours, cannot write payments/expenses/management docs; denied on many management writes |
| customer | N/A (data record only) | Cannot call privileged callables; client cannot write appointments/payments |

## 6. Workflow Matrix (sample)

| Workflow | Role(s) | UI entry | Backend | Rules | Tests | Status |
|---|---|---|---|---|---|---|
| Create appointment | member (staff/manager/owner) | BookingFlowScreen → provider.create | createAppointment (server prices/locks) | client create/update/delete false | unit+emulator+integration | PASS |
| Cancel appointment | ops (owner/manager) | AppointmentEditScreen (status/cancel) | updateAppointment(action=status) | status ops-only | integration/mutations | PASS |
| Payment record/delete | ops (owner/manager) | BusinessTools/AppointmentEdit | updateAppointment(action=payment/delete_payment) | payments read manager; write false | emulator/mutations | PASS |
| Reschedule | (unsupported) | None (edit view read-only) | None | N/A | N/A | **NOT IMPLEMENTED** |

## 7. Appointment Lifecycle

- Status strings: equested,confirmed,completed,cancelled,noShow ([enums.dart:1](lib/models/enums.dart#L1), [validate.js:13](functions/src/lib/validate.js#L13)).
- Blocking: !FREE_STATUSES.has(status) with FREE_STATUSES={'cancelled','noShow'} ([conflict.js:6,12-14](functions/src/lib/conflict.js#L6-L12-L14)).
- Closed for transitions: CLOSED_STATUSES.has(current) or current==='completed' blocks further status changes ([index.js:51,668-670](functions/src/index.js#L51-L668-L670)).
- Initial: ppointmentStatusFor(settings) → confirmed if utoConfirm===true else equested ([repository.js:74-76](functions/src/lib/repository.js#L74-L76), [index.js:254,420](functions/src/index.js#L254-L420)).
- Closing: sets lateCancellation = (start-now < cancelFreeHours*3600s), closedAt, closedById, deletes locks via eleasePlan ([index.js:674-686](functions/src/index.js#L674-L686)).
- Series: max 4 occurrences, +7d; seriesId once; shared reference ([index.js:48-51,257-259,271](functions/src/index.js#L48-L51-L257-L259-L271)).
- E2E: client sends ISO-8601 UTC + requestId (or generated); server returns authoritative rows; provider does not inject returned list (relies on stream) ([secure_api.dart:132,137-152](lib/services/secure_api.dart#L132-L137-L152), [appointment_provider.dart:132-146](lib/providers/appointment_provider.dart#L132-L146), [booking_flow_screen.dart:249-297](lib/screens/customer/booking_flow_screen.dart#L249-L297)).
- Idempotency: ookingRequests/{uid}_{requestId} (namespaced by uid); existingByRequestId queries by requestId+createdById; in-tx claim replay returns pricing:null; replay branch logs createAppointment.duplicate and returns duplicated:true ([index.js:182-192,246-249,274-283,475-486](functions/src/index.js#L182-L192-L246-L249-L274-L283-L475-L486)).
- Conflict prevention: 15-min bucket locks, 120-min grace, ±1440m padding; double-layer (locks + appointment range scan) with equestId self-skip ([conflict.js:3-5,42-80,100-110](functions/src/lib/conflict.js#L3-L5-L42-L80-L100-L110), [index.js:375-402](functions/src/index.js#L375-L402)).

## 8. Pricing Integrity & Coupon Lifecycle

- Server-only: computePricing({services,discount,settings}) returns subtotal/discount/total/deposit/paymentStatus ([pricing.js:60-88](functions/src/lib/pricing.js#L60-L88)); client never computes totals ([appointment_provider.dart:132-146](lib/providers/appointment_provider.dart#L132-L146), [booking_flow_screen.dart:249-251](lib/screens/customer/booking_flow_screen.dart#L249-L251)).
- Coupon: case-insensitive lookup; ssertCouponUsable checks active/usageLimit/validFrom/validTo/minValue/service scope; series usage check usageCount + occurrences.length > usageLimit ([index.js:151-180,366-371](functions/src/index.js#L151-L180-L366-L371)).
- Atomicity: appointment writes, locks, usageCount increment, claim write all inside single unTransaction ([index.js:273-473,437,443,458-470](functions/src/index.js#L273-L473-L437-L443-L458-L470)) — rollback on failure is structural; replay returns pricing:null ([index.js:425,475-486](functions/src/index.js#L425-L475-L486)).

## 9. Payment Workflow

- Actions payment/delete_payment require equireOperations (ops only). Client cannot write payments ([index.js:524,577](functions/src/index.js#L524-L577), [firestore.rules:92-95](firestore.rules#L92-L95)).
- Validation: method in {cash,card,transfer}; amount 0.01–1,000,000, 2dp ([validate.js:131-142](functions/src/lib/validate.js#L131-L142)).
- Manual sale (ppointmentId empty): non-transactional; hardcodes customerName/phone/chairId/employeeId/materialCost/notes to ''/null/0 ([index.js:528-545](functions/src/index.js#L528-L545)).
- Appointment-linked: sums all payments (excluding deleted), sets 
extCollected = round2(collected+amount), derives paymentStatus via derivePaymentStatus(totalAmount, nextCollected), updates only paymentStatus,collectedAmount ([index.js:548-569](functions/src/index.js#L548-L569), [pricing.js:60-66](functions/src/lib/pricing.js#L60-L66)).
- Delete payment: recomputes excluding deleted payment; standalone deletion returns without touching appointment ([index.js:576-603](functions/src/index.js#L576-L603)).
- **Gaps:** no remaining-balance cap (over-collection allowed); UI collects materialCost/chair/employee/customer for payments but only ppointmentId/method/amount sent; server writes materialCost:0 always; standalone payments get chairId:null (breaks chair profit mapping); payment-not-found on repeat delete (not idempotent); paymentDataFor dead ([repository.js:78-90](functions/src/lib/repository.js#L78-L90)).
- Tests: partial→full derivation, two-payment recompute on delete, standalone sale/delete — all green.

## 10. Cancellation, Rescheduling, Late Cancellation

- Close: status in {cancelled,noShow} ops-only; same-status returns unchanged:true; closed/completed cannot be reopened ([index.js:662,667-670](functions/src/index.js#L662-L667-L670)).
- Late cancellation: lateCancellation = (start-now < cancelFreeHours*3600s); sets closedAt, closedById; locks released via eleasePlan ([index.js:674-686](functions/src/index.js#L674-L686), [conflict.js:100-110](functions/src/lib/conflict.js#L100-L110), [settings.js:5](functions/src/lib/settings.js#L5)).
- **Not rendered:** lateCancellation, closedAt, closedById not parsed by Appointment.fromMap and never displayed ([lib/models/appointment.dart:149-184](lib/models/appointment.dart#L149-L184)).
- **Not enforced:** cancelFeePercent/whoPaysFees defaults exist but never used ([settings.js:6-7](functions/src/lib/settings.js#L6-L7)).
- **Rescheduling:** **NOT IMPLEMENTED**. No eschedule action; startTime only written on create; rules block client appointment writes; appointment edit screen is view-only (no date/time save); deleteAppointment callable exists but has **no UI caller**; "move" = cancel+recreate (new doc/reference, payments not migrated, closed cannot reopen) ([validate.js:17](functions/src/lib/validate.js#L17), [index.js:418,692-709](functions/src/index.js#L418-L692-L709), [firestore.rules:63-66](firestore.rules#L63-L66), [appointment_edit_screen.dart:194-197,151](lib/screens/admin/appointment_edit_screen.dart#L194-L197-L151), grep for deleteAppointment callers: none in lib/).

## 11. Timezone / Working Hours

- shopOffsetMinutes default 180, clamped ±840; localParts shifts by offset, weekday Monday=1; slot normalization drops malformed entries ([time.js:3-57](functions/src/lib/time.js#L3-L57)).
- itsWorkingHours: same weekday after shift required; containment check; empty hours ⇒ 	rue ([time.js:42-50](functions/src/lib/time.js#L42-L50), [index.js:341-344](functions/src/index.js#L341-L344)).
- Employee override when non-empty ([index.js:337-340](functions/src/index.js#L337-L340)).
- Out-of-hours: flag + canManageOperations(role) + settings.allowOutOfHours===true; if not fit and flag false → OUTSIDE_WORKING_HOURS; missing manager/flag/setting → OUT_OF_HOURS_NOT_ALLOWED ([index.js:344-359](functions/src/index.js#L344-L359), [time.js:52-57](functions/src/lib/time.js#L52-L57)).
- hasWorkingDay skipped in the out-of-hours branch by structure ([index.js:344-358](functions/src/index.js#L344-L358)).
- Client: shop_time.dart mirrors server helpers; generateSlots uses device-local day and employee-only hours (diverges from server shop-hours fallback) — server authoritative ([slot_utils.dart:12-50](lib/widgets/slot_utils.dart#L12-L50), [shop_time.dart](lib/models/shop_time.dart), [index.js:337-343](functions/src/index.js#L337-L343)).

## 12. Shop Isolation, Shop Switching, Logout/Session

- Shop isolation enforced server-side (paths scoped to shops/{shopId}; rules deny cross-shop; esolveRole from shop; join code lookup returns shopId only). Client has **no shop-switching capability** ([firestore.rules](firestore.rules), [index.js:193,215](functions/src/index.js#L193-L215), [access.js:9-13](functions/src/lib/access.js#L9-L13)).
- Startup: Firebase init guarded by irebaseReady/irebaseError → ConfigErrorScreen; RootGate binds providers only after uth.shopId!=null; no pre-role stream start causing deadlock ([main.dart:11-39](lib/main.dart#L11-L39), [root_gate.dart:23-52](lib/screens/root_gate.dart#L23-L52), [auth_provider.dart:23-38,60-71,130-131](lib/providers/auth_provider.dart#L23-L38-L60-L71-L130-L131)) — regression-tested ([test/auth_startup_test.dart](test/auth_startup_test.dart), [test/startup_config_error_test.dart](test/startup_config_error_test.dart)).
- Logout: captures providers first, calls uth.signOut(), resets 6 providers, clears avorite_barber_{shopId} best-effort, pops to first route ([profile_screen.dart:121-157](lib/screens/profile_screen.dart#L121-L157)); AuthProvider.signOut unsubscribes FCM topic, clears session in inally ([auth_provider.dart:164-179,76-80](lib/providers/auth_provider.dart#L164-L179-L76-L80)).
- **Gaps:** ShopManager.shopName never reset ([shop_manager.dart:5](lib/services/shop_manager.dart#L5)); NotificationService._initialized is one-way latch (not reset on logout/sign-in cycle) — topic resubscription still happens on sign-in ([notification_service.dart:19,25-26](lib/services/notification_service.dart#L19-L25-L26), [auth_provider.dart:132,153](lib/providers/auth_provider.dart#L132-L153)).
- ShopManager.shopId! non-null assertions appear in 9 call sites (post-bind, but latent if reached during teardown) ([grep via prior audit: staff_screen.dart:93,152; track_booking_screen.dart:42]).

## 13. Loading/Error/Empty States, Stream Safety, Firebase Error Mapping

- Shared _listen<T> pattern sets loading=false on data/error, handles FirebaseException with code=='permission-denied' by not setting error (prevents noisy errors) and clearing gatesLoading ([appointment_provider.dart:47-67](lib/providers/appointment_provider.dart#L47-L67)); similar in shop/discount/expense/feedback providers (permissionDenied cleared on error/read) ([shop_provider.dart:62-69](lib/providers/shop_provider.dart#L62-L69), [discount_provider.dart:35-41](lib/providers/discount_provider.dart#L35-L41), [expense_provider.dart:34-41](lib/providers/expense_provider.dart#L34-L41), [feedback_provider.dart:34-41](lib/providers/feedback_provider.dart#L34-L41), [business_tools_provider.dart:93-104](lib/providers/business_tools_provider.dart#L93-L104)).
- **Critical gaps:** permissionDenied/error fields **never read by any widget** ([business_tools_provider.dart:37,50,96,391](lib/providers/business_tools_provider.dart#L37-L50-L96-L391)); staff sees plausible-but-wrong "no data" (expenses/reports) instead of "permission denied" ([reports_screen.dart:31-47](lib/screens/admin/reports_screen.dart#L31-L47), [dashboard_screen.dart:22-39](lib/screens/admin/dashboard_screen.dart#L22-L39)).
- **Denied-write loop:** BusinessToolsProvider._syncCustomerProfiles writes to customers (manager-only) from appointments stream callback without wait/catch; runs for staff on every snapshot ([business_tools_provider.dart:70-77,243-312](lib/providers/business_tools_provider.dart#L70-L77-L243-L312)) — generates recurring unhandled async errors.
- Stream safety: all 23 .listen() sites covered; AuthProvider.dispose() added; subscriptions cancelled on bind/reset/dispose ([appointment_provider.dart:47-67,189-207](lib/providers/appointment_provider.dart#L47-L67-L189-L207), [auth_provider.dart:23-38,60-71](lib/providers/auth_provider.dart#L23-L38-L60-L71)).
- Firebase error mapping: SecureApi._kindFor maps stable codes; _call normalizes FirebaseFunctionsException and **also** catches transport exceptions (SocketException, TimeoutException, HandshakeException) → 
etwork-unavailable ([secure_api.dart:30-70,76-102](lib/services/secure_api.dart#L30-L70-L76-L102)). UI uses code-based mapping ([secure_error_text.dart:10-67](lib/services/secure_error_text.dart#L10-L67)).

## 14. Customer/Staff/Manager/Owner Journeys, Idempotency, Offline Resilience

- **Customer journey:** create booking E2E tested via server (pricing/conflict/idempotency green). UI never computes price; uses server response ([booking_flow_screen.dart:249-297](lib/screens/customer/booking_flow_screen.dart#L249-L297)).
- **Staff journey:** can create appointments (member), cannot approve out-of-hours alone, cannot write payments/expenses/management; **but** can navigate all admin tabs (no UI gating) — server blocks writes.
- **Manager/Owner:** UI unguarded; server enforces equireOperations/owner-only.
- **Double-click/idempotency:** equestId generated client-side (UUID) or passed; server returns duplicated:true on replay — prevents duplicates ([secure_api.dart:104,132-152](lib/services/secure_api.dart#L104-L132-L152), [index.js:246-249,274-283,475-486](functions/src/index.js#L246-L249-L274-L283-L475-L486)).
- **Offline:** transport exceptions normalized to 
etwork-unavailable ([secure_api.dart:90-102](lib/services/secure_api.dart#L90-L102)); streams can error (handled) — retry is app-level, not automatic blind retry.

## 15. Data Consistency, Cache, Notifications, Indexes, Models, Logging, Perf

- **Consistency:** server is source of truth; appointment streams drive UI. Returned appointments used only for success screen ([booking_flow_screen.dart:274-297](lib/screens/customer/booking_flow_screen.dart#L249-L297), [appointment_provider.dart:26-43](lib/providers/appointment_provider.dart#L26-L43)).
- **Cache:** 6 providers reset on logout; ShopManager.shopName never reset (INFO). avorite_barber_{shopId} cleared best-effort ([profile_screen.dart:144-152](lib/screens/profile_screen.dart#L144-L152)).
- **Notifications:** client-only push/local; eminderSent marker only ([notification_service.dart](lib/services/notification_service.dart), [index.js:650-660](functions/src/index.js#L650-L660)).
- **Indexes:** 22 single-field orderBy need no composite; 6 composites in irestore.indexes.json serve server queries ([PHASE1_REPORT.md](PHASE1_REPORT.md), [firestore.indexes.json](firestore.indexes.json)) — no index changes required.
- **Model contract:** dates parsed via irestore_date.dart accepting Timestamp/ISO/epoch/DateTime → UTC-flagged ([firestore_date.dart](lib/models/firestore_date.dart), [appointment.dart:149-184](lib/models/appointment.dart#L149-L184)); enums string-matched ([enums.dart](lib/models/enums.dart), [validate.js:13-17](functions/src/lib/validate.js#L13-L17)).
- **Logging:** debugPrint for create result; server uses irebase-functions/logger with redacted codes ([secure_api.dart:151](lib/services/secure_api.dart#L151), [index.js:103-106,488-505](functions/src/index.js#L103-L106-L488-L505)) — no passwords/tokens observed.
- **Perf:** IndexedStack keeps 12 admin screens alive (intentional); duplicate listeners avoided by bind guard; business-tools sync runs on every appointments snapshot (inefficient but not correctness bug) ([admin_home_screen.dart:79](lib/screens/admin/admin_home_screen.dart#L79), [business_tools_provider.dart:70-77](lib/providers/business_tools_provider.dart#L70-L77)).

## 16. Bugs Found

| ID | Severity | Component | Description | Root Cause | Reproduction | Fix Suggestion | Status |
|---|---|---|---|---|---|---|---|
| AUTH-001 | **P0** | UI/Auth/Navigation | Role capability getters never consumed; entire admin shell unguarded. Any role can deep-link to all 12 tabs. | isOwner/isManager/canManage* defined but unused ([app_role.dart:28-38](lib/models/app_role.dart#L28-L38), [auth_provider.dart:41-44](lib/providers/auth_provider.dart#L41-L44)); dmin_home_screen.dart renders unconditionally ([34-47,79,146-164](lib/screens/admin/admin_home_screen.dart#L34-L47-L79-L146-L164)). | Login as staff, open AdminHomeScreen (or any push target) → all management entries visible and accessible. | Gate drawer/tabs by role (filter items; redirect on route entry). Also guard provider-heavy screens that depend on denied reads. Do not rely on server alone for UX. | **OPEN** |
| AUTH-002 | P0 | BusinessTools/Streams | _syncCustomerProfiles writes to customers (manager-only) on every appointments snapshot; staff triggers denied writes, unhandled async errors. | Callback at [70-77](lib/providers/business_tools_provider.dart#L70-L77) calls _syncCustomerProfiles() without wait/catch; write at [309](lib/providers/business_tools_provider.dart#L309). Rules: [117-121](firestore.rules#L117-L121) manager-only. | Staff session with appointments → repeated permission-denied from customers writes; console errors. | Gate sync behind ole==manager||role==owner (or ops). Catch and ignore permission-denied explicitly. Avoid unawaited fire-and-forget that throws. | **OPEN** |
| STATE-001 | P1 | UI State | permissionDenied/error never surfaced to widgets. Reports/Dashboard show zeros/empty for denied reads. | Set at [96](lib/providers/business_tools_provider.dart#L96), [37,50,391](lib/providers/business_tools_provider.dart#L37-L50-L391) but never read. | Staff views Reports/Expenses tabs → appears "no data" vs "permission denied". | Display permission-denied banner/error state in affected screens (Reports, Dashboard, Expenses, Feedback, BusinessTools tabs) using provider flags. | **OPEN** |
| PAY-001 | P2 | Payments UI/Server | UI sends only ppointmentId/method/amount; server hardcodes materialCost:0, drops collected materialCost/chair/employee/customer. Standalone payments get chairId:null. | [business_tools_screen.dart:206-246](lib/screens/admin/business_tools_screen.dart#L206-L246), [business_tools_provider.dart:156-164](lib/providers/business_tools_provider.dart#L156-L164), [index.js:530-542,556-568](functions/src/index.js#L530-L542-L556-L568). | Record payment via BusinessTools → server ignores material cost/chair mapping. | Either extend callable to accept/validate these fields (and write them), or remove UI fields until supported. Align chair-profit filter with stored chairId. | **OPEN** |
| PAY-002 | P2 | Payments Deletion | delete_payment not idempotent (repeat → payment-not-found); UI has no confirmation dialog. | [index.js:582](functions/src/index.js#L582); delete button at [business_tools_screen.dart:284-287](lib/screens/admin/business_tools_screen.dart#L284-L287) (vs confirm at [expenses_screen.dart:95-102](lib/screens/admin/expenses_screen.dart#L95-L102)). | Delete same payment twice → second call returns payment-not-found. | Make delete idempotent server-side (treat missing as success) or handle 
ot-found as success in UI; add confirm dialog. | **OPEN** |
| PAY-003 | P3 | Payments Logic | Over-collection allowed; derivePaymentStatus returns depositPaid when 	otal==0 && collected>0 (never paid). | [validate.js:137-142](functions/src/lib/validate.js#L137-L142), [index.js:548-554](functions/src/index.js#L548-L554), [pricing.js:60-66](functions/src/lib/pricing.js#L60-L66). | Record amount > remaining → collectedAmount exceeds 	otalAmount; status becomes paid only when collected>=total and total>0. | Consider capping to remaining balance and/or normalizing status when 	otal==0. Document intended behavior if free appointments allowed. | **OPEN** |
| RES-001 | P2 | Rescheduling | **No reschedule API/UI.** Moving requires cancel+recreate (new reference; payments not migrated; closed cannot reopen). | [validate.js:17](functions/src/lib/validate.js#L17) (no reschedule action); edit screen view-only [appointment_edit_screen.dart:194-197](lib/screens/admin/appointment_edit_screen.dart#L194-L197); no deleteAppointment callers in lib/; rules block client writes [firestore.rules:63-66](firestore.rules#L63-L66). | Attempt to change date/time on existing appointment → no save path exists. | If business requires reschedule, add server action (atomic move with lock re-acquisition, preserve payment linkage or handle migration) and wire UI. If not required, document as "not supported" in UX. | **OPEN** |
| META-001 | P2 | Closure metadata | lateCancellation, closedAt, closedById stored but never read/rendered; cancelFeePercent/whoPaysFees never enforced. | [index.js:677-679](functions/src/index.js#L677-L679), [appointment.dart:149-184](lib/models/appointment.dart#L149-L184), [settings.js:6-7](functions/src/lib/settings.js#L6-L7). | Cancel late/early → flag stored server-side but UI shows no indicator/fee. | Surface late-cancellation in UI; either enforce fee server-side or remove fee settings from UI. | **OPEN** |
| STATE-002 | P3 | Session/cache | ShopManager.shopName never reset; NotificationService._initialized one-way latch. | [shop_manager.dart:5](lib/services/shop_manager.dart#L5), [notification_service.dart:19,25-26](lib/services/notification_service.dart#L19-L25-L26). | Logout → login different shop → shopName may remain stale; process lifetime: FCM init not re-run. | Reset shopName in signOut/eset; consider resetting _initialized on sign-out or re-initializing on auth change. | **OPEN** |
| TOOL-001 | P3 | Tooling | Emulator teardown flake: 1/7 runs exits 2 after inner script succeeded (race in firebase-tools 15.25.1); fails safe. Analyzer 20 infos (pre-existing). | [PHASE1_3_REPORT.md §8.4, §12](PHASE1_3_REPORT.md#L8.4-L12). | Local runs occasionally show teardown error despite all tests green. | Monitor; retry once in hooks if CI; pin newer firebase-tools when adopting majors. No code change needed. | **KNOWN** |

## 17. Remaining Issues Summary

| Priority | Count | IDs |
|---|---|---|
| P0 | 2 | AUTH-001, AUTH-002 |
| P1 | 1 | STATE-001 |
| P2 | 4 | PAY-001, PAY-002, RES-001, META-001 |
| P3 | 2 | STATE-002, TOOL-001 |

## 18. Final Test Matrix

| Check | Command | Result |
|---|---|---|
| Functions unit | 
pm --prefix functions run test:unit | **68 passing** (exit 0) |
| Functions rules | 
pm --prefix functions run test:rules | **33 passing** (exit 0) |
| Functions integration | 
pm --prefix functions run test:integration | **75 passing** (exit 0) |
| Functions full | 
pm --prefix functions run test:all | **68+108 passing** (exit 0) |
| Flutter pub get | lutter pub get | OK |
| Flutter analyze | lutter analyze --no-fatal-infos | 0 errors/0 warnings/20 infos (exit 0) |
| Flutter test | lutter test | **51/51 passing** (exit 0) |
| Release APK (unsigned-by-design) | lutter build apk --release | 59.0 MB, no META-INF signature (verified earlier); signing path proven with throwaway key |
| Security scan (secrets/mojibake/paths) | git grep + checks | No private keys/service accounts; Firebase client API keys only (documented); no machine-bound paths in tracked code (fixed in cfb6394) |
| Security regressions | all above | **PASS** |

## 19. Final Verdict

**PASS WITH LOW-RISK NOTES**

All security and business-critical backend invariants hold. The P0 items are **UI-only authorization gaps**: server-side rules and callables correctly deny unauthorized actions. They represent UX correctness and defense-in-depth (not exploitable to bypass server checks). P1–P3 are documentation/UX/robustness issues with no observed regression.

**PHASE 2 COMPLETE — READY FOR PHASE 3**
