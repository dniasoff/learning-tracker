# DNI-336 — 25.15 core/learning/CompletionWriter — single transactional commit path

## Status
review

## Story
**As** any UI that records a completion,
**I want** one `CompletionWriter.commit(CompletionCommand)` call that inserts the
projection row and outbox row in one DB transaction,
**So that** completions are atomic, idempotent, and side-effect-driven via the outbox
rather than via 14-provider invalidation cascades (FR15, T2.7).

## Acceptance Criteria
See Linear DNI-336. The orchestrator narrowed the schema-touching scope:
- `completion_events` insertion is deferred to once DNI-323 lands (table not on `dev` yet).
- The `completionCommittedProvider` reader-screen swap is Story 26.13.
- This story delivers the transactional writer infrastructure: `completions` row + `outbox` row, atomic; freezed `CompletionCommand`; Riverpod provider; migration of user-initiated call sites.

## Tasks/Subtasks

- [x] **T1. Define `CompletionCommand` freezed value type**
  - [x] Create `lib/core/learning/completion_command.dart` with non-nullable identity fields
  - [x] Run `dart run build_runner build`
  - [x] Tests: equality, all fields required at construction
- [x] **T2. Implement `CompletionWriter`**
  - [x] Create `lib/core/learning/completion_writer.dart`
  - [x] `commit(CompletionCommand)` opens a transaction, inserts completion + outbox row
  - [x] Rollback contract: if either insert throws, neither row persists
  - [x] Idempotency: re-committing the same `(profileId, sefariaRef, stageId, trackType)` returns the existing row without writing a new outbox row
  - [x] Tests: happy path (both rows persisted), outbox-failure rollback, duplicate-command no-op
- [x] **T3. Riverpod provider**
  - [x] Create `lib/core/learning/completion_writer_providers.dart` exposing `completionWriterProvider`
  - [x] Run build_runner; verified `.g.dart` generates
- [x] **T4. Migrate user-initiated call sites in `completion_repository_impl.dart`**
  - [x] Replace direct `completionDao.insertCompletion(...)` in `_createCompletion` with `CompletionWriter.commit`
  - [x] Replace bulk batch path with a loop of `CompletionWriter.commit` calls (the bulk-prior path)
  - [x] Existing outer transaction in `markComplete` still applies; `CompletionWriter` uses a Drift savepoint for the inner transaction
  - [x] Leave `sync_engine.dart:1085` untouched (incoming pull — must NOT enqueue outbox)
- [x] **T5. Acceptance tests**
  - [x] Added `test/story_acceptance/epic_25_story_15_completion_writer_test.dart` (7 tests, all green)
  - [x] Added `make test-story-25.15` Makefile target
