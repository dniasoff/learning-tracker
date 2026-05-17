# Performance Findings — 2026-05-17 (I-6)

Static analysis of provider rebuild chains following the sync-engine rebuild. No DevTools / ADB available; findings are based on source reading.

---

## Top rebuild hotspots found

### H1 — `dashboardStreak` tears down its DB stream on every completion

**File:** `lib/features/dashboard/presentation/providers/dashboard_providers.dart:188`

`dashboardStreak` is an `@riverpod Stream<...>` that contained:
```dart
ref.watch<int>(completionCommittedProvider);
```
When `completionCommittedProvider` increments (once per task completion), Riverpod
tears down the entire stream provider and re-executes the `async*` body — which:
1. Creates a new `StreakStateProvider` instance.
2. Calls `_restorer.restoreIfEmpty()` (DB query).
3. Subscribes to a brand-new Drift `watch()` on `streak_events`.

This is redundant. `CompletionRepositoryImpl._createCompletion` already writes a
`streak_events` row on every completion, so the existing Drift reactive query fires
automatically. The `completionCommittedProvider` watch just caused an extra full
stream restart for no additional data freshness.

**Fix applied:** Removed `ref.watch<int>(completionCommittedProvider)` from
`dashboardStreak`. The provider now relies solely on its Drift DB stream.

---

### H2 — `_snapshotMissingProgramAssignments` ran on every completion re-evaluation

**File:** `lib/features/scheduler/presentation/providers/scheduler_providers.dart:303`
**Supporting file:** `lib/features/scheduler/data/repositories/daily_plan_repository.dart:34`

`allDailyTasksProvider` watches `completionCommittedProvider` (correctly — the task
list must shrink after each completion). On every re-evaluation it ran:
```dart
final snapshotMissingProgramAssignments =
    await _snapshotMissingProgramAssignments(...);
```
This function iterates every active curriculum, queries `tracks`, `profile_programs`,
resolves `CalendarProgramRegistry` entries, fetches calendar service entries, and
loads full curriculum content items — purely to guard against a stale snapshot built
on a previous day. This guard is only meaningful immediately after the snapshot is
first created; on every subsequent read (including completion-triggered ones) the
snapshot already exists and the guard is a no-op that wastes several DB round-trips.

**Fix applied:**
- `DailyPlanRepository.getOrSnapshotPlan` now returns
  `({List<DailyTask> tasks, bool isNew})` instead of bare `List<DailyTask>`.
- `allDailyTasksProvider` passes `planResult.isNew` as a gate:
  ```dart
  final snapshotMissingProgramAssignments = planResult.isNew
      ? await _snapshotMissingProgramAssignments(...)
      : false;
  ```
  On every completion-triggered re-evaluation the plan is not new, so the expensive
  check is skipped entirely.

---

### H3 — `DashboardBody` rebuilt on every completion even when global points unchanged

**File:** `lib/features/dashboard/presentation/widgets/dashboard_body.dart:117`

`DashboardBody` watched `dashboardGlobalPointsProvider` directly, which internally
watches `completionCommittedProvider`. For adult users the provider always returns 0;
for child users points typically don't change on every single completion. Without
`.select()`, any `AsyncValue` re-emission (even with the same value) forced a full
`DashboardBody` rebuild — rebuilding the entire `ListView` including the 460-px
carousel.

**Fix applied:** Switched to `.select()` to gate rebuilds on actual value changes:
```dart
final totalPoints = ref.watch(
  dashboardGlobalPointsProvider.select((v) => v.asData?.value ?? 0),
);
```
The `DashboardBody` now only rebuilds when the integer changes, not on every
`completionCommittedProvider` increment.

---

## Summary of changes

| File | Change |
|------|--------|
| `lib/features/dashboard/presentation/providers/dashboard_providers.dart` | Removed `ref.watch<int>(completionCommittedProvider)` from `dashboardStreak` |
| `lib/features/scheduler/data/repositories/daily_plan_repository.dart` | `getOrSnapshotPlan` returns `({List<DailyTask> tasks, bool isNew})` |
| `lib/features/scheduler/presentation/providers/scheduler_providers.dart` | Skip `_snapshotMissingProgramAssignments` when `!planResult.isNew` |
| `lib/features/dashboard/presentation/widgets/dashboard_body.dart` | Use `.select()` on `dashboardGlobalPointsProvider` to narrow rebuild scope |
| `test/features/scheduler/data/repositories/daily_plan_repository_test.dart` | Updated tests to use `result.tasks` / `result.isNew` from new return type |

All tests pass (`make ci`). No behaviour changes — only the frequency and cost of
provider re-evaluation on each completion event is reduced.

---

## What remains (requires DevTools to validate)

1. **`dashboardChildNextReward` rebuild cost** — for child-mode users, this provider
   does a full multi-track loop with DB queries on every completion. It watches
   `completionCommittedProvider` and there is no `.select()` guard. Statically this
   is expensive but whether it causes perceptible latency depends on track count and
   DB speed. A DevTools timeline trace during task completion would confirm.

2. **`DashboardScreen` + `DashboardBody` rebuild cascade** — `DashboardScreen` and
   `DashboardBody` are both `ConsumerWidget`s. Both watch `allDailyTasksProvider`
   (screen via `dashboardStreak`, body directly). When the provider emits,
   `DashboardScreen.build()` re-runs, which constructs a new `DashboardBody(...)`,
   which then also re-runs its own `build()`. The `dashboardModelProvider` composition
   layer exists but is unused — if `DashboardScreen` were refactored to use it and
   pass data down as constructor parameters, `DashboardBody` could become a
   `StatelessWidget`, eliminating one full subtree rebuild per completion. This is
   a worthwhile refactor but is larger in scope.

3. **`_snapshotMissingActiveCurriculum` check** — still runs on every completion
   (it only queries the active curricula table and does a set intersection, so it's
   cheap). Could be further gated on `planResult.isNew` if profiling shows it matters.
