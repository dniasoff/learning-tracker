# V2-R6 Tests & CI Review — Post-Refactor Adversarial Findings

**Reviewer:** V2-R6 (Tests & CI reviewer)
**Date:** 2026-05-20
**Branch:** dev
**Scope:** Test suite quality, CI configuration, and audit greps after V3 Option B repair (91 files fixed)
**Mode:** READ-ONLY

---

## Summary

The Option B repair wave restored compilation across the test suite. B1/B2 regression tests are solid. However, the review uncovered several critical false-positive tests (including a schema-version assertion that will always pass regardless of the actual schema), two whole-file @Skip annotations with no recovery plan, structural gaps in the B3 and B1 regression coverage, zero test coverage for two load-bearing Cloud Functions, and custom lint rules with no associated test files.

**Finding count:** 21 findings (5 CRITICAL, 5 HIGH, 7 MEDIUM, 4 LOW)

---

## CRITICAL Findings

---

### C-1: epic_25_story_22_firewall_test.dart asserts schemaVersion == 23 but production DB declares schemaVersion == 1 (false positive)

**File:** `test/story_acceptance/epic_25_story_22_firewall_test.dart` line 65–66
**Also:** `test/story_acceptance/epic_02_content_test.dart` lines 760, 773; `test/infrastructure_test.dart` line 124

The AC1 test in the FIREWALL story asserts:
```dart
test('UserDatabase.schemaVersion is 23', () {
  expect(db.schemaVersion, equals(23));
});
```

The production `UserDatabase` at `lib/core/database/user/user_database.dart` line 119 declares:
```dart
int get schemaVersion => 1;
```

The test will **always fail at runtime** if it executes (it asserts 23 but gets 1). However, because the full `make ci` pipeline was blocked by analyze errors during the refactor, this test has not been run end-to-end since the Wave 3 schema rebuild reset `schemaVersion` back to 1. This is not a false positive that silently passes — it is a test that will crash — but it demonstrates that the FIREWALL schema migration acceptance criterion (AC1) is currently broken and would block CI the moment the analyze gate clears. The `schema_v1_smoke_test.dart` correctly asserts `equals(1)`, confirming the production value.

**Impact:** The story 25.22 AC1 acceptance criterion is unverified. The actual migration step count (v1 to v23 was the pre-rebuild count; v1 is the new baseline) is mis-documented across three test files.

---

### C-2: epic_25_story_22_firewall_test.dart asserts deleted tables ('streaks', 'sync_queue', 'completions') exist in sqlite_master

**File:** `test/story_acceptance/epic_25_story_22_firewall_test.dart` lines 95, 103, 105

The `expected` set in the "all expected tables exist in sqlite_master" test includes:
```dart
'completions',   // <- deleted in W3.19 rebuild (replaced by completions_view)
'streaks',       // <- deleted in W3.19 rebuild (replaced by streak_events)
'sync_queue',    // <- deleted in W2.37
```

`user_database.dart` comment at line 52 explicitly states: "Dropped legacy tables: completions, streaks, sync_queue." None of these are in the Drift `@DriftDatabase(tables: [...])` declaration. The test will fail for each of these three entries when it runs. This is a direct consequence of the firewall test not being re-run after the Wave 3 schema rebuild.

**Impact:** The entire AC1 table-existence verification is untrustworthy until these three stale entries are removed.

---

### C-3: B3 regression test uses a hand-rolled duplicate of ProvisionTrackUseCase._toResult rather than the production class

**File:** `test/features/tracks/setup/domain/use_cases/provision_track_use_case_test.dart` lines 50–123

The `_TestableUseCase` class in the B3 test contains its own `_buildResult()` method that duplicates the bridge logic from `ProvisionTrackUseCase._toResult()`. The test comment at line 65 acknowledges this explicitly: "Replicate the bridge logic from ProvisionTrackUseCase so the tests cover the same code path without requiring a real TrackCreationService."

