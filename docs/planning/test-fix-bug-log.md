# Test-and-fix bug log

One line per defect: **symptom → cause → fix → test**. Newest first. Part of the exhaustive
test-and-fix run (plan: `exhaustive-test-and-fix-plan-2026-05-29.md`).

> Production fixes are Opus-owned. Sonnet sub-agents only write/verify test files.

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
