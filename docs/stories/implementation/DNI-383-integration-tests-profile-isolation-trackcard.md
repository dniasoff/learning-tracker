# DNI-383 — 27.7 Integration tests: multi-profile isolation + track-card canonical layout

Status: review

Linear: https://linear.app/orvexai/issue/DNI-383

## Story

As a developer trusting Stories 25.1 and 26.6, I want integration tests asserting Profile A's completion never surfaces in Profile B's anything, and all 4 track-card data shapes render through one canonical surface, so that the data-isolation and UI canonical-layout invariants are pinned down (NFR13, FR1, UX-DR10).

## Acceptance Criteria

### Test 1 — multi-profile isolation

1. Creates Profile A and Profile B against an in-memory `UserDatabase`.
2. Records a completion under Profile A.
3. Every profile-aware `CompletionDao` query for Profile B returns empty / zero / false / null.
4. The DAO surface the dashboard providers consume (`getCompletionsByCurriculumAndProfile`, used by `dashboardCompletionPercentageProvider` and `dashboardLastCompletionProvider`) returns empty for Profile B even when Profile A has the only completion in the curriculum.
5. Cross-table coverage — bookmarks and goals written under A do not surface in any profile-scoped read for B.

### Test 2 — track-card canonical layout

1. All 4 `TrackProgressVariant`s (`programCalendar`, `deadlineGoal`, `velocityGoal`, `momentum`) flow through one `TrackProgress` constructor surface; the variants share `runtimeType` and the variant ↔ shape-specific-field correspondence holds for the four optional fields (`calendarPos`, `paceStatus`, `momentum`).
2. `resolveVariant(programId, goalType)` routes the 5 routing tuples to the 4 canonical variants per UX-DR10's permutation matrix.
3. Widget-tree comparison of the canonical `TrackCard` + 5 subcomponents (UX-DR10 final form) — **skip-stub**, pending Story 26.6 / DNI-388 which builds `TrackCardViewModel`, `TrackCardHeader`, `NextTaskBreadcrumb`, `TrackStatGrid`, `LifetimeLearningLine`, `TrackContinueButton`. Activated once 26.6 lands. Matches the DNI-378 (27.2) skip-stub precedent.

## Tasks / Subtasks

- [x] Inspect on-dev DAO surface (`CompletionDao` profile-scoped methods), profile creation surface (`ProfileRepositoryImpl.createProfile`), and dashboard provider sources to identify the canonical isolation invariants.
- [x] Write `test/story_acceptance/epic_27_story_7_isolation_and_canonical_layout_test.dart` covering 16 profile-isolation assertions + 2 canonical-layout shape assertions + 1 skip-stub.
- [x] Register `epic_27` and `story_27_7` tags in `dart_test.yaml`.
- [x] Add `test-story-27.7` Makefile target. Redirect the dev-only `test-epic-27` target (which previously pointed at a non-existent test file shipped by the chore-only DNI-377 merge) to the new file.
- [x] `dart analyze --fatal-infos <test file>` clean.
- [x] `make test-story-27.7` — all 18 tests pass, 1 skipped (the canonical layout stub).

## File List

- `learning_tracker/test/story_acceptance/epic_27_story_7_isolation_and_canonical_layout_test.dart` (new)
- `learning_tracker/dart_test.yaml` (modified — register epic_27 / story_27_7 tags)
- `learning_tracker/Makefile` (modified — add `test-story-27.7`, redirect `test-epic-27`)
- `docs/stories/implementation/DNI-383-integration-tests-profile-isolation-trackcard.md` (new)

## Dev Agent Record

- Worktree: `/tmp/dev-dni-383`. Branched from `origin/dev` (`6ffe6d54`).
- DNI-377 helper files (`test/helpers/drift_memory.dart` with `inMemoryDb()`, `firestore_fake.dart`, `golden_runner.dart`) are NOT on origin/dev — only the Makefile-targets chore landed in `ddd96a50`. Used the equivalent on-dev helper `createTestDatabase()` from `test/helpers/test_database.dart`, which returns a `UserDatabase(NativeDatabase.memory())` — functionally identical.
- Story 26.6's `TrackCardViewModel` + 5 named subcomponents do not exist on origin/dev. Asserted the data-shape canonical-form half of UX-DR10 against the existing `TrackProgress` model with its 4 `TrackProgressVariant`s, and left the widget-tree comparison as a skip-stub for the next agent. Matches the DNI-378 / 27.2 precedent for the `StreakReducer` stub.
- Dashboard isolation assertion takes a provider-stack-free shortcut: the on-dev dashboard providers (`dashboardCompletionPercentageProvider` at `dashboard_providers.dart:131-152`, `dashboardLastCompletionProvider` at `:155-172`) consume `CompletionDao.getCompletionsByCurriculumAndProfile(curriculum, profileId)` exclusively. Asserting that DAO call returns empty for Profile B is sufficient and avoids pulling in `activeProfileIdProvider` / Firebase / `SharedPreferences` mocks.

## Change Log

| Date | Description |
|------|-------------|
| 2026-05-13 | Initial implementation of Story 27.7 integration tests (DNI-383). 18 tests passing, 1 skip-stub for the post-26.6 widget-tree comparison. |
