# Story 15.1 -- Multi-Profile Data Model & Migration (DNI-109)

## Story Overview

Currently the app is single-user: all local data (completions, bookmarks, stages, goals, rewards, streaks, tracks, learning order, point configs, active curricula) is implicitly owned by whichever Firebase user is signed in. The `user_profiles` table stores one row per Firebase UID with `display_name` and `user_mode`.

This story introduces a **profiles** layer between the Firebase account and all data tables. One Firebase account can own up to 10 learner profiles (e.g., a parent plus multiple children). Every data table that currently holds user-scoped data gains a `profile_id` foreign key. A Drift schema migration (v9 -> v10) auto-creates a default profile for each existing `user_profiles` row and backfills `profile_id` across all affected tables.

---

## Acceptance Criteria

- [ ] A new `profiles` Drift table exists with columns: `id` (text, UUID primary key), `account_id` (text, Firebase UID), `display_name` (text), `mode` (text, "child" or "adult"), `avatar_index` (integer, default 0), `is_default` (boolean), `created_at` (DateTime), `updated_at` (DateTime)
- [ ] A `profile_id` (text) foreign-key column is added to: `completions`, `bookmarks`, `stage_definitions`, `goals`, `rewards`, `active_curricula`, `curriculum_tracks`, `learning_order`, `point_configs`, `streaks`
- [ ] Schema migration v9 -> v10 runs without data loss: creates the `profiles` table, adds `profile_id` columns, generates a default profile per existing `user_profiles` row, backfills all existing data rows with that default profile's UUID
- [ ] A `ProfileRepository` provides CRUD: create, read (by id, by account), update, delete (with cascade), list by account
- [ ] Creating an 11th profile for the same account throws / returns an error (max 10 enforced at repository level)
- [ ] Deleting a profile cascades: all rows in completions, bookmarks, stage_definitions, goals, rewards, active_curricula, curriculum_tracks, learning_order, point_configs, streaks that reference the deleted `profile_id` are removed
- [ ] A Freezed `ProfileModel` domain model exists with a `fromDriftRow` factory
- [ ] The existing `UserProfiles` table and `UserProfileDao` continue to work (they represent account-level data, not per-profile data); the new `Profiles` table is a child of `UserProfiles`
- [ ] Unit tests cover: profile CRUD, max-10 enforcement, cascade delete, migration from v9 to v10

---

## Architecture & Design Notes

### Entity Relationship

```
FirebaseAuth User (UID)
  |
  v
UserProfiles (account-level, 1 row per UID)  -- existing table, unchanged
  |
  v
Profiles (1..10 per account)                  -- NEW table
  |
  v
Completions, Bookmarks, StageDefinitions,     -- existing tables gain profile_id FK
Goals, Rewards, ActiveCurricula,
CurriculumTracks, LearningOrder,
PointConfigs, Streaks
```

### Profile ID Format

Use UUID v4 (via the `uuid` package, already likely available or trivially added). Text column, not autoincrement integer, to avoid collisions during cross-device sync. The UUID is generated client-side at profile creation time.

### Tables That Get `profile_id`

| Table | Current PK | Notes |
|-------|-----------|-------|
| `completions` | autoincrement int | Append-only; add `profile_id` text NOT NULL |
| `bookmarks` | autoincrement int; unique on (curriculumId, trackType) | Unique key becomes (profile_id, curriculumId, trackType) |
| `stage_definitions` | autoincrement int; unique on (curriculumId, stageOrder) | Unique key becomes (profile_id, curriculumId, stageOrder) |
| `goals` | autoincrement int | Add `profile_id` text NOT NULL |
| `rewards` | autoincrement int | Add `profile_id` text NOT NULL |
| `active_curricula` | PK on (curriculumId) | PK becomes (profile_id, curriculumId) |
| `curriculum_tracks` | PK on (curriculumId, trackType) | PK becomes (profile_id, curriculumId, trackType) |
| `learning_order` | autoincrement int; unique on (curriculumId, sefariaRef) | Unique key becomes (profile_id, curriculumId, sefariaRef) |
| `point_configs` | autoincrement int; unique on (curriculumId, stageOrder) | Unique key becomes (profile_id, curriculumId, stageOrder) |
| `streaks` | autoincrement int (single-row) | Becomes single-row per profile |

