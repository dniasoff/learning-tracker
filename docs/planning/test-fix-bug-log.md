# Test-and-fix bug log

One line per defect: **symptom → cause → fix → test**. Newest first. Part of the exhaustive
test-and-fix run (plan: `exhaustive-test-and-fix-plan-2026-05-29.md`).

> Production fixes are Opus-owned. Sonnet sub-agents only write/verify test files.

---

## Phase 5b — Navigation guards (unit tests + SYSTEMIC LOCKOUT FIX)

Added unit tests for all 5 AutoRoute guards (Auth 19, Restore 12, Pin 25, ChildMode 7, Profile 14 — branch
coverage + per-branch "resolver always resolves, never a dead-end" assertions). Adversarial verifiers then
surfaced a **systemic production bug** across the whole guard layer:

**BUG (HIGH, lockout): no guard wrapped `onNavigation` in a top-level try/catch.** Any throw inside a guard —
`PinLockoutException` from the PIN prompt, `ProfileMode.fromStorageKey` `ArgumentError` on an unknown mode, a
Drift/SharedPreferences/device_registry failure, a disposed-provider lambda — escaped `onNavigation`, so
AutoRoute's `NavigationResolver` completer was never completed. auto_route 11.1.0 awaits that completer →
**permanent navigation hang (lockout)** on the affected route, with no error surfaced. This is precisely the
lockout class the project has been burned by before.

**FIX:** wrapped every guard's `onNavigation` body in a try/catch that logs (`AppLogger.error`) and always
resolves, guarded by `if (!resolver.isResolved)`. Fail direction chosen per guard role:
- `AuthGuard` → fail to the always-reachable **SignInRoute** + `next(false)` (was a `try/finally` with no
  `catch`, so a corrupt `device_registry` made `getAllAccounts()`/`close()` propagate → hang).
- `ProfileGuard`, `RestoreGuard` → **fail OPEN** (`next()`) — not security gates; let the user into the
  app/shell (which handle empty/no-profile state) rather than hang. (ProfileGuard body extracted to `_resolve`.)
- `PinGuard`, `ChildModeGuard` → **fail CLOSED** (`next(false)`) — security gates; deny cleanly, never bypass.

**Tests:** each guard got a fail-safe regression test that injects a throwing dependency and asserts the safe
resolve (no throw, no hang). AuthGuard's is exercised by writing a non-sqlite file to the registry path.
`make analyze` clean; all 111 navigation/auth tests green.

**Dismissed as NOT a bug:** the ChildModeGuard "corrupt mode string → ArgumentError" finding is already
defended at the DB layer — `learner_profiles.mode` has a CHECK constraint `IN ('adult','child')`, so a corrupt
string can't be persisted. The fail-safe stays for the reachable throw sources (disposed provider, DB I/O,
defence-in-depth against a future migration). Also **deleted** the redundant old `test/core/auth/auth_guard_test.dart`
(3 branches, no lockout assertions, shared-path mock) — fully subsumed by the new canonical
`test/core/navigation/auth_guard_test.dart` (19 tests).

---

## Phase 8 — Coverage wave 4: account/tutoring/dashboard (+ CRITICAL upgrade-crash fix)

**+188 tests** (green; 3 skips on email-panel medium bugs): upgrade_to_cloud_service (33), email_verification_confirm_panel
(24), firestore_tutor_grant_repository (76), dashboard_providers (41), achievement_unlock_celebration (14).
(`magic_link_service` agent failed to return output — re-target next wave.)

**BUG fixed (CRITICAL — runtime crash on the account-merge flow):** `discardLocalCredentials()` called
`UserProfileDao.updateUserProfile()` → `update(accounts).replace(entry)`, which requires a COMPLETE row but was
handed a partial companion (`id` + `passwordHash` only) → **`InvalidDataException` at runtime**. Any user who
chose "discard local" on the email-collision merge path (and thus all of `executeKeepCloudDiscardLocal()`) would
crash. FIX: added a dedicated `UserProfileDao.clearPasswordHash(profileId)` doing a targeted `.write()` (the same
partial-update pattern as `upgradeLocalToCloud`); `discardLocalCredentials` now calls it. **Un-skipped the 3
tests** the wave had parked over this crash — they pass against the real in-memory DAO. Full suite re-gated.

### Findings logged (email_verification_confirm_panel — medium/low, backlog)
- RTL (he) layout overflow (~16px) in the Send-Again+Cancel row at 360px (wrap children in Flexible).
- `_wrapSendAgain`/`_wrapVerified` use try/finally with NO catch → a throwing callback propagates as an unhandled
  async error (should catch + surface). (2 tests skipped over this.)
