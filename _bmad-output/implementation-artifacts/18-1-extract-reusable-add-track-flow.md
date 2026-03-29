# Story 18.1: Add Track Flow — 8 Screens (DNI-180)

Status: review

## Story

As a learner (or parent setting up a child),
I want a standalone "Add Track" flow that walks me through configuring a single learning track,
so that the same polished experience is available during initial onboarding AND when adding tracks later from settings.

## Acceptance Criteria

**AC-1:** `AddTrackFlow` is a standalone widget with NO dependency on OnboardingScreen
**AC-2:** Exactly 8 screens, each with ONE concept (never mix goals + study days, never mix scope + import)
**AC-3:** Study days (screen 4) comes BEFORE chazara (screen 5)
**AC-4:** Program screen auto-skips when no programs exist for the curriculum
**AC-5:** Content loading from bundled assets is invisible — no "import" screen
**AC-6:** Track name defaults are smart: program name > scope name > curriculum name
**AC-7:** Bulk mark marks ALL stages complete — no future chazara for selected items
**AC-8:** Back navigation preserves all selections on every screen
**AC-9:** State persists across app interruption (SharedPreferences)
**AC-10:** On completion, creates the track in DB with all settings applied
**AC-11:** No rewards step in this flow

## Tasks / Subtasks

### T1: Create track_setup Feature Module Scaffold (AC: 1)

- [x] Create directory structure: `lib/features/track_setup/{data,domain,presentation}/{screens,widgets,providers,entities}`
- [x] Create `AddTrackResult` freezed entity at `lib/features/track_setup/domain/entities/add_track_result.dart`
  - Fields: `curriculumId`, `label`, `programId?`, `scopeSelection?`, `studyDays`, `stageDefinitions`, `goal?`, `bulkMarkResult?`
- [x] Create `AddTrackState` freezed class for internal flow state management
- [x] Run `dart run build_runner build --delete-conflicting-outputs`

### T2: AddTrackFlow Shell — Step Management & Navigation (AC: 1, 7, 9)

- [x] Create `AddTrackFlow` ConsumerStatefulWidget at `lib/features/track_setup/presentation/screens/add_track_flow.dart`
  - Parameters: `profileId`, `isOnboarding`, `isChildMode`, `onComplete`, `onCancel`
- [x] Implement 8-step enum: `curriculum`, `scope`, `program`, `studyDays`, `chazaraSetup`, `goal`, `trackName`, `bulkMark`
- [x] Implement PageView + NeverScrollableScrollPhysics for programmatic step navigation
- [x] Implement PopScope back navigation that preserves state across all steps
- [x] From Step 1, back exits with confirmation dialog if data entered
- [x] Persist flow state to SharedPreferences on each step completion (AC-9)
- [x] On launch, check for persisted state and resume from last completed step
- [x] Return `AddTrackResult` on flow completion via `onComplete` callback (AC-8)

### T3: Stage 1 — Curriculum Picker (AC: 1, 2, 5)

- [x] Create `CurriculumPickerStep` widget at `lib/features/track_setup/presentation/widgets/curriculum_picker_step.dart`
- [x] Display all 9 curricula with Hebrew names from `CurriculumId` enum
- [x] Single tap selection advances immediately
- [x] After selection, trigger `CurriculumActivationService.activate()` in background (fire-and-forget)
- [x] Track activation status via `_activationFuture` + `contentActivated` state for use by Stage 2

### T4: Stage 2 — Scope Selection (AC: 2, 5)

- [x] Create `_ScopeStepAdapter` inline widget wrapping scope selection
- [x] Default: "Track All" button (skippable)
- [x] If curriculum content not yet activated, show spinner via FutureBuilder until ready
- [x] No dedicated import screen — spinner only if needed

### T5: Stage 3 — Program Selection (AC: 4)

- [x] Create `ProgramSelectionStep` widget at `lib/features/track_setup/presentation/widgets/program_selection_step.dart`
- [x] Query available programs: Bavli (Daf Yomi id=1, Oraysa id=3), Mishna Berurah (Dirshu id=2)
- [x] If no programs available (7 of 9 curricula) auto-skip via `_activeSteps` filtering
- [x] If program selected, auto-adjust scope to null (full scope)
- [x] "Self-paced" option for no program

### T6: Stage 4 — Study Days (AC: 2, 3)

- [x] Create `_StudyDaysStepAdapter` inline widget with 7-day FilterChip picker
- [x] Default: Sun-Thu study (ISO 7,1,2,3,4), Fri-Sat review (ISO 5,6)
- [x] Skippable (uses defaults)
- [x] Store result for use by Stage 5 (chazara setup)