### Tables NOT Getting `profile_id`

| Table | Reason |
|-------|--------|
| `user_profiles` | Account-level table; parent of profiles |
| `sync_queue` | Operations are account-scoped (the payload already contains context) |
| `text_cache` | Shared content cache, not user-specific |
| `text_download_statuses` | Shared download state, not user-specific |

### Migration Strategy (v9 -> v10)

The migration must handle existing users who already have data without a profile_id. The approach:

1. **Create** the `profiles` table
2. **For each row in `user_profiles`**, generate a UUID and insert a default profile: `(id=UUID, account_id=firebaseUid, display_name=displayName, mode=userMode, avatar_index=0, is_default=true, created_at=now, updated_at=now)`
3. **For each data table**, use `ALTER TABLE ... ADD COLUMN profile_id TEXT` with a temporary default, then backfill using the default profile UUID
4. Since SQLite does not support `ALTER TABLE ... ADD CONSTRAINT`, unique key changes require the **12-step rename pattern**: create new table with correct schema, copy data, drop old table, rename new table. This applies to: `bookmarks`, `stage_definitions`, `active_curricula`, `curriculum_tracks`, `learning_order`, `point_configs`
5. Tables that only need a new non-unique column (`completions`, `goals`, `rewards`, `streaks`) can use simple `ALTER TABLE ADD COLUMN` + `UPDATE SET`

**Critical safety note**: The migration must run inside a single transaction. If any step fails, the entire migration rolls back and the user stays on v9.

### Default Profile Assignment During Migration

Since the app was single-user, during migration there is at most one `user_profiles` row. However, if there are zero rows (the user has not completed onboarding), the migration still succeeds -- the data tables are simply empty, so the ALTER + backfill is a no-op.

If somehow there are multiple `user_profiles` rows, each gets its own default profile, and data rows are assigned to the first (lowest-id) profile. In practice this should not occur.

---

## Implementation Steps

### Step 1: Add `uuid` dependency

**File**: `pubspec.yaml`

Add `uuid: ^4.0.0` (or latest) to dependencies if not already present.

### Step 2: Create the `Profiles` Drift table

**File (create)**: `lib/core/database/tables/profiles.dart`

