> **ARCHIVED 2026-08-13 — superseded.** Superseded by `docs/firestore-rewrite-map.md`. Retained for history only; do not treat as current. See `docs/planning/firestore-finish-line-plan.md` for the live plan.

# Two-Database Drift Architecture — Detailed Technical Design

**Date:** 2026-03-29
**Status:** Canonical blueprint (shipped as designed; see note below)
**Relates to:** [architecture-offline-v2.md](architecture-offline-v2.md), §5 (Inherited Unchanged)

> ⚠️ **Evolution note — 2026-04-19.** The two-database split was shipped as designed in this document (Epic 19, completed March 2026). A **third database** — `DeviceRegistryDatabase` (Epic 21, 2 tables, schema v1) — was added later to track multiple accounts per device. The **User DB schema has since evolved from v1 (at time of this spec) to v4**: v2→v3 Epic 23 hard-tier auth refactor (added `email`, `passwordHash`, `tier` columns; dropped `localUid`, `hasAccount`); v3→v4 added append-only `StreakEvents` and `XpEvents` tables. Table counts in §2.2 are accurate to the time of writing but the User DB now contains 23 tables, not 20. Treat this doc as the canonical reference for the split design; for current schema details, see [`architecture-offline-v2.md`](architecture-offline-v2.md) and [`../data-models.md`](../data-models.md).

---

## Table of Contents

