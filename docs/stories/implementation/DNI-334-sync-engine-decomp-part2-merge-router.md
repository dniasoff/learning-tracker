# DNI-334 — 25.13 SyncEngine decomp Part 2 — MergeRouter + sealed EntityMerger

Status: review

Linear: https://linear.app/orvexai/issue/DNI-334

## Story

As a developer adding a new sync-able entity, I want `MergeRouter` to dispatch
to per-kind `EntityMerger<T>` sealed strategy classes so that adding a new
entity is a one-file addition rather than a 12-touch sprawl (NFR20, T2.9).

## Acceptance Criteria

1. `MergeRouter implements MergeDispatcher` (the interface from DNI-333) and
   dispatches by entity kind to an `EntityMerger` implementation.
2. Seven sealed mergers live in `lib/core/sync/merge/`, one per file:
   `CompletionEventMerger`, `StreakEventMerger`, `LearnerProfileMerger`,
   `TrackConfigMerger`, `BookmarkMerger`, `SettingsMerger`,
   `StageDefinitionMerger`.
3. `StageDefinitionMerger` merges all fields (`scheduleType`, `daysOfWeek`,
   `rollingWindowSize`, `delayDays`, etc.) — not just `delayDays`. Closes T1.9.
4. `MergeRules` (`features/sync/domain/merge_rules.dart`) is load-bearing —
   every LWW merger imports it and calls `remoteIsNewer`.
5. Adding a new entity touches only the new merger file and the
   `MergeRouter` constructor's `mergers` map (structural acceptance test
   enforces this by verifying that `merge_router.dart` is the only file
   outside `entity_merger.dart` that enumerates the full kind set).

## Tasks / Subtasks

- [x] Write red acceptance test exercising AC1..AC5.
- [x] Create `lib/core/sync/merge/entity_merger.dart` — sealed
      `EntityMerger` interface, `EntityKind` taxonomy, `MergeStore` adapter
      seam.
- [x] Create `lib/core/sync/merge/merge_router.dart` — implements
      `MergeDispatcher`, switches by kind to the injected merger.
- [x] Create seven concrete merger files under `lib/core/sync/merge/`.
- [x] Add `make test-story-25.13` Makefile target.
- [x] `dart analyze --fatal-infos` clean on new files.
- [x] `dart format` applied.

## File List

- `learning_tracker/lib/core/sync/merge/entity_merger.dart` (new)
- `learning_tracker/lib/core/sync/merge/merge_router.dart` (new)
- `learning_tracker/lib/core/sync/merge/completion_event_merger.dart` (new)
- `learning_tracker/lib/core/sync/merge/streak_event_merger.dart` (new)
- `learning_tracker/lib/core/sync/merge/learner_profile_merger.dart` (new)
- `learning_tracker/lib/core/sync/merge/track_config_merger.dart` (new)
- `learning_tracker/lib/core/sync/merge/bookmark_merger.dart` (new)
- `learning_tracker/lib/core/sync/merge/settings_merger.dart` (new)
- `learning_tracker/lib/core/sync/merge/stage_definition_merger.dart` (new)
- `learning_tracker/test/story_acceptance/epic_25_story_13_merge_router_test.dart` (new)
- `Makefile` (modified: added `test-story-25.13` target)
- `docs/stories/implementation/DNI-334-sync-engine-decomp-part2-merge-router.md` (new)

## Dev Agent Record

- Branched from `dev-dni-333` (`b2486d55`) so the `MergeDispatcher` /
  `MergeOutcome` interfaces from DNI-333 are available. When dev-dni-333
  merges to dev, this branch should rebase cleanly.
- Schema unchanged.
- No new pub dependencies — mergers talk to a small `MergeStore` adapter
  interface; concrete `DriftMergeStore` will be wired up in DNI-335 once
  the listener supervisor exists to drive sustained pulls and feed real
  pages from Firestore. This keeps the merger unit tests free of
  Drift / Firestore wiring.
- Append-only mergers (`CompletionEventMerger`, `StreakEventMerger`) use
  `MergeStore.insertIfAbsent` keyed by `firestore_id` (or a deterministic
  composite key) — the composite-UNIQUE indexes from DNI-323 already
  deduplicate at the DB level so a duplicate pull is a no-op.
- LWW mergers all consult `MergeRules.remoteIsNewer` from
  `features/sync/domain/merge_rules.dart`. Direct import is verified by
  the acceptance test (structural import-check + behavioural drop-when-
  older test on `BookmarkMerger`).
- `StageDefinitionMerger.mergedFields` lists every preserved field so a
  future developer cannot regress T1.9 without explicitly editing the
  list (which would also fail review by inspection).

## Change Log

- 2026-05-13 — Initial implementation. `make test-story-25.13` — 10/10
  passing. `make test-story-25.12` (DNI-333 regression) — 6/6 passing.
  `make epic_25_schema_core_test.dart` (DNI-326 outbox regression) — 13/13
  passing. Analyzer clean on changed paths.
