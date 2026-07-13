# Story 19.2: Two-Database Split (ContentDatabase + UserDatabase)

Status: done

## Story

As a developer,
I want to split the monolithic AppDatabase into a read-only ContentDatabase and a mutable UserDatabase,
so that content can be shipped as a pre-built seed file replaced wholesale on app updates, while user data uses standard Drift migrations.

## Acceptance Criteria

**AC-1: ContentDatabase exists with correct tables**
**Given** the codebase has been split
**When** ContentDatabase is opened
**Then** it contains exactly 4 tables: TextCache, CalendarCycles (new), LearningPrograms, SeedMetadata (new)
**And** it exposes only read-only DAO methods (no insert/update/delete on content)

**AC-2: UserDatabase exists with correct tables**
**Given** the codebase has been split
**When** UserDatabase is opened
**Then** it contains exactly 20 tables: UserProfiles, Profiles, ActiveCurricula, CurriculumTracks, CurriculumScopes, ProfilePrograms, StageDefinitions, PointConfigs, StudyDayConfigs, Completions, LearningLedger, Bookmarks, LearningOrder, Goals, Rewards, RewardPools, RewardPoolItems, Streaks, SyncQueue, TextDownloadStatuses
**And** it uses standard Drift migrations starting at schemaVersion 1

**AC-3: Eliminated tables are removed**
**Given** the codebase has been split
**When** inspecting the database layer
**Then** CalendarCache table and CalendarCacheDao are removed (replaced by CalendarCycles)
**And** ContentDownloadStatuses table and ContentDownloadStatusDao are removed (hierarchy data now bundled in APK)

**AC-4: Two database providers replace the single provider**
**Given** the codebase has been split
**When** any feature accesses database state via Riverpod
**Then** it uses either `contentDatabaseProvider` or `userDatabaseProvider` (never `appDatabaseProvider`)
**And** all 46+ provider files referencing `appDatabaseProvider` have been updated

**AC-5: DAOs use correct database accessor types**
**Given** the codebase has been split
**When** inspecting DAO class declarations
**Then** Content DAOs extend `DatabaseAccessor<ContentDatabase>`
**And** User DAOs extend `DatabaseAccessor<UserDatabase>`
**And** no DAO extends `DatabaseAccessor<AppDatabase>`

**AC-6: Cross-database reads work at the provider layer**
**Given** a feature needs data from both databases (e.g., AddTrackFlow reads LearningPrograms from ContentDB, writes StageDefinitions to UserDB)
**When** the operation executes
**Then** the provider/service layer performs the cross-DB read-then-write
**And** no DAO queries across database boundaries

**AC-7: All tests pass with the new dual-database architecture**
**Given** the codebase has been split
**When** running `make ci`
**Then** all tests pass with updated test helpers (`createTestUserDatabase()`, `createTestContentDatabase()`)

**AC-8: AppDatabase and old files are fully removed**
**Given** the migration is complete
**When** inspecting the codebase
**Then** `app_database.dart`, `app_database.g.dart` are deleted
**And** no file imports `AppDatabase`
**And** code generation succeeds cleanly

## Tasks / Subtasks

### Phase 1: Create ContentDatabase + New Tables (AC: 1)

#### T1.1: Create new table definition files

- [ ] Create `lib/core/database/tables/calendar_cycles.dart`:
  - Composite PK on `{programKey, dateKey}`
  - Columns: `programKey` (text), `dateKey` (text, YYYY-MM-DD), `sefariaRef` (text), `displayName` (text, default '')
- [ ] Create `lib/core/database/tables/seed_metadata.dart`:
  - PK on `{version}`
  - Columns: `version` (int), `builtAt` (text), `buildId` (text), `textCacheCount` (int), `calendarCycleCount` (int)

#### T1.2: Create ContentDatabase class

- [ ] Create directory `lib/core/database/content/`
- [ ] Create `lib/core/database/content/content_database.dart`:
  - `@DriftDatabase` annotation listing: TextCache, CalendarCycles, LearningPrograms, SeedMetadata
  - DAO list: TextCacheDao, CalendarCycleDao, LearningProgramDao, SeedMetadataDao
  - `schemaVersion => 1`
  - No migration strategy (DB is replaced wholesale, not migrated)
- [ ] Create `lib/core/database/content/content_database_opener.dart`:
  - `Future<ContentDatabase> openContentDatabase()` function
  - Checks if seed file exists at `content.db` path
  - Extracts from `assets/db/content.db.gz` if missing
  - Returns `ContentDatabase(NativeDatabase(dbFile))`

#### T1.3: Create new Content DAOs

- [ ] Create `lib/core/database/content/daos/calendar_cycle_dao.dart`:
  - `DatabaseAccessor<ContentDatabase>`
  - Read-only methods: `getCyclesForDate(String dateKey)`, `getCycleForProgramAndDate(String programKey, String dateKey)`, `getCyclesForDateRange(String startDate, String endDate)`
- [ ] Create `lib/core/database/content/daos/seed_metadata_dao.dart`:
  - `DatabaseAccessor<ContentDatabase>`
  - Single read method: `Future<SeedMetadataData?> getVersion()`