1. [ContentDatabase Class Design](#1-contentdatabase-class-design)
2. [UserDatabase Class Design](#2-userdatabase-class-design)
3. [Drift Code Generation Considerations](#3-drift-code-generation-considerations)
4. [Provider Architecture](#4-provider-architecture)
5. [DAO Reorganization](#5-dao-reorganization)
6. [Testing Strategy](#6-testing-strategy)
7. [File Organization](#7-file-organization)
8. [Migration Path from Current Codebase](#8-migration-path-from-current-codebase)

---

## 1. ContentDatabase Class Design

### 1.1 Purpose

The ContentDatabase holds **immutable reference data** that ships with the app and is replaced wholesale on app updates. It is never written to by application code at runtime. It contains text content, calendar cycles, program definitions, test dates, and seed metadata.

### 1.2 Tables (5 total)

| Table | Status | Notes |
|-------|--------|-------|
| `TextCache` | **Existing** — move from AppDatabase | 52K+ rows of Sefaria text. No schema changes needed. |
| `CalendarCycles` | **New** | Pre-computed calendar program cycles (replaces live API calls) |
| `LearningPrograms` | **Existing** — move from AppDatabase | 9 program presets. No schema changes needed. |
| `SeedMetadata` | **New** | Version tracking for the seed database file |

**Note:** `TestDates` stays in User DB — Dirshu test reminders are a separate feature to be scoped in its own ticket.

### 1.3 New Table Schemas

#### CalendarCycles

Replaces the runtime `CalendarCache` table (which cached live API responses). This table is pre-computed at build time with all 12 calendar program cycles.

```dart
/// Pre-computed calendar program cycles for fully offline operation.
/// Each row maps a date to a Sefaria ref for one calendar program.
class CalendarCycles extends Table {
  /// API program key matching LearningPrograms.apiProgramKey
  /// e.g., 'Daf Yomi', 'Mishnah Yomit', 'Nach Yomi'
  TextColumn get programKey => text()();

  /// Date in 'YYYY-MM-DD' format (ISO 8601)
  TextColumn get dateKey => text()();

  /// Sefaria ref for this program on this date
  /// e.g., 'Berakhot 2a', 'Mishnah Berakhot 1.1'
  TextColumn get sefariaRef => text()();

  /// Human-readable display name (localized)
  TextColumn get displayName => text().withDefault(const Constant(''))();

  @override
  Set<Column> get primaryKey => {programKey, dateKey};
}
```

**Design rationale:** Flat table with composite PK is the simplest query pattern. A lookup is `WHERE programKey = ? AND dateKey = ?`. No joins needed. The old `CalendarCache` table (id, source, dateKey, responseJson, fetchedAt) stored raw API JSON; this table stores parsed, normalized data.

**Data volume:** ~12 programs x 365 days x 7 years (2024-2030) = ~30,684 rows. Trivial.

#### SeedMetadata

Tracks which version of the seed database is installed, enabling the app to detect whether a replacement is needed on update.

```dart
/// Metadata about the seed database itself.
/// Single-row table (one entry per seed build).
class SeedMetadata extends Table {
  /// Monotonically increasing version number set at build time
  IntColumn get version => integer()();

  /// ISO 8601 timestamp of when the seed DB was built
  TextColumn get builtAt => text()();

  /// Git SHA or build identifier of the content pipeline run
  TextColumn get buildId => text()();

  /// Number of TextCache rows in this seed
  IntColumn get textCacheCount => integer()();

  /// Number of CalendarCycles rows in this seed
  IntColumn get calendarCycleCount => integer()();

  @override
  Set<Column> get primaryKey => {version};
}
```

### 1.4 Schema Version and Migration Strategy

**The ContentDatabase has `schemaVersion = 1` but never runs migrations.**

Rationale: This database is replaced wholesale. The app ships a pre-built `content.db.gz` in assets. On first launch (or after app update), the file is decompressed into the app's database directory. If the file already exists and its `SeedMetadata.version` matches the bundled version, no replacement occurs.

```dart
@DriftDatabase(
  tables: [TextCache, CalendarCycles, LearningPrograms, SeedMetadata],
  daos: [TextCacheDao, CalendarCycleDao, LearningProgramDao, TestDateDao, SeedMetadataDao],
)
class ContentDatabase extends _$ContentDatabase {
  ContentDatabase(super.e);

  @override
  int get schemaVersion => 1;

  // No migration strategy needed — DB is replaced, not migrated.
  // Drift requires schemaVersion but will call onCreate on a fresh file.
  // Since we copy a pre-built file, onCreate is never actually invoked.
}
```

### 1.5 Opening Read-Only in Drift

Drift's `NativeDatabase` supports a `setup` callback that runs raw SQL on the underlying `sqlite3` database connection before Drift uses it. However, SQLite's `PRAGMA query_only = ON` prevents all writes including Drift's internal schema version check.

**Recommended approach: Do NOT use `query_only` pragma.** Instead, enforce read-only at the application layer:

1. The `ContentDatabase` class only exposes read DAOs (no insert/update/delete methods).
2. The DAO methods only contain `select` and `watch` operations.
3. The database file's filesystem permissions are not changed (Drift needs to open it r/w for its internal housekeeping).

**Opening the pre-built file:**

```dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io' show gzip;

/// Opens the ContentDatabase from the pre-built seed file.
/// If the seed file doesn't exist or is outdated, extracts it from assets.
Future<ContentDatabase> openContentDatabase() async {
  final dbDir = await getApplicationDocumentsDirectory();
  final dbPath = '${dbDir.path}/content.db';
  final dbFile = File(dbPath);

  // Check if we need to extract the seed
  if (!dbFile.existsSync()) {
    await _extractSeedDb(dbPath);
  }
  // Version check happens after opening (compare SeedMetadata.version
  // against bundled version constant)

  return ContentDatabase(
    NativeDatabase(dbFile),
  );
}

Future<void> _extractSeedDb(String targetPath) async {
  final compressed = await rootBundle.load('assets/db/content.db.gz');
  final decompressed = gzip.decode(compressed.buffer.asUint8List());
  await File(targetPath).writeAsBytes(decompressed);
}
```

### 1.6 Tables Removed from Content DB vs Current AppDatabase

The existing `CalendarCache` table is **dropped entirely** — it stored raw API JSON responses and is replaced by the pre-computed `CalendarCycles` table. The `CalendarCacheDao` is also removed.

The `ContentDownloadStatuses` and `TextDownloadStatuses` tables stay in the **UserDatabase** because they track user-initiated download progress (even though they relate to content, they are mutable state).

---

## 2. UserDatabase Class Design

### 2.1 Purpose

The UserDatabase holds **all mutable user data** — profiles, progress, configuration, and sync state. It is the only database that accepts writes at runtime. It uses standard Drift migrations.

### 2.2 Tables (20 total)

| # | Table | Category |
|---|-------|----------|
| 1 | `UserProfiles` | Account |
| 2 | `Profiles` | Account |
| 3 | `ActiveCurricula` | Curriculum config |
| 4 | `CurriculumTracks` | Curriculum config |
| 5 | `CurriculumScopes` | Curriculum config |
| 6 | `ProfilePrograms` | Curriculum config |
| 7 | `StageDefinitions` | Per-profile config (seeded from LearningPrograms.stagesConfig) |
| 8 | `PointConfigs` | Per-profile config (seeded with defaults on track activation) |
| 9 | `StudyDayConfigs` | Per-profile config |
| 10 | `Completions` | Progress (append-only) |
| 11 | `LearningLedger` | Progress (append-only) |
| 12 | `Bookmarks` | Progress |
| 13 | `LearningOrder` | Progress |
| 14 | `Goals` | Gamification |
| 15 | `Rewards` | Gamification |
| 16 | `RewardPools` | Gamification |
| 17 | `RewardPoolItems` | Gamification |
| 18 | `Streaks` | Gamification |
| 19 | `SyncQueue` | Sync infrastructure |
| 20 | `TextDownloadStatuses` | Download tracking |

**Note:** `ContentDownloadStatuses` is **removed entirely**. It tracked hierarchy JSON downloads from Firebase Cloud Storage, but in the offline-first architecture all hierarchy data is bundled in APK assets. This table has no purpose.

### 2.3 Database Class

```dart
@DriftDatabase(
  tables: [
    UserProfiles,
    Profiles,
    ActiveCurricula,
    CurriculumTracks,
    CurriculumScopes,
    ProfilePrograms,
    StageDefinitions,
    PointConfigs,
    StudyDayConfigs,
    Completions,
    LearningLedger,
    Bookmarks,
    LearningOrder,
    Goals,
    Rewards,
    RewardPools,
    RewardPoolItems,
    Streaks,
    SyncQueue,
    TextDownloadStatuses,
  ],
  daos: [
    UserProfileDao,
    ProfileDao,
    ActiveCurriculumDao,
    TrackDao,
    CurriculumScopeDao,
    ProfileProgramDao,
    StageDao,
    PointConfigDao,
    StudyDayConfigDao,
    CompletionDao,
    LearningLedgerDao,
    BookmarkDao,
    LearningOrderDao,
    GoalDao,
    RewardDao,
    RewardPoolDao,
    StreakDao,
    SyncQueueDao,
    TextDownloadStatusDao,
  ],
)
class UserDatabase extends _$UserDatabase {
  UserDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
        // No seed data here — LearningPrograms are in ContentDatabase.
        // StageDefinitions/PointConfigs are seeded per-profile during onboarding
        // by the AddTrackFlow, not at DB creation time.
      },
      onUpgrade: (Migrator m, int from, int to) async {
        // Future migrations go here. Start clean at v1.
      },
    );
  }
}
```

### 2.4 The "Mixed" Tables — Seeding StageDefinitions, PointConfigs, StudyDayConfigs

These three tables hold **per-profile configuration** that is initialized with defaults derived from `LearningPrograms.stagesConfig` (which lives in ContentDatabase). The seeding flow is:

1. User activates a track via `AddTrackFlow`.
2. `AddTrackFlow` reads the selected `LearningProgram` from **ContentDatabase** (via `LearningProgramDao`).
3. It parses `stagesConfig` JSON from the program definition.
4. It writes `StageDefinitions` rows into **UserDatabase** (via `StageDao`).
5. It writes corresponding `PointConfigs` rows with default point values (via `PointConfigDao`).
6. It writes default `StudyDayConfigs` if the program specifies day-of-week schedules.

**This cross-database read-then-write is handled at the service/provider layer, not at the DAO layer.** No DAO needs to query both databases. The provider reads from ContentDB, transforms the data, then writes to UserDB. Example:

```dart
// In the AddTrackFlow service/provider:
final program = await ref.read(contentDatabaseProvider).learningProgramDao
    .getProgramByName(selectedProgram);

final stages = parseStagesConfig(program!.stagesConfig);
final userDb = ref.read(userDatabaseProvider);

await userDb.transaction(() async {
  for (final (i, stage) in stages.indexed) {
    await userDb.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: Value(profileId),
        curriculumId: curriculumId.storageKey,
        stageOrder: i,
        stageName: stage.name,
        delayDays: stage.delayDays,
        isDefault: const Value(true),
      ),
    );
    await userDb.pointConfigDao.insertPointConfig(
      PointConfigsCompanion.insert(
        profileId: Value(profileId),
        curriculumId: curriculumId.storageKey,
        stageOrder: i,
        points: stage.defaultPoints,
      ),
    );
  }
});
```

---

## 3. Drift Code Generation Considerations

### 3.1 Two @DriftDatabase Classes — How Code Generation Works

Drift generates a `.g.dart` file for each file containing a `@DriftDatabase` or `@DriftAccessor` annotation. With two database classes in separate files, Drift generates separate code for each:

- `content_database.g.dart` — generated types for ContentDatabase tables
- `user_database.g.dart` — generated types for UserDatabase tables

**Each database gets its own complete set of generated data classes** for the tables it declares. This means `TextCacheData` (the generated row class for `TextCache`) will be generated in `content_database.g.dart`, and `CompletionData` will be generated in `user_database.g.dart`.

### 3.2 Shared Table Definitions — No Conflicts

Table definition classes (`TextCache extends Table`, `Completions extends Table`, etc.) are plain Dart classes with no generated code. They can be imported by either database class. The generated code is scoped to the database file, not the table file.

**There is no conflict** from having table definition files shared or imported, as long as each table class appears in exactly one `@DriftDatabase` annotation. If the same table class were listed in both databases, Drift would generate duplicate row classes, which would cause ambiguous import errors. **Each table must belong to exactly one database.**

### 3.3 Modular Code Generation — Not Needed

The `drift.modular` build option (which generates one file per table instead of one monolithic `.g.dart`) is useful for very large codebases where incremental compilation becomes slow. With 5 tables in ContentDB and 20 tables in UserDB, the standard generation mode is fine.

The current `build.yaml` already has `scoped_dart_components: true`, which is the right setting — it scopes generated `$Table` classes to avoid name collisions.

**No changes to `build.yaml` are needed.**

### 3.4 DAO Code Generation with New Database Types

Every DAO uses `DatabaseAccessor<AppDatabase>` today. Each DAO must be changed to reference its owning database type:

- Content DAOs: `DatabaseAccessor<ContentDatabase>`
- User DAOs: `DatabaseAccessor<UserDatabase>`

The generated `_$XxxDaoMixin` is specific to the database type. This is a mechanical change — find-and-replace `AppDatabase` with the correct type in each DAO file.

### 3.5 Where Database Class Files Live

See [Section 7 — File Organization](#7-file-organization) for the full directory structure. Summary:

- `lib/core/database/content/content_database.dart`
- `lib/core/database/user/user_database.dart`

---

## 4. Provider Architecture

### 4.1 Two Riverpod Providers

```dart
// lib/core/providers/database_provider.dart

@Riverpod(keepAlive: true)
ContentDatabase contentDatabase(Ref ref) {
  // Opened from pre-built seed file — see Section 1.5
  // In practice this will be an AsyncNotifier since opening
  // requires async I/O (checking/extracting the seed file).
  // Simplified here for clarity.
  final database = ContentDatabase(
    NativeDatabase(File(contentDbPath)),
  );
  ref.onDispose(database.close);
  return database;
}

@Riverpod(keepAlive: true)
UserDatabase userDatabase(Ref ref) {
  final database = UserDatabase(
    driftDatabase(name: 'learning_tracker'),
  );
  ref.onDispose(database.close);
  return database;
}
```

**Async initialization concern:** The ContentDatabase requires async file I/O to check whether the seed file needs extracting. Two approaches:

**Option A — Eager initialization in `main()` (Recommended):**

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final contentDb = await openContentDatabase(); // async seed extraction

  runApp(
    ProviderScope(
      overrides: [
        contentDatabaseProvider.overrideWithValue(contentDb),
      ],
      child: const App(),
    ),
  );
}
```

This avoids `AsyncValue` unwrapping everywhere content is accessed. The splash screen naturally covers the extraction time.

**Option B — AsyncNotifier:** Use `AsyncNotifierProvider` and handle loading states. More complex, less recommended since content DB must be ready before anything renders.

### 4.2 Repositories/Services that Need Both Databases

Several screens need data from both databases. The pattern is: **providers compose from both database providers, never at the DAO level.**

Example — Dashboard showing today's calendar program assignment (ContentDB) with user's completion status (UserDB):

```dart
@riverpod
Future<DashboardData> dashboardData(Ref ref, int profileId) async {
  final contentDb = ref.watch(contentDatabaseProvider);
  final userDb = ref.watch(userDatabaseProvider);

  // Read from ContentDB: what's today's assignment?
  final todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final cycles = await contentDb.calendarCycleDao
      .getCyclesForDate(todayKey);

  // Read from UserDB: which programs has this profile enrolled in?
  final enrollments = await userDb.profileProgramDao
      .getProgramsForProfile(profileId);

  // Read from UserDB: what's been completed today?
  final completions = await userDb.completionDao
      .getCompletionsForDate(profileId, DateTime.now());

  // Combine at the provider layer
  return DashboardData(
    assignments: _mergeAssignmentsWithCompletions(cycles, enrollments, completions),
  );
}
```

**Key principle:** The DAO layer never crosses database boundaries. The provider/service layer does the join in Dart code. This is acceptable because:
- Cross-DB joins are always small (a handful of program enrollments, not thousands of rows).
- The two datasets are linked by string identifiers (`programKey`, `curriculumId`, `sefariaRef`), not foreign keys.

### 4.3 Affected Provider Files (40 files reference `appDatabaseProvider`)

All 40 files that currently `ref.watch(appDatabaseProvider)` must be updated. Most of them only access UserDB tables and will simply change to `ref.watch(userDatabaseProvider)`. A smaller number access content tables:

**Content-only access (change to `contentDatabaseProvider`):**
- `text_display_providers.dart` — reads TextCache
- `calendar_providers.dart` — reads calendar data
- `cloud_content_providers.dart` — reads content (will be restructured)

**User-only access (change to `userDatabaseProvider`):**
- All 35+ remaining provider files (completions, bookmarks, profiles, tracks, rewards, etc.)

**Cross-database access (need both providers):**
- `onboarding_providers.dart` — reads LearningPrograms (Content), writes StageDefinitions (User)
- `add_track_providers.dart` — same pattern
- `scheduler_providers.dart` — reads CalendarCycles (Content) + Completions (User)
- `dashboard_providers.dart` — potentially reads both

---

## 5. DAO Reorganization

### 5.1 Current State: 25 DAOs on AppDatabase

### 5.2 New Assignment

#### ContentDatabase DAOs (5)

| DAO | Table(s) | Changes Needed |
|-----|----------|----------------|
| `TextCacheDao` | TextCache | Change `DatabaseAccessor<AppDatabase>` to `DatabaseAccessor<ContentDatabase>` |
| `CalendarCycleDao` | CalendarCycles | **New DAO** — replaces `CalendarCacheDao`. Read-only queries: get by date, get by program+date, get date range. |
| `LearningProgramDao` | LearningPrograms | Change accessor type. **Remove `insertProgram` and `deprecateProgram`** — Content DB is read-only. Keep only read methods. |
| `TestDateDao` | TestDates | Stays in User DB — Dirshu test reminders are a separate feature to be scoped separately. |
| `SeedMetadataDao` | SeedMetadata | **New DAO** — single method: `getVersion()`. |

#### UserDatabase DAOs (19)

| DAO | Table(s) | Changes Needed |
|-----|----------|----------------|
| `UserProfileDao` | UserProfiles | Change accessor type |
| `ProfileDao` | Profiles | Change accessor type |
| `ActiveCurriculumDao` | ActiveCurricula | Change accessor type |
| `TrackDao` | CurriculumTracks | Change accessor type |
| `CurriculumScopeDao` | CurriculumScopes | Change accessor type |
| `ProfileProgramDao` | ProfilePrograms | Change accessor type |
| `StageDao` | StageDefinitions | Change accessor type |
| `PointConfigDao` | PointConfigs | Change accessor type |
| `StudyDayConfigDao` | StudyDayConfigs | Change accessor type |
| `CompletionDao` | Completions | Change accessor type |
| `LearningLedgerDao` | LearningLedger | Change accessor type |
| `BookmarkDao` | Bookmarks | Change accessor type |
| `LearningOrderDao` | LearningOrder | Change accessor type |
| `GoalDao` | Goals | Change accessor type |
| `RewardDao` | Rewards | Change accessor type |
| `RewardPoolDao` | RewardPools, RewardPoolItems | Change accessor type |
| `StreakDao` | Streaks | Change accessor type |
| `SyncQueueDao` | SyncQueue | Change accessor type |
| `TextDownloadStatusDao` | TextDownloadStatuses | Change accessor type |

#### Removed DAOs (2)

| DAO | Reason |
|-----|--------|
| `CalendarCacheDao` | Replaced by `CalendarCycleDao` (different table schema) |
| `ContentDownloadStatusDao` | Table removed (hierarchy data now bundled in APK) |

### 5.3 Cross-Boundary DAO Analysis

**No existing DAO queries across content+user boundaries.** Every current DAO accesses exactly one table (or a closely related pair like RewardPools+RewardPoolItems). The cross-referencing happens at the provider layer via string identifiers:

- `Completions.stageId` references `StageDefinitions.id` — both in UserDB. No issue.
- `ProfilePrograms.programId` references `LearningPrograms.id` — cross-DB reference. This is a **logical FK, not an enforced one**. The `programId` integer is stable because Content DB program IDs are deterministic (inserted in the same order from the same seed data every time). If needed, we can switch to `programName` (text) as the reference key for extra safety.
- `TestDates.programId` references `LearningPrograms.id` — cross-DB reference (User DB → Content DB). Same string key pattern as other cross-DB refs.
- `Completions.sefariaRef` references `TextCache.sefariaRef` — cross-DB. Already a string key, no FK enforcement. No issue.

**Risk: `ProfilePrograms.programId` as cross-DB integer FK.** If we ever reorder the seed data or change autoincrement behavior, the IDs could drift. **Recommendation:** Add a `programName` text column to `ProfilePrograms` alongside `programId` as the stable cross-DB key. This is a minor schema change in v1.

---

## 6. Testing Strategy

### 6.1 Current Test Helper

```dart
// test/helpers/test_database.dart
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
```

### 6.2 New Test Helpers

```dart
// test/helpers/test_database.dart

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

/// Creates an in-memory UserDatabase for testing.
/// This is the direct replacement for createTestDatabase().
UserDatabase createTestUserDatabase() {
  return UserDatabase(NativeDatabase.memory());
}

/// Creates an in-memory ContentDatabase for testing.
/// Seeds it with program and test date data (mirrors the production seed DB).
Future<ContentDatabase> createTestContentDatabase() async {
  final db = ContentDatabase(NativeDatabase.memory());
  await _seedTestContentData(db);
  return db;
}

/// Seeds a ContentDatabase with the standard reference data.
/// This reproduces what the production content.db.gz contains.
Future<void> _seedTestContentData(ContentDatabase db) async {
  // Seed LearningPrograms from the same seed data used in production
  for (final seed in learningProgramSeeds) {
    await db.into(db.learningPrograms).insert(
      LearningProgramsCompanion.insert(
        name: seed['name']! as String,
        displayName: seed['display_name']! as String,
        description: Value(seed['description']! as String),
        curriculumType: seed['curriculum_type']! as String,
        isActive: Value(seed['is_active']! as bool),
        stagesConfig: seed['stages_config']! as String,
        hasTests: Value(seed['has_tests']! as bool),
        testConfig: Value(seed['test_config']! as String),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  // Seed SeedMetadata
  await db.into(db.seedMetadata).insert(
    SeedMetadataCompanion.insert(
      version: 1,
      builtAt: '2026-01-01T00:00:00Z',
      buildId: 'test',
      textCacheCount: 0,
      calendarCycleCount: 0,
    ),
  );
}

/// Convenience: creates both databases for integration tests.
Future<({ContentDatabase content, UserDatabase user})> createTestDatabases() async {
  return (
    content: await createTestContentDatabase(),
    user: createTestUserDatabase(),
  );
}
```

### 6.3 Backward Compatibility for Existing Tests

The existing `createTestDatabase()` function returns `AppDatabase`. During migration, we keep it working until all tests are ported:

```dart
/// @deprecated Use createTestUserDatabase() and createTestContentDatabase()
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}
```

### 6.4 Content DB Test Data Strategy

**Generate in-memory, do not ship a test seed DB file.**

Rationale:
- The seed data is small (9 programs, ~48 test dates, a metadata row). In-memory generation takes <10ms.
- Shipping a binary `.db` file in the test directory creates maintenance burden (must rebuild whenever schema changes).
- TextCache rows (52K) are NOT needed for most tests. Tests that need text content can insert a handful of rows directly.
- CalendarCycles data can be generated programmatically from the same computation function used to build the production seed.

### 6.5 Provider Test Setup

Tests that use Riverpod providers need both database overrides:

```dart
final container = ProviderContainer(
  overrides: [
    contentDatabaseProvider.overrideWithValue(testContentDb),
    userDatabaseProvider.overrideWithValue(testUserDb),
  ],
);
```

### 6.6 Test Fixture Pattern

For tests that need specific content data (e.g., a particular calendar cycle entry):

```dart
// test/fixtures/content_fixtures.dart
Future<void> seedCalendarCycleFixture(ContentDatabase db) async {
  await db.into(db.calendarCycles).insert(
    CalendarCyclesCompanion.insert(
      programKey: 'Daf Yomi',
      dateKey: '2026-03-29',
      sefariaRef: 'Berakhot 2a',
    ),
  );
}
```

---

## 7. File Organization

### 7.1 Proposed Directory Structure

```
lib/core/database/
  content/
    content_database.dart          # @DriftDatabase class
    content_database.g.dart        # generated
    content_database_opener.dart   # seed file extraction logic
    daos/
      text_cache_dao.dart
      text_cache_dao.g.dart
      calendar_cycle_dao.dart      # NEW (replaces calendar_cache_dao)
      calendar_cycle_dao.g.dart
      learning_program_dao.dart    # moved, made read-only
      learning_program_dao.g.dart
      test_date_dao.dart           # moved, made read-only
      test_date_dao.g.dart
      seed_metadata_dao.dart       # NEW
      seed_metadata_dao.g.dart
  user/
    user_database.dart             # @DriftDatabase class
    user_database.g.dart           # generated
    daos/
      active_curriculum_dao.dart
      bookmark_dao.dart
      completion_dao.dart
      curriculum_scope_dao.dart
      goal_dao.dart
      learning_ledger_dao.dart
      learning_order_dao.dart
      point_config_dao.dart
      profile_dao.dart
      profile_program_dao.dart
      reward_dao.dart
      reward_pool_dao.dart
      stage_dao.dart
      streak_dao.dart
      study_day_config_dao.dart
      sync_queue_dao.dart
      text_download_status_dao.dart
      track_dao.dart
      user_profile_dao.dart
      (+ .g.dart files for each)
  tables/                          # SHARED — table definitions stay here
    active_curricula.dart
    bookmarks.dart
    calendar_cycles.dart           # NEW (replaces calendar_cache.dart)
    completions.dart
    curriculum_scopes.dart
    curriculum_tracks.dart
    goals.dart
    learning_ledger.dart
    learning_order.dart
    learning_programs.dart
    point_configs.dart
    profile_programs.dart
    profiles.dart
    reward_pool_items.dart
    reward_pools.dart
    rewards.dart
    seed_metadata.dart             # NEW
    stage_definitions.dart
    streaks.dart
    study_day_configs.dart
    sync_queue.dart
    test_dates.dart
    text_cache.dart
    text_download_status.dart
    user_profiles.dart
  seed/                            # SHARED — seed data definitions
    learning_program_seeds.dart    # used by content DB build pipeline AND test helpers
    test_date_seeds.dart           # same
```

### 7.2 Design Decisions

**Table definitions stay in a shared `tables/` directory.** Table classes are plain Dart — no generated code, no dependency on a specific database type. They are imported by whichever database needs them.

**DAOs are split into `content/daos/` and `user/daos/`.** Each DAO depends on its database type (`DatabaseAccessor<ContentDatabase>` vs `DatabaseAccessor<UserDatabase>`), so they must live under their respective database directory.

**Old files removed:**
- `app_database.dart` + `.g.dart` — replaced by the two new database classes
- `daos/calendar_cache_dao.dart` + `.g.dart` — replaced by `calendar_cycle_dao.dart`
- `daos/content_download_status_dao.dart` + `.g.dart` — table removed
- `tables/calendar_cache.dart` — replaced by `calendar_cycles.dart`
- `tables/content_download_statuses.dart` — table removed

---

## 8. Migration Path from Current Codebase

### 8.1 Strategy: Big-Bang Split (Recommended)

Since the app has NOT been deployed, there is no installed base to worry about. A big-bang split is cleaner than an incremental approach because:

1. Incremental would require maintaining `AppDatabase` + one new database simultaneously during the transition, causing import confusion and duplicate generated code.
2. The split is mechanical (move tables, change accessor types, update provider references) — not algorithmically complex.
3. All existing tests break and must be fixed regardless of approach.

### 8.2 Execution Steps (ordered)

**Phase 1 — Scaffold (1 PR, ~2 hours)**

1. Create `content/content_database.dart` and `user/user_database.dart` with their `@DriftDatabase` annotations.
2. Create the two new table files: `tables/calendar_cycles.dart`, `tables/seed_metadata.dart`.
3. Create the two new DAO files: `content/daos/calendar_cycle_dao.dart`, `content/daos/seed_metadata_dao.dart`.
4. Run `dart run build_runner build --delete-conflicting-outputs` to verify generation succeeds.
5. Do NOT delete `AppDatabase` yet — let both coexist temporarily.

**Phase 2 — Move DAOs (1 PR, ~3 hours)**

1. Move DAO files from `daos/` to `content/daos/` or `user/daos/`.
2. Change `DatabaseAccessor<AppDatabase>` to the correct type in each DAO.
3. Update import paths in all DAO files.
4. Make Content DAOs read-only (remove write methods from `LearningProgramDao`, `TestDateDao`).
5. Delete `CalendarCacheDao`, `ContentDownloadStatusDao`.
6. Run code generation. Fix any compile errors.

**Phase 3 — Update Providers (1 PR, ~4 hours)**

1. Replace `appDatabaseProvider` with `contentDatabaseProvider` and `userDatabaseProvider`.
2. Update all 40 provider files that reference `appDatabaseProvider`.
3. Update `database_provider.dart` with both new providers.
4. Delete the old `appDatabaseProvider`.

**Phase 4 — Delete AppDatabase (1 PR, ~1 hour)**

1. Delete `app_database.dart` and `app_database.g.dart`.
2. Delete removed table files (`calendar_cache.dart`, `content_download_statuses.dart`).
3. Run code generation one final time.
4. Run full test suite.

**Phase 5 — Fix Tests (1 PR, ~3 hours)**

1. Update `test/helpers/test_database.dart` with new helpers.
2. Update all test files that use `createTestDatabase()`.
3. Add content DB seeding to tests that need program/text data.
4. Verify all story acceptance tests pass.

### 8.3 Files Affected — Estimated Scope

| Category | Count | Description |
|----------|-------|-------------|
| New files | 6 | 2 database classes, 2 new tables, 2 new DAOs |
| Moved + modified DAOs | 23 | All existing DAOs get moved and accessor type changed |
| Deleted files | 5 | AppDatabase (2), CalendarCacheDao (2), ContentDownloadStatusDao (2), old table files (2) = ~8 files |
| Provider files updated | 40 | Every file referencing `appDatabaseProvider` |
| Test files updated | ~25 | Every test file using `createTestDatabase()` |
| Config files | 0 | No changes to `build.yaml` or `pubspec.yaml` |
| **Total touched** | **~94 files** | |

### 8.4 Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Code generation fails with two databases | Low | High | Drift officially supports multiple databases. The `scoped_dart_components: true` option already handles namespacing. |
| Import cycles between content/user | Low | Medium | Table definitions are in a shared `tables/` directory with no dependencies on database classes. DAOs only import their own database class. |
| Provider wiring errors at runtime | Medium | Medium | Riverpod's compile-time generation catches most issues. Integration tests catch the rest. |
| `ProfilePrograms.programId` cross-DB FK breaks | Low | High | Add `programName` text column in v1 schema as stable cross-DB key. Mitigates future seed-order changes. |
| Seed file extraction adds startup latency | Low | Low | gzip decompress of ~5MB takes <500ms. Only happens on first launch or app update. Splash screen covers it. |
| Tests take longer with two DBs | Low | Low | In-memory SQLite is fast. Two in-memory DBs add negligible overhead. |

### 8.5 What NOT to Change in This Split

- **Drift version stays at 2.31.0** — no upgrade needed.
- **`build.yaml` stays as-is** — `scoped_dart_components: true` already handles the multi-DB case.
- **No new dependencies** — `drift`, `drift_flutter`, `drift_dev` are sufficient.
- **Table schemas are unchanged** (except removing `CalendarCache` and `ContentDownloadStatuses`, and adding `CalendarCycles` and `SeedMetadata`).
- **No changes to the sync layer** — SyncQueue stays in UserDB, sync logic is unaffected.

---

## Appendix A: Quick Reference — Table-to-Database Mapping

| Table | Database | Category |
|-------|----------|----------|
| TextCache | Content | Bundled text content |
| CalendarCycles | Content | Pre-computed calendar programs |
| LearningPrograms | Content | Program presets |
| TestDates | User | Dirshu test reminders (separate feature) |
| SeedMetadata | Content | Seed version tracking |
| UserProfiles | User | Account |
| Profiles | User | Multi-profile |
| ActiveCurricula | User | Config |
| CurriculumTracks | User | Config |
| CurriculumScopes | User | Config |
| ProfilePrograms | User | Config |
| StageDefinitions | User | Config (seeded from Content) |
| PointConfigs | User | Config (seeded from Content) |
| StudyDayConfigs | User | Config |
| Completions | User | Progress |
| LearningLedger | User | Progress |
| Bookmarks | User | Progress |
| LearningOrder | User | Progress |
| Goals | User | Gamification |
| Rewards | User | Gamification |
| RewardPools | User | Gamification |
| RewardPoolItems | User | Gamification |
| Streaks | User | Gamification |
| SyncQueue | User | Sync |
| TextDownloadStatuses | User | Download tracking |

**Removed:** CalendarCache (replaced by CalendarCycles), ContentDownloadStatuses (hierarchy now bundled)

## Appendix B: Quick Reference — DAO-to-Database Mapping

| DAO | Database | Notes |
|-----|----------|-------|
| TextCacheDao | Content | Read-only |
| CalendarCycleDao | Content | NEW — replaces CalendarCacheDao |
| LearningProgramDao | Content | Read-only (write methods removed) |
| TestDateDao | Content | Read-only (write methods removed) |
| SeedMetadataDao | Content | NEW — read-only |
| UserProfileDao | User | |
| ProfileDao | User | |
| ActiveCurriculumDao | User | |
| TrackDao | User | |
| CurriculumScopeDao | User | |
| ProfileProgramDao | User | |
| StageDao | User | |
| PointConfigDao | User | |
| StudyDayConfigDao | User | |
| CompletionDao | User | |
| LearningLedgerDao | User | |
| BookmarkDao | User | |
| LearningOrderDao | User | |
| GoalDao | User | |
| RewardDao | User | |
| RewardPoolDao | User | |
| StreakDao | User | |
| SyncQueueDao | User | |
| TextDownloadStatusDao | User | |

**Removed:** CalendarCacheDao, ContentDownloadStatusDao
