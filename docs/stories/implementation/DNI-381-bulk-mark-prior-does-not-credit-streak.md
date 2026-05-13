# DNI-381 — 27.5: Integration test — `bulk_mark_prior_does_not_credit_streak`

Status: review

## Story

As a developer trusting Story 26.27,
I want an integration test asserting that bulk-mark-prior does not credit
streak at any stage,
So that future changes can't silently reintroduce the bug (NFR13).

## Acceptance Criteria

**Given** the test scaffolding from Story 27.1 is available,
**When** the test runs,
**Then** it creates a fresh in-memory DB, simulates a bulk-mark-prior over 50
items across stages 1, 2, and 3,
**And** asserts `StreakStateProvider.read()` returns `currentStreak == 0` and
`maxStreak == 0`
**And** asserts the `streak_events` table contains zero rows attributable to
the bulk-mark batch.

## Tasks / Subtasks

- [x] Confirm bulk-mark-prior call path skips streak teeing across stages
  - [x] Stage-1 path (`_bulkMarkCompletePriorOptimized`) — already routes
        through `CompletionWriter.commit`, no streak append
  - [x] Stage 2+ slow path — `_markCompleteSingleInTransaction` was teeing
        streak events; gated on `awardGamificationPoints` so prior-learning
        bulk marks no longer credit streak
- [x] Write integration test (red → green)
  - Path: `learning_tracker/test/story_acceptance/epic_27_story_05_bulk_mark_prior_test.dart`
  - 50 sefariaRefs, `stageIds: [1, 2, 3]`, `awardGamificationPoints: false`
  - Assert `StreakStateProvider.read()` returns `currentStreak == 0`,
    `maxStreak == 0`
  - Assert `streak_events` table count == 0 for the test profile
- [x] Make target `test-story-27.5`

## Dev Agent Record

- Base: `origin/dev` @ `6ffe6d54` + cherry-pick of DNI-337 (`df0aa11f`).
- Conflict resolution during DNI-337 cherry-pick:
  - `learning_tracker/lib/core/time/local_day_clock.dart`     → kept origin/dev (full provider)
  - `learning_tracker/lib/core/sync/merge/streak_event_merger.dart` → kept origin/dev (MergeStore seam)
  - `learning_tracker/lib/features/profiles/data/repositories/profile_repository_impl.dart` → kept origin/dev (`DateTimeFactory.nowUtc()`)
  - `Makefile` → kept all targets from both sides
- DNI-337's own acceptance suite (`epic_25_story_16_streak_test.dart`) still
  references the old `StreakEventMerger(db)` ctor and must be updated when
  DNI-337 merges through the merger; that is out of DNI-381 scope.

## File List

- `learning_tracker/test/story_acceptance/epic_27_story_05_bulk_mark_prior_test.dart` (new)
- `learning_tracker/lib/features/learning/data/repositories/completion_repository_impl.dart`
  (fix: skip `_appendStreakEvent` when `awardGamificationPoints == false`)
- `Makefile` (add `test-story-27.5` target)

## Change Log

- 2026-05-13 — initial implementation