#### T1.4: Run code generation and verify compilation

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verify `content_database.g.dart` is generated without errors
- [ ] Verify no naming conflicts with existing `app_database.g.dart` types

### Phase 2: Create UserDatabase (AC: 2)

#### T2.1: Create UserDatabase class

- [ ] Create directory `lib/core/database/user/`
- [ ] Create `lib/core/database/user/user_database.dart`:
  - `@DriftDatabase` annotation listing all 20 user tables: UserProfiles, Profiles, ActiveCurricula, CurriculumTracks, CurriculumScopes, ProfilePrograms, StageDefinitions, PointConfigs, StudyDayConfigs, Completions, LearningLedger, Bookmarks, LearningOrder, Goals, Rewards, RewardPools, RewardPoolItems, Streaks, SyncQueue, TextDownloadStatuses
  - DAO list: all 19 User DAOs (see Phase 3)
  - `schemaVersion => 1`
  - `MigrationStrategy` with `onCreate` that calls `m.createAll()` (no seed data — LearningPrograms are in ContentDB)
  - `onUpgrade` stub for future migrations
  - TestDates and TestScores tables stay in UserDB

#### T2.2: Run code generation

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verify `user_database.g.dart` is generated without errors
- [ ] Verify both database `.g.dart` files coexist without import conflicts

### Phase 3: Split DAOs Between Databases (AC: 5)

#### T3.1: Move and update Content DAOs

- [ ] Move `daos/text_cache_dao.dart` to `content/daos/text_cache_dao.dart`:
  - Change `DatabaseAccessor<AppDatabase>` to `DatabaseAccessor<ContentDatabase>` (line 9)
  - Change import from `app_database.dart` to `content_database.dart` (line 2)
  - **Remove write methods**: `storeText()` (line 20-33), `deleteText()` (line 36-37), `storeBatch()` (line 46-63), `clearCache()` (line 66) — ContentDB is read-only at runtime
  - Keep read methods: `getText()` (line 15-17), `getAllCachedRefs()` (line 40-43)
- [ ] Move `daos/learning_program_dao.dart` to `content/daos/learning_program_dao.dart`:
  - Change `DatabaseAccessor<AppDatabase>` to `DatabaseAccessor<ContentDatabase>` (line 8)
  - Change import from `app_database.dart` to `content_database.dart` (line 2)
  - **Remove write methods**: `insertProgram()` (line 32-33), `deprecateProgram()` (line 35-38) — ContentDB is read-only
  - Keep read methods: `getAllPrograms()` (line 12-13), `getActivePrograms()` (line 15-16), `getProgramById()` (line 18-20), `getProgramByName()` (line 22-24), `getProgramsByCurriculumType()` (line 26-30)
- [ ] Move `daos/test_date_dao.dart` to `content/daos/test_date_dao.dart`:
  - Change `DatabaseAccessor<AppDatabase>` to `DatabaseAccessor<ContentDatabase>` (line 8)
  - Change import from `app_database.dart` to `content_database.dart` (line 2)
  - **Remove write methods**: `insertTestDate()` (line 34-35), `insertMultipleTestDates()` (line 37-38) — ContentDB is read-only
  - Keep read methods: `getAllTestDates()` (line 12), `getTestDatesForProgram()` (line 14-15), `getNextTestDateForProgram()` (line 17-26), `getUpcomingTestDates()` (line 28-32)
  - **NOTE**: Architecture doc says TestDates stays in UserDB, but also lists TestDateDao under ContentDB DAOs. Per the design doc appendix B, TestDateDao goes to ContentDB as read-only. Follow this.

#### T3.2: Move and update User DAOs (19 files)

- [ ] For each of the following DAOs, change `DatabaseAccessor<AppDatabase>` to `DatabaseAccessor<UserDatabase>` and update the import from `app_database.dart` to `user_database.dart`:
  - `daos/active_curriculum_dao.dart` (line 2: import, line ~9: accessor type)
  - `daos/bookmark_dao.dart` (line 2: import, line 8: accessor type)
  - `daos/completion_dao.dart` (line 2: import, line 12: accessor type)
  - `daos/curriculum_scope_dao.dart` (line 2: import, accessor type)
  - `daos/goal_dao.dart` (line 2: import, accessor type)
  - `daos/learning_ledger_dao.dart` (line 2: import, accessor type)
  - `daos/learning_order_dao.dart` (line 2: import, accessor type)
  - `daos/point_config_dao.dart` (line 2: import, accessor type)
  - `daos/profile_dao.dart` (line 2: import, line 9: accessor type)
  - `daos/profile_program_dao.dart` (line 2: import, line 8: accessor type)
  - `daos/reward_dao.dart` (line 2: import, accessor type)
  - `daos/reward_pool_dao.dart` (line 2: import, line 10: accessor type)
  - `daos/stage_dao.dart` (line 2: import, line 8: accessor type)
  - `daos/streak_dao.dart` (line 2: import, accessor type)
  - `daos/study_day_config_dao.dart` (line 2: import, accessor type)
  - `daos/sync_queue_dao.dart` (line 2: import, line 9: accessor type)
  - `daos/test_download_status_dao.dart` (line 2: import, accessor type)
  - `daos/test_score_dao.dart` (line 2: import, accessor type)
  - `daos/track_dao.dart` (line 2: import, line 11: accessor type)
  - `daos/user_profile_dao.dart` (line 2: import, line 8: accessor type)
