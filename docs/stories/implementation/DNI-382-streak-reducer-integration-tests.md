# DNI-382 — 27.6: Integration tests — streak reducer reconciles + cloud restore

Status: in-progress

## Story

**As a** developer trusting Stories 25.16 and 25.17,
**I want** integration tests proving the reducer reconciles correctly from the event log and cloud restore preserves streak,
**So that** the streak-restore-from-completions reconstitution is verified (NFR13, FR2, FR3).

## Acceptance Criteria

1. **Reducer reconciles** — appending a known sequence of streak events via
   `StreakEventLog.append(inMemoryDb(), …)` and calling `StreakReducer.reduce()`
   returns the expected `(currentStreak, maxStreak)` pair.
2. **Cloud restore preserves streak** — starting with a fresh device (empty
   `streak_events`), pulling `completion_events` from a fake Firestore and
   running the cloud-restore path reconstitutes events (one per distinct UTC
   day) and the reducer computes the correct streak.

## Tasks / Subtasks

- [x] Cherry-pick DNI-377 (test helpers) and DNI-337 (`core/streak/`) into the
      worktree; resolve `LocalDayClock` / `StreakEventMerger` /
      `DateTimeFactory` conflicts in favour of `origin/dev`.
- [x] Run `build_runner` so the streak/Drift generated files are present.
- [x] AC1 — reducer reconciles test (red → green).
- [x] AC2 — cloud-restore test (red → green).
- [x] `make test-story-27.6` + `make test-epic-27` both green.
- [x] `dart analyze --fatal-infos` clean for files added by this story.
- [x] Story file + Linear comments updated.

## Dev Agent Record

- Agent: dev-336 (Opus 4.7, 1M context)
- Worktree: `/tmp/dev-dni-382` on branch `dev-dni-382` (base `origin/dev` =
  `ddd96a50`)
- Cherry-picks applied to satisfy file-path expectations in the brief:
  - `9938b579` → DNI-377 test infra (`test/helpers/{drift_memory,firestore_fake,golden_runner}.dart`)
  - `df0aa11f` → DNI-337 `core/streak/` (StreakEvent, StreakEventLog,
    StreakReducer, StreakRestorer, StreakStateProvider, StreakEventMerger).
    Canonical-rule conflict resolutions applied:
    - `core/time/local_day_clock.dart` → take `origin/dev`
    - `core/sync/merge/streak_event_merger.dart` → take `origin/dev`
      (uses MergeStore seam from DNI-334)
    - `lib/features/profiles/.../profile_repository_impl.dart` → keep
      `DateTimeFactory.nowUtc()`
    - `Makefile` → union of both target sets
- Pre-existing collision noted: DNI-337's AC4/AC6 acceptance test
  (`epic_25_story_16_streak_test.dart`) calls `StreakEventMerger(db)` but the
  origin/dev merger uses `{required MergeStore store}`. This is a known DNI-337
  cherry-pick issue that the **batch-4 merger** will fix — it is not in scope
  for DNI-382 and does not affect the new tests added by this story.

## File List

- `docs/stories/implementation/DNI-382-streak-reducer-integration-tests.md` (new)
- `learning_tracker/test/story_acceptance/epic_27_story_06_streak_reconciles_test.dart` (new)
- `learning_tracker/Makefile` — add `test-story-27.6` target, update `test-epic-27` glob

## Change Log

| Date       | Change |
|------------|--------|
| 2026-05-13 | Initial implementation of AC1 + AC2 integration tests |