This means the B3 bridge tests (tests 1–8 in the `ProvisionTrackUseCase bridge` group) do not exercise the production `ProvisionTrackUseCase._toResult()` method at all — they exercise the test's own duplicate. A regression in the production `_toResult` (e.g., a wrong `switch` branch or a missed `today` usage) would not be caught by these tests.

The B3 projection tests (B3-1 through B3-5) are pure `programSchedule + project` pipeline tests that also bypass `ProvisionTrackUseCase` entirely. No test in the file actually instantiates the production `ProvisionTrackUseCase` with a fake `TrackCreationService`.

**Impact:** The stated B3 regression protection for `ProvisionTrackUseCase` is illusory. A bug reintroduced in `_toResult` would pass all 13 tests.

---

### C-4: epic_18_track_overhaul_test.dart and epic_15_multi_profile_test.dart @Skip entire file with no recovery plan

**Files:**
- `test/story_acceptance/epic_18_track_overhaul_test.dart` line 3: `@Skip('TODO: Fix missing pushCurriculumTrack parameter')`
- `test/story_acceptance/epic_15_multi_profile_test.dart` line 2: `@Skip('TODO: Fix missing pushCurriculumTrack parameter')`

Both files are fully @Skip'd at the library level. Epic 18 covers the Track Management Overhaul; Epic 15 covers Multi-Profile (15.5, 15.6, 15.8). The skip reason "missing pushCurriculumTrack parameter" describes a compilation issue that was left unresolved by the repair wave. The CI report (refactor-v1-ci-report.md) confirms these were pre-existing skips from the Test-Fix-A pass. There is no DNI ticket, no timeline, and no recovery plan for either file.

**Impact:** All Epic 18 and Epic 15 acceptance criteria are unverified. Epic 15 contains multi-profile tests that include `expect(true, isTrue)` structural stubs (lines 749, 779, 833, 851, 859, 2344, 2354, 2363, 2371, 2707) — when the @Skip is eventually removed these will silently pass without verifying anything.

---

### C-5: epic_13_cloud_sync_test.dart and sync_rework_engine_test.dart are entirely placeholder-skipped with cross-references to replacement tests that are themselves partly skipped

**Files:**
- `test/story_acceptance/epic_13_cloud_sync_test.dart`: all 4 story groups are `@skip`'d with "Retired W2.35" reasons; each contains only `test('placeholder', () {})`.
- `test/sync/sync_rework_engine_test.dart`: all 5 groups are `@skip`'d with "Retired W2.35" reasons.

The skip messages claim coverage exists in OutboxProcessor tests, CompletionMerger tests, and `two_device_sync_test.dart`. However:
- Story 13.4 (New Device Data Restore) is marked `skip: 'Retired W2.35 — to be ported using _StubSyncOrchestrator pattern'` — the port has not happened.
- The invariant N1 (offline queue drains to 0) in `regression_invariants_test.dart` is also skip'd with the same reason.

**Impact:** Stories 13.1, 13.2, 13.3, and 13.4 have zero active test coverage in the story-acceptance suite. The acceptance criteria for Epic 13 (Cloud Sync) are entirely unverified at the acceptance-test level.

---

## HIGH Findings

---

### H-1: B1 regression tests do not verify MarkCompletionUseCase routing — only CompletionSource predicates

**File:** `test/features/learning/domain/use_cases/mark_completion_use_case_b1_test.dart`
**Also:** `test/features/learning/domain/entities/batch_plan_test.dart`

The stated 12 B1 tests in `batch_plan_test.dart` verify `BatchPlan.classify` routing and `BatchPlan` credit-tier predicates. The 11 additional tests in `mark_completion_use_case_b1_test.dart` verify the `CompletionSource` enum predicates directly. Neither test file exercises `MarkCompletionUseCase.call()` with `source = CompletionSource.bulkInTrack` or `lifetimeOnly` and verifies that:
1. `awardGamificationPoints: false` is passed to the repository for bulk/lifetime sources.
2. The `bulkEngagementSkipped` or `lifetimeAchievementSkipped` telemetry events fire.
3. A streak event is NOT created for bulk/lifetime sources.