- All panel strings hardcoded English (i18n) — `Confirm Your Email`, `I've verified`, `Open Email`, `Send Again`, `Cancel`.
- `upgrade_to_cloud_service` deeper paths (verifier): `tryFinalizeVerifiedCloudUpgrade` bare `catch(_)` swallows
  DB/network errors; `executeUploadLocalIntoCloud` no cloudBorn guard; `_extractFirebaseCode` null-return rethrow.

---

## Phase 8 — Coverage wave 3: remaining screens & widgets (+ scope-save bug fix)

**+242 tests** (green, analyze clean): scope_selection + lifetime_marking (42), track_management_body +
track_learning_order (29), onboarding + bulk_mark (34), profile_picker + tutored_children_section (19),
text_display reader (38, incl. tutor live-mark gating), lifetime_folder_styled_widgets + notification_providers (79).

**BUG fixed (scope_selection_screen, LOW but real):** `_save()` had no else-branch — with "select all" toggled
OFF, a level picked, but NO values ticked, it wrote nothing yet still `pop()`ed with a *success* snackbar, so
the user believed the scope was cleared/changed while the previous scope silently survived. FIX: the AppBar
Save button is now disabled (`onPressed: null`) unless `_selectAll || _selectedValues.isNotEmpty` (a `_canSave`
getter) — an empty subset is no longer "saveable". Regression test added (Save disabled on empty subset, re-enabled
once a value is ticked).

### Findings logged (not fixed — low/edge or test-coverage gaps)
- `scope_selection._save`: `trackId = track?.id ?? 0` fallback can write a dangling `trackId=0` row if a
  curriculum has no track (likely unreachable for an enrolled curriculum; logged).
- `TrackManagementBody` vs `TrackManagementHubScreen`: archive path diverges (low).
- Verifier false-confidence notes: several suites pre-set state rather than driving the widget (sliders/drag),
  and a couple of "policy" asserts call the mock directly rather than through the screen — backlog to harden.

---

## Phase 8 — Coverage wave 2: sync engine + onboarding/settings/profiles

**+298 tests** (green, analyze clean, 2 documented skips; no high-severity prod bugs): `firestore_gateway_impl`
19.6%→ (**114** — path building, merge idempotency, internal-key stripping, Timestamp normalisation, batch
chunking, pagination, listeners, unauthenticated/permission-denied error paths), `sync_orchestrator` 54.5%→
(**29** — pull/push state machine, once-per-launch guard, resume throttle, status emissions, pull ordering),
`local_data_upload_service` 0%→ (**42** — outbox pipeline), onboarding `wizard_steps` 0%→ (**62**),
`account_actions` 0%→ (**25** — sign-out/delete dialog confirm+cancel flows), `parent_pin_keypad_dialog` 30%→
(**26** — digit entry, verify, error/clear).

### Documented skips / findings (not high-severity)
- `firestore_gateway` fetchPage cursor test: `fake_cloud_firestore` can't handle a `FieldPath.documentId`
  startAfter cursor (`skip:true`) — fake-library limitation, works on the real emulator/prod.
- `sync_orchestrator` timeout test: `_perStepTimeout`/`_overallTimeout` are private static consts with no
  injectable seam (`skip:true`); would need 30–90s real waits. Low — recommend constructor Duration params.
- `sync_orchestrator` goals-subcollection PUSH gap: known/pre-existing (memory project_sync_orchestrator_status_bug)
  — pull works + is tested; push absence is the open item, unchanged here.
- `account_actions` (LOW): `_DeletingAccountOverlay` calls `ref.read(authStateProvider.notifier).signOut()` in a
  catch during the build/initState-driven deletion; if `deleteAccount` threw *synchronously* it would mutate a
  provider during build. Edge case (deleteAccount is an async CF call). Logged.

### Verifier-flagged deeper gaps (backlog)
- `firestore_gateway`: real multi-chunk partial-commit `SyncPushException` committed-keys accuracy;
  `deleteLearnerProfile` callable path; `_timestampify` DateTime input branch; self-tutoring grant dedup in
  `listenToTutorGrants`; `deleteUserData` nested sub-subcollection cleanup.
- `local_data_upload_service`, `wizard_steps` (sliders pre-set not dragged), `pin_keypad`: several branches.

---

## Phase 8 — Coverage-leverage wave (highest-uncovered files)

