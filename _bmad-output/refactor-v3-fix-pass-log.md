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