- [ ] Move DAO files to `user/daos/` subdirectory (or keep in `daos/` with updated imports — follow design doc structure)

#### T3.3: Delete eliminated DAOs

- [ ] Delete `daos/calendar_cache_dao.dart` and `daos/calendar_cache_dao.g.dart`
  - Replaced by new `CalendarCycleDao` in ContentDB
- [ ] Delete `daos/content_download_status_dao.dart` and `daos/content_download_status_dao.g.dart`
  - Table removed entirely (hierarchy data now bundled in APK)

#### T3.4: Run code generation

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verify all `.g.dart` files regenerate cleanly
- [ ] Fix any compile errors from accessor type mismatches

### Phase 4: Update Providers (AC: 4)

#### T4.1: Replace database_provider.dart

- [ ] Update `lib/core/providers/database_provider.dart` (currently 12 lines):
  - Remove `appDatabaseProvider` (lines 7-12)
  - Add `contentDatabaseProvider`:
    ```dart
    @Riverpod(keepAlive: true)
    ContentDatabase contentDatabase(Ref ref) {
      // Eagerly initialized in main() via override
      throw UnimplementedError('Must be overridden in ProviderScope');
    }
    ```
  - Add `userDatabaseProvider`:
    ```dart
    @Riverpod(keepAlive: true)
    UserDatabase userDatabase(Ref ref) {
      final database = UserDatabase(driftDatabase(name: 'learning_tracker'));
      ref.onDispose(database.close);
      return database;
    }
    ```
  - Update imports: add `content_database.dart`, `user_database.dart`, remove `app_database.dart`

#### T4.2: Update main.dart for eager ContentDB initialization

- [ ] In `main()`, add async initialization:
  ```dart
  final contentDb = await openContentDatabase();
  ```
- [ ] Add `contentDatabaseProvider.overrideWithValue(contentDb)` to `ProviderScope.overrides`

#### T4.3: Update Content-only provider files (change to `contentDatabaseProvider`)

- [ ] `lib/features/content_browsing/presentation/providers/text_display_providers.dart` (line 13):
  - Change `ref.watch(appDatabaseProvider)` to `ref.watch(contentDatabaseProvider)`
  - Accesses: `database.textCacheDao`
- [ ] `lib/core/providers/calendar_providers.dart` (line 25):
  - Change `ref.watch(appDatabaseProvider)` to `ref.watch(contentDatabaseProvider)` (or restructure CalendarProgramService to accept ContentDB)
  - This file will need rework since CalendarProgramService constructor takes the full database
- [ ] `lib/features/content_browsing/presentation/providers/cloud_content_providers.dart`:
  - Change to `contentDatabaseProvider` for TextCache access

#### T4.4: Update User-only provider files (change to `userDatabaseProvider`) — ~35 files

- [ ] Update all of the following files to replace `ref.watch(appDatabaseProvider)` with `ref.watch(userDatabaseProvider)`:
  - `lib/features/learning/presentation/providers/bookmark_providers.dart`
  - `lib/features/learning/presentation/providers/completion_providers.dart`
  - `lib/features/learning/presentation/providers/learning_ledger_providers.dart`
  - `lib/features/learning/presentation/providers/track_providers.dart`
  - `lib/features/profiles/presentation/providers/profile_providers.dart`
  - `lib/features/progress/presentation/providers/chart_providers.dart`
  - `lib/features/progress/presentation/providers/journey_providers.dart`
  - `lib/features/progress/presentation/providers/progress_providers.dart`
  - `lib/features/gamification/presentation/providers/points_providers.dart`
  - `lib/features/gamification/presentation/providers/reward_providers.dart`
  - `lib/features/gamification/presentation/screens/gamification_screen.dart`
  - `lib/features/scheduler/presentation/providers/scheduler_providers.dart`
  - `lib/features/scheduler/presentation/providers/study_day_config_providers.dart`
  - `lib/features/scheduler/presentation/screens/study_day_config_screen.dart`
  - `lib/features/stages/presentation/providers/stage_providers.dart`
  - `lib/features/settings/presentation/providers/account_management_providers.dart`
  - `lib/features/settings/presentation/providers/curriculum_activation_providers.dart`
  - `lib/features/settings/presentation/providers/curriculum_scope_providers.dart`
  - `lib/features/settings/presentation/providers/data_export_import_providers.dart`
  - `lib/features/settings/presentation/screens/curriculum_settings_screen.dart`
  - `lib/features/settings/presentation/screens/scope_selection_screen.dart`
  - `lib/features/sync/presentation/providers/restore_providers.dart`
  - `lib/features/sync/presentation/providers/sync_providers.dart`
  - `lib/features/notifications/presentation/providers/notification_providers.dart`
  - `lib/features/tutor_mode/presentation/providers/tutor_dashboard_providers.dart`
  - `lib/features/parent_mode/presentation/providers/parent_dashboard_providers.dart`
  - `lib/features/parent_mode/presentation/providers/parent_track_providers.dart`
  - `lib/features/parent_mode/presentation/screens/point_config_screen.dart`
  - `lib/features/learning_order/presentation/providers/learning_order_providers.dart`
  - `lib/features/dashboard/presentation/providers/dashboard_providers.dart`
  - `lib/features/content_browsing/presentation/widgets/content_item_tile.dart`
  - `lib/core/navigation/router_provider.dart`
  - `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart`
  - `lib/features/track_setup/presentation/providers/track_management_providers.dart`