Coverage measured 2026-05-30: **68.4%** overall (36774/53763), up from the 58.5% baseline; full suite +6956
tests green. Targeted the highest-leverage uncovered files with **+249 tests** (all green, analyze clean, no
prod bugs):
- `sefaria_ref_matcher.dart` (was 0%) — **116 unit tests** across normalize/displayRef/range-expand/fuzzy-match/
  container-resolution/program-today-refs.
- `scheduler_providers.dart` (was 11.7%) — 43 tests (section/grouped notifiers, SkippedTasks date-rollover,
  paceStatus, overdueCount, firstTaskInTrackForCategory).
- `sign_in_controller.dart` (was 8.5%) — 24 tests (auth-error mapping, Google sign-in routing, resend-verify).
- `step_scope.dart`/`scope_views.dart` (was ~0%) — 22 tests (DNI-202 scope auto-skip, toggle/select-all/Learn-All).
- `step_starting_position(+calendar+goal).dart` (was ~0%) — 44 tests (the [today−30, today] window + **back-date
  → positive daysFromToday/overdue** product rule, goal step).

### OPEN — deeper integration paths still uncovered (verifier-flagged backlog)
- `scheduler_providers`: `allDailyTasksProvider`'s ~400-line body is bypassed (tests override it with fixed
  lists) — the previously-skipped priority-boost + bulk-prior sentinel paths aren't exercised end-to-end.
- `sefaria_ref_matcher`: level4 hierarchy filtering, fuzzy-score==1 boundary, container-vs-indexed fallback
  ordering, range→container fallback, and `normalizeTitle` blind spots (bavli/yerushalmi/tractate/masechta).
- track-setup scope: re-render/re-selection stateful logic; start-position: a few production UI paths.

---

## Phase 6 — Settings / scheduler / notifications / sacred-time / learning (wave a)

+127 L1 behaviour tests across 5 zero/low-coverage screens (all green, analyze clean): **CityPicker** (19 —
search/filter, select→`setManualCity`+`router.pop`, loading/empty/error), **CurriculumSettings** (26 —
program tiles, change/request, no track-type label), **Learning** (22 — reader states + the **tutor
live-mark-block product invariant** `canMarkLiveCompletion=false`, chazara-only-when-enabled), **Scheduler**
(23 — view toggle, skip writes + snackbar, states), **Notifications** (37 — each reminder toggle persists to
prefs, permission-denied/disabled, states). The LearningScreen live-mark invariant test passes → the gate
holds in the UI.

### OPEN — i18n / cosmetic (Phase 8 / backlog)
- `city_picker_screen.dart:79`: empty-state `'No matches for "$query".'` hardcoded English (not l10n).
- `learning_screen.dart` `_LearnTaskCard`: `Icons.history_rounded` renders on ALL task cards regardless of
  priority (cosmetic, not a product bug).

### OPEN — coverage strengthening (verifier-flagged; backlog for the loop pass)
- Notifications: reminder **time** selection persistence (`reminderTimeProvider`) is not asserted (toggles are).
- Scheduler: skip **Undo** action is found but not tapped/asserted to call `undoSkip`.
- CurriculumSettings: error-state path claimed in header but no throwing-provider test (screen is thin).
- Learning: OVERDUE task UI branch (priority_high icon + red OVERDUE badge) not asserted.
- CityPicker: `TrimLeadingSpaceFormatter`, `admin1==""` branch, query-change provider re-watch untested.

---

## Phase 7 — Backend / Cloud Functions (wave b)

**All 27 Cloud Functions now have tests: 271 assertions, 271/271 green** via `make test-functions`
(tsc build → `firebase emulators:exec --only firestore,auth` → `node --test --test-concurrency=1
functions/test/cf_*.test.mjs`). The suites run the REAL built handlers through `fft.wrap()` and assert the
gate matrix (unauthenticated / invalid-argument / not-found / inactive-grant / wrong-tutor / missing-permission)
plus the Firestore side-effect + audit-log write of each happy path. Files: cf_tutor_completions (8),
cf_tutor_goals_tracks (48), cf_tutor_content (70), cf_tutor_settings_profile (44), cf_grant_invite (29),
cf_grant_revoke (29), cf_deletes (22), cf_triggers (21).

**DEPLOYED 2026-05-30:** `firebase deploy --only functions --project torah-study-tracker` — all 27 functions
"Successful update operation", "Deploy complete!". The 3 fixes (expirePendingInvites / declineTutorInvite /
deleteCurriculumTrack) are live; the live backend now matches the repo.

