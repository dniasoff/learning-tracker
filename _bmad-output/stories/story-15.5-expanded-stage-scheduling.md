# Story 15.5 — Expanded Stage Scheduling Model (DNI-113)

## Story Overview

Currently every stage uses a single `delay_days` field to determine when chazarah is due. This works for the default "review N days after previous stage completion" pattern, but cannot express two scheduling models required by programs like Oraysa:

1. **Weekly (day-of-week)** — review all items from the current week on specific days (e.g., Friday/Shabbos).
2. **Rolling window** — always keep the most recent N items in active rotation (e.g., back-20 dapim).

This story adds a `schedule_type` enum and type-specific fields to the stage definition, updates the scheduler engine to generate tasks for all three types, and migrates existing data without loss.

---

## Acceptance Criteria

1. **Schema**: `stage_definitions` table gains three new columns: `schedule_type TEXT NOT NULL DEFAULT 'delay'`, `days_of_week TEXT NULL`, `rolling_window_size INTEGER NULL`.
2. **Migration**: Existing rows receive `schedule_type = 'delay'`; `days_of_week` and `rolling_window_size` remain NULL. No data loss. Schema version bumps from 9 to 10.
3. **Domain model**: `StageDefinition` (Freezed) and `SchedulerStage` gain matching fields. A new `ScheduleType` enum (`delay`, `weekly`, `rolling`) is defined.
4. **Delay-based scheduling**: Behavior is unchanged from current implementation. `delayDays` is used; new fields are ignored.
5. **Weekly scheduling**: When `schedule_type = 'weekly'` and today's ISO weekday is in `days_of_week`, the scheduler generates tasks for all items whose previous stage was completed during the current week (Monday-based). `delayDays` is ignored for these stages.
6. **Rolling-window scheduling**: When `schedule_type = 'rolling'`, the scheduler generates tasks for the most recent `rolling_window_size` items that have completed the previous stage but not this stage. No date-based due calculation; the window always includes the N most-recently-completed items. `delayDays` is ignored.
7. **Stage editor UI**: The add/edit dialog lets the user choose a schedule type and shows the appropriate fields (delay days, day-of-week checkboxes, or window size).
8. **Sync**: Push and pull correctly serialize/deserialize the new fields. Unknown `schedule_type` values from newer clients fall back to `delay`.
9. **Validation**: `days_of_week` values must be in 1..7. `rolling_window_size` must be >= 1. `delayDays` must be >= 0 for delay type.
10. **Backward compatibility**: All existing tests continue to pass. Stages without the new fields behave identically to before.

---

## Architecture & Design Notes

### Schedule Type Enum

```dart
// lib/core/enums/schedule_type.dart
enum ScheduleType {
  delay,   // existing behavior
  weekly,  // day-of-week scheduling
  rolling, // rolling window
}
```

Store as a `TEXT` column in Drift (not an integer) for forward-compatible parsing. Use a converter or manual mapping in the DAO/repository layer. If an unknown value is read (e.g., from a newer client version), default to `delay`.

### Drift Table Changes

```dart
// lib/core/database/tables/stage_definitions.dart
class StageDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get curriculumId => text()();
  IntColumn get stageOrder => integer()();
  TextColumn get stageName => text()();
  IntColumn get delayDays => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  // NEW
  TextColumn get scheduleType => text().withDefault(const Constant('delay'))();
  TextColumn get daysOfWeek => text().nullable()(); // JSON array: "[5,6]"
  IntColumn get rollingWindowSize => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {curriculumId, stageOrder},
  ];
}
```

`days_of_week` is stored as a JSON-encoded list of ints (e.g., `"[5,6]"` for Friday/Shabbos). This avoids adding a junction table for a small, fixed-size list (max 7 values). Parse with `jsonDecode` in the repository layer.

### Domain Model Changes

```dart
// lib/features/stages/domain/models/stage_definition.dart
@freezed
abstract class StageDefinition with _$StageDefinition {
  const factory StageDefinition({
    required int id,
    required CurriculumId curriculumId,
    required int stageOrder,
    required String stageName,
    required int delayDays,
    required bool isDefault,
    required ScheduleType scheduleType,
    List<int>? daysOfWeek,      // 1=Mon..7=Sun (ISO 8601)
    int? rollingWindowSize,
  }) = _StageDefinition;
}
```