The comment in `mark_completion_use_case_b1_test.dart` at line 18 acknowledges this: "The routing tests for MarkCompletionUseCase require a live DB … and are deferred until the cross-stream user_database.g.dart conflicts are resolved."

**Impact:** B1 is protected at the predicate level but not at the integration level. A regression in `MarkCompletionUseCase.call()` routing (e.g., always passing `awardGamificationPoints: true`) would not be caught.

---

### H-2: B2 regression test uses a hardcoded `today = DateTime(2026, 5, 20)` — the window will silently drift

**File:** `test/core/domain/value_objects/program_starting_position_test.dart` line 11

The test pins today as `final today = DateTime(2026, 5, 20)` and does arithmetic like `today.subtract(const Duration(days: 31))`. This is intentional for determinism but creates a subtle maintenance hazard: the `fromLegacyGrammar` test at line 167 (`offset:31 rejects`) implicitly relies on the hardcoded date. If the `ProgramStartingPosition` implementation were changed to use the system clock fallback instead of the injected `today`, these tests would still pass (they pass `today:` explicitly) while production would break.

More importantly, there is no test that verifies `ProgramStartingPosition.create` rejects a start date that is `today - 30 - epsilon` (i.e., exactly one millisecond before the lower boundary). The boundary at exactly `today - 30 days` is tested, but not a sub-day offset within the 30th day. Given the spec uses whole-day granularity this is acceptable, but the lack of a `today - 30 days + 23:59:59` test leaves a precision ambiguity unverified.

**Impact:** Medium — the window boundary tests are substantially correct; the hardcoding is a maintenance risk rather than an immediate gap.

---

### H-3: tutorBulkPriorCompletions and purgeExpiredAuditLogs Cloud Functions have zero test coverage

**File:** `learning_tracker/functions/src/index.ts`

The `functions/package.json` has no test script, no test framework (no jest/mocha/vitest), and `functions/` contains no `*.spec.*` or `*.test.*` files. The two load-bearing security functions:
- `tutorBulkPriorCompletions` (lines 309–end): enforces `canBulkPriorCompletion`, rejects future-dated completions, verifies active grant, verifies caller == tutor_uid. This is the ONLY path through which a tutor can write completions, making it the critical security boundary for B1 tutor enforcement.
- `purgeExpiredAuditLogs` (lines 204–256): scheduled daily; purges audit_log sub-collections for grants terminated > 12 months ago.

Neither function has a unit test with mocked admin SDK, an emulator-based test, or any CI coverage.

**Impact:** Any regression in the security checks (e.g., a grant state check that becomes a no-op, or a `completedAt` validation that allows future dates) would reach production with no test catching it.

---

### H-4: Two custom lint rules (no_e_to_string_in_ui, no_raw_logevent) have no test files

**Files:**
- `packages/custom_lints/lib/src/rules/no_e_to_string_in_ui.dart` (W7.20)
- `packages/custom_lints/lib/src/rules/no_raw_logevent.dart` (W7.21)

The six existing lint rules each have a corresponding `test/` file in `packages/custom_lints/test/`. The two rules added in W7.20/W7.21 do not:
- No `no_e_to_string_in_ui_test.dart` exists.
- No `no_raw_logevent_test.dart` exists.

Without tests, the lint rules could silently become no-ops (e.g., if the AST visitor node type changed) and the test suite would not detect it.

---

### H-5: audit Makefile target labels rules 1–15 but calls them 1/15 through 15/15, then renumbers 16/17 and 17/17 — inconsistent count messaging

**File:** `learning_tracker/Makefile` lines 232–346

The `audit` target header says "all 17 enforcement greps (NFR19)" and the final echo says "all 17 greps clean". However, the individual rule echos are labeled `1/15` through `15/15`, then jump to `16/17` and `17/17`. Rules 14 and 15 are explicitly marked `[warn-only: pre-existing violations pending Wave-2 fix]` — meaning they do not set `FAIL=1` even on violations. This makes the effective hard-fail rule count 15 (rules 1–13 plus 16 and 17), not 17. The header messaging is misleading.