#### T4.5: Update cross-database provider files (need both providers)

- [ ] `lib/features/onboarding/presentation/providers/onboarding_providers.dart`:
  - Line 20: `ref.watch(appDatabaseProvider)` accesses `db.userProfileDao` — change to `userDatabaseProvider`
  - Line 38: `ref.watch(appDatabaseProvider)` for GoalRepositoryImpl — change to `userDatabaseProvider`
  - If any onboarding flow reads LearningPrograms, add `ref.watch(contentDatabaseProvider)` alongside
- [ ] `lib/features/track_setup/presentation/providers/add_track_providers.dart`:
  - Line 9: `ref.watch(appDatabaseProvider)` — TrackCreationService needs both DBs
  - Refactor TrackCreationService constructor to accept `UserDatabase` + `ContentDatabase` (or pass individual DAOs)
  - Read LearningProgram from ContentDB, write StageDefinitions/PointConfigs to UserDB
- [ ] `lib/features/scheduler/presentation/providers/scheduler_providers.dart`:
  - If scheduler reads CalendarCycles from ContentDB + Completions from UserDB, inject both providers

#### T4.6: Run code generation for provider changes

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Verify all `.g.dart` files for providers regenerate cleanly

### Phase 5: Update Repositories/Services to Use Correct DB (AC: 6)

#### T5.1: Audit and update repository constructors

- [ ] Search all repository/service classes that currently accept `AppDatabase` as a constructor parameter
- [ ] Change to `UserDatabase` or `ContentDatabase` as appropriate
- [ ] For cross-DB services (e.g., `TrackCreationService`, `CalendarProgramService`):
  - Accept both database types as separate parameters, OR
  - Accept individual DAOs rather than full database objects

#### T5.2: Update CalendarProgramService

- [ ] `lib/core/services/calendar_program_service.dart`:
  - Currently accepts `AppDatabase` for CalendarCache access
  - Refactor to accept `ContentDatabase` and use `CalendarCycleDao` instead of `CalendarCacheDao`
  - Remove all write operations (no more caching API responses — data is pre-computed)
  - The service should only read from `CalendarCycles` table now

#### T5.3: Verify no DAO crosses database boundaries

- [ ] Grep all DAO files for imports of both `content_database.dart` and `user_database.dart` — should find zero files importing both
- [ ] Verify all cross-DB data flow happens at the provider/service layer

### Phase 6: Update Tests (AC: 7)

#### T6.1: Update test_database.dart helper

- [ ] Update `test/helpers/test_database.dart`:
  - Add `createTestUserDatabase()` returning `UserDatabase(NativeDatabase.memory())`
  - Add `createTestContentDatabase()` returning `Future<ContentDatabase>` with seed data (LearningPrograms from `learningProgramSeeds`, SeedMetadata, no TextCache/CalendarCycles needed for most tests)
  - Add `createTestDatabases()` convenience returning both
  - Keep `createTestDatabase()` temporarily marked `@deprecated` for incremental migration
  - Update `batchInsert` helper to accept generalized `GeneratedDatabase` instead of `AppDatabase`

#### T6.2: Update story acceptance tests (~14 files)

- [ ] Update each test file that calls `createTestDatabase()`:
  - `test/story_acceptance/epic_01_foundation_test.dart`
  - `test/story_acceptance/epic_02_content_test.dart`
  - `test/story_acceptance/epic_03_learning_cycle_test.dart`
  - `test/story_acceptance/epic_06_scheduler_test.dart`
  - `test/story_acceptance/epic_07_dashboard_test.dart`
  - `test/story_acceptance/epic_08_gamification_test.dart`
  - `test/story_acceptance/epic_10_parent_mode_test.dart`
  - `test/story_acceptance/epic_11_tutor_mode_test.dart`
  - `test/story_acceptance/epic_12_notifications_test.dart`
  - `test/story_acceptance/epic_14_settings_test.dart`
  - `test/story_acceptance/epic_15_multi_profile_test.dart`
  - `test/story_acceptance/epic_16_pace_dashboard_test.dart`
  - `test/infrastructure_test.dart`
- [ ] Replace `createTestDatabase()` with `createTestUserDatabase()` (and `createTestContentDatabase()` where needed)
- [ ] Update provider overrides in tests that use `appDatabaseProvider.overrideWithValue(db)` to use the new provider names

