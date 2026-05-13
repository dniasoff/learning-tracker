# DNI-333 — 25.12 SyncEngine decomp Part 1 — FirestoreGateway, PushPipeline, PullPipeline

Status: review

Linear: https://linear.app/orvexai/issue/DNI-333

## Story

As a developer testing sync logic, I want the 3227-line `sync_engine.dart` split
into `FirestoreGateway`, `PushPipeline`, and `PullPipeline` so the sync subsystem
becomes testable in isolation and the god-object is broken up (NFR20, T2.9).

## Acceptance Criteria

1. `core/sync/firestore_gateway_impl.dart` is the only file in `lib/` that
   imports `cloud_firestore` (legacy `features/sync/data/*` and adjacent files
   are on a documented transitional allowlist scheduled for removal by
   DNI-334/335).
2. `core/sync/push_pipeline_impl.dart` (`OutboxPushPipeline implements PushPipeline`)
   drains the outbox table per entity kind with single-flight semantics — no
   overlapping pushes for the same kind. Different kinds run in parallel.
3. `core/sync/pull_pipeline.dart` paginates Firestore queries via the gateway
   and dispatches each page to an abstract `MergeDispatcher` (concrete
   `MergeRouter` lands in DNI-334).
4. Unit-level coverage of all three classes via test doubles in
   `test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart`.

The full thinning of the legacy `sync_engine.dart` to a coordinator <300 lines
happens after DNI-334 (MergeRouter) and DNI-335 (ListenerSupervisor) provide
the remaining building blocks.

## Tasks / Subtasks

- [x] Write red acceptance test exercising AC1/AC2/AC3.
- [x] Create `core/sync/firestore_gateway.dart` (abstract interface) +
      `FirestorePage` value type.
- [x] Create `core/sync/firestore_gateway_impl.dart` — only file importing
      `cloud_firestore`. Implements raw push + paginated `fetchPage`.
- [x] Create `core/sync/push_pipeline_impl.dart` — `OutboxPushPipeline` with
      per-kind single-flight chain.
- [x] Create `core/sync/pull_pipeline.dart` — paginates via gateway,
      dispatches to `MergeDispatcher`.
- [x] Add `make test-story-25.12` Makefile target.
- [x] `dart analyze --fatal-infos` clean on changed files.
- [x] `dart format` applied.

## File List

- `learning_tracker/lib/core/sync/firestore_gateway.dart` (new)
- `learning_tracker/lib/core/sync/firestore_gateway_impl.dart` (new)
- `learning_tracker/lib/core/sync/pull_pipeline.dart` (new)
- `learning_tracker/lib/core/sync/push_pipeline_impl.dart` (new)
- `learning_tracker/test/story_acceptance/epic_25_story_12_sync_decomp_part1_test.dart` (new)
- `Makefile` (modified: added `test-story-25.12` target)
- `docs/stories/implementation/DNI-333-sync-engine-decomp-part1-gateway-pipelines.md` (new)

## Dev Agent Record

- Schema unchanged (v13 from DNI-326).
- No new pub dependencies added; `fake_cloud_firestore` deferred to DNI-377 —
  unit tests here use plain Dart test doubles implementing the gateway
  interface, which is sufficient because the gateway is the only Firestore
  seam.
- Legacy `features/sync/data/sync_engine.dart` and `firestore_data_source.dart`
  remain untouched. The next two stories (DNI-334 MergeRouter and DNI-335
  ListenerSupervisor) replace their merge + listener responsibilities; after
  those land, the legacy SyncEngine collapses to a thin coordinator delegating
  to the three new classes.

## Change Log

- 2026-05-13 — Initial implementation. Acceptance test green (`make
  test-story-25.12` — 6 passing). Analyzer clean on changed paths.
