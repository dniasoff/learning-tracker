# V3 Fix Pass Log

---

## V3-W1 — Sync/Data Criticals

- C1: FIXED / commit e7e8dffa / test test/core/sync/merge/learning_ledger_merger_test.dart (4 tests — snake_case row ingested, camelCase fallback, missing-field skip, dedup)
- C2: FIXED / commit e7e8dffa / test test/core/sync/merge/streak_event_merger_test.dart (4 tests — study_date shape, event_timestamp fallback, missing-both skip, dedup)
- C3: FIXED / commit e7e8dffa / test (covered by C2 test; channel rename verified via SyncOrchestrator._channelToKind)
- C4: FIXED / commit e7e8dffa / deploy torah-study-tracker rules (allow delete: if isOwner(uid)); no separate rules-unit test added (rules security tests require emulator — V3-W2 scope)
- H1: FIXED / commit e7e8dffa / (doc-id = curriculumId only in pushTrack)
- H2: FIXED / commit e7e8dffa / (deleteCurriculumTrack Cloud Function updated — trackType param removed)
- H4: FIXED / commit e7e8dffa / test test/features/learning/data/repositories/h4_lifetime_only_detection_test.dart (2 tests — lifetimeOnly no siyum, live completion creates siyum)
- H5: FIXED / commit e7e8dffa / deploy torah-study-tracker indexes ((state, updated_at) composite added)
- H7: FIXED / commit e7e8dffa / (pushAllLocalData iterates streak_events rows, per-event enqueue with event_type/study_date/ulid)

---

## V3-W3 — B1 Callpath Gaps

- C2 (BulkMarkCompletionUseCase): FIXED / commit fdc99249 / test test/features/learning/domain/use_cases/bulk_mark_completion_use_case_test.dart:C2 — BulkMarkCompletionUseCase B1 engagement gate (6 tests)
- H1 (MarkLiveCompletionUseCase wiring): FIXED / commit 8da0c443 / test test/features/tutoring/domain/use_cases/mark_live_completion_use_case_test.dart:H1 — MarkLiveCompletionUseCase tutor boundary enforcement (7 tests)

---

## V3-Cleanup — Last 2 CI Fails

### Fix 1 — audit_and_arb_parity_test.dart

- Root cause: Root-level Makefile (deleted in commit 99193333) used `[N/12]` bracket format; test was
  checking that format and running `make` from repo root (parent of `learning_tracker/`). After deletion,
  the audit target lives only in `learning_tracker/Makefile` using `N/15` and `N/17` format (no brackets).
- Fix: Updated test to run `make audit` from `packageDir` (= `learning_tracker/`); updated assertions
  to match current header format `N/15` (greps 1-15) and `N/17` (greps 16-17); updated total from 12→17.
- Commit: 75271bda / `fix(test): audit grep count 12 → 17, workingDir repo-root → packageDir`
- Result: PASS (8 tests, 1 skip)

### Fix 2 — store_screenshots_test.dart (Screenshot 1: Dashboard)

- Root cause: Golden file `phone_1_dashboard.png` was stale after W1-W6 refactor (AppErrorView migrations,
  AppBar tutor indicator, profile picker segmentation, god-screen splits).
- Fix: Regenerated golden via `flutter test --update-goldens`; sanity-checked all 5 screenshots pass.
- Commit: 005f4247 / `test(golden): regenerate store_screenshots after refactor`
- Result: PASS (5 tests)

### make ci status

- The 2 target tests now PASS.
- `make ci` still fails at `dart analyze --fatal-infos` due to pre-existing V3 refactor issues in
  unstaged files (`provision_track_use_case_test.dart` directives_ordering, tutoring cast warnings).
  These are NOT caused by V3-Cleanup fixes — they pre-existed and are in unstaged V3 agent work.
  Stopping per hard-rule: "if make ci still fails after your 2 fixes, log it and STOP."

---

## V3-W2 — Tutor Mode Criticals