#### T6.3: Update feature-level tests (~22 files)

- [ ] Update each test file:
  - `test/features/settings/domain/services/account_management_service_test.dart`
  - `test/features/profiles/data/repositories/profile_repository_impl_test.dart`
  - `test/features/progress/domain/services/curriculum_progress_service_test.dart`
  - `test/features/scheduler/data/repositories/goal_repository_impl_test.dart`
  - `test/features/scheduler/domain/services/daily_task_generator_test.dart`
  - `test/features/scheduler/domain/services/scheduler_engine_integration_test.dart`
  - `test/features/content_browsing/integration/text_display_integration_test.dart`
  - `test/features/content_browsing/data/repositories/text_cache_repository_test.dart`
  - `test/features/gamification/domain/services/points_service_test.dart`
  - `test/features/gamification/domain/services/streak_service_test.dart`
  - `test/features/learning/data/repositories/bookmark_repository_impl_test.dart`
  - `test/features/learning/data/repositories/completion_repository_impl_test.dart`
  - `test/features/learning/data/repositories/learning_ledger_repository_impl_test.dart`
  - `test/features/learning/domain/services/completion_detection_service_test.dart`
  - `test/features/learning/domain/use_cases/manual_completion_use_case_test.dart`
  - `test/features/notifications/domain/services/streak_alert_service_test.dart`
  - `test/core/database/daos/learning_ledger_dao_test.dart`
  - `test/core/database/daos/learning_program_dao_test.dart`
  - `test/core/database/daos/profile_program_dao_test.dart`
  - `test/core/database/daos/text_download_status_dao_test.dart`
  - `test/core/database/migration_test.dart`
  - `test/core/navigation/app_shell_test.dart`
  - `test/features/onboarding/presentation/screens/mode_selection_screen_test.dart`
  - `test/features/settings/presentation/screens/settings_screen_test.dart`
  - `test/features/safe_area_protection_test.dart`
  - `test/features/gamification/presentation/screens/gamification_screen_test.dart`
  - `test/features/parent_mode/child_mode_guard_test.dart`

#### T6.4: Update migration_test.dart

- [ ] `test/core/database/migration_test.dart`:
  - Remove or deprecate tests for the old AppDatabase migration chain (versions 1-23)
  - Add test that UserDatabase starts fresh at schemaVersion 1 with `m.createAll()`
  - Add test that ContentDatabase opens at schemaVersion 1 with no migration
  - Verify both databases create all expected tables

#### T6.5: Run full test suite

- [ ] Run `make ci` (analyze + format + all stories)
- [ ] Fix any remaining failures

### Phase 7: Remove Eliminated Tables and AppDatabase (AC: 3, 8)

#### T7.1: Delete removed table files

- [ ] Delete `lib/core/database/tables/calendar_cache.dart` (23 lines — replaced by `calendar_cycles.dart`)
- [ ] Delete `lib/core/database/tables/content_download_statuses.dart` (27 lines — hierarchy now bundled in APK)

#### T7.2: Delete AppDatabase

- [ ] Delete `lib/core/database/app_database.dart` (437 lines)
- [ ] Delete `lib/core/database/app_database.g.dart` (generated)

#### T7.3: Delete eliminated DAO .g.dart files

- [ ] Delete `daos/calendar_cache_dao.g.dart`
- [ ] Delete `daos/content_download_status_dao.g.dart`
- [ ] Verify no remaining imports reference deleted files

#### T7.4: Final code generation and verification

- [ ] Run `dart run build_runner build --delete-conflicting-outputs`
- [ ] Run `dart analyze --fatal-infos`
- [ ] Run `dart format --set-exit-if-changed .`
- [ ] Run `make ci`

## Dev Context

### Architecture

| Aspect | Detail |
|--------|--------|
| Pattern | Monolithic DB split into read-only Content DB + mutable User DB |
| Dependencies | None — this is a foundational refactor for Epic 19 |
| Drift version | 2.31.0 (no upgrade needed) |
| Code gen | `build.yaml` already has `scoped_dart_components: true` — no changes needed |
| New dependencies | None — `drift`, `drift_flutter`, `drift_dev` are sufficient |

### Current Code Analysis

#### Monolithic AppDatabase (`lib/core/database/app_database.dart`)

- **Line 58-86**: `@DriftDatabase` annotation lists all 25 tables in a single database
- **Line 87-113**: All 24 DAOs registered on AppDatabase
- **Line 115**: `class AppDatabase extends _$AppDatabase`
- **Line 119**: `schemaVersion => 23` — 23 migration versions accumulated
- **Lines 122-395**: Massive `MigrationStrategy` with `onCreate` and `onUpgrade` handling versions 1-23
- **Lines 398-436**: Seed methods `_seedTestDates()` and `_seedLearningPrograms()` — these move to content build pipeline

#### Database Provider (`lib/core/providers/database_provider.dart`)

