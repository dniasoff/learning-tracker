# DNI-331 — 25.10 core/time/LocalDayClock — single time provider

Status: review

## Summary

Introduce `core/time/LocalDayClock` — the single source of truth for
"what UTC instant is it" and "what is today's local date" across the
app. Every prior `DateTime.now()` call site in `lib/` is migrated to
either `DateTimeFactory.nowUtc()` (non-Riverpod) or
`ref.read(localDayClockProvider).today()` (Riverpod). Closes NFR21
and NFR25 and removes the root cause of T1.2's timezone divergence in
streak/scheduler day-boundary logic.

## Acceptance Criteria (from Linear DNI-331)

1. `LocalDayClock` is the only public provider for "today's local date".
2. The clock takes a deterministic test seed via Riverpod override.
3. `grep -rn 'DateTime\.now\(\)' lib/ --exclude-dir=core/time` returns
   zero results.
4. When a test overrides the clock to `2026-05-13 23:30 Asia/Jerusalem`,
   the streak reducer reads `2026-05-13` consistently regardless of the
   host machine's timezone.

## Tasks / Subtasks

- [x] T1 — Add failing acceptance tests for Story 25.10 in
  `epic_25_schema_core_test.dart` (RED phase).
- [x] T2 — Implement `lib/core/time/local_day_clock.dart` with
  `LocalDayClock` interface, `SystemLocalDayClock`,
  `FakeLocalDayClock`, and `localDayClockProvider`.
- [x] T3 — Rewire `DateTimeFactory.nowUtc()` to delegate to the
  globally-installed clock; add `nowLocal()` and `useLocalDayClock` /
  `resetLocalDayClock` helpers for non-Riverpod tests.
- [x] T4 — Migrate every `DateTime.now()` / `DateTime.now().toUtc()`
  call site in `lib/` (94 sites across 37 files) to the clock.
- [x] T5 — Add `make test-story-25.10` Makefile target and add it to
  `.PHONY`.
- [x] T6 — `dart analyze` clean for `lib/`; full epic-25 acceptance
  suite green (38/38).
- [x] T7 — Commit.

## Dev Agent Record

### File List

- `learning_tracker/lib/core/time/local_day_clock.dart` (new)
- `learning_tracker/lib/core/utils/date_utils.dart` (rewired to clock)
- `learning_tracker/Makefile` (new `test-story-25.10` target)
- `learning_tracker/test/story_acceptance/epic_25_schema_core_test.dart`
  (new Story 25.10 group, 10 tests)
- 37 lib/ files migrated (DAOs, services, presentation, repositories) —
  see git diff for the full list.

### Change Log

- 2026-05-13: Story drafted, TDD scaffold added, implementation +
  migration complete.