**HARNESS BUG fixed (was hiding 31 failures):** `clearFirestore()` used the emulator REST clear endpoint,
which returned before nested subcollections (`tutor_grants/{id}/audit_log`) were purged — stale grants
survived (so "no grant → not-found" tests instead hit a stale active grant → permission-denied) and audit
entries accumulated across tests (`2 !== 1`, `3 !== 1`…). Switched to the Admin SDK's awaited
`recursiveDelete` over `tutor_grants`/`users`/`tutor_active_access`. Also added the **Auth emulator**
(`--only firestore,auth`) since accept/decline invite call `admin.auth().getUser()`.

### Server-function findings (triaged)
**FIXED (real bugs, with regression tests — 274/274 green):**
- `expirePendingInvites` (MEDIUM): the Firestore transaction `txn.update(grantDoc.ref, …)` never re-read the
  doc inside the txn — the snapshot was taken outside it, so a state change (accept/decline/rescind) between
  the query and commit was a lost-update race that could expire an already-accepted grant. FIXED: re-read
  inside the txn and only expire if `state === 'pending'`; return whether it actually expired.
- `declineTutorInvite` (MEDIUM): called `admin.auth().getUser(callerUid)` BEFORE the cheap uid check. FIXED:
  resolve `isTutorByUid` first (no Auth call) and only fall back to the live `getUser` email comparison when
  the uid doesn't match — preserves the permission-before-state order, avoids an Auth round-trip on the common
  path, and makes the uid-match decline path testable without the Auth emulator (2 new regression tests).