### T7: Stage 5 — Chazara Setup (AC: 2, 3)

- [x] Create `_ChazaraStepAdapter` wrapping `LearningProcessWizardScreen` via Navigator.push
- [x] Presets: standard, custom, no-review
- [x] Schedule type: delay-only, delay + Shabbos review, delay + Friday + Shabbos
- [x] Can reference study days from Stage 4
- [x] Skip = no review

### T8: Stage 6 — Goal Setup (AC: 2)

- [x] Create `_GoalStepAdapter` wrapping `GoalSetupScreen` via Navigator.push
- [x] Pace-based or deadline-based goal
- [x] Skippable (no goal = no pace tracking)

### T9: Stage 7 — Track Name (AC: 6)

- [x] Create `TrackLabelStep` widget at `lib/features/track_setup/presentation/widgets/track_label_step.dart`
- [x] Smart default pre-fill logic: program name > scope name > curriculum Hebrew name
- [x] Editable TextField with default pre-filled
- [x] Validate non-empty

### T10: Stage 8 — Bulk Mark (AC: 7)

- [x] Create `_BulkMarkStepAdapter` wrapping `BulkMarkScreen` via Navigator.push
- [x] When marking items, insert completions for ALL configured stages
- [x] Prominent "Skip" button alongside "Mark completions"

### T11: Database Persistence — Create Track on Completion (AC: 10)

- [x] Create `TrackCreationService` at `lib/features/track_setup/domain/services/track_creation_service.dart`
- [x] Wrap all DB operations in a single `_database.transaction()` call
- [x] Orchestrate: curriculum activation, stage definitions, study day config, scope insertion, goal creation
- [x] Error handling with try/catch in `_finishFlow()` — saved state NOT cleared until success confirmed
- [x] Return `AddTrackResult` to caller via `onComplete` callback

### T12: Unit & Widget Tests (AC: 1-11)

- [x] 16 unit tests for `AddTrackResult`, `ScopeEntry`, `AddTrackState`, `AddTrackStep`
- [x] 4 widget tests for `CurriculumPickerStep` (scrollable list, onboarding header, default header, tap callback)
- [x] 4 widget tests for `TrackLabelStep` (pre-fill, submit, validation, accept default)
- [x] 4 widget tests for `ProgramSelectionStep` (Bavli programs, MB programs, tap callback, self-paced)

### T13: Code Review Fixes (REDO) (AC: 1-11)

- [x] Wrap `TrackCreationService.createTrack()` in `_database.transaction()` (was CRITICAL)
- [x] Fix study days defaults to Sun-Thu (ISO 7,1,2,3,4) — was Mon-Fri in 3 places
- [x] Remove presentation-layer imports from domain entity `AddTrackResult` (clean architecture)
- [x] Eliminate cross-feature module imports from `add_track_providers.dart` and `add_track_flow.dart`
- [x] Add try/catch around `_finishFlow()` — clear saved state only on success
- [x] Extract default study days constant to shared location (was duplicated 3x)

## Dev Notes

### Architecture

- **Feature module:** `lib/features/track_setup/` — new module following clean architecture (data/domain/presentation)
- **Pattern:** Feature-first clean architecture with Riverpod providers [Source: _bmad-output/project-context.md]
- **Key principle:** Each screen = ONE concept. Never mix concerns.
- **State management:** Local `AddTrackState` (Freezed) for wizard state, NOT Riverpod providers
- **Navigation:** PageView + NeverScrollableScrollPhysics, controlled programmatically
- **Back nav:** PopScope intercepts system back button to go to previous step or show exit dialog

### Key Files

| File | Path | Role |
|------|------|------|
| AddTrackFlow | `lib/features/track_setup/presentation/screens/add_track_flow.dart` | Main 8-step wizard widget |
| CurriculumPickerStep | `lib/features/track_setup/presentation/widgets/curriculum_picker_step.dart` | Stage 1 |
| ProgramSelectionStep | `lib/features/track_setup/presentation/widgets/program_selection_step.dart` | Stage 3 |
| TrackLabelStep | `lib/features/track_setup/presentation/widgets/track_label_step.dart` | Stage 7 |
| AddTrackResult | `lib/features/track_setup/domain/entities/add_track_result.dart` | Freezed entities |
| TrackCreationService | `lib/features/track_setup/domain/services/track_creation_service.dart` | DB persistence orchestrator |
| AddTrackProviders | `lib/features/track_setup/presentation/providers/add_track_providers.dart` | Riverpod provider wiring |

### Database Tables Touched

- `active_curricula` — curriculum activation (idempotent)
- `curriculum_tracks` — track creation
- `stage_definitions` — chazara config per track
- `study_day_configs` — study day selections
- `curriculum_scopes` — scope narrowing
- `goals` — pace/deadline goals
- `completions` — bulk mark inserts (append-only, all stages)