- [x] **T6. Regression sweep**
  - [x] `make test-epic-25` green (19 tests)
  - [x] `make test-story-25.15` green (7 tests)
  - [x] Full `flutter test test/` green (1766 tests passed, 103 skipped, 0 failed)
  - [x] `dart analyze` clean on all touched files (the 2 errors and 3 infos remaining in `make analyze` output are pre-existing on `dev` and unrelated to this story: `firebase_options.dart` is git-ignored / generated locally, plus 3 info-only lints in test files outside this story's scope)

## Dev Notes

### Architecture
- The outbox table (DNI-326) is the side-effect bus. Writing both rows in the same Drift transaction guarantees that a completion either becomes visible AND queued for cloud push, or neither.
- The `completion_events` table from DNI-323 will become the third row in the transaction once it merges. The writer is built with that future shape in mind: a single `commit()` method that callers don't have to think about.
- Incoming Firestore pulls (`sync_engine.dart:1085`) must continue to bypass the outbox — otherwise we'd loop remote writes back as outbox pushes.

### Idempotency
The existing repository already checks for a duplicate completion (same `(profileId, sefariaRef, stageId, trackType)`) and returns the existing row without writing. The writer must preserve this so a double-tap on the complete button doesn't double-enqueue an outbox row. The writer does the dup-check inside the same transaction.

### Outbox payload schema
Following the Story 25.5 test fixtures, payload is JSON with the entity fields. `entityKey` is `<profileId>:<sefariaRef>:<stageId>:<trackType>` so the OutboxProcessor's idempotency-on-retry can dedupe.

## Dev Agent Record

### Debug Log
- 2026-05-13: Started DNI-336. Scope reviewed against orchestrator context — see Linear comment for the `completion_events` and reader-screen deferral rationale.

### Completion Notes
- `CompletionWriter.commit(CompletionCommand)` is now the single authoritative completion write path. The writer's Drift transaction inserts the `completions` projection row AND the `outbox` row atomically, satisfying FR15 for both per-row and rollback contracts.
- `CompletionCommand` is freezed with non-nullable identity fields: `(profileId, curriculumId, sefariaRef, stageId, trackType, trackId, completedAt, points)`. `trackId` and `curriculumId` are included because the existing `completions` schema requires them — leaving them out of the command would have forced the writer to do an extra resolution query inside its transaction, which the caller is already doing.
- Idempotency: a duplicate `(profileId, sefariaRef, stageId, trackType)` returns the existing row with `isNew = false` and does NOT enqueue a second outbox row. Verified by the duplicate-command acceptance test.
- Rollback: verified by wrapping the writer's commit inside an outer transaction that throws — both rows roll back.
- The outbox `entityKey` follows the convention `<profileId>:<sefariaRef>:<stageId>:<trackType>`, giving the OutboxProcessor an idempotency key on retry.
- The outbox `createdAt` is the command's `completedAt`. Drift returns DateTime as a local-timezone value but the underlying instant is preserved; tests compare on `microsecondsSinceEpoch`.
- Call-site migration: `completion_repository_impl.dart` `_createCompletion` and `_bulkMarkCompletePriorOptimized` now both go through `CompletionWriter`. The chunked-batch optimisation in the bulk path was replaced with a per-ref loop — each completion now gets its own atomic transaction, which is correct semantically (each completion has its own outbox row) and trades a small amount of throughput for end-to-end atomicity.
- The `sync_engine.dart:1085` pull-merge insert was deliberately left calling `completionDao.insertCompletion` directly — incoming Firestore data must NOT enqueue outbox rows (that would loop remote writes back into the push pipeline).
- Streak-event tee in `_appendStreakEvent` was left in `CompletionRepositoryImpl`; per scope note, it migrates into the writer in DNI-337 (Story 25.16) once the StreakReducer arrives.
- `completion_events` insertion is deferred: that table is added by DNI-323 (still in-progress, not on `dev`). The writer's `commit()` method signature is the seam where the third insert will be added later without changing callers.
- Reader-screen 14-provider invalidation swap (`completionCommittedProvider`) is Story 26.13, not this story.

### Debug Log
- Test `outbox row createdAt matches the command completedAt` initially failed because Drift returns `DateTime` as a local-timezone value when the row was stored as UTC. Fixed by comparing on the microsecond instant rather than the `DateTime` object.

## File List
**Added:**
- `learning_tracker/lib/core/learning/completion_command.dart`
- `learning_tracker/lib/core/learning/completion_command.freezed.dart` (generated)
- `learning_tracker/lib/core/learning/completion_writer.dart`
- `learning_tracker/lib/core/learning/completion_writer_providers.dart`
- `learning_tracker/lib/core/learning/completion_writer_providers.g.dart` (generated)
- `learning_tracker/test/story_acceptance/epic_25_story_15_completion_writer_test.dart`
- `docs/stories/implementation/DNI-336-completion-writer-transactional-commit.md`

**Modified:**
- `learning_tracker/lib/features/learning/data/repositories/completion_repository_impl.dart` (route writes through `CompletionWriter`; drop unused `math` import and `_kBulkInsertChunkSize`)
- `learning_tracker/lib/features/learning/presentation/providers/completion_providers.dart` (wire `completionWriterProvider` into `CompletionRepositoryImpl`)
- `learning_tracker/Makefile` (`test-story-25.15` target; `test-epic-25` now runs both epic-25 test files)

## Change Log
- 2026-05-13: Status → in-progress; tasks drafted from Linear AC + orchestrator context.
- 2026-05-13: Implemented `CompletionWriter` + `CompletionCommand`; migrated user-initiated call sites; added acceptance tests; full regression suite green. Status → review.
