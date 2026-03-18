# Story 15.4 — Learning Program Preset Model & Seed Data (DNI-112)

## Story Overview

Introduce the `learning_programs` and `profile_programs` Drift tables, domain models, DAO, repository, Riverpod providers, and seed all 9 preset definitions. This is the data-layer foundation that later stories (program wizard UI, "Change Program" flow, Dirshu test tracking) depend on.

Currently, every curriculum gets the same 3 default stages (Learn / Chazara 1 / Chazara 2) via `StageDefinitionRepositoryImpl._defaults`. After this story, a user can instead select a named learning program preset that auto-configures stages with richer scheduling (delay, day-of-week, rolling-window). "Custom" is not a stored row — it is the absence of a `profile_programs` entry.

**Depends on:** Story 15.3 (new `nach` and `mussar` curriculum IDs in `CurriculumId` enum).
**Blocks:** Story 15.5 (Program Wizard UI), Story 15.8 (Dirshu Test Tracking).

---

## Acceptance Criteria

1. **`learning_programs` table exists** with columns: `id` (text PK), `name` (text), `display_name` (text), `description` (text), `curriculum_type` (text FK to `CurriculumId.storageKey`), `is_active` (bool, default true), `stages_config` (text/JSON), `has_tests` (bool, default false), `test_config` (text/JSON, nullable), `created_at` (datetime).
2. **`profile_programs` table exists** with columns: `profile_id` (int FK to `user_profiles.id`), `curriculum_type` (text), `program_id` (text FK to `learning_programs.id`), with composite PK `(profile_id, curriculum_type)`.
3. **All 9 presets are seeded** on first database creation and on migration from schema v9 to v10. Seed is idempotent (skips if rows already exist).
4. **Presets are queryable by curriculum type** — `LearningProgramDao.getProgramsForCurriculum('bavli')` returns Oraysa, Dirshu Kinyan Torah, Dirshu Amud HaYomi, and Daf Yomi.
5. **Preset rows are immutable** — DAO exposes no `update` or `delete` methods for `learning_programs`. Deprecation is handled by setting `is_active = false` in a future migration.
6. **`profile_programs` supports CRUD** — assign a program to a profile+curriculum, query the current program, remove (revert to custom).
7. **Domain model** `LearningProgram` (Freezed) faithfully represents all table columns with typed `CurriculumId` and parsed `StagesConfig` / `TestConfig`.
8. **Riverpod providers** expose: `learningProgramsByCurriculumProvider(CurriculumId)`, `profileProgramProvider((profileId, CurriculumId))`, `assignProgramNotifier`.
9. **Unit tests** cover: seed idempotency, query-by-curriculum filtering, profile-program assignment/removal, JSON round-trip for `stages_config` and `test_config`.

---

## Architecture & Design Notes

### New Curricula Prerequisite

Story 15.3 adds two new values to `CurriculumId`:

```dart
// lib/core/enums/curriculum_id.dart
enum CurriculumId {
  mishnayos('mishnayos'),
  bavli('bavli'),
  yerushalmi('yerushalmi'),
  mishnaBerurah('mishna_berurah'),
  chumash('chumash'),
  nach('nach'),       // NEW — Story 15.3
  mussar('mussar'),   // NEW — Story 15.3
}
```

### Table Definitions

#### `learning_programs`

```dart
// lib/core/database/tables/learning_programs.dart
class LearningPrograms extends Table {
  // Stable string ID, e.g. 'oraysa', 'dirshu_kinyan_torah'
  TextColumn get id => text()();
  TextColumn get name => text()();           // internal name
  TextColumn get displayName => text()();    // user-facing
  TextColumn get description => text()();
  TextColumn get curriculumType => text()(); // CurriculumId.storageKey
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get stagesConfig => text()();   // JSON array
  BoolColumn get hasTests => boolean().withDefault(const Constant(false))();
  TextColumn get testConfig => text().nullable()(); // JSON object or null
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
```

#### `profile_programs`