### Scheduler-Local SchedulerStage Changes

```dart
// lib/features/scheduler/domain/repositories/scheduler_stage_repository.dart
class SchedulerStage {
  const SchedulerStage({
    required this.id,
    required this.stageOrder,
    required this.stageName,
    required this.delayDays,
    required this.scheduleType,
    this.daysOfWeek,
    this.rollingWindowSize,
  });

  final int id;
  final int stageOrder;
  final String stageName;
  final int delayDays;
  final ScheduleType scheduleType;
  final List<int>? daysOfWeek;
  final int? rollingWindowSize;
}
```

### Scheduler Engine Behavior by Type

The core scheduling loop in `SchedulerEngine.generateDailyTasks()` (lines 89-139 of `scheduler_engine.dart`) currently assumes all stages are delay-based. The loop must branch on `stage.scheduleType`:

#### Delay (existing, no change)

```
if previousStage completed AND thisStage not completed:
  dueDate = previousCompletedAt + stage.delayDays
  if dueDate <= today: emit task
```

#### Weekly

```
if today.weekday NOT IN stage.daysOfWeek: skip this stage entirely
// Find items whose previous stage was completed this week (Mon..today)
weekStart = today - (today.weekday - 1) days  // Monday
for each item where:
  previousStage completedAt >= weekStart AND
  thisStage NOT completed (or completedAt < weekStart):
    emit task with priority=scheduledChazara
```

Key design decisions:
- "This week" means ISO week starting Monday, ending Sunday.
- If an item's previous stage was completed before this week, it is NOT included -- it was due last week.
- If the user completes the weekly review stage for an item, it should not reappear until the following week (guard: `thisStage.completedAt >= weekStart`).
- Multiple days in `daysOfWeek` (e.g., [5, 6] for Fri+Shabbos) means the tasks appear on both days. The user can complete on either.

#### Rolling Window

```
// Get all items that have completed the previous stage, ordered by
// previousStage.completedAt DESC. Take the first N (rolling_window_size).
// For each of those N items where thisStage is NOT completed:
//   emit task with priority=scheduledChazara
```

Key design decisions:
- The window is always based on the N most recently completed items for the previous stage.
- As new items enter the window, old ones drop out automatically.
- Rolling-window tasks are always "due" (no date calculation). They appear every day until completed.
- Once an item is completed for the rolling stage, it leaves the "not completed" set. If it is still within the top-N window, it does not reappear.

### Migration (v9 -> v10)

```dart
if (from < 10) {
  await customStatement(
    "ALTER TABLE stage_definitions ADD COLUMN schedule_type TEXT NOT NULL DEFAULT 'delay'",
  );
  await customStatement(
    'ALTER TABLE stage_definitions ADD COLUMN days_of_week TEXT',
  );
  await customStatement(
    'ALTER TABLE stage_definitions ADD COLUMN rolling_window_size INTEGER',
  );
}
```

Three `ALTER TABLE ADD COLUMN` statements. SQLite supports these individually. The `DEFAULT 'delay'` ensures existing rows are migrated without a data migration step.

### Sync Serialization Changes

**Push** (`_pushStages` in `stage_definition_repository_impl.dart`):

```dart
'stages': stages.map((s) => {
  'stage_order': s.stageOrder,
  'stage_name': s.stageName,
  'delay_days': s.delayDays,
  'is_default': s.isDefault,
  'schedule_type': s.scheduleType,           // NEW
  'days_of_week': s.daysOfWeek,              // NEW (nullable)
  'rolling_window_size': s.rollingWindowSize, // NEW (nullable)
}).toList(),
```

**Pull** (`_mergeSettings` in `sync_engine.dart`):

```dart
scheduleType: s['schedule_type'] as String? ?? 'delay',
daysOfWeek: s['days_of_week'] as String?,
rollingWindowSize: s['rolling_window_size'] as int?,
```

The `?? 'delay'` fallback ensures older sync payloads (without `schedule_type`) are handled gracefully.

---

## Implementation Steps

### Step 1: Add ScheduleType enum
- Create `lib/core/enums/schedule_type.dart` with `delay`, `weekly`, `rolling` values.
- Add `storageKey` extension or use `.name` since the enum names match the DB values.

