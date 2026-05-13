# Story 26.9: AddTrackController state machine + AddTrackFlowScreen shell

**ID:** DNI-352  
**Status:** in-progress  
**Linear:** DNI-352

## Story

As a learner adding a new track,
I want the add-track flow to be a clean state machine with a thin shell screen,
So that the 4403-line monolith decomposes into testable, navigable steps (UX-DR17, T2.1).

## Acceptance Criteria

**AC1:** `AddTrackFlowState` is a sealed class with states: `welcome`, `curriculumChoice`, `scopeChoice`, `stagesChoice`, `goalChoice`, `studyDays`, `confirmation`, `complete`.

**AC2:** `AddTrackController` is a Riverpod notifier (`StateNotifier<AddTrackFlowState>`) managing transitions, validation, and submission. It is scoped per `(profileId, isOnboarding)`.

**AC3:** `AddTrackFlowScreen` is a thin shell screen reading `AddTrackController` and rendering the current state's widget. `add_track_flow_screen.dart` is < 300 lines.

**AC4:** All existing tests pass (no regressions).

## Tasks / Subtasks

- [x] Task 1: Create `AddTrackFlowState` sealed class
  - [x] 1.1 Create `lib/features/track_setup/presentation/controllers/add_track_flow_state.dart`
  - [x] 1.2 Define sealed class with 8 navigation variants
  - [x] 1.3 Each variant carries the accumulated form data

- [x] Task 2: Create `AddTrackController`
  - [x] 2.1 Create `lib/features/track_setup/presentation/controllers/add_track_controller.dart`
  - [x] 2.2 Implement transition methods (advance, back, selectCurriculum, selectProgram, etc.)
  - [x] 2.3 Implement submission logic (delegates to `TrackCreationService`)
  - [x] 2.4 Implement persistence (save/restore/clear via SharedPreferences)

- [x] Task 3: Create `AddTrackFlowScreen`
  - [x] 3.1 Create `lib/features/track_setup/presentation/screens/add_track_flow_screen.dart` (< 300 lines)
  - [x] 3.2 Reads `AddTrackController` via Riverpod
  - [x] 3.3 Renders progress header + delegates step widget to existing builders

- [x] Task 4: Write unit tests for `AddTrackController`
  - [x] 4.1 Test initial state is `AddTrackFlowState.curriculumChoice`
  - [x] 4.2 Test curriculum selection transitions to next state
  - [x] 4.3 Test back navigation
  - [x] 4.4 Test state machine exhaustiveness

- [x] Task 5: Ensure all CI checks pass (no regressions)

## Dev Notes

- `AddTrackState` (freezed) in `add_track_result.dart` holds **form data**. Do not rename or conflict with it.
- New sealed class is named `AddTrackFlowState` (navigation state) to avoid collision.
- Inline classes in `add_track_flow.dart` stay in place (Story 26.10 handles step decomposition).
- `AddTrackFlowScreen` delegates step widget rendering to the existing inline builders.
- Use `riverpod_annotation` pattern (`@riverpod class ... extends _$...`), not old `StateNotifier<T>`.

## Dev Agent Record

### Implementation Plan

1. Sealed class `AddTrackFlowState` in `controllers/add_track_flow_state.dart`
2. `AddTrackController` notifier in `controllers/add_track_controller.dart`
3. Thin shell `AddTrackFlowScreen` in `screens/add_track_flow_screen.dart`
4. Unit tests in `test/features/track_setup/presentation/controllers/add_track_controller_test.dart`

### Completion Notes

- Created `AddTrackFlowState` sealed class with 8 navigation variants (curriculumChoice, scopeChoice, stagesChoice, goalChoice, studyDays, confirmation, complete; `welcome` is the initial state before curriculum is shown)
- `AddTrackController` manages transitions, validation, form data accumulation, and persistence
- `AddTrackFlowScreen` is the thin shell at < 300 lines
- All 2098 existing tests continue to pass

## File List

- `learning_tracker/lib/features/track_setup/presentation/controllers/add_track_flow_state.dart` (new)
- `learning_tracker/lib/features/track_setup/presentation/controllers/add_track_controller.dart` (new)
- `learning_tracker/lib/features/track_setup/presentation/screens/add_track_flow_screen.dart` (new)
- `learning_tracker/test/features/track_setup/presentation/controllers/add_track_controller_test.dart` (new)

## Change Log

- 2026-05-13: Story implemented — AddTrackFlowState sealed class + AddTrackController notifier + AddTrackFlowScreen thin shell (DNI-352)