```dart
// lib/core/database/tables/profile_programs.dart
class ProfilePrograms extends Table {
  IntColumn get profileId => integer()
      .references(UserProfiles, #id)();
  TextColumn get curriculumType => text()();
  TextColumn get programId => text()
      .references(LearningPrograms, #id)();

  @override
  Set<Column> get primaryKey => {profileId, curriculumType};
}
```

### JSON Schema: `stages_config`

An ordered JSON array. Each element describes one stage the preset creates when applied.

```json
[
  {
    "stage_order": 1,
    "stage_name": "Learn",
    "schedule_type": "daily",
    "delay_days": 0,
    "days_of_week": null,
    "rolling_window_size": null,
    "is_default": true
  },
  {
    "stage_order": 2,
    "stage_name": "Next-Day Review",
    "schedule_type": "delay",
    "delay_days": 1,
    "days_of_week": null,
    "rolling_window_size": null,
    "is_default": true
  },
  {
    "stage_order": 3,
    "stage_name": "Weekly Review",
    "schedule_type": "day_of_week",
    "delay_days": null,
    "days_of_week": ["friday", "shabbos"],
    "rolling_window_size": null,
    "is_default": true
  },
  {
    "stage_order": 4,
    "stage_name": "Back-20 Review",
    "schedule_type": "rolling_window",
    "delay_days": null,
    "days_of_week": null,
    "rolling_window_size": 20,
    "is_default": true
  }
]
```

**`schedule_type` enum values:** `daily`, `delay`, `day_of_week`, `rolling_window`

- `daily` — new content, no delay
- `delay` — review after N days (`delay_days`)
- `day_of_week` — review on specific days (`days_of_week` array)
- `rolling_window` — review the last N items cyclically (`rolling_window_size`)

### JSON Schema: `test_config`

Nullable. Present only when `has_tests = true`.

```json
{
  "frequency": "monthly",
  "question_count": 30,
  "passing_score_percent": 80,
  "default_reminder_days_before": [7, 1],
  "score_format": "percentage"
}
```