- **Line 8**: Single `appDatabase` provider returning `AppDatabase`
- **Line 9**: Opens database with `driftDatabase(name: 'learning_tracker')`
- **12 lines total** — will be replaced with two providers

#### Table Files (26 files in `lib/core/database/tables/`)

Tables moving to **ContentDatabase** (3 existing + 2 new):
- `text_cache.dart` (13 lines) — PK on `sefariaRef`, stores Hebrew/English text
- `learning_programs.dart` (29 lines) — autoincrement id, 9 preset programs with stagesConfig JSON
- `test_dates.dart` (13 lines) — autoincrement id, FK to programId
- NEW: `calendar_cycles.dart` — composite PK `{programKey, dateKey}`, replaces `calendar_cache.dart`
- NEW: `seed_metadata.dart` — PK on `version`, single-row version tracking

Tables moving to **UserDatabase** (20 existing):
- `user_profiles.dart` (11 lines), `profiles.dart` (15 lines)
- `active_curricula.dart` (18 lines), `curriculum_tracks.dart` (32 lines), `curriculum_scopes.dart` (26 lines)
- `profile_programs.dart` (22 lines), `stage_definitions.dart` (23 lines), `point_configs.dart` (19 lines)
- `study_day_configs.dart` (13 lines)
- `completions.dart` (16 lines), `learning_ledger.dart` (24 lines), `bookmarks.dart` (19 lines), `learning_order.dart` (21 lines)
- `goals.dart` (20 lines), `rewards.dart` (34 lines), `reward_pools.dart` (11 lines), `reward_pool_items.dart` (10 lines), `streaks.dart` (15 lines)
- `sync_queue.dart` (24 lines), `text_download_status.dart` (27 lines)
- `test_scores.dart` (14 lines)

Tables **eliminated**:
- `calendar_cache.dart` (23 lines) — replaced by `calendar_cycles.dart`
- `content_download_statuses.dart` (27 lines) — hierarchy data now bundled in APK

#### DAO Files (24 non-generated files in `lib/core/database/daos/`)

Every DAO follows the same pattern:
```dart
import 'package:learning_tracker/core/database/app_database.dart';
// ...
class XxxDao extends DatabaseAccessor<AppDatabase> with _$XxxDaoMixin {
```

Content DAOs (move to `content/daos/`, change to `DatabaseAccessor<ContentDatabase>`, remove writes):
- `text_cache_dao.dart` — 67 lines, has write methods to remove: `storeText`, `deleteText`, `storeBatch`, `clearCache`
- `learning_program_dao.dart` — 39 lines, has write methods to remove: `insertProgram`, `deprecateProgram`
- `test_date_dao.dart` — 39 lines, has write methods to remove: `insertTestDate`, `insertMultipleTestDates`

New Content DAOs:
- `calendar_cycle_dao.dart` — replaces `calendar_cache_dao.dart` (47 lines)
- `seed_metadata_dao.dart` — new, ~10 lines

User DAOs (change to `DatabaseAccessor<UserDatabase>`):
- `active_curriculum_dao.dart`, `bookmark_dao.dart`, `completion_dao.dart` (348 lines), `curriculum_scope_dao.dart`, `goal_dao.dart`, `learning_ledger_dao.dart`, `learning_order_dao.dart`, `point_config_dao.dart`, `profile_dao.dart` (45 lines), `profile_program_dao.dart`, `reward_dao.dart`, `reward_pool_dao.dart`, `stage_dao.dart` (74 lines), `streak_dao.dart`, `study_day_config_dao.dart`, `sync_queue_dao.dart` (65 lines), `text_download_status_dao.dart`, `test_score_dao.dart`, `track_dao.dart` (227 lines), `user_profile_dao.dart`

Eliminated DAOs:
- `calendar_cache_dao.dart` (47 lines) — replaced by `calendar_cycle_dao.dart`
- `content_download_status_dao.dart` (79 lines) — table removed

#### Provider Files Referencing `appDatabaseProvider` (46 files)

All 46 files import `database_provider.dart` and call `ref.watch(appDatabaseProvider)`:

**Content-only access** (3 files — change to `contentDatabaseProvider`):
- `lib/features/content_browsing/presentation/providers/text_display_providers.dart` (line 13)
- `lib/core/providers/calendar_providers.dart` (line 25)
- `lib/features/content_browsing/presentation/providers/cloud_content_providers.dart`

**User-only access** (~35 files — change to `userDatabaseProvider`):
- All profile, completion, bookmark, goal, reward, streak, scheduler, settings, sync, notification providers

**Cross-database access** (3-4 files — need both providers):
- `lib/features/onboarding/presentation/providers/onboarding_providers.dart`
- `lib/features/track_setup/presentation/providers/add_track_providers.dart`
- `lib/features/scheduler/presentation/providers/scheduler_providers.dart` (if reading CalendarCycles)
- `lib/features/dashboard/presentation/providers/dashboard_providers.dart` (if showing calendar assignments)

#### Test Files Using `createTestDatabase()` (37 files)

All 37 test files import `test/helpers/test_database.dart` and call `createTestDatabase()` to get an `AppDatabase`. Each must be updated to use the new helpers.