```dart
import 'package:drift/drift.dart';

/// Learner profiles -- up to 10 per Firebase account.
///
/// Each profile has its own completions, bookmarks, stages, goals, etc.
/// One profile per account is marked is_default = true.
class Profiles extends Table {
  /// UUID v4 primary key (text, not autoincrement)
  TextColumn get id => text()();

  /// Firebase UID of the owning account
  TextColumn get accountId => text()();

  TextColumn get displayName => text()();

  /// 'child' or 'adult' -- matches UserMode enum
  TextColumn get mode => text()();

  /// Index into a predefined avatar list (0-based)
  IntColumn get avatarIndex => integer().withDefault(const Constant(0))();

  /// Whether this is the default profile for the account
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

### Step 3: Add `profile_id` to all affected tables

Modify the following existing table files to add a `profile_id` text column:

**Files to modify**:
- `lib/core/database/tables/completions.dart` -- add `TextColumn get profileId => text()()`
- `lib/core/database/tables/bookmarks.dart` -- add `profileId`, update `uniqueKeys` to `{profileId, curriculumId, trackType}`
- `lib/core/database/tables/stage_definitions.dart` -- add `profileId`, update `uniqueKeys` to `{profileId, curriculumId, stageOrder}`
- `lib/core/database/tables/goals.dart` -- add `profileId`
- `lib/core/database/tables/rewards.dart` -- add `profileId`
- `lib/core/database/tables/active_curricula.dart` -- add `profileId`, update `primaryKey` to `{profileId, curriculumId}`
- `lib/core/database/tables/curriculum_tracks.dart` -- add `profileId`, update `primaryKey` to `{profileId, curriculumId, trackType}`
- `lib/core/database/tables/learning_order.dart` -- add `profileId`, update `uniqueKeys` to `{profileId, curriculumId, sefariaRef}`
- `lib/core/database/tables/point_configs.dart` -- add `profileId`, update `uniqueKeys` to `{profileId, curriculumId, stageOrder}`
- `lib/core/database/tables/streaks.dart` -- add `profileId`

### Step 4: Register the new table in AppDatabase

**File**: `lib/core/database/app_database.dart`

- Import `tables/profiles.dart`
- Add `Profiles` to the `tables:` list in `@DriftDatabase`
- Add `ProfileDao` to the `daos:` list (created in Step 6)
- Bump `schemaVersion` from `9` to `10`
- Add migration block for `from < 10`

### Step 5: Write the migration (v9 -> v10)

**File**: `lib/core/database/app_database.dart` (inside `onUpgrade`)

The migration block (`if (from < 10)`) must:

1. Create `profiles` table via `m.createTable($ProfilesTable(attachedDatabase))`
2. Query existing `user_profiles` rows
3. For each row, `INSERT INTO profiles (id, account_id, display_name, mode, avatar_index, is_default, created_at, updated_at)` with a generated UUID
4. For simple tables (completions, goals, rewards, streaks): `ALTER TABLE <table> ADD COLUMN profile_id TEXT NOT NULL DEFAULT '<default_uuid>'`, then `UPDATE <table> SET profile_id = '<uuid>'` to ensure correctness, then remove the default (SQLite keeps it but that is acceptable)
5. For tables with composite PK/unique key changes (bookmarks, stage_definitions, active_curricula, curriculum_tracks, learning_order, point_configs): use the 12-step SQLite migration pattern
6. Wrap everything in the migration transaction (Drift does this automatically for `onUpgrade`)

**Important**: Since `ALTER TABLE ADD COLUMN ... NOT NULL` requires a DEFAULT in SQLite, use a placeholder default during migration. After backfilling, all rows will have the correct `profile_id`. New inserts post-migration will always supply `profile_id` explicitly.

**Alternative (simpler)**: If the data volume is small (which it is for a mobile app), use the 12-step pattern for ALL tables. This is safer and avoids DEFAULT workarounds.

### Step 6: Create `ProfileDao`

**File (create)**: `lib/core/database/daos/profile_dao.dart`

```dart
@DriftAccessor(tables: [Profiles])
class ProfileDao extends DatabaseAccessor<AppDatabase> with _$ProfileDaoMixin {
  // getProfileById(String id)
  // getProfilesByAccountId(String accountId)
  // getDefaultProfile(String accountId)
  // insertProfile(ProfilesCompanion entry)
  // updateProfile(ProfilesCompanion entry)
  // deleteProfile(String id) -- raw delete, cascade handled by repository
  // countProfilesForAccount(String accountId)
  // watchProfilesByAccountId(String accountId)
}
```

### Step 7: Create `ProfileModel` (Freezed)

**File (create)**: `lib/features/profiles/domain/models/profile_model.dart`

Follow the pattern from `lib/features/gamification/domain/models/reward_model.dart`:

```dart
@freezed
abstract class ProfileModel with _$ProfileModel {
  const factory ProfileModel({
    required String id,
    required String accountId,
    required String displayName,
    required UserMode mode,
    required int avatarIndex,
    required bool isDefault,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) = _ProfileModel;

  factory ProfileModel.fromDriftRow(Profile row) => ProfileModel(
    id: row.id,
    accountId: row.accountId,
    displayName: row.displayName,
    mode: UserMode.values.byName(row.mode),
    avatarIndex: row.avatarIndex,
    isDefault: row.isDefault,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}
```

### Step 8: Create `ProfileRepository`

**File (create)**: `lib/features/profiles/domain/repositories/profile_repository.dart` (abstract interface)
**File (create)**: `lib/features/profiles/data/repositories/profile_repository_impl.dart`

The repository encapsulates:
- **create**: Validate count < 10, generate UUID, insert via DAO, return `ProfileModel`
- **getById**: Delegate to DAO, map to `ProfileModel`
- **getByAccountId**: Return `List<ProfileModel>` for the account
- **getDefault**: Return the default profile for an account
- **update**: Update display_name, mode, avatar_index, updated_at
- **delete**: In a transaction, delete all data for the profile across ALL tables (completions, bookmarks, etc.), then delete the profile row itself. If deleting the default profile and other profiles exist, promote another to default.
- **setDefault**: Unset current default, set new default (within transaction)

### Step 9: Create Riverpod providers for profiles

**File (create)**: `lib/features/profiles/presentation/providers/profile_providers.dart`

- `profileRepositoryProvider` -- provides the `ProfileRepository`
- `profilesProvider(accountId)` -- `FutureProvider.family` listing profiles for an account
- `activeProfileProvider` -- holds the currently selected profile (global state)
- `profileDaoProvider` -- provides the `ProfileDao`

### Step 10: Update all existing DAOs to accept `profileId`

Every DAO method that reads or writes user-scoped data must filter by `profile_id`. This is a large but mechanical change.

**Files to modify** (non-exhaustive, every method in each DAO):
- `lib/core/database/daos/completion_dao.dart` -- all query methods add `.where(profileId.equals(...))`; `insertCompletion` requires `profileId` in companion
- `lib/core/database/daos/bookmark_dao.dart` -- same pattern
- `lib/core/database/daos/stage_dao.dart` -- same pattern
- `lib/core/database/daos/goal_dao.dart` -- same pattern
- `lib/core/database/daos/reward_dao.dart` -- same pattern
- `lib/core/database/daos/active_curriculum_dao.dart` -- same pattern
- `lib/core/database/daos/track_dao.dart` -- same pattern
- `lib/core/database/daos/learning_order_dao.dart` -- same pattern
- `lib/core/database/daos/point_config_dao.dart` -- same pattern
- `lib/core/database/daos/streak_dao.dart` -- same pattern

**Note**: This step has the widest blast radius. Every call site that invokes a DAO method must now pass `profileId`. Consider a phased approach: first add `profileId` as a required parameter to DAO methods, then fix all call sites via compile errors.

### Step 11: Update `AccountManagementService._clearLocalDatabase`

**File**: `lib/features/settings/domain/services/account_management_service.dart`

Add `await _database.delete(_database.profiles).go()` to the clear list, after deleting dependent tables and before deleting `userProfiles`.

### Step 12: Run code generation

```bash
dart run build_runner build --delete-conflicting-outputs
```

This regenerates `.g.dart` and `.freezed.dart` files for all modified tables, DAOs, and models.

---

## Dev Notes

### Gotchas

1. **SQLite ALTER TABLE limitations**: SQLite cannot add a NOT NULL column without a default, cannot drop a column's default after adding it, and cannot modify primary keys or unique constraints in place. The 12-step rename-and-copy pattern is mandatory for tables whose PK or unique keys change.

2. **UUID generation during migration**: The migration runs in raw SQL. You cannot use Dart's `uuid` package inside `customStatement()`. Instead, generate the UUID in Dart, then interpolate it into the SQL strings. Be careful with SQL injection -- UUIDs are safe but always use parameterized queries where possible.

3. **Completions are append-only**: The `CompletionDao` intentionally has no UPDATE or DELETE. Profile cascade delete is the one exception -- it must delete completions for a deleted profile. Implement this in the `ProfileRepository` using raw `customStatement` or a dedicated `deleteCompletionsForProfile` method on `CompletionDao`.

4. **ActiveCurricula PK change**: Currently PK is `{curriculumId}`. After migration it is `{profileId, curriculumId}`. This means two profiles can independently activate the same curriculum. This is correct behavior.

5. **Streaks single-row assumption**: Currently `StreakDao.getStreak()` does `limit(1)`. After this change, there is one streak row per profile. All streak queries must filter by `profile_id`.

6. **SyncQueue payloads**: The sync queue stores JSON payloads. After this migration, payloads should include `profile_id`. However, existing queued operations from before the migration will not have it. The sync engine should handle missing `profile_id` by assuming the default profile. This is a concern for a future sync story (not 15.1), but worth noting.

7. **Bookmark unique key**: The current unique key is `(curriculumId, trackType)`. After adding `profileId`, it becomes `(profileId, curriculumId, trackType)`. The `getBookmarkByCurriculumAndTrack` method must also filter by `profileId`.

8. **Empty database migration**: If the user installs fresh (no existing data), `onCreate` creates all tables with the new schema including `profile_id` columns. No migration code runs. Make sure `m.createAll()` produces the correct v10 schema.

### Edge Cases

- **Zero user_profiles rows at migration time**: Migration creates `profiles` table but inserts nothing. Data tables get the column added but no rows need backfilling. This is fine.
- **User with data but no user_profiles row**: Theoretically possible if the user completed onboarding partially. The migration should create a fallback profile with `account_id = 'unknown'` and `is_default = true`, then assign all existing data to it. On next sign-in, the profile's `account_id` can be updated.
- **Concurrent database access during migration**: Drift serializes database access, so this is not a concern.

---

## Test Plan

### Unit Tests

**File (create)**: `test/core/database/daos/profile_dao_test.dart`

- Insert a profile, read it back, verify all fields
- Insert 10 profiles for same account, verify count
- Delete a profile, verify it is gone
- Watch profiles stream emits correct values
- Get default profile returns the one with `is_default = true`

**File (create)**: `test/features/profiles/data/repositories/profile_repository_impl_test.dart`

- Create profile succeeds and returns `ProfileModel`
- Create 11th profile throws/returns error (max 10)
- Delete profile cascades: insert profile + completions + bookmarks + goals + rewards + stages + etc., delete profile, verify all related rows gone
- Delete default profile promotes another to default (if others exist)
- Delete last profile for account removes all data
- Update profile changes display_name, mode, avatar_index
- setDefault swaps the is_default flag between profiles

### Migration Tests

**File (create)**: `test/core/database/migration_v10_test.dart`

- Start with v9 schema (in-memory), insert sample data (user_profiles row, completions, bookmarks, etc.), run migration to v10, verify:
  - `profiles` table exists with one row (default profile)
  - All completions have `profile_id` matching the default profile UUID
  - All bookmarks have correct `profile_id` and unique key still works
  - All other tables similarly backfilled
  - New unique constraints are enforced (e.g., two rows with same `(profileId, curriculumId, trackType)` in bookmarks are rejected)
- Migration on empty database (no user_profiles rows) completes without error
- Fresh `onCreate` produces same schema as migrated v10

### Story Acceptance Tests

**File (create or modify)**: `test/story_acceptance/epic_15_multi_profile_test.dart`

```
group('Story 15.1: Multi-Profile Data Model & Migration', tags: ['story_15_1']) {
  - 'profiles table exists with correct schema'
  - 'profile_id column exists on all data tables'
  - 'max 10 profiles per account enforced'
  - 'cascade delete removes all associated data'
  - 'migration creates default profile for existing user'
  - 'migration backfills profile_id on existing data'
}
```

Add to `Makefile`:
```makefile
test-story-15.1: ## Run Story 15.1 acceptance tests
	flutter test test/story_acceptance/epic_15_multi_profile_test.dart --name "Story 15.1"

test-epic-15: ## Run all Epic 15 acceptance tests
	flutter test test/story_acceptance/epic_15_multi_profile_test.dart
```

---

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `lib/core/database/tables/profiles.dart` | New Drift table definition |
| `lib/core/database/daos/profile_dao.dart` | DAO for profiles CRUD |
| `lib/features/profiles/domain/models/profile_model.dart` | Freezed domain model |
| `lib/features/profiles/domain/repositories/profile_repository.dart` | Abstract repository interface |
| `lib/features/profiles/data/repositories/profile_repository_impl.dart` | Repository implementation with cascade delete + max-10 |
| `lib/features/profiles/presentation/providers/profile_providers.dart` | Riverpod providers |
| `test/core/database/daos/profile_dao_test.dart` | DAO unit tests |
| `test/features/profiles/data/repositories/profile_repository_impl_test.dart` | Repository unit tests |
| `test/core/database/migration_v10_test.dart` | Migration tests |
| `test/story_acceptance/epic_15_multi_profile_test.dart` | Story acceptance tests |

### Modified Files

| File | Change |
|------|--------|
| `pubspec.yaml` | Add `uuid` dependency |
| `lib/core/database/app_database.dart` | Import Profiles table + ProfileDao, add to @DriftDatabase, bump schemaVersion to 10, add migration block |
| `lib/core/database/tables/completions.dart` | Add `profileId` column |
| `lib/core/database/tables/bookmarks.dart` | Add `profileId` column, update uniqueKeys |
| `lib/core/database/tables/stage_definitions.dart` | Add `profileId` column, update uniqueKeys |
| `lib/core/database/tables/goals.dart` | Add `profileId` column |
| `lib/core/database/tables/rewards.dart` | Add `profileId` column |
| `lib/core/database/tables/active_curricula.dart` | Add `profileId` column, update primaryKey |
| `lib/core/database/tables/curriculum_tracks.dart` | Add `profileId` column, update primaryKey |
| `lib/core/database/tables/learning_order.dart` | Add `profileId` column, update uniqueKeys |
| `lib/core/database/tables/point_configs.dart` | Add `profileId` column, update uniqueKeys |
| `lib/core/database/tables/streaks.dart` | Add `profileId` column |
| `lib/core/database/daos/completion_dao.dart` | Filter all queries by profileId, require profileId in insert |
| `lib/core/database/daos/bookmark_dao.dart` | Filter all queries by profileId |
| `lib/core/database/daos/stage_dao.dart` | Filter all queries by profileId |
| `lib/core/database/daos/goal_dao.dart` | Filter all queries by profileId |
| `lib/core/database/daos/reward_dao.dart` | Filter all queries by profileId |
| `lib/core/database/daos/active_curriculum_dao.dart` | Filter all queries by profileId |
| `lib/core/database/daos/track_dao.dart` | Filter all queries by profileId |
| `lib/core/database/daos/learning_order_dao.dart` | Filter all queries by profileId |
| `lib/core/database/daos/point_config_dao.dart` | Filter all queries by profileId |
| `lib/core/database/daos/streak_dao.dart` | Filter all queries by profileId |
| `lib/features/settings/domain/services/account_management_service.dart` | Add profiles table to `_clearLocalDatabase` |
| `Makefile` | Add `test-story-15.1` and `test-epic-15` targets |
| `test/helpers/test_database.dart` | No changes needed (in-memory DB auto-creates all tables) |

### Files That Need Call-Site Updates (Downstream)

Every file that calls a DAO method on the affected DAOs will need to pass `profileId`. These are not modified in this story but will produce **compile errors** that serve as a checklist. Major call sites include:

- All repository implementations under `lib/features/*/data/repositories/`
- `lib/features/sync/data/sync_engine.dart` and `lib/features/sync/data/firestore_data_source.dart`
- `lib/features/settings/domain/services/curriculum_activation_service.dart`
- `lib/core/services/track_service.dart`, `daily_schedule_composer.dart`, `cross_curriculum_aggregator.dart`, `duplicate_prevention_service.dart`

**Strategy**: Add `profileId` as a required parameter to all DAO methods. Let the compiler surface every call site. Fix them by threading the active profile's ID through from the provider layer.