### Step 2: Update Drift table
- Add three columns to `StageDefinitions` in `lib/core/database/tables/stage_definitions.dart`.
- Bump `schemaVersion` to 10 in `app_database.dart`.
- Add migration block `if (from < 10)` with three ALTER TABLE statements.
- Run `dart run build_runner build --delete-conflicting-outputs` to regenerate Drift code.

### Step 3: Update domain model
- Add `scheduleType`, `daysOfWeek`, `rollingWindowSize` fields to the Freezed `StageDefinition` model.
- Run build_runner to regenerate `.freezed.dart`.

### Step 4: Update DAO / repository layer
- Update `_rowToModel` in `StageDefinitionRepositoryImpl` to parse `scheduleType` (text -> enum), `daysOfWeek` (JSON string -> `List<int>`), and `rollingWindowSize`.
- Update `addStage`, `updateStage`, `reorderStages`, `resetToDefaults`, `initializeDefaults` to include the new fields in `StageDefinitionsCompanion`.
- Update `_pushStages` to serialize new fields.
- Update `StageDefinitionRepository` interface: `addStage` and `updateStage` signatures gain optional new params.

### Step 5: Update SchedulerStage and its repository
- Add `scheduleType`, `daysOfWeek`, `rollingWindowSize` to `SchedulerStage`.
- Update `SchedulerStageRepositoryImpl` to map the new DB columns.

### Step 6: Update SchedulerEngine
- Refactor the chazara-due loop (lines 89-139 of `scheduler_engine.dart`) to branch on `stage.scheduleType`.
- Extract helper methods: `_processDelayStage`, `_processWeeklyStage`, `_processRollingStage`.
- Each helper returns a list of `DailyTask` to add to overdue/scheduled buckets.

### Step 7: Update sync engine
- Update `_mergeSettings` in `sync_engine.dart` to deserialize new fields in the `StageDefinitionsCompanion.insert()` call.
- Add fallback for missing `schedule_type` key.

### Step 8: Update stage editor UI
- Add a `ScheduleType` dropdown to `_showStageFormDialog` in `stage_editor_screen.dart`.
- Conditionally show: delay days field (delay), day-of-week checkboxes (weekly), or window size field (rolling).
- Update `StageRowWidget` subtitle to display the schedule type description.
- Update `StageEditorNotifier.addStage` / `updateStage` to pass new params.

### Step 9: Update CurriculumDefaults
- Existing defaults use delay type. Add `scheduleType: ScheduleType.delay` to `DefaultStageDefinition`.
- No default stages use weekly/rolling (those are user-configured for specific programs).

### Step 10: Update tests
- See Test Plan below.

---

## Dev Notes

### Migration Safety
- SQLite `ALTER TABLE ADD COLUMN` with a `DEFAULT` value is safe and does not rewrite the table. Existing rows automatically get the default.
- Nullable columns (`days_of_week`, `rolling_window_size`) default to NULL with no explicit DEFAULT needed.
- The migration is non-destructive and idempotent if re-run (SQLite will error on duplicate column, but the `if (from < 10)` guard prevents that).

### Enum Storage in Drift
- Store `schedule_type` as `TEXT`, not `INTEGER`, to be self-documenting and forward-compatible. If a future version adds a fourth type, older clients reading the DB will see an unknown string and can fall back to `delay`.
- Parse with: `ScheduleType.values.firstWhere((e) => e.name == raw, orElse: () => ScheduleType.delay)`.

### days_of_week JSON Encoding
- Stored as a JSON array string: `"[5,6]"`.
- Use `dart:convert` `jsonEncode` / `jsonDecode` in the repository layer.
- The Drift table stores it as plain `TEXT`. No Drift type converter needed (handle in repo).

### Rolling Window Edge Cases
- If `rolling_window_size` is larger than the number of items that have completed the previous stage, all of them are included.
- If the user changes the window size, the new size takes effect immediately on next scheduler run.
- Items that have already been completed for the rolling stage are excluded from the active window.

### Weekly Edge Cases
- If today is Sunday (weekday=7) and `days_of_week = [5, 6]`, items from this week that were NOT completed on Fri/Sat are still visible until the week resets on Monday.
- The "week" boundary is Monday 00:00 UTC. All date comparisons in the scheduler already use UTC dates.

### Backward Compatibility with Sync
- Older clients that don't know about `schedule_type` will ignore the extra JSON keys when pulling. When they push, the keys will be absent. The pull code uses `?? 'delay'` to handle this.
- Older data in Firestore without `schedule_type` will be pulled as `delay` type.