For bimonthly (Daf HaYomi B'Halacha):

```json
{
  "frequency": "bimonthly",
  "question_count": 30,
  "passing_score_percent": 70,
  "default_reminder_days_before": [7, 1],
  "score_format": "percentage"
}
```

### Complete Seed Data (All 9 Presets)

| `id` | `display_name` | `curriculum_type` | `has_tests` | Stages summary |
|------|----------------|-------------------|-------------|----------------|
| `oraysa` | Oraysa | `bavli` | false | Learn (daily) -> Next-Day Review (delay:1d) -> Weekly Review (day_of_week: fri/shabbos) -> Back-20 Review (rolling_window:20) |
| `dirshu_kinyan_torah` | Dirshu Kinyan Torah | `bavli` | true (monthly) | Learn (daily) -> 1st Review (delay:1d) -> 2nd Review (delay:7d) -> 3rd Review (delay:30d) |
| `dirshu_amud_hayomi` | Dirshu Amud HaYomi | `bavli` | true (monthly) | Learn (daily, half-daf) -> 1st Review (delay:1d) -> 2nd Review (delay:7d) -> 3rd Review (delay:30d) |
| `dirshu_kinyan_yerushalmi` | Dirshu Kinyan Yerushalmi | `yerushalmi` | true (monthly) | Learn (daily) -> 1st Review (delay:1d) -> 2nd Review (delay:7d) -> 3rd Review (delay:30d) |
| `dirshu_daf_hayomi_bhalacha` | Dirshu Daf HaYomi B'Halacha | `mishna_berurah` | true (bimonthly) | Learn (daily) -> 1st Review (delay:1d) -> 2nd Review (delay:14d) |
| `dirshu_kinyan_chochma` | Dirshu Kinyan Chochma | `mussar` | false | Learn (daily) -> 1st Review (delay:1d) -> 2nd Review (delay:7d) -> 3rd Review (delay:30d) |
| `daf_yomi` | Daf Yomi | `bavli` | false | Learn (daily) |
| `mishnah_yomis` | Mishnah Yomis | `mishnayos` | false | Learn (daily) |
| `nach_yomi` | Nach Yomi | `nach` | false | Learn (daily) |

### Domain Models (Freezed)

```dart
// lib/features/programs/domain/models/learning_program.dart

enum ScheduleType { daily, delay, dayOfWeek, rollingWindow }

@freezed
abstract class StageConfig with _$StageConfig {
  const factory StageConfig({
    required int stageOrder,
    required String stageName,
    required ScheduleType scheduleType,
    int? delayDays,
    List<String>? daysOfWeek,
    int? rollingWindowSize,
    @Default(true) bool isDefault,
  }) = _StageConfig;

  factory StageConfig.fromJson(Map<String, dynamic> json) =>
      _$StageConfigFromJson(json);
}

@freezed
abstract class TestConfig with _$TestConfig {
  const factory TestConfig({
    required String frequency,
    required int questionCount,
    required int passingScorePercent,
    required List<int> defaultReminderDaysBefore,
    @Default('percentage') String scoreFormat,
  }) = _TestConfig;

  factory TestConfig.fromJson(Map<String, dynamic> json) =>
      _$TestConfigFromJson(json);
}

@freezed
abstract class LearningProgram with _$LearningProgram {
  const factory LearningProgram({
    required String id,
    required String name,
    required String displayName,
    required String description,
    required CurriculumId curriculumType,
    required bool isActive,
    required List<StageConfig> stagesConfig,
    required bool hasTests,
    TestConfig? testConfig,
    required DateTime createdAt,
  }) = _LearningProgram;
}
```

### Immutability Strategy

Presets are **read-only at the application layer**:

1. `LearningProgramDao` exposes only `getAll()`, `getById(String)`, `getByCurriculum(String)`, and a package-private `seedAll()` used during migration.
2. No `update` or `delete` methods are exposed.
3. To deprecate a preset in a future version, a migration sets `is_active = false` and inserts a replacement row with a new `id`. The `profile_programs` entries referencing the old ID remain valid (the old row is never deleted), but the program wizard will no longer show it for new selections.
4. The `getByCurriculum` method filters `WHERE is_active = true` by default.

### Database Migration

Schema version `9 -> 10`:

```dart
if (from < 10) {
  await m.createTable($LearningProgramsTable(attachedDatabase));
  await m.createTable($ProfileProgramsTable(attachedDatabase));
  await _seedLearningPrograms();
}
```

The `_seedLearningPrograms()` helper is also called from `onCreate` to ensure presets exist in fresh databases.

---

## Implementation Steps

### Step 1: Add `ScheduleType` enum
- **File:** `lib/core/enums/schedule_type.dart` (new)
- Define `enum ScheduleType { daily, delay, dayOfWeek, rollingWindow }` with `storageKey` for JSON serialization (`'daily'`, `'delay'`, `'day_of_week'`, `'rolling_window'`).

### Step 2: Create Drift table definitions
- **File:** `lib/core/database/tables/learning_programs.dart` (new)
- **File:** `lib/core/database/tables/profile_programs.dart` (new)
- Follow the existing table pattern (see `stage_definitions.dart`, `active_curricula.dart`).

### Step 3: Create Freezed domain models
- **File:** `lib/features/programs/domain/models/stage_config.dart` (new)
- **File:** `lib/features/programs/domain/models/test_config.dart` (new)
- **File:** `lib/features/programs/domain/models/learning_program.dart` (new)
- Include `fromJson`/`toJson` on `StageConfig` and `TestConfig` for JSON column round-tripping.

### Step 4: Create seed data constant
- **File:** `lib/core/constants/learning_program_seeds.dart` (new)
- Define all 9 presets as `List<LearningProgramsCompanion>` constants (or a factory function that returns them).
- Each entry has the full `stages_config` JSON string and optional `test_config` JSON string.
- This is the single source of truth for preset data. Keep the JSON inline as Dart string literals for easy diffing.

### Step 5: Create DAO
- **File:** `lib/core/database/daos/learning_program_dao.dart` (new)
- `@DriftAccessor(tables: [LearningPrograms, ProfilePrograms])`
- Methods:
  - `Future<List<LearningProgram>> getAllActive()`
  - `Future<LearningProgram?> getById(String id)`
  - `Future<List<LearningProgram>> getByCurriculum(String curriculumType)` — filters `is_active = true`
  - `Future<void> seedAll(List<LearningProgramsCompanion> presets)` — insert-or-ignore, idempotent
  - `Future<ProfileProgram?> getProfileProgram(int profileId, String curriculumType)`
  - `Future<void> assignProgram(int profileId, String curriculumType, String programId)` — upsert
  - `Future<void> removeProgram(int profileId, String curriculumType)` — delete row (reverts to custom)

### Step 6: Create repository
- **File:** `lib/features/programs/domain/repositories/learning_program_repository.dart` (new) — abstract interface
- **File:** `lib/features/programs/data/repositories/learning_program_repository_impl.dart` (new) — concrete impl
- Repository wraps DAO, converts Drift rows to Freezed domain models (parsing JSON columns into `List<StageConfig>` and `TestConfig?`).

### Step 7: Register in AppDatabase
- **File:** `lib/core/database/app_database.dart` (modify)
  - Add `LearningPrograms` and `ProfilePrograms` to `@DriftDatabase(tables: [...])`.
  - Add `LearningProgramDao` to `daos: [...]`.
  - Bump `schemaVersion` to `10`.
  - Add migration block for `from < 10`.
  - Call seed in both `onCreate` and `onUpgrade`.

### Step 8: Create Riverpod providers
- **File:** `lib/features/programs/presentation/providers/program_providers.dart` (new)
- `learningProgramsByCurriculumProvider` — `FutureProvider.family<List<LearningProgram>, CurriculumId>`
- `profileProgramProvider` — `FutureProvider.family<LearningProgram?, (int, CurriculumId)>`
- `assignProgramNotifier` — `AsyncNotifier` for assign/remove operations

### Step 9: Run code generation
```bash
cd learning_tracker
dart run build_runner build --delete-conflicting-outputs
```

### Step 10: Write unit tests
- **File:** `test/core/database/daos/learning_program_dao_test.dart` (new)
- **File:** `test/features/programs/data/repositories/learning_program_repository_impl_test.dart` (new)
- **File:** `test/story_acceptance/epic_15_programs_test.dart` (new or modify)

---

## Dev Notes

### JSON column storage pattern

Drift stores `stages_config` and `test_config` as `TEXT` columns containing JSON. The DAO returns raw Drift rows; the repository layer is responsible for `jsonDecode` into `List<StageConfig>` and `TestConfig?`. Use `dart:convert` `jsonEncode`/`jsonDecode`. The Freezed models have `fromJson`/`toJson` for this purpose.

### Relationship to existing `stage_definitions` table

The `learning_programs.stages_config` column is a **blueprint** — it describes what stages a program defines. When a user *selects* a preset (Story 15.5), the system reads `stages_config`, deletes existing `stage_definitions` rows for that curriculum+profile, and inserts new `stage_definitions` rows based on the blueprint. This story does NOT implement that "apply preset" logic — it only stores the blueprints and the profile-program linkage.

The existing `StageDefinitions` table will need a `schedule_type` column and related fields in a sibling story (15.6 — Expanded Stage Model). This story's `stages_config` JSON already uses the expanded schema so presets are forward-compatible.

### Seed script idempotency

`seedAll()` uses Drift's `insertOnConflictUpdate` or a check-then-insert pattern:

```dart
Future<void> seedAll(List<LearningProgramsCompanion> presets) async {
  for (final preset in presets) {
    await into(learningPrograms).insert(
      preset,
      mode: InsertMode.insertOrIgnore,
    );
  }
}
```

This means re-running the seed (e.g., on app update) will not overwrite existing rows. If a preset needs updating in a future version, a migration will handle it explicitly.

### String ID rationale

Using text IDs (e.g., `'oraysa'`, `'dirshu_kinyan_torah'`) rather than auto-increment integers because:
- Presets are defined in code and must be stable across devices/reinstalls.
- Foreign keys from `profile_programs.program_id` must resolve identically on every device.
- Easier to reference in seed data, tests, and sync payloads.

### Profile-scoping note

The `profile_programs` table references `user_profiles.id`. The multi-profile system (Story 15.1) must land first or concurrently. If implementing in isolation, use the existing single-profile `user_profiles.id` as the `profile_id` and document that multi-profile support will expand this naturally.

---

## Test Plan

### Unit Tests — DAO (`learning_program_dao_test.dart`)

1. **Seed inserts all 9 presets** — call `seedAll()`, verify `getAllActive()` returns 9 rows.
2. **Seed is idempotent** — call `seedAll()` twice, verify still 9 rows (no duplicates).
3. **Filter by curriculum** — `getByCurriculum('bavli')` returns exactly 4 (Oraysa, Dirshu KT, Dirshu AHY, Daf Yomi). `getByCurriculum('nach')` returns 1 (Nach Yomi).
4. **Inactive preset excluded** — manually set `is_active = false` on one preset, verify `getByCurriculum` no longer returns it.
5. **Get by ID** — `getById('oraysa')` returns correct row with all fields.
6. **Get by ID — not found** — `getById('nonexistent')` returns null.
7. **Assign program to profile** — insert a profile-program row, query it back.
8. **Assign program — upsert** — assign bavli -> oraysa, then reassign bavli -> daf_yomi, verify only one row and it's daf_yomi.
9. **Remove program** — assign then remove, verify `getProfileProgram` returns null.
10. **Remove program — no-op if absent** — removing a non-existent assignment does not throw.

### Unit Tests — Repository (`learning_program_repository_impl_test.dart`)

1. **Maps Drift row to domain model** — verify `CurriculumId` enum conversion, `stagesConfig` JSON parsed to `List<StageConfig>`, `testConfig` JSON parsed to `TestConfig`.
2. **Null test_config** — preset with `has_tests = false` has `testConfig == null`.
3. **Round-trip JSON** — encode `StageConfig` to JSON, decode back, verify equality.
4. **Round-trip TestConfig JSON** — same for `TestConfig`.

### Acceptance Tests (`epic_15_programs_test.dart`)

1. **Story 15.4 group:**
   - "9 learning program presets are seeded on fresh database"
   - "presets are filterable by curriculum type"
   - "Oraysa preset has 4 stages with correct schedule types"
   - "Dirshu presets have has_tests = true with valid test_config"
   - "Simple presets (Daf Yomi, Mishnah Yomis, Nach Yomi) have single Learn stage"
   - "profile_programs table supports assign and remove"
   - "preset rows have no update/delete DAO methods" (verify at compile time — no method exists)

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/core/enums/schedule_type.dart` | `ScheduleType` enum |
| `lib/core/database/tables/learning_programs.dart` | Drift table definition |
| `lib/core/database/tables/profile_programs.dart` | Drift table definition |
| `lib/features/programs/domain/models/stage_config.dart` | Freezed model + JSON |
| `lib/features/programs/domain/models/test_config.dart` | Freezed model + JSON |
| `lib/features/programs/domain/models/learning_program.dart` | Freezed domain model |
| `lib/core/constants/learning_program_seeds.dart` | All 9 preset seed companions |
| `lib/core/database/daos/learning_program_dao.dart` | DAO for both tables |
| `lib/features/programs/domain/repositories/learning_program_repository.dart` | Abstract interface |
| `lib/features/programs/data/repositories/learning_program_repository_impl.dart` | Concrete impl |
| `lib/features/programs/presentation/providers/program_providers.dart` | Riverpod providers |
| `test/core/database/daos/learning_program_dao_test.dart` | DAO unit tests |
| `test/features/programs/data/repositories/learning_program_repository_impl_test.dart` | Repo unit tests |
| `test/story_acceptance/epic_15_programs_test.dart` | Story acceptance tests |

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/database/app_database.dart` | Add tables, DAO, bump schema to 10, migration + seed |
| `lib/core/database/app_database.g.dart` | Regenerated |
| `*.g.dart` / `*.freezed.dart` | Regenerated by `build_runner` |