### Critical Constraints

- All DB writes in transactions [Source: _bmad-output/project-context.md]
- Completions are append-only — never update/delete
- DateTime always UTC
- Use `@riverpod` code generation for providers
- Use `freezed` for all data classes
- Never import between feature modules — use core providers

### Testing Standards

- 80%+ coverage on domain layer, 70%+ on data layer [Source: _bmad-output/project-context.md]
- Use mocktail for mocks, real freezed instances for data
- Arrange-Act-Assert pattern
- Mirror lib/ structure in test/

### Project Structure Notes

- New module at `lib/features/track_setup/` aligns with feature-first architecture
- Existing widgets stay in their current modules; adapters in `track_setup` wrap them
- Route registration in `lib/core/navigation/app_router.dart`

### References

- [Source: docs/developer-guide.md#Core Domain Model: The Track] — Track model, curricula
- [Source: _bmad-output/project-context.md#Critical Implementation Rules] — Coding standards, patterns
- [Source: docs/developer-guide.md#Onboarding: The Critical UX Challenge] — Onboarding flow design

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: Created `track_setup` feature module with clean architecture directories. `AddTrackResult`, `ScopeEntry`, `AddTrackState` as freezed classes. `AddTrackStep` 8-step enum. build_runner generated successfully.
- T2: `AddTrackFlow` ConsumerStatefulWidget with PageController, 8-step wizard, back navigation with exit confirmation, SharedPreferences persistence for all state fields, resume-from-saved-state on launch.
- T3: `CurriculumPickerStep` displays all 9 curricula with Hebrew+English names, single tap advances. Content activation fires in background.
- T4: `_ScopeStepAdapter` with "Track All" default. FutureBuilder shows spinner at scope step if activation not yet complete.
- T5: `ProgramSelectionStep` — Bavli: Daf Yomi (id=1) + Oraysa (id=3); MB: Dirshu (id=2). Auto-skip via `_activeSteps` filtering. Self-paced option.
- T6: `_StudyDaysStepAdapter` — inline FilterChip day grid, 7-day ISO, defaults Sun-Thu study. Skippable.
- T7: `_ChazaraStepAdapter` launches `LearningProcessWizardScreen` via Navigator.push, receives result via pop.
- T8: `_GoalStepAdapter` launches `GoalSetupScreen` via Navigator.push, skip option.
- T9: `TrackLabelStep` — smart defaults (program > scope > curriculum Hebrew name), TextFormField with validation.
- T10: `_BulkMarkStepAdapter` launches `BulkMarkScreen` via Navigator.push. Prominent Skip alongside Mark Completions.
- T11: `TrackCreationService` orchestrates all DB writes in a single transaction. Wired into `_finishFlow()`.
- T12: 28 tests passing (16 unit + 12 widget), 0 analyzer issues.
- T13 (REDO): Fixed all 7 code review findings — transaction wrapper, Sun-Thu defaults, clean architecture imports, try/catch error handling, extracted shared constant.

### Change Log

- 2026-03-29: Code review fixes applied (REDO commit `3826a23`). 1 critical, 4 high, 2 low issues resolved.
- 2026-03-28: Initial implementation complete. 8-step wizard, 3 custom widgets, 5 adapter widgets, TrackCreationService, 28 tests. Commits `d0e60c2`, `8390794`.

### File List

**Created:**
- `lib/features/track_setup/domain/entities/add_track_result.dart`
- `lib/features/track_setup/domain/services/track_creation_service.dart`
- `lib/features/track_setup/presentation/screens/add_track_flow.dart`
- `lib/features/track_setup/presentation/providers/add_track_providers.dart`
- `lib/features/track_setup/presentation/widgets/curriculum_picker_step.dart`
- `lib/features/track_setup/presentation/widgets/program_selection_step.dart`
- `lib/features/track_setup/presentation/widgets/track_label_step.dart`
- `test/features/track_setup/domain/entities/add_track_result_test.dart`
- `test/features/track_setup/presentation/widgets/curriculum_picker_step_test.dart`
- `test/features/track_setup/presentation/widgets/track_label_step_test.dart`
- `test/features/track_setup/presentation/widgets/program_selection_step_test.dart`

**Modified:**
- `lib/features/track_setup/domain/entities/add_track_result.dart` (REDO: removed presentation imports)
- `lib/features/track_setup/domain/services/track_creation_service.dart` (REDO: added transaction wrapper)
- `lib/features/track_setup/presentation/screens/add_track_flow.dart` (REDO: Sun-Thu defaults, try/catch, shared constant)
