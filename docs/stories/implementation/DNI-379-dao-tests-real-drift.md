# DNI-379 — Story 27.3: DAO + repository test suite using real in-memory Drift

**Status:** review
**Epic:** DNI-315 (Epic 27 — Test Infrastructure)
**Linear:** [DNI-379](https://linear.app/orvexai/issue/DNI-379)

## Acceptance Criteria

1. Every DAO in `lib/core/database/daos/` has a sibling test file under `test/core/database/daos/`.
2. Every DAO test file constructs its database through `inMemoryDb()` from `test/helpers/drift_memory.dart`.
3. `MockUserDatabase` references are deleted from the test suite.
4. Per-method branch coverage ≥ 80% across DAOs.

## Implementation

DAOs surveyed on `origin/dev@6ffe6d54`: 20 source files (story spec said 18 — drift due to `outbox_dao` + `track_learning_order_dao` added since the spec was written).

### Migrations (16 existing DAO test files)

Replaced inline `UserDatabase(NativeDatabase.memory())` and three `createTestDatabase()` callers with `inMemoryDb()` from `test/helpers/drift_memory.dart`:

- `active_curriculum_dao_test.dart`, `bookmark_dao_test.dart`, `completion_dao_test.dart`, `curriculum_scope_dao_test.dart`, `goal_dao_test.dart`, `learning_order_dao_test.dart`, `point_config_dao_test.dart`, `profile_dao_test.dart`, `stage_dao_test.dart`, `streak_dao_test.dart`, `sync_queue_dao_test.dart`, `track_dao_test.dart`, `user_profile_dao_test.dart` (inline pattern)
- `learning_ledger_dao_test.dart`, `profile_program_dao_test.dart`, `text_download_status_dao_test.dart` (`createTestDatabase()` pattern)
- `track_scoped_dao_test.dart` (cross-cutting DAO scope test — also migrated)

### New DAO test files (4)

Written from scratch covering every public method:

- `outbox_dao_test.dart` — 12 tests on insert / getPendingByKind / markAttempted / deleteRow including no-op-on-missing-id and FIFO ordering.
- `daily_plan_dao_test.dart` — 12 tests on getPlanForDay / watch / hasPlanForDay / hasPlanForTrackOnDay / getPriorlyShownRefsForTrack / insertEntries (incl. empty no-op + insertOrIgnore) / deletePlansByTrack / deletePlanForDay / deleteOlderThan.
- `study_day_config_dao_test.dart` — 18 tests on upsertDayConfig / seedDefaults / seedDefaultsForTrack (incl. StateError path) / get & watch / isStudyDay & isStudyDayForTrack / getStudyDaysPerWeek / countStudyDaysInInclusiveDateRangeForTrack (incl. start>end and rest-day exclusion) / deletes / getLatestUpdatedAt.
- `track_learning_order_dao_test.dart` — 8 tests on upsertOrder (insert / idempotence / sortOrder update on conflict / empty no-op) / getByTrack (empty + ordering) / deleteByTrack (track isolation).

### `chart_data_service_test.dart`

Rewrote the only `MockUserDatabase` consumer in the suite against a real `inMemoryDb()`. The test now inserts real `Completion` rows via `db.into(db.completions).insert(...)` and exercises `ChartDataService` end-to-end. 8 / 8 tests pass.

### Story 27.3 acceptance group

Added to `test/story_acceptance/epic_27_test_infrastructure_test.dart`:

- AC1: walks `lib/core/database/daos/*_dao.dart` and asserts every DAO has a `test/core/database/daos/<base>_test.dart` sibling.
- AC2: greps every DAO test for both `inMemoryDb()` and `helpers/drift_memory.dart`.
- AC3: walks `test/**` and asserts `MockUserDatabase` appears in zero source files (skipping this acceptance file itself, which mentions the string in failure messages).

### Make target

`make test-story-27.3` runs the acceptance group; added to `.PHONY` and `help`.

## Pre-flight note

Batch-3 cherry-picked only the DNI-377 follow-up commit (Makefile targets, `ddd96a50`) and skipped the actual helper commit (`9938b579`) that introduced `drift_memory.dart`. Cherry-picked `9938b579` onto `dev-dni-379` so the helper is available. Team-lead confirmed batch-4 already includes `9938b579`, so the cherry-pick will collapse at merge time.

## Verification

- `make test-story-27.3` — 3 / 3 passing
- `flutter test test/core/database/daos/` — 232 / 232 passing
- `flutter test test/features/progress/domain/services/chart_data_service_test.dart` — 8 / 8 passing
- `flutter test` (full regression) — **1934 passing, 103 skipped, 0 failing**
- `dart analyze --fatal-infos` — clean (only the 2 pre-existing gitignored `lib/firebase_options.dart` errors remain on origin/dev)

## File List

- `learning_tracker/test/story_acceptance/epic_27_test_infrastructure_test.dart` (modified — added Story 27.3 group)
- `learning_tracker/test/helpers/drift_memory.dart` (cherry-picked from DNI-377 `9938b579`)
- `learning_tracker/test/helpers/firestore_fake.dart` (cherry-picked from DNI-377 `9938b579`)
- `learning_tracker/test/helpers/golden_runner.dart` (cherry-picked from DNI-377 `9938b579`)
- `learning_tracker/test/core/database/daos/active_curriculum_dao_test.dart`
- `learning_tracker/test/core/database/daos/bookmark_dao_test.dart`
- `learning_tracker/test/core/database/daos/completion_dao_test.dart`
- `learning_tracker/test/core/database/daos/curriculum_scope_dao_test.dart`
- `learning_tracker/test/core/database/daos/daily_plan_dao_test.dart` (new)
- `learning_tracker/test/core/database/daos/goal_dao_test.dart`
- `learning_tracker/test/core/database/daos/learning_ledger_dao_test.dart`
- `learning_tracker/test/core/database/daos/learning_order_dao_test.dart`
- `learning_tracker/test/core/database/daos/outbox_dao_test.dart` (new)
- `learning_tracker/test/core/database/daos/point_config_dao_test.dart`
- `learning_tracker/test/core/database/daos/profile_dao_test.dart`
- `learning_tracker/test/core/database/daos/profile_program_dao_test.dart`
- `learning_tracker/test/core/database/daos/stage_dao_test.dart`
- `learning_tracker/test/core/database/daos/streak_dao_test.dart`
- `learning_tracker/test/core/database/daos/study_day_config_dao_test.dart` (new)
- `learning_tracker/test/core/database/daos/sync_queue_dao_test.dart`
- `learning_tracker/test/core/database/daos/text_download_status_dao_test.dart`
- `learning_tracker/test/core/database/daos/track_dao_test.dart`
- `learning_tracker/test/core/database/daos/track_learning_order_dao_test.dart` (new)
- `learning_tracker/test/core/database/daos/track_scoped_dao_test.dart`
- `learning_tracker/test/core/database/daos/user_profile_dao_test.dart`
- `learning_tracker/test/features/progress/domain/services/chart_data_service_test.dart`
- `learning_tracker/Makefile`