Additionally, the audit target does not grep for:
- `DateTime.now()` in `test/` files (rule 6 excludes `test/` by design, but test code calling `DateTime.now()` can feed wrong data into time-sensitive domain logic).
- Violations inside `integration_test/`.

---

## MEDIUM Findings

---

### M-1: expect(true, isTrue) compile-check placeholders in active (non-skipped) tests

**Files:**
- `test/story_acceptance/epic_01_foundation_test.dart`: lines 82, 161, 294 — stories 1.1 ("key dependencies are importable"), 1.3 ("AuthRepositoryImpl exists in data layer"), 1.10 ("project compiles and analyse target exists")
- `test/story_acceptance/epic_27_story_4_widget_golden_test.dart`: line 242 — `CompletionButton — constructor surface locks required fields` (inside an active test with an explicit `skip:` + `expect(true, isTrue)` body)

These tests will always pass regardless of whether the thing they claim to verify is true. For story 1.10 in particular — claiming "project compiles and analyse target exists" — this is identical to the CI analyze job checking the same thing, but the test adds false confidence since it cannot fail.

---

### M-2: regression_invariants_test.dart N2 test verifies source text, not runtime behaviour

**File:** `test/story_acceptance/regression_invariants_test.dart` lines 51–79

The N2 test ("exactly one SyncOrchestrator instance per session") reads the provider source file and does `expect(source, isNot(contains('watch(activeProfileIdProvider')))`. This is a static text grep, not a runtime assertion. It would pass if the string were renamed (e.g., to `ref.watch(profileIdProvider)`) without the actual singleton behavior being verified. The real invariant — that no duplicate LifecycleObserver is registered — cannot be checked this way.

---

### M-3: deactivateTrack test changed from throwsA to completes without verifying the post-state

**File:** `test/core/database/daos/track_dao_test.dart` lines 48–57

The W3.22 fix changed the test from expecting `throwsA(isA<InvalidTrackOperationException>())` to `expectLater(..., completes)`. The test now only verifies the operation does not throw. It does not verify the track's new state (e.g., `state == 'retired'`, `stateChangedAt` updated). `expectLater(..., completes)` is the minimal assertion that guards against the operation crashing, but it provides no protection against the operation silently doing nothing.

---

### M-4: B3 test has no N=30 boundary case for the projection pipeline

**File:** `test/features/tracks/setup/domain/use_cases/provision_track_use_case_test.dart`

The B3 projection tests exercise N=5 (B3-1), N=0 (B3-2), and N=3 with 2 completions (B3-3). There is no test for N=30 (the maximum allowed back-date by B2). Given that `ProgramStartingPosition` enforces [today-30, today], the projection pipeline should be verified at the boundary case N=30 → 30 overdue tasks. This is the case most likely to expose an off-by-one in the `programSchedule` function's `while (!cursor.isAfter(end))` loop.

---

### M-5: Story 14.4 (App info & legal) skip has TODO body tests that would silently pass

**File:** `test/story_acceptance/epic_14_settings_test.dart` lines 697–710

```dart
skip: 'Backlog: app info screen not yet implemented',
() {
  test('about screen shows app version', () {
    // TODO: verify version string display
  });
  test('privacy policy and terms links are accessible', () {
    // TODO: verify link navigation
  });
},
```

Both test bodies are empty (no assertions). If the skip is removed without filling in the assertions, both tests will silently pass. The TODO comments provide no implementation guidance. Same pattern appears in `epic_10_parent_mode_test.dart` line 938 for Story 10.6 (Multi-child profiles).

---

### M-6: make ci does not include format-check — format enforcement only in a parallel CI job

**File:** `learning_tracker/Makefile` line 208

```makefile
ci: analyze validate-calendar test
```

The `make ci` pipeline runs `analyze`, `validate-calendar`, and `flutter test --coverage`. It does not include `format-check`. The GitHub Actions workflow runs `format-check` as a separate parallel job, so CI catches format issues. However, the local `make ci` workflow — which is what developers and agent squads use before committing — silently ignores format violations. A developer running `make ci` locally would get a false green if their code has formatting issues.