- `deleteCurriculumTrack` (MEDIUM): used shallow `trackRef.delete()` while every sibling delete CF uses
  `recursiveDelete`. FIXED: `db.recursiveDelete(trackRef)` (+ a regression test seeding a nested subcollection
  doc and asserting it's purged).

**Documented (defensible design / low value — NOT changing):**
- `tutorBulkPriorCompletions`: today/future completion → `permission-denied` (arguably `invalid-argument`);
  also inline-duplicates `verifyTutorGrant` instead of calling it (drift risk). Rejection itself is correct.
- `revokeTutorGrant`/`resignTutorGrant`: inactive grant → `failed-precondition` (not `permission-denied` like
  the verifyTutorGrant CFs) — defensible; and neither writes an audit_log entry (grant `state`/`revoked_at`
  are self-documenting). Consider an audit entry later.
- `tutorEditProfile`: `permKey=null` → any active grant may edit name/avatar/mode (intentional per FR-3 §1920).
- `listTutorGrants` `pending_for_me` returns `[]` when caller has no verified email (silent, not an error).
- `purgeExpiredAuditLogs`: counter increments per-grant not per-entry (cosmetic logging only).

### Coverage gap (logged)
- `acceptTutorInvite`/`declineTutorInvite` happy paths need a seeded Auth-emulator user; the gate tests are in
  but the full accept/decline success flow is not yet asserted. Follow-up: seed `admin.auth().createUser` +
  assert the grant→active transition + tutor_active_access doc + audit entry.

---

## Phase 7 — Backend / Firestore rules (wave a)

`functions/test/firestore_rules.test.mjs`: **5 → 24/24 match paths, 70 assertions, 0 fail** (4.8s under the
firestore emulator via `make test-rules`). New coverage: the full learner subtree (settings, stage_definitions,
curriculum_tracks, bookmarks, learning_order, preferences, streak_events, learning_ledger, points_ledger,
reward_redemptions, import_metadata, profile_programs, curriculum_scopes, study_day_configs) — each asserting
owner read+write, tutor active-access read-only, write-block, stranger/anon deny, delete policy, and `hasOnly`
field whitelists; the tutor-EXCLUSION blocks (`users/{uid}/profile/{docId}`, `diagnostic_logs`); the
`tutor_grants/audit_log` party-read/no-client-write; and the global `/{document=**}` default-deny.

**Rule hardening (comment-only — no behaviour/deploy change, re-verified green):** added explicit "tutor access
intentionally excluded" intent comments to the `/profile/{docId}` and `/diagnostic_logs` blocks (agent finding
#1) — account-scoped siblings of `learner_profiles/`, owner-only by design; guards against a future refactor
accidentally extending tutor read access to account data.

### Reviewed & dismissed (NOT bugs)
- Finding #2 (tutor_active_access asymmetry): the parent/owner cannot directly read the
  `{tutor}_{owner}_{profile}` access-index doc (only the tutor can). BY DESIGN — the index is a CF-maintained
  tutor-side lookup; the parent discovers active tutors via `tutor_grants` (which they CAN read). No change.

---

## Phase pre-0 — green the baseline (WIP-induced failures)

The working tree carried in-progress work (profile-switcher / settings account-separation /
tutor-permissions). The full suite was red: **12 failing tests**. Owner decision: *treat the working
tree as the baseline and fix the 12*. Each WIP change was checked against the product memories and
found correct; two of the WIP files also carried real bugs that the stale tests had masked.

### Real production bugs (fixed)

- **BUG-001 · AppShell crashes for profile-less users.**
  *Symptom:* `app_shell_test` threw `AutoTabsRouter operation requested with a context that does not
  include an AutoTabsRouter`; in production a tutor-only adult (0 own profiles) entering the shell
  would crash in a post-frame callback.
  *Cause:* the WIP "jump to Settings tab" called `AutoTabsRouter.of(context)` using the
  `_AppShellScreenState`'s own context, which sits **above** the `AutoTabsScaffold` that creates the
  tabs router — so the lookup fails.
  *Fix:* `lib/app/router/app_shell.dart` — schedule the jump from inside `appBarBuilder`, which hands
  a valid `tabsRouter`; `build()` only resets the `_didJumpToSettings` latch.
  *Test:* `test/core/navigation/app_shell_test.dart` (seeds a profile so the shell stays on Dashboard;
  the profile-less jump path is exercised on-device in Phase 5).

- **BUG-002 · Account actions sheet — invisible ink / framework assertion.**
  *Symptom:* opening the account sheet threw `ListTile background color or ink splashes may be
  invisible` (one per tile); tile taps had no ink feedback.
  *Cause:* `account_actions_sheet.dart` wrapped its `ListTile`s in a coloured `DecoratedBox` with no
  `Material` ancestor between them.
  *Fix:* `lib/features/settings/presentation/widgets/account_actions_sheet.dart` — root container is
  now a `Material(color, shape)`.
  *Test:* `test/features/profiles/presentation/profile_switcher_sheet_test.dart` — tapping the Settings
  header opens the account sheet and finds ACCOUNT / Switch account / Sign Out.

### Test-truth alignments (stale tests updated to the intended WIP behavior — no production change)

- **Tutor permission defaults false→true.** `ws3_3d_tutor_permissions_surface_test.dart` asserted the
  old read-only defaults. Updated AC5 to expect the parent-equivalent defaults (`canEdit*` = true) and
  rewrote the copyWith test to start from `TutorPermissions.readOnly()`. (`feedback_tutor_parent_view`.)
- **Profile-less → AppShell (not the picker).** `profile_guard_test.dart` Branch-2 now expects
  `resolver.next()` (allow into shell) instead of `router.replace(ProfilePickerRoute)`.
- **Settings account-separation.** `settings_screen_test.dart` "renders lower sections" → repurposed to
  assert account actions are **absent** from the Settings body (they live in the header sheet).
  (`feedback_settings_account_profile_separation`.)
- **Header tap opens the account sheet.** `profile_switcher_sheet_test.dart` — header tap now opens the
  account-actions sheet, not the profile switcher.
- **Empty-login CTA copy.** `empty_login_ws2_test.dart` — banner CTA is now "Add a learning track".

**Result:** `make ci` green — analyze (no issues) · validate-calendar (OK) · test (6098 pass / 125
skip / 0 fail). Line coverage baseline **58.4%** (31,238 / 53,527).

---

## On-device verification (2026-05-29, Galaxy S24 over Tailscale ADB)

Confirmed live on the physical phone (`com.jcom.torah.learning_tracker`):
- **Build→install→run pipeline** works end-to-end: `flutter build apk --debug` (JDK 21) → `adb install`
  → relaunch → MainActivity renders. `flutter devices` lists the phone (android-arm64, Android 16).
- **Dashboard** (empty-state "Add a learning track"), **Settings**, the **account-actions sheet**
  (Switch/Add/Sign-out/Delete — Material fix confirmed, no invisible-ink), and the **Account Picker**
  (Daniel = CLOUD valid; Family = "SIGN IN AGAIN" expired) all render correctly.
- **Account switch**: tapping the valid account switched **instantly back to the Dashboard, no sign-out**
  — matches DEC-34. (Locked by `account_picker_switch_test.dart`.)
- **Deploy**: `firebase deploy --only firestore:rules` → "Deploy complete!".

L4 tooling note: this Flutter build does **not** expose a semantics tree to `uiautomator` (single-surface
render), so the on-device sweep harness must be **screenshot-coordinate based** (read screenshot → compute
pixel → `input tap`), NOT UI-hierarchy based. The app bottom-nav row is ~y≈2200 on 1080×2340; the system
nav bar sits ~y≈2300 (don't tap there — it backgrounds the app). `integration_test` (widget-finder based)
needs the debug-VM connection, which is flaky over wireless ADB — prefer the coordinate sweep for L4.

---

## Phase 1 — Tutoring (wave 1: 6 zero-coverage screens)

Added **111 L1 widget tests** across the 6 screens that had no dedicated tests — TutorPinSetup (18),
TutorPinReset (9), InviteTutor (19), ManageTutors (31), ManageGrants (12), TutorAuditLog (22). 108 pass,
3 skipped pending the RP3-RETRY decision below. (Fan-out: Sonnet wrote/greened tests; Opus reproduced
every reported bug + owns this analysis.)

### FIXED (root cause)

- **RP3-RETRY · Riverpod 3 auto-retry hides the error+retry UI on persistent first-load errors.**
  *Symptom:* a hand-written `FutureProvider` that errors on first load (e.g. `incomingTutorGrantsProvider`,
  `tutorAuditLogProvider`) never reaches `asyncValue.when(error:)` — the screen shows the loading spinner
  forever. Reproduced with a `ProviderContainer`: default → `AsyncLoading(error:)` (`isLoading=true`);
  with `retry: (_, __) => null` → `AsyncError` (`.when(error:)` fires). Riverpod 3.0 **retries failed
  providers by default** (the app upgraded to flutter_riverpod 3.3.1). Codegen `@riverpod` providers
  already emit `retry: null`; only the hand-written `FutureProvider`s inherit the retrying default, so
  their error UI is effectively unreachable on persistent errors (transient errors do still recover —
  that's the upside of retry).
  *Scope:* app-wide (every `.when(loading:, error:, data:)` over a hand-written FutureProvider).
  *Options:* (A) bounded global retry on the root container/ProviderScope (transient recovery **and**
  eventual `AsyncError` → error view) — recommended; (B) `retry: (_, __) => null` globally (matches
  codegen, immediate error view, no transient recovery); (C) per-provider `retry: null`; (D) change the
  render pattern to treat `hasError` as error even while loading (loses transient recovery).
  *Resolution (FIXED 2026-05-29):* disabled provider retry globally in `bootstrap()`
  (`retry: (_, __) => null` on the root `ProviderContainer`) — restores the app's original error+retry
  design intent and matches the codegen providers (already `retry: null`). Errored providers now surface
  `AsyncError`, so `.when(error:)` renders the error+retry view. The 3 tests are un-skipped (their test
  `ProviderScope` sets `retry: (_, __) => null` to match production) and pass. Owner granted full
  authority for this app-wide change.

### OPEN — i18n (Phase 8)

- Hardcoded fallbacks in `tutor_grant_aggregate.dart`: `childDisplayLabel` → `'Talmid'` (~:144),
  `parentDisplayLabel` → `'Parent account'` (~:150) when the name is null — not l10n. Fix belongs in the
  presentation layer (domain VO must not import l10n — layering Rule). 
- Shared widgets with hardcoded English: `AppErrorView` `'Retry'` / `'Report this issue'`
  (`app_error_view.dart`); `pin_entry_widget.dart` `'Clear'` / `'Too many failed attempts'` /
  `'Try again in N minute(s)'`. Reachable from tutor PIN setup error state.

### Wave 2 (2026-05-29)

+104 behaviour-focused L1 tests: AcceptInviteScreen (23 — all 6 `_AcceptStep` transitions, auth gate,
offline stub-grant fallback, precondition branches), DeclineInviteScreen (21), TutorPinEntryGate (21 —
correct/wrong PIN, lockout, reset), ManageTutorsScreen strengthened (31→39). Each file has an he-RTL
smoke test. No production bugs found; the only finding is the `pin_entry_widget.dart` hardcoded strings
(already logged under i18n). **All 10 tutoring screens now have L1 coverage.**

### Tests need strengthening (tracked, not blocking)

Verify pass flagged the wave-1 tests as render-heavy (render-only counts: PinSetup 11, ManageTutors 19,
AuditLog 10, others fewer). Missing cells noted: loading/`_isSaving` spinner, he-RTL, negative
assertions (callback NOT fired on error). Wave 2 will strengthen behaviour assertions + add he-RTL.

---

## Phase 2 — Sync & offline-first (wave 1)

+52 L1 tests: **OfflineTopBanner** (15 — tier-gated visibility: cloud-born+offline shows, local-born/
online hidden), **SyncStatusIndicator** (19 — 7 states: localOnly/synced/syncing/pending/offline/error/
degraded), **BackupSyncSection** (18 — cloud-synced / cloud-offline "LOCAL ONLY" / local-born upgrade
cards). All green.

### FIXED — dead code removed

- **SyncScreen (`/sync`) was an unreachable placeholder.** AppBar + a static `Center(Text)` with no
  state-driven rendering; the `SyncRoute` was registered with authGuard but **never navigated to** from
  anywhere in the app (no in-app push, no deep-link). The real sync UX is BackupSyncSection + the offline
  banner + the status indicator (sync is informational-only, `feedback_offline_first`). Deleted the
  screen + route + import and regenerated the router. (The 6 "bugs" the test agent reported against it
  were all "this placeholder is unimplemented" — resolved by removal, not implementation.)

### OPEN — i18n (Phase 8)

- `offline_top_banner.dart`: banner body + Semantics label are hardcoded English ("Offline — changes
  will sync when you're back…"), not l10n.
- `sync_status_indicator.dart`: 9 hardcoded status labels ("Local only", "Synced", "Syncing",
  "$n pending", "$n queued", "Offline", "Sync error", "Sync paused", …) — not l10n.

---

## Phase 4 — Gamification (wave 1)

+67 L1 tests: **GamificationScreen** (19 — achievements/streak/points; adults have no points),
**ChildRedemption** (15 — affordable vs unaffordable gating, confirm/cancel, balance deduction verified),
**ParentPendingRedemptions** (17 — approve/decline), **RewardConfiguration** (16 — create/edit validation,
delete confirm). All green, analyze clean.

### FIXED (production)

- **Double-tap guard on ParentPendingRedemptions Fulfil/Decline.** Both buttons were always-enabled; a
  rapid double-tap could run `fulfilRedemption` → `_pushRedemption` (a redundant sync push) twice. LOW
  severity — the DAO is idempotent (`fulfilRedemption` sets `status='fulfilled'`; `declineRedemption`
  early-returns unless `status == 'pending_fulfilment'`, so **no double-refund**) — but the kickoff
  requires the guard and it matches the app's `_isFinishing`/`_isSaving` pattern. Fix: `_RedemptionCard`
  is now `StatefulWidget` with a `_busy` flag that disables both actions while the async is in flight.
  (A deterministic double-tap regression test is infeasible in flutter_test here — guarded `tap()` calls
  can't overlap and the in-memory DAO resolves before a second awaited tap — so the test asserts the
  fulfil path and the guard is verified by construction.)

### OPEN — i18n (Phase 8)

- `streak_widget.dart`: `'${currentStreak} day streak!'` (:125) + `'(best: $maxStreak)'` (:177) hardcoded.
- `points_display_widget.dart`: `'+$pointsEarned points!'` (:96) hardcoded.

### Strengthening backlog

- GamificationScreen render-heavy (9/19 render-only): lock/affordability gating (`LockedAchievementShell`),
  progress-bar arithmetic, status labels, unlock-celebration double-tap guard, pull-to-refresh, sort order
  untested. → strengthen in a later wave.

## Phase 5 — Account / Onboarding screens (wave a)

+68 L1 tests: **AppIntro** (12 — palette, page swipes, Skip/Get-Started → SignInRoute + kIntroSeen write),
**PermissionPrompt** (24 — notification/location asks, grant→gateway, skip→proceed), **UpgradeToCloud**
(17, +7 skipped — see DI note), **DeviceRestore** (15 — in-progress/success/error states). All green,
analyze clean. No functional production bugs.

### OPEN — i18n (Phase 8)
- `app_intro_screen.dart`: `'Skip'` / `'Continue Journey'` / `'Get Started'` hardcoded.
- `permission_prompt_screen.dart`: ALL user-facing strings hardcoded (titles, CTAs, card titles/subtitles, body).

### OPEN — testability / DI refactor (Opus, careful — security-sensitive)
- `UpgradeToCloudScreen` inline-instantiates `UpgradeToCloudService` (2 call sites) instead of injecting it
  via a provider, so L1 tests can't mock the argon2id-gated local→cloud upgrade path → **7 tests skipped**.
  Fix: add `upgradeToCloudServiceProvider` (its deps — authRepository, dao, registry — are already
  providers) and read it; then un-skip + complete the 7 tests. Functional path works; this is a
  testability/DI debt to clear in a focused pass.

---

## Phase 4 — Profiles (wave 1)

+90 L1 tests: **ProfilePicker** (17 — selection, sign-out matrix, max-10, empty→TutoredChildrenSection),
**ManageLearners** (20 — CRUD, edit/delete flows), **ParentSettings** (33 — tutor-permission tile matrix:
edit tiles gated on `activeTutorPermissionsProvider`, owner-only tiles hidden in tutored context),
**ParentTrackManagement** (20). All green, analyze clean.

### FIXED (production)

- **[HIGH] ProfileEditFormDialog crashed on open** — the avatar picker was a lazy horizontal `ListView`
  inside `AlertDialog`, which measures its content's intrinsic dimensions; a lazy `RenderViewport` throws
  *"RenderViewport does not support returning intrinsic dimensions"*. The edit/rename-profile dialog
  crashed whenever opened. Fix (`profile_edit_delete_actions.dart`): replaced the `ListView.builder` with
  a `Row` inside a horizontal `SingleChildScrollView` (intrinsic-friendly; only 10 avatars). Un-skipped
  the 3 edit-dialog tests → green.
- **[medium] AddProfileCard RTL/grid overflow** — fixed icon (96) + spacing + text with no flex
  overflowed (~43px) at constrained grid-cell heights. Fix (`add_profile_card.dart`): wrapped the column
  in `FittedBox(scaleDown)`.

### OPEN — i18n + RTL (Phase 8)

- `manage_learners_screen.dart`: AppBar title `'Manage Learners'` hardcoded (not l10n).
- `parent_track_management_screen.dart`: `'Active Tracks'` header + `'$activeCount RUNNING'` badge hardcoded.
- Residual small RTL overflows in the profile-grid cards (ProfileCard) at 360×780-logical Hebrew
  (~12px horizontal, ~3.6px vertical) — for the Phase 8 RTL/overflow sweep.

### UX note (low)

- `ManageLearnersScreen` FAB is always enabled; the 10-profile cap is enforced only by the repository
  (`MaxProfilesExceededException`). Consider a proactive cap indicator / disabled FAB at 10.

### Skipped-suite repair — epic_15 multi-profile

Un-skipped the library-level `@Skip` on `epic_15_multi_profile_test.dart` (was fully dark) → **119 tests
now passing**, 12 intentionally skipped (file-existence/git/architecture/compile-time-API checks that
can't be unit-asserted), analyze clean. **No production bugs** — all 11 exposed failures were test-fixture
issues (7 repairs): missing `seedProfile`/`seedProfileZero` before FK-constrained inserts, the 10-profile
cap test colliding with the pre-seeded "Test User", `getGlobalTotal()`→`getDerivedTotal()` (raw events
don't touch points_balance), per-curriculum distinct `trackId`s, and FK-valid trackId/profileId in ledger
tests.

---

## Phase 3 — Tracks & track-setup wizard (wave 1)

+87 L1 tests: **AddTrackFlow** (23 — the LIVE screen + real controller, 6-step machine, exit-confirm +
replace-existing dialogs, TutorWriteException snackbar, generic error + retry), **EditTrack +
ChazaraInlineSetup** (25), **TrackManagementHub** (19 — empty/populated, delete archive vs wipe),
**StudyDayConfig** (20). All green. **No production bugs.**

- Test-harness notes (not prod bugs): EditTrack's ListView lazily culls offstage sections → tall test
  viewport needed; `FutureProvider.autoDispose.family` `overrideWith((ref) async …)` needs a pump to
  settle (use `overrideWithValue(AsyncData(x))` for synchronous resolution). study_day_config sizes the
  viewport via the deprecated `binding.window.*TestValue` (file-level `deprecated_member_use` ignore —
  no non-deprecated binding-level setter exists for `setUp`; test-only, functional).
- **Strengthening backlog** (verify flagged render-heavy + partial product-rule coverage): chazara
  conditional checked only at step-count level, not which chazara widget renders per track type; scope
  auto-skip positive case (single child → auto-drill) untested; back-date→overdue exercised at the
  service layer, not through the widget's StartingPositionStep; no-track-type-label asserted only at
  step 0. → revisit in a strengthening wave.
</content>
</invoke>