#### Cross-Database FK Risk: `ProfilePrograms.programId`

- `lib/core/database/tables/profile_programs.dart` line 10: `IntColumn get programId => integer()()`
- This integer FK references `LearningPrograms.id` which will be in ContentDB
- **Risk**: Autoincrement IDs are deterministic only if seed insertion order is stable
- **Mitigation**: Consider adding `programName` text column as stable cross-DB key (minor schema addition)

### Patterns to Follow

1. **Table definitions stay in shared `tables/` directory** — plain Dart classes with no generated code dependency on a specific database type
2. **DAOs split into `content/daos/` and `user/daos/`** — each DAO depends on its database type
3. **Content DAOs are read-only** — no insert/update/delete methods exposed
4. **Cross-database data flow at provider/service layer only** — no DAO imports both database types
5. **Seed data in `seed/` directory is shared** — used by content build pipeline and test helpers
6. **`build.yaml` unchanged** — `scoped_dart_components: true` handles multi-DB code gen

### File Organization (Target State)

```
lib/core/database/
  content/
    content_database.dart
    content_database.g.dart
    content_database_opener.dart
    daos/
      text_cache_dao.dart (+.g.dart)
      calendar_cycle_dao.dart (+.g.dart)       # NEW
      learning_program_dao.dart (+.g.dart)
      test_date_dao.dart (+.g.dart)
      seed_metadata_dao.dart (+.g.dart)         # NEW
  user/
    user_database.dart
    user_database.g.dart
    daos/
      active_curriculum_dao.dart (+.g.dart)
      bookmark_dao.dart (+.g.dart)
      completion_dao.dart (+.g.dart)
      curriculum_scope_dao.dart (+.g.dart)
      goal_dao.dart (+.g.dart)
      learning_ledger_dao.dart (+.g.dart)
      learning_order_dao.dart (+.g.dart)
      point_config_dao.dart (+.g.dart)
      profile_dao.dart (+.g.dart)
      profile_program_dao.dart (+.g.dart)
      reward_dao.dart (+.g.dart)
      reward_pool_dao.dart (+.g.dart)
      stage_dao.dart (+.g.dart)
      streak_dao.dart (+.g.dart)
      study_day_config_dao.dart (+.g.dart)
      sync_queue_dao.dart (+.g.dart)
      test_download_status_dao.dart (+.g.dart)
      test_score_dao.dart (+.g.dart)
      track_dao.dart (+.g.dart)
      user_profile_dao.dart (+.g.dart)
  tables/                    # SHARED — unchanged location
    (all .dart table definitions)
  seed/                      # SHARED
    learning_program_seeds.dart
    test_date_seeds.dart
```

## Acceptance Tests

### AT-1: ContentDatabase creates with correct schema (AC: 1)
```
Given a fresh in-memory ContentDatabase
When opened via createTestContentDatabase()
Then it has 4 tables: text_cache, calendar_cycles, learning_programs, seed_metadata
And learning_programs can be queried (returns 9 seeded programs)
And no write operations are exposed on Content DAOs
```

### AT-2: UserDatabase creates with correct schema (AC: 2)
```
Given a fresh in-memory UserDatabase
When opened via createTestUserDatabase()
Then it has 20 tables matching the @DriftDatabase annotation
And a profile can be inserted and read back
And a completion can be inserted and read back
And schemaVersion is 1
```

### AT-3: CalendarCache and ContentDownloadStatuses are gone (AC: 3)
```
Given the codebase after the split
When searching for CalendarCache references
Then no Dart file imports calendar_cache.dart
And no DAO file references CalendarCacheDao
When searching for ContentDownloadStatuses references
Then no Dart file imports content_download_statuses.dart
And no DAO file references ContentDownloadStatusDao
```

### AT-4: No file references AppDatabase (AC: 8)
```
Given the codebase after the split
When grepping for 'AppDatabase' across all .dart files
Then zero matches are found (excluding .g.dart cache files if any)
When grepping for 'appDatabaseProvider' across all .dart files
Then zero matches are found
```

### AT-5: Provider wiring works end-to-end (AC: 4, 6)
```
Given a ProviderContainer with both database overrides
When reading a LearningProgram from contentDatabaseProvider
Then the program data is returned correctly
When inserting a completion via userDatabaseProvider
Then the completion persists and can be queried back
When a service reads from ContentDB and writes to UserDB (cross-DB flow)
Then no errors occur and data flows correctly
```

### AT-6: All existing story tests pass (AC: 7)
```
Given the full test suite
When running `make ci`
Then all story acceptance tests pass
And dart analyze reports zero issues
And dart format reports zero changes needed
```

### AT-7: Code generation succeeds cleanly (AC: 5, 8)
```
Given the split codebase
When running `dart run build_runner build --delete-conflicting-outputs`
Then no errors are reported
And content_database.g.dart is generated
And user_database.g.dart is generated
And no app_database.g.dart exists
```

## Technical Notes

### Execution Order