---

### M-7: integration_test/app_test.dart is a skeleton with TODO-only body; not run by make ci

**File:** `learning_tracker/integration_test/app_test.dart`

The integration test file contains one `testWidgets` test ("app launches without crashing") and a comment block of TODO items (authentication flow, content browsing, mark completion, sync). The test requires a real device/emulator and Firebase emulators. `make ci` runs `flutter test --coverage` which does not execute files in `integration_test/`. The CI workflow also has no `flutter drive` or integration test step. The integration_test directory effectively has no CI coverage.

---

## LOW Findings

---

### L-1: audit_and_arb_parity_test.dart has a skipped test for make audit clean exit with no DNI ticket on the skip

**File:** `test/tool/audit_and_arb_parity_test.dart` line 82

The `skip:` reason references "DNI-389" but does not link to a ticket, and the comment "Pre-existing violations from Epics 25–26 not yet resolved" is stale now that the refactor has landed. The test should be re-enabled once `make audit` exits 0.

---

### L-2: test_story_25_22 schema test misses `prior_completion_imports` table in expected set

**File:** `test/story_acceptance/epic_25_story_22_firewall_test.dart` lines 86–113

The `expected` table set in the AC1 test does not include `prior_completion_imports`, which was added in W4.26 (`lib/core/database/tables/prior_completion_imports.dart`) and is declared in the `@DriftDatabase` tables list. This means a DROP of `prior_completion_imports` would not be detected by this test. (The test already has larger problems per C-2, but even after those fixes this gap would remain.)

---

### L-3: No_e_to_string_in_ui and no_raw_logevent referenced in W7.20/W7.21 but Makefile audit greps do not cover their violations

**File:** `learning_tracker/Makefile`

The `make audit` greps enforce Firebase isolation, Talker isolation, DateTime.now isolation, etc. The two W7-era restrictions (`no_e_to_string_in_ui` — no `.toString()` on exceptions in UI code; `no_raw_logevent` — no string literals passed directly to AppLogger) are enforced only via the custom_lint package. Given that `custom_lint` is currently soft-failing in CI due to the analyzer version conflict (W1.14 known blocker), both rules are effectively unenforced until the custom_lint compatibility issue is resolved.

---

### L-4: make test-invariants target description says "N1–N7" but the suite covers N1–N8

**File:** `learning_tracker/Makefile` line 12

```makefile
test-invariants: ## Run the N1–N7 quality-crisis invariant net
```

The regression_invariants_test.dart documents and tests N1 through N8 (N8 = purgeHistory never decreases completion_events row count). The help text is stale.

---

## @Skip Inventory

Total skip annotations found: **31**

| File | Count | Reason summary |
|------|-------|----------------|
| `epic_18_track_overhaul_test.dart` | 1 (entire file) | Missing pushCurriculumTrack parameter — no recovery plan |
| `epic_15_multi_profile_test.dart` | 1 (entire file) + 2 inner | Same missing parameter; inner skips for removed ContentVersionCheckService |
| `epic_13_cloud_sync_test.dart` | 4 | W2.35 retirement — 3 with replacement coverage; 1 (13.4) flagged "to be ported" with no port |
| `sync_rework_engine_test.dart` | 5 | W2.35 retirement — replacement coverage claimed |
| `regression_invariants_test.dart` | 1 | N1 W2.35 retirement |
| `epic_27_story_4_widget_golden_test.dart` | 1 | CompletionButton removed in Wave-3/4, no replacement |
| `epic_07_dashboard_test.dart` | 1 | TodaysTasksWidget removed in Wave 3 |
| `epic_10_parent_mode_test.dart` | 1 | Backlog: multi-child profiles not implemented |
| `epic_14_settings_test.dart` | 2 | Backlog (app info screen); auth contract change |
| `epic_02_content_test.dart` | 3 | Bundled JSON removed (content now fetched from cloud) |
| `test/features/content_browsing/...` | 3 | Same bundled JSON removal |
| `test/features/sync/...` | 2 | W2.35 retirement (OfflineQueue deleted) |
| `test/migration/...` | 2 | Schema fields removed (derived_from_events, sync_queue table) |
| `test/tool/audit_and_arb_parity_test.dart` | 1 | make audit not yet clean (DNI-389) |

