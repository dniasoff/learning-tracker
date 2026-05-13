# DNI-337 — 25.16: core/streak/ — event log + reducer + round-trip sync

**Status:** review
**Epic:** DNI-313 (E25 — schema + core foundation)
**Branch:** `dev-dni-337` (off `origin/dev` @ d6cbe89c)

## Story

As the streak invariant holder, I want `StreakEventLog` + `StreakReducer` (UTC days only) + `StreakStateProvider` + `StreakEventMerger`, so that streak is computed deterministically from an append-only event log, syncs round-trip across devices, and reconstitutes from `completion_events` on empty-log restore (FR2, FR3).

## Acceptance Criteria

1. `StreakEventLog` is a thin wrapper over the `streak_events` DAO with a single `append(StreakEvent)` method.
2. `StreakReducer` reads `streak_events` and returns `(currentStreak, maxStreak)` using **UTC day boundaries** from `LocalDayClock`.
3. `StreakStateProvider` is the only read path for streak values (`StreakService.recordCompletion` is removed).
4. `StreakEventMerger` (Story 25.13 / DNI-334) pushes and pulls `streak_events` round-trip.
5. Empty-log restore: when a user signs in on a new device with empty local `streak_events`, the reducer reconstitutes events from `completions` (one row per distinct UTC day).
6. Two devices writing completions on the same UTC day → UNIQUE constraint collapses to one row (`(profileId, eventTimestamp, eventType)` from Story 25.2 / DNI-323).

## Tasks/Subtasks

- [x] Acceptance test scaffold — `epic_25_story_16_streak_test.dart` (red → green, 14 tests).
- [x] `LocalDayClock` minimal interface in `core/time/`.
- [x] `core/streak/StreakEvent` value type + `StreakEventLog.append`.
- [x] `core/streak/StreakReducer` — pure `(events, today) → (current, max)`.
- [x] `core/streak/StreakRestorer.restoreIfEmpty` from `completions`.
- [x] `core/streak/StreakStateProvider.read/.watch`.
- [x] `core/sync/merge/StreakEventMerger.merge` (append-only, round-trip).
- [x] Rewire `dashboard_providers.dart::dashboardStreak` to `StreakStateProvider`.
- [x] Remove `StreakService.recordCompletion` + `reconcileFromEvents` and the completion-path callers.
- [x] Delete legacy `features/sync/domain/reducers/streak_reducer.dart`.
- [x] Migrate impacted tests (`streak_service_test`, `epic_08_gamification`, `epic_20_hard_tier_auth`, `completion_repository_impl`).
- [x] Acceptance test green; full regression: **2100 / 2100 tests pass**.
- [x] `dart analyze --fatal-infos`: 5 pre-existing baseline issues only (firebase_options scaffolding + 3 unrelated infos); zero new.
- [x] `dart format --set-exit-if-changed`: clean.

## Dev Agent Record

Agent: dev-331 (Claude Opus 4.7).

**Scope decision (AC3).** "StreakService.recordCompletion writes are removed" is interpreted as: remove the writer + its callers on the completion path + rewire the dashboard read path. Other transitional callers of `streakDao.getStreak()` (notifications, parent-mode, sync_engine, data export) continue to read the cached `streaks` snapshot; that snapshot is now stale-but-irrelevant for the streak count (the new read path bypasses it). A follow-up story (likely DNI-338 or a dedicated snapshot retirement) drops the `streaks` table entirely.

**Dependency note.** `LocalDayClock` (DNI-331) and `StreakEventMerger` infra (DNI-334) were both done but unmerged to `origin/dev`. This story landed a scope-minimal `LocalDayClock` interface (`nowUtc()`) — a strict subset of the DNI-331 surface; the eventual DNI-331 merge collapses to a no-op union. `StreakEventMerger` is shipped as a standalone class in `core/sync/merge/` that plugs into the DNI-334 `MergeRouter` once that lands.

## File List

New:
- `learning_tracker/lib/core/streak/streak_event.dart`
- `learning_tracker/lib/core/streak/streak_event_log.dart`
- `learning_tracker/lib/core/streak/streak_reducer.dart`
- `learning_tracker/lib/core/streak/streak_restorer.dart`
- `learning_tracker/lib/core/streak/streak_state_provider.dart`
- `learning_tracker/lib/core/sync/merge/streak_event_merger.dart`
- `learning_tracker/lib/core/time/local_day_clock.dart`
- `learning_tracker/test/story_acceptance/epic_25_story_16_streak_test.dart`
- `docs/stories/implementation/DNI-337-streak-event-log-reducer-sync.md`

Deleted:
- `learning_tracker/lib/features/sync/domain/reducers/streak_reducer.dart`

Modified:
- `learning_tracker/lib/features/dashboard/presentation/providers/dashboard_providers.dart` (+ `.g.dart`)
- `learning_tracker/lib/features/gamification/domain/services/streak_service.dart`
- `learning_tracker/lib/features/learning/data/repositories/completion_repository_impl.dart`
- `learning_tracker/lib/features/learning/presentation/providers/completion_providers.dart` (+ `.g.dart`)
- `learning_tracker/test/features/gamification/domain/services/streak_service_test.dart`
- `learning_tracker/test/features/learning/data/repositories/completion_repository_impl_test.dart`
- `learning_tracker/test/story_acceptance/epic_08_gamification_test.dart`
- `learning_tracker/test/story_acceptance/epic_20_hard_tier_auth_test.dart`
- `Makefile` (added `test-story-25.16` target)
- formatting-only changes from `dart format` on existing files (necessary for `make ci`).

## Change Log

- 2026-05-13: Initial implementation (DNI-337). 2100 / 2100 tests pass.