Phases must be executed in order (1 through 7). Within each phase, subtasks can be parallelized where noted. The recommended approach is big-bang split since the app has NOT been deployed to production — there is no installed base requiring incremental migration.

### Migration Strategy — Fresh Start at v1

Both new databases start at `schemaVersion => 1`. The 23-version migration history in the current `AppDatabase` is discarded. This is safe because:
- The app has not shipped to production yet
- No real user data exists that needs migration
- A clean schema is simpler to maintain going forward

### ContentDatabase Is Never Migrated

The ContentDatabase is replaced wholesale via `content.db.gz` in app assets. Drift's `schemaVersion` is set to 1 but `onCreate`/`onUpgrade` are never invoked in production — the pre-built file already has all tables and data. In tests, `NativeDatabase.memory()` triggers `onCreate` which calls `m.createAll()`.

### TestDates Table Placement

The architecture doc has a minor inconsistency: Section 1.2 says "TestDates stays in User DB" but Appendix B lists `TestDateDao` under Content DB as read-only. Follow the Appendix B guidance: `TestDates` goes to **ContentDatabase** (since test dates are pre-seeded reference data, not user-generated). `TestScores` stays in **UserDatabase** (user-generated data).

### Cross-Database Integer FK Safety

`ProfilePrograms.programId` references `LearningPrograms.id` across DB boundaries. The IDs are stable because seed data is inserted in the same order every time. If this proves fragile, add a `programName` text column to `ProfilePrograms` as the stable cross-DB join key.

### Estimated Scope

| Category | Count |
|----------|-------|
| New files created | ~8 (2 database classes, 2 new tables, 2 new DAOs, 1 opener, updated provider) |
| DAO files moved + modified | ~22 |
| Deleted files | ~8 (AppDatabase x2, CalendarCacheDao x2, ContentDownloadStatusDao x2, 2 old table files) |
| Provider files updated | ~46 |
| Test files updated | ~37 |
| **Total files touched** | **~94** |

### Estimated Time: ~13 hours

| Phase | Hours |
|-------|-------|
| Phase 1: ContentDatabase + new tables | 2 |
| Phase 2: UserDatabase | 1 |
| Phase 3: Split DAOs | 3 |
| Phase 4: Update providers | 3 |
| Phase 5: Update repositories/services | 1 |
| Phase 6: Update tests | 2.5 |
| Phase 7: Remove old files + final verification | 0.5 |

### Gap Analysis Additions (2026-03-31)

#### Content DB Runtime Upgrade Flow (scoped into this story)

The `content_database_opener.dart` must include SeedManager logic:
1. On startup, check if `content.db` exists → if not, extract from `assets/db/content.db.gz`
2. If exists, read `SeedMetadata.version` and compare to `BUNDLED_SEED_VERSION` constant
3. If bundled > installed: close connection → rename to `.bak` → decompress new → verify → delete `.bak`
4. Key guarantee: deleting `content.db` can never lose user data (separate DB files)

#### Stale Cross-DB Reference Handling

Since Content DB and User DB have no hard foreign keys, repositories doing cross-DB lookups must handle missing refs:
- Completions referencing `sefariaRef` → TextCache: graceful null display ("Content unavailable")
- Bookmarks referencing `sefariaRef` → TextCache: skip missing refs in UI
- LearningOrder referencing `sefariaRef` → TextCache: filter out missing refs
- ProfilePrograms referencing `programId` → LearningPrograms: programs are stable, low risk

All content lookups should return nullable or use a `ContentResult<T>` wrapper. This is further elaborated in story 19.12 (DNI-209).

### References

- Design doc: `docs/planning/two-database-drift-architecture.md`
- Offline-first architecture v2: `docs/planning/architecture-offline-v2.md`
- Current DB: `learning_tracker/lib/core/database/app_database.dart`
- Current provider: `learning_tracker/lib/core/providers/database_provider.dart`
- Test helper: `learning_tracker/test/helpers/test_database.dart`

## Dev Agent Record

### Agent Model Used

_Retroactively reconciled 2026-07-13 (AUD-docs-06) — this record was never backfilled at implementation time; sprint-status.yaml already showed `done` while this header still read the template default. No contemporaneous dev-agent record exists for the original implementation._

### Debug Log References

### Completion Notes List

- Re-verified 2026-07-13 against the live tree: the two-database split is shipped. `UserDatabase` (`lib/core/database/user/user_database.dart`, per-account, read-write) and `ContentDatabase` (`lib/core/database/content/content_database.dart`, read-only, bundled+extracted) are both live, distinct `@DriftDatabase` classes.
- Acceptance coverage: `test/story_acceptance/epic_19_offline_first_test.dart`, group `Story 19.2 — Two-Database Split`, 0 `skip:` markers.
- Status header + sprint-status.yaml were inconsistent (header said `ready-for-dev`, tracker said `done`) — header corrected to match verified reality, not the other way around.

### File List

- `learning_tracker/lib/core/database/user/user_database.dart`
- `learning_tracker/lib/core/database/content/content_database.dart`
- `learning_tracker/test/story_acceptance/epic_19_offline_first_test.dart`