---

## Test Plan

### Unit Tests: ScheduleType Enum
- File: `test/core/enums/schedule_type_test.dart`
- Parse known values: `'delay'`, `'weekly'`, `'rolling'`.
- Parse unknown value falls back to `delay`.

### Unit Tests: SchedulerEngine — Delay Type
- File: `test/features/scheduler/domain/services/scheduler_engine_test.dart` (extend existing)
- Existing tests continue to pass (delay stages with `scheduleType: ScheduleType.delay`).
- Explicitly set `scheduleType` on `SchedulerStage` in existing test helpers.

### Unit Tests: SchedulerEngine — Weekly Type
- File: `test/features/scheduler/domain/services/scheduler_engine_test.dart` (new group)
- **Today is a scheduled day**: Items completed this week for previous stage appear as tasks.
- **Today is NOT a scheduled day**: No tasks generated for the weekly stage.
- **Item completed before this week**: Not included.
- **Item already reviewed this week**: Not included.
- **Multiple days in daysOfWeek**: Tasks appear on each day.
- **Week boundary**: Monday start, items from previous week excluded.

### Unit Tests: SchedulerEngine — Rolling Type
- File: `test/features/scheduler/domain/services/scheduler_engine_test.dart` (new group)
- **Window of 3, 5 items completed previous stage**: Only 3 most recent appear.
- **Window of 20, only 10 items completed**: All 10 appear.
- **Item completed for rolling stage**: Excluded from tasks.
- **Window size changes**: New size reflected immediately.
- **No items completed previous stage**: No tasks.

### Unit Tests: StageDefinitionRepositoryImpl
- File: `test/features/stages/data/repositories/stage_definition_repository_impl_test.dart` (extend or create)
- `addStage` with `scheduleType: weekly, daysOfWeek: [5, 6]` persists correctly.
- `addStage` with `scheduleType: rolling, rollingWindowSize: 20` persists correctly.
- `updateStage` changes schedule type.
- `getStagesForCurriculum` returns correct parsed fields.
- `_pushStages` serializes new fields.

### Unit Tests: Sync Merge
- Extend sync engine tests to verify `_mergeSettings` handles payloads with and without `schedule_type`.

### Integration / Widget Tests: Stage Editor
- Add/edit dialog shows correct fields per schedule type.
- Switching type hides/shows appropriate inputs.
- Validation: days_of_week must have at least one day selected for weekly; rolling_window_size >= 1.

### Migration Test
- Create a v9 database, run migration to v10, verify columns exist and existing rows have `schedule_type = 'delay'`.

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/core/enums/schedule_type.dart` | `ScheduleType` enum definition |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/core/database/tables/stage_definitions.dart` | Add `scheduleType`, `daysOfWeek`, `rollingWindowSize` columns |
| `lib/core/database/app_database.dart` | Bump `schemaVersion` to 10, add migration block |
| `lib/features/stages/domain/models/stage_definition.dart` | Add new fields to Freezed model |
| `lib/features/stages/domain/repositories/stage_definition_repository.dart` | Update `addStage`/`updateStage` signatures |
| `lib/features/stages/data/repositories/stage_definition_repository_impl.dart` | Parse/serialize new fields, update all mutation methods, update `_pushStages` |
| `lib/features/stages/presentation/providers/stage_providers.dart` | Update `addStage`/`updateStage` notifier methods |
| `lib/features/stages/presentation/screens/stage_editor_screen.dart` | Schedule type picker, conditional form fields |
| `lib/features/stages/presentation/widgets/stage_row_widget.dart` | Display schedule type in subtitle |
| `lib/features/scheduler/domain/repositories/scheduler_stage_repository.dart` | Add fields to `SchedulerStage` |
| `lib/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart` | Map new DB columns to `SchedulerStage` |
| `lib/features/scheduler/domain/services/scheduler_engine.dart` | Branch scheduling logic by type, add weekly/rolling helpers |
| `lib/features/sync/data/sync_engine.dart` | Deserialize new fields in `_mergeSettings` |
| `lib/core/constants/curriculum_defaults.dart` | Add `scheduleType` to `DefaultStageDefinition` |
| `test/features/scheduler/domain/services/scheduler_engine_test.dart` | Update `SchedulerStage` construction, add weekly/rolling test groups |