### C1 — MarkLiveCompletionUseCase never called

ALREADY FIXED in V3-W3 (commit 8da0c443). UI now routes via MarkLiveCompletionUseCase. No action.

### C2 — isActiveTutorGrant dead; tutors denied all subcollection reads

FIXED / commit 5a9347bc

- **Approach:** Added `hasActiveTutorAccess(ownerUid, profileId)` function to firestore.rules. Uses
  `exists()` on a new `tutor_active_access/{tutorUid}_{parentUid}_{profileId}` secondary index
  maintained by Cloud Functions. Avoids needing grantId in rules context (isActiveTutorGrant requires
  grantId which isn't available when reading subcollection paths). O(1) lookup.
- **Rules change:** Added `|| hasActiveTutorAccess(uid, profileId)` to `allow read` on all 12
  profile subcollections: completions, streak_events, learning_ledger, settings, stage_definitions,
  curriculum_tracks, bookmarks, learning_order, preferences, goals, import_metadata, profile_programs.
  Tutor WRITE rules unchanged — TUTOR WRITE BLOCK still holds.
- **New collection:** `tutor_active_access/{accessId}` — client writes denied, tutor read allowed.
- **Deploy:** Firestore rules deployed to torah-study-tracker. Compiled successfully with 3 expected
  warnings (unused isActiveTutorGrant function — retained for future per-grantId use).
- **Tests:** 12 new structural assertions added to w3_41_tutor_security_rules_test.dart (groups 5 + 6).
  22 pass, 1 intentionally skipped.

### C3 — No lifecycle Cloud Functions; entire invite/accept/revoke flow stub-only

FIXED / commit 14fd65e3

- **7 new Cloud Functions deployed** to torah-study-tracker (us-central1):
  - `inviteTutor` — creates pending grant with 256-bit invite_token (NFR-3) and default permissions.
  - `acceptTutorInvite` — validates auth.email == grant.tutor_email (security gate), writes
    tutor_active_access index, clears invite_token (single-use), captures tutor_name_snapshot from
    Firebase Auth (partial H3 fix), uses runTransaction for atomicity.
  - `declineTutorInvite` — validates by email or tutorUid, transitions to declined.
  - `rescindTutorInvite` — parent-only, transitions pending → rescinded.
  - `revokeTutorGrant` — parent-only, transitions active → revoked_by_parent, deletes
    tutor_active_access atomically via runTransaction.
  - `resignTutorGrant` — tutor-only, transitions active → revoked_by_tutor, deletes
    tutor_active_access atomically via runTransaction.
  - `listTutorGrants` — mode=incoming or outgoing, returns serialised grant docs.
  - `onUserDeleted` — updated to also delete tutor_active_access docs on account deletion.
- **FirestoreTutorGrantRepository** implemented at
  `lib/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart`. Uses
  `cloud_functions` package (same pattern as AccountManagementService, no direct Firestore import).
- **Both stub providers replaced:** manage_tutors_providers.dart and tutor_grant_providers.dart
  both now wire FirestoreTutorGrantRepository (M1 fix in passing — both providers point to real repo).
- **Tests:** 10 unit tests in firestore_tutor_grant_repository_test.dart — all pass.
  TypeScript compiles clean (tsc exit 0).

### C4 — Pending invite 7-day TTL never enforced server-side

FIXED / commit 14fd65e3 (same commit as C3)

- **`expirePendingInvites` Cloud Function** added to functions/src/index.ts. Scheduled daily at
  01:00 UTC (offset from purgeExpiredAuditLogs at 02:00 to avoid simultaneous runs). Queries
  `tutor_grants` where `state == 'pending' AND expires_at <= now`. For each matching grant:
  uses runTransaction to update state='expired' + delete invite_token + write audit log entry.
  Logs per-grant and summary counts.
- **Deploy:** Deployed to torah-study-tracker as 1st Gen scheduled function.
- **Tests:** 3 structural assertions in w3_41_tutor_security_rules_test.dart (group 6: V2-R3 C4).

### Summary

| Fix | Commit | Deploy | Tests |
|-----|--------|--------|-------|
| C1 | Already fixed (8da0c443) | N/A | Already covered |
| C2 | 5a9347bc | Firestore rules ✓ | 12 new assertions (22 pass) |
| C3 | 14fd65e3 | 7 Cloud Functions ✓ | 10 unit tests pass |
| C4 | 14fd65e3 | 1 Cloud Function ✓ | 3 structural assertions |

---

## V3-W4b — Schema + Skips

### V2-R6 C1/C2 — Schema version + dropped table assertions

**Status: Already resolved (commit a36bb4ae)**

Verified all 3 files were fixed in the Runtime-Fix-C pass:
- `test/story_acceptance/epic_25_story_22_firewall_test.dart` — `greaterThanOrEqualTo(1)`; table list updated to `completion_events`, `streak_events`, `outbox`, `prior_completion_imports`; dropped `completions`, `streaks`, `sync_queue`.
- `test/story_acceptance/epic_02_content_test.dart` — both `schemaVersion` assertions → `greaterThanOrEqualTo(1)`.
- `test/infrastructure_test.dart` — `schemaVersion` assertion → `greaterThanOrEqualTo(1)` with comment.

No further action needed for C1/C2.

---

### V2-R6 C4 — @Skip recovery for epic_18 + epic_15

**Commit: 98f842b4**

**epic_18_track_overhaul_test.dart:**
- File-level `@Skip('TODO: Fix missing pushCurriculumTrack parameter')` removed.
- Root cause (pushCurriculumTrack param) was already fixed in a36bb4ae.
- All 21 tests now pass green (0 skips).

**epic_15_multi_profile_test.dart:**
- Blanket `@Skip('TODO: Fix missing pushCurriculumTrack parameter')` replaced with concrete: `@Skip('V3-W4: 30 fixture FK failures after removing blanket skip — see TODO above')`.
- All 10+ `expect(true, isTrue)` placeholders replaced with per-test `skip:` annotations carrying specific reasons (ContentVersionCheckService removed, widget/compile-time-only tests, architecture docs).
- Blocking issue documented: seedProfile() pre-creates profile 1; FK-constrained groups need per-group seedProfile; max-profile tests need count adjustment.
- TODO left for targeted fixture refactor.

---

### V2-R6 C5 — Epic 13 cloud sync coverage (Story 13.4 port)

**Commits: 3e50a2c6 (test + impl fix)**

**epic_13_cloud_sync_test.dart:**
- Story 13.4 (New Device Data Restore) ported with 8 real assertions (AC1–AC8) using `_StubSyncOrchestrator` pattern identical to epic_25_story_22_firewall_test.dart.
- Stories 13.1–13.3 remain skipped with concrete references to replacement test files (outbox processor, SyncOrchestratorImpl + PullPipeline, EntityMerger unit tests).
- Result: 8 pass, 3 skipped.

**lib/app/restore/device_restore_service.dart (impl fix):**
- `isNewDevice()` was missing `state == _kStateComplete → return false` guard — caused AC5 failure (restore ran on already-restored device).
- `isNewDevice()` was not gating on `_isAuthenticated` — caused AC3 failure (unauthenticated + empty DB returned `true`).
- Fixed: `_kStateComplete` guard added; unauthenticated guard added after in_progress check; dead `profiles.isEmpty` fallback path removed.
- `dart analyze` + `dart format` clean.

---

## V3-W4c — Real B3 Regression Test

**Finding:** V2-R6 C3 — The W4.14 committed test file used `_TestableUseCase._buildResult()`, a hand-rolled duplicate of production `ProvisionTrackUseCase._toResult()`. All 13 tests exercised the duplicate, not the real use case. A regression in `_toResult` would pass all tests.

**Fix applied:**
- Replaced `_TestableUseCase` / `_FakeCreationService` pattern with `_SpyTrackCreationService`, a proper subclass of the real `TrackCreationService` that overrides `createTrack` to capture calls without DB writes.
- `ProvisionTrackUseCase` is now instantiated directly with `service: spyService, clock: clock`. The real `_toResult()` is exercised on every bridge test call.
- Deleted `_TestableUseCase`, `_FakeCreationService`, and `_buildResult()` entirely.
- Added `setUp` / `tearDown` with in-memory `UserDatabase` (required to construct `_SpyTrackCreationService`).
- Added 14th test: `adversarial validator — _toResult regression sensitivity / N=1 back-date → startingRef is exactly "offset:1"`. This test documents that a mutation silencing the offset branch (returning null or "offset:0" for N=1) would produce a clear assertion failure, confirming the spy exercises the real code path.

**Test file:** `learning_tracker/test/features/tracks/setup/domain/use_cases/provision_track_use_case_test.dart`

**Result:**
- 13 original B3 cases: all pass against real `ProvisionTrackUseCase`
- 1 adversarial validator test: passes (and would fail if `_toResult` offset branch were corrupted)
- `dart format`: no changes required
- `dart analyze --fatal-infos`: no issues

**Commit:** fix(v2-r6-c3): replace hollow B3 regression with real use case test (13 tests + adversarial validator)

---

## V3-W4a — PII Leaks

### C1 — DuplicateEmailException embeds email in message / toString()

- **Fix:** Removed raw email from `super()` call in `DuplicateEmailException`; message is now `'Email already in use'`. Raw email retained in separate `email` field for callers that need it. Added `redactedEmail` getter returning `***@<domain>` for log-safe use.
- **Test:** `test/features/auth/domain/services/auth_exceptions_test.dart` — updated existing `toString` test to assert email is NOT present; added redactedEmail coverage via `exposes email field` test.
- **Commit:** c8e6b1d2 — `fix(v2-r5-c1): DuplicateEmailException — generic message, no PII in toString()`

### C2 — LoggingTransactionalEmailService logs unredacted email ('to' key not in sensitiveKeys)

- **Fix:** Added `'to'`, `'recipient'`, `'email_to'` to `PiiRedactor.sensitiveKeys` in `lib/core/logging/logger.dart`. The `LoggingTransactionalEmailService.send()` call at `transactional_email_service.dart:191` uses `{'to': email.toAddress}` — this key now triggers redaction.
- **Test:** `test/core/logging/logger_extended_test.dart` — new group `PiiRedactor — transactional email keys (V2-R5 C2)` with 5 tests: redacts `'to'`, `'recipient'`, `'email_to'` individually; asserts all three are in `sensitiveKeys`; integration test simulating the exact `LoggingTransactionalEmailService` log call and asserting email does not appear in Talker output.
- **Commit:** 6a490ae0 — `fix(v2-r5-c2): add 'to', 'recipient', 'email_to' to PiiRedactor.sensitiveKeys`

### C3 — learning_screen.dart:301 raw e.toString() in UI subtitle

- **Fix:** Replaced `_InfoCard(icon: Icons.error_outline, title: …, subtitle: e.toString())` with `AppErrorView(error: e, stackTrace: st, onRetry: () => ref.invalidate(allDailyTasksProvider))` in the `dailyTasksAsync.when(error:)` branch of `_DailyTasksSection`.
- **Test:** `test/features/learning/presentation/screens/learning_screen_test.dart` — new widget test `AppErrorView shows generic message for InternalException (not raw exception string)`: renders `AppErrorView` directly with a `MergeException` carrying a recognisable raw message, asserts `AppErrorView` is present and `'Something went wrong'` is shown, asserts raw exception message is not found anywhere in the widget tree.
- **Commit:** 0805ada1 — `fix(v2-r5-c3): replace e.toString() in dailyTasksAsync error branch with AppErrorView`

---

## V3-W5 — Duplicate Feature Trees

### CR1a — Delete duplicate `features/track_setup/` (canonical: `features/tracks/setup/`)

**Root cause:** W2.2 MOVE was executed as a copy — `features/track_setup/` was never deleted after its contents were moved to `features/tracks/setup/`. The trees were already diverging: `tracks/setup/step_starting_position_calendar.dart` contained B2 window enforcement logic absent from the stale copy.

**Divergence resolved:** The canonical `tracks/setup/` already had the superior version (with B2 enforcement). No porting needed — only the stale `track_setup/` tree needed deletion.

**Importers updated (lib, 4 files):**
- `lib/app/router/app_router.dart` — `track_detail_screen`, `track_management_hub_screen`
- `lib/features/gamification/presentation/screens/point_config_screen.dart` — `track_management_providers`
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` — `add_track_flow_screen`
- `lib/features/profiles/presentation/screens/parent_track_management_screen.dart` — 4 imports

**Test files updated (11 files):**
- `test/features/track_setup/presentation/controllers/add_track_controller_test.dart`
- `test/features/track_setup/presentation/widgets/curriculum_picker_step_test.dart`
- `test/features/track_setup/presentation/widgets/program_selection_step_test.dart`
- `test/features/track_setup/presentation/widgets/track_label_step_test.dart`
- `test/features/track_setup/presentation/steps/goal_helpers_test.dart`
- `test/features/track_setup/domain/entities/add_track_result_test.dart`
- `test/track_setup/mandatory_pace_test.dart`
- `test/story_acceptance/epic_18_track_overhaul_test.dart` — also fixed `StageDefinitionRepositoryImpl` import to canonical `tracks/stages/`
- `test/story_acceptance/epic_25_story_25_9_lints_test.dart` — removed duplicate set entry created by path update
- `test/story_acceptance/epic_26_story_26_22_track_management_body_test.dart`
- `test/story_acceptance/epic_26_story_26_7_dashboard_model_provider_test.dart` — updated import + all string path literals in `_src()` calls
- `test/story_acceptance/epic_26_story_26_31_rtl_audit_test.dart`
- `test/story_acceptance/epic_27_story_4_widget_golden_test.dart`

**Files deleted:** 34 dart files (`git rm -rf learning_tracker/lib/features/track_setup/`)

### CR1b — Delete duplicate `signup_screen.dart` in `features/onboarding/` (canonical: `features/account/onboarding/`)

**Root cause:** W2.12 MOVE was executed as a copy — `features/onboarding/presentation/screens/signup_screen.dart` was never deleted. Both files were byte-for-byte identical at time of deletion.

**Importers updated (2 files):**
- `lib/app/router/app_router.dart` — import path updated to `account/onboarding/`
- `test/features/onboarding/presentation/screens/signup_screen_test.dart` — import path updated

**Files deleted:** 1 dart file (`git rm learning_tracker/lib/features/onboarding/presentation/screens/signup_screen.dart`)

### Summary

| Item | Files deleted | Importers updated | CI status |
|------|:---:|:---:|:---:|
| `features/track_setup/` | 34 | 15 | GREEN |
| `signup_screen.dart` dupe | 1 | 2 | GREEN |
| **Total** | **35** | **17** | **GREEN (5215 pass, 125 skip)** |

**Commit:** e365a4c8 — `refactor(v2-r4-cr1): delete duplicate features/track_setup/ tree (canonical: features/tracks/setup/)`

---

## V3-W6 — V5 Demotion Cleanup

**Date:** 2026-05-20
**Agent:** V3-W6

Resolved 9 V5 demotions (tasks incorrectly marked done in the refactor tracker because code was copied to canonical paths but originals were never deleted, leaving importers pointing at the old locations).

### Tier 1 — copy-without-delete cleanup (W2.3, W2.4, W2.5, W2.7, W2.9, W2.13, W2.25)

**Root cause:** Five feature trees and two service files were moved as copy+create, never deleted. After the deletions were committed in a prior pass (commits `6c9c0c0b` + `43b6de92`), ~60 lib/test files still imported from the old paths.

**Old paths deleted (prior commits):**
- `lib/features/learning_order/` (10 files) → canonical `features/tracks/whole_curriculum_order/`
- `lib/features/track_learning_order/` (5 files) → canonical `features/tracks/track_order/`
- `lib/features/stages/` (10 files) → canonical `features/tracks/stages/`
- `lib/features/settings/domain/services/curriculum_activation_service.dart` → canonical `features/tracks/domain/services/`
- `lib/features/settings/domain/services/account_management_service.dart` → canonical `features/account/domain/services/`
- `lib/core/services/pin_service.g.dart`

**Import fixes (this pass — commit 688fa74c):**
- 33 lib files updated with corrected import paths
- 26 test files updated with corrected import paths
- `CurriculumActivationService` callers updated to pass required `trackRepository:` argument (canonical ctor has extra param the settings copy lacked)
- `directives_ordering` violations fixed in all affected files
- Backward-compat decode improvements ported to canonical `StageDefinitionRepositoryImpl` before deletion (accepts both `days_of_week`/`days` and `rolling_window_size`/`window_size`)

### W1.6 — Slim main.dart to ~30 lines

**Root cause:** main.dart was 102 lines; bootstrap logic was inline.

**Fix (prior commit 6c9c0c0b):**
- Extracted all bootstrap orchestration to `lib/app/bootstrap/bootstrap.dart`
- `main.dart` reduced to 35 lines (WidgetsFlutterBinding + bootstrap() call + zone error handler)
- Returns named record `BootstrapResult = ({ProviderContainer container, CrashlyticsService crashlytics})`

### W2.29 — stage_definitions real-time listener

**Root cause:** `FirestoreListenerSource.openChannels()` was missing the `stage_definitions` channel, so real-time changes pushed from another device only reached the local DB after a cold-start pull.

**Fix (commit 9513ac5b):**
- Added `'stage_definitions'` channel to `FirestoreListenerSource.openChannels()`
- Added `'stage_definitions' => EntityKind.stageDefinition` to `SyncOrchestratorImpl._channelToKind`
- Added regression tests in `test/core/sync/firestore_listener_source_test.dart` (3 tests)
- Updated `epic_26_story_15_composite_strategy_test.dart` source-path assertion to use canonical `tracks/whole_curriculum_order/` path

### Summary

| Item | Description | CI status |
|------|-------------|:---:|
| W1.6 | main.dart slimmed to 35 lines | GREEN |
| W2.3/2.4/2.5/2.7/2.13/2.25 | Deleted duplicate trees + import fixes | GREEN |
| W2.9 | Auto-resolved by W2.3/2.4/2.5 (no importers file needed) | GREEN |
| W2.29 | stage_definitions listener wired + regression tests | GREEN |
| **Total** | **9 demotions resolved** | **GREEN (5218 pass, 125 skip)** |

**Commits:**
- `688fa74c` — `refactor(v5-w2-w9): fix all stale imports after duplicate-tree deletion`
- `9513ac5b` — `feat(v5-w2.29): wire stage_definitions real-time listener channel`

---

## Reorder Amnesty + §10.1

**Date:** 2026-05-20

### Task A — Reorder amnesty mechanism

**Schema changes:**
- `lib/core/database/tables/curriculum_tracks.dart`: added `lastReorderAt: DateTime?` nullable column. Set to `activatedAt` on track creation in `activateTrack`, `restoreOrCreate`, `initializeDefaultTracks`.
- `lib/core/database/tables/learning_order.dart`: added `learningOrderVersion: int` (default 1) for the §10.1 version-mismatch guard.

**Projection filter** (`lib/features/scheduler/presentation/providers/scheduler_providers.dart` `_buildProjectionTasks`):
- Reads `preferred.lastReorderAt` into `trackLastReorderAtMap` (null → epoch 0).
- After `project()`, builds `scheduleIndex` (ref → scheduledDate) and filters `projection.overdue`: refs with `scheduledDate < lastReorderAt` are amnestied (skipped).
- Applied to both the self-paced path and the program-track path.

**Reorder write sites stamped:**
- `lib/core/database/daos/track_dao.dart`: new `stampReorderAt(trackId, {DateTime? at})` method.
- `lib/features/tracks/whole_curriculum_order/data/repositories/learning_order_repository_impl.dart`: `saveOrder` and `resetToDefault` call `_stampReorderAt` after writes.
- `lib/features/tracks/track_order/data/repositories/track_learning_order_repository_impl.dart`: `saveSedarimOrder`, `saveMasechtosOrder`, `resetToDefault` call `db.trackDao.stampReorderAt(trackId)`.

**NOT triggered on:** pace changes (`resetPace`), stage-config changes, bookmark advances, profile-level edits.

### Task B — Confirm dialog before reorder

**Dialog:** `lib/core/widgets/reorder_confirm_dialog.dart` — `ReorderConfirmDialog.showIfNeeded(context, overdueCount:)`.
- No-ops (returns true) when `overdueCount == 0`.
- Shows "Reordering will clear your N outstanding overdue item(s). Consider completing them first." with Cancel / Continue.

**Provider:** `overdueCountForCurriculumProvider(CurriculumId)` in `scheduler_providers.dart` — counts `isOverdue` tasks from `allDailyTasks` for a single curriculum.

**Wire-up:**
- `lib/features/tracks/whole_curriculum_order/presentation/screens/learning_order_screen.dart` `_onReorder` — async, shows dialog before persisting.
- `lib/features/tracks/track_order/presentation/screens/track_learning_order_screen.dart` `_onReorderSedarim` / `_onReorderMasechtos` — both async, show dialog before persisting.

**L10n:** `reorderConfirmTitle` + `reorderConfirmBody(overdueCount)` in `app_en.arb` and `app_he.arb`.

### Task C — §10.1 `learning_order_version` guard

**Implementation:** `LearningOrderRepositoryImpl` gains `currentContentVersion` param (default 1).
- `getOrder`: if `rows.first.learningOrderVersion != _currentContentVersion`, logs `learning_order_version_mismatch` warning and calls `_stampReorderAt` to re-amnesty.
- `saveOrder`: stamps `learningOrderVersion = _currentContentVersion` on every upserted row.

**Provider wiring:** `contentVersionProvider` (FutureProvider<int>) reads `SeedMetadata.version` from the content DB. `learningOrderRepositoryProvider` passes it and the active `profileId` to `LearningOrderRepositoryImpl`.

### Regression tests

9 tests in `test/features/scheduler/reorder_amnesty_test.dart`:
- Scenario A (4): stampReorderAt updates the column; projection amnesty logic; saveOrder stamps the track; resetToDefault stamps the track.
- Scenario B (2): resetPace does NOT change lastReorderAt; non-reorder state change does NOT change lastReorderAt.
- Scenario C (3): version mismatch triggers amnesty; no mismatch leaves lastReorderAt untouched; saveOrder stamps the version on rows.

| Item | Description | CI |
|------|-------------|:--:|
| Task A | Schema + projection filter + reorder write sites | GREEN |
| Task B | Confirm dialog (en + he) | GREEN |
| Task C | Version guard + amnesty on mismatch | GREEN |
| **Total** | **9 new tests** | **GREEN (5227 pass, 125 skip)** |

**Commits:**
- `3a8b023a` — `feat(amnesty): reorder clears overdue via lastReorderAt filter`
- `54c334ec` — `feat(amnesty): confirm dialog before reorder with overdue count`
- `8b646212` — `feat(content-version): learning_order_version guard + amnesty on mismatch`
