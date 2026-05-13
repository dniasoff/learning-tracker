# DNI-329 — 25.8 core/content/ContentIndex + ProgramRefResolver

Status: review

## Summary

Introduce `core/content/ContentIndex` — a `keepAlive` Riverpod provider that
serves a `Map<sefariaRef, ContentItem>` populated from all 9 curricula at
first access — and `core/content/ProgramRefResolver`, which converts
`(programId, dayOffset)` into a concrete `sefariaRef` resolved through
`ContentIndex`. Closes FR16 and NFR22.

## Acceptance Criteria (from Linear DNI-329)

1. `core/content/ContentIndex` is a keepAlive Riverpod provider holding
   `Map<String /* sefariaRef */, ContentItem>` populated from all 9
   curricula at first access.
2. `ContentIndex.lookup(sefariaRef)` returns the item or null in O(1).
3. `ContentIndex.adjacent(sefariaRef)` returns prev/next items without
   walking 9 curricula lists.
4. `core/content/ProgramRefResolver` (built on `ContentIndex`) exposes
   `resolve(programId, dayOffset) → sefariaRef` so dashboard, scheduler,
   and reader share one matcher (FR16).
5. A benchmark unit test asserts lookup completes in < 1ms after first
   cache warmup.

## Tasks / Subtasks

- [x] T1 — Write failing acceptance tests for Story 25.8 in `epic_25_schema_core_test.dart`.
- [x] T2 — Implement `lib/core/content/content_index.dart` (data class + provider).
- [x] T3 — Implement `lib/core/content/program_ref_resolver.dart` (resolver + abstract source).
- [x] T4 — Add `make test-story-25.8` and update `test-epic-25` listing.
- [x] T5 — `dart analyze --fatal-infos` clean for new files; `make test-epic-25` green.
- [x] T6 — Commit.

## Dev Agent Record

### File List

- `learning_tracker/lib/core/content/content_index.dart` (new)
- `learning_tracker/lib/core/content/program_ref_resolver.dart` (new)
- `learning_tracker/test/story_acceptance/epic_25_schema_core_test.dart` (updated)
- `learning_tracker/Makefile` (updated)
- `docs/stories/implementation/DNI-329-content-index-program-ref-resolver.md` (new)

### Change Log

- 2026-05-13: Story drafted; TDD scaffold for `Story 25.8` added.