**Skips without recovery plan (no ticket, no "to be ported" with deadline):**
- `epic_18` (entire file)
- `epic_15` (entire file)
- Story 13.4 device restore ("to be ported" with no work started)
- `epic_27_story_4` CompletionButton (widget removed, test body is `expect(true, isTrue)`)

---

## CI Workflow Assessment

The `.github/workflows/ci.yml` runs 7 parallel jobs: `format-check`, `analyze`, `audit`, `lint`, `test` (with coverage floor), `firestore-rules`, and `arb-parity`.

**What works correctly:**
- `make ci` is invoked in the `test` job, which chains `analyze + validate-calendar + flutter test --coverage`.
- `make audit` is invoked in the `audit` job with graceful skip if target absent.
- Coverage floor is enforced at 60% line coverage.
- `custom_lint` failure is soft (emit warning, continue) — correctly documented as W1.14 known blocker.
- Golden failure artifacts are uploaded on test failure.
- Firestore rules are tested against the Firebase emulator when `test/firestore-rules/` exists.

**Gaps:**
- The `analyze` job blocks on `dart analyze --fatal-infos`. V1-CI-Report documents 1040 pre-existing test compilation errors that would cause this job to fail until they are fully resolved.
- `format-check` runs as a separate CI job but is absent from `make ci` — local pre-commit runs miss format enforcement.
- No CI job for Cloud Functions (`functions/`): no `tsc --noEmit` type-check, no `npm test`.
- `actions/checkout@v6`, `actions/upload-artifact@v7`, `codecov/codecov-action@v6` — these version pins use major version tags without SHA pinning, which is a supply-chain risk for a production app (out of scope for this review but worth noting).
- Integration tests (`integration_test/`) are never run in CI.

---

## B-Regression Coverage Summary

| Bug | Tests | Actual coverage | Gap |
|-----|-------|----------------|-----|
| B1 (3-tier credit policy) | 12 (batch_plan) + 11 (CompletionSource predicates) | Predicate/enum level only | No integration test exercises MarkCompletionUseCase.call() with non-live source |
| B2 (start-date window) | 20 tests | Window boundaries well-covered | Minor: no sub-day precision test at boundary |
| B3 (back-dated overdue) | 13 tests | Projection pipeline covered | Critical: bridge tests exercise test-duplicate, not production ProvisionTrackUseCase._toResult |

---

## Story-Acceptance Suite Health (sampled)

| File | Real assertions | Skips | Quality |
|------|----------------|-------|---------|
| `epic_01_foundation_test.dart` | Mix — 3 `expect(true, isTrue)` compile stubs, rest real | 0 | Adequate for foundation; compile-check tests are weak |
| `epic_06_scheduler_test.dart` | Real DB + engine assertions | 0 | Strong |
| `epic_13_cloud_sync_test.dart` | Placeholder only | 4 whole-group skips | No coverage |
| `epic_15_multi_profile_test.dart` | File-level skip; contains `expect(true, isTrue)` | Entire file | No coverage |
| `epic_25_story_12_sync_decomp_part1_test.dart` | Real structural + behavioural assertions | 0 | Strong |
| `epic_25_story_14_listener_lifecycle_test.dart` | Real lifecycle assertions | 0 | Strong |
| `epic_25_story_15_completion_writer_test.dart` | Full transactional write verification | 0 | Strong |
| `epic_25_story_22_firewall_test.dart` | Contains false-positive schema assertions | 0 | Broken (C-1, C-2) |
| `epic_27_story_06_streak_reconciles_test.dart` | Real DB + reducer assertions | 0 | Strong |
| `regression_invariants_test.dart` | N2–N8 real; N1 retired | 1 | Good |
