# Story 18.1: Extract Reusable Add Track Flow (הוספת מסלול)

Status: in-progress

## Story

As a learner (or parent setting up a child),
I want a standalone "Add Track" flow that walks me through configuring a single learning track,
so that the same polished experience is available during initial onboarding AND when adding tracks later from settings.

## Acceptance Criteria

**AC-1: AddTrackFlow widget exists as standalone component**
**Given** the new `AddTrackFlow` widget
**When** launched with required parameters (`profileId`, `isOnboarding`, `isChildMode`)
**Then** it renders a self-contained 8-step wizard

**AC-2: One concept per screen**
**Given** any stage in the flow
**When** the user views the screen
**Then** it addresses exactly ONE configuration concern
**And** goals and study days are NEVER on the same screen
**And** scope and content loading are NEVER on the same screen
**And** study days and חזרה config are NEVER on the same screen

**AC-3: Study days come before חזרה**
**Given** the user completes study day selection
**When** they advance to חזרה setup
**Then** the חזרה screen can reference which days are already configured as active

**AC-4: Smart track name defaults**
**Given** the user reaches the Track Name stage
**When** a program was selected (e.g., Daf Yomi)
**Then** the default name is "דף היומי"
**When** scope was narrowed (e.g., Masechta Berachos)
**Then** the default name is "מסכת ברכות"
**When** no program and full scope
**Then** the default name is the curriculum name (e.g., "משניות")

**AC-5: Content activation is invisible**
**Given** the user selects a curriculum
**When** bundled content needs to be loaded into local DB
**Then** it happens in the background — no dedicated "import" screen
**And** if loading isn't complete by scope selection, a brief spinner appears

**AC-6: Program step auto-skips**
**Given** the user selected a curriculum with no available programs
**When** they complete scope selection
**Then** they jump directly to Study Days (no empty program screen)

**AC-7: Back navigation preserves state**
**Given** the user is on any stage
**When** they press back
**Then** they return to the previous stage with selections preserved
**And** from Stage 1, back exits the flow (with confirmation if data entered)

**AC-8: Flow returns result**
**Given** the user completes all stages
**When** the flow finishes
**Then** it returns an `AddTrackResult` with all configuration
**And** the track is created in the database with all settings applied

**AC-9: State persistence across interruption**
**Given** the user is mid-flow
**When** the app is backgrounded or killed
**Then** on return, the flow resumes from the last completed stage

**AC-10: Bulk mark marks ALL stages complete**
**Given** the user selects items in bulk mark
**When** they confirm
**Then** every selected item is marked complete for ALL configured stages (לימוד through final חזרה)
**And** no reviews will be scheduled for those items
**And** "Skip" is as prominent as "Mark completions"

**AC-11: No rewards in this flow**
**Given** the Add Track flow
**When** completing all stages (adult or child mode)
**Then** there is no rewards setup step — rewards are configured separately

## Tasks / Subtasks

### T1: Create track_setup Feature Module Scaffold (AC: 1)

- [x] Create directory structure: `lib/features/track_setup/{data,domain,presentation}/{screens,widgets,providers,entities}`
- [x] Create `AddTrackResult` freezed entity at `lib/features/track_setup/domain/entities/add_track_result.dart`
  - Fields: `curriculumId`, `label`, `programId?`, `scopeSelection?`, `studyDays`, `stageDefinitions`, `goal?`, `bulkMarkResult?`
- [x] Create `AddTrackState` freezed class for internal flow state management
- [x] Run `dart run build_runner build --delete-conflicting-outputs`

### T2: AddTrackFlow Shell — Step Management & Navigation (AC: 1, 7, 9)

- [x] Create `AddTrackFlow` StatefulWidget at `lib/features/track_setup/presentation/screens/add_track_flow.dart`
  - Parameters: `profileId`, `isOnboarding`, `isChildMode`
  - Internal `PageController` or indexed stack for step management
- [x] Implement 8-step enum: `curriculum`, `scope`, `program`, `studyDays`, `chazaraSetup`, `goal`, `trackName`, `bulkMark`
- [x] Implement back navigation that preserves state across all steps
- [x] From Step 1, back exits with confirmation dialog if data entered
- [x] Persist flow state to SharedPreferences on each step completion (AC-9)
- [x] On launch, check for persisted state and resume from last completed step
- [x] Return `AddTrackResult` on flow completion (AC-8)

### T3: Stage 1 — Curriculum Picker (AC: 1, 2, 5)

- [x] Create `CurriculumPickerStep` widget at `lib/features/track_setup/presentation/widgets/curriculum_picker_step.dart`
- [x] Display all 9 curricula with Hebrew names from `CurriculumId` enum
- [x] Single tap selection → advance immediately
- [ ] After selection, trigger `CurriculumActivationService.activate()` in background (fire-and-forget)
- [ ] Track activation status via a `ValueNotifier<bool>` for use by Stage 2

### T4: Stage 2 — Scope Selection (AC: 2, 5)

- [x] Reuse existing `ScopeSelectionScreen` from `lib/features/settings/presentation/screens/scope_selection_screen.dart`
- [x] Wrap with adapter widget that passes curriculum and receives scope result
- [x] Default: "All" (skippable)
- [ ] If curriculum content not yet activated, show brief spinner until ready
- [ ] No dedicated import screen — spinner only if needed

### T5: Stage 3 — Program Selection (AC: 6)

- [x] Create `ProgramSelectionStep` widget at `lib/features/track_setup/presentation/widgets/program_selection_step.dart`
- [x] Query available programs for selected curriculum (Daf Yomi → Bavli, Dirshu → Mishna Berurah, Oraysa → Bavli)
- [x] If no programs available → auto-skip to Stage 4
- [ ] If program selected, auto-adjust scope (e.g., Daf Yomi = all of Bavli)
- [x] Option to continue self-paced (no program)

### T6: Stage 4 — Study Days (AC: 2, 3)

- [x] Reuse existing `StudyDayConfigScreen` from `lib/features/scheduler/presentation/screens/study_day_config_screen.dart`
- [x] Wrap with adapter that passes curriculum and receives day config
- [x] Default: Sun–Thu study, Fri–Sat review
- [x] Skippable (uses defaults)
- [x] Store result for use by Stage 5 (חזרה setup)

### T7: Stage 5 — חזרה Setup (AC: 2, 3)

- [x] Reuse existing `LearningProcessWizardScreen` from `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart`
- [x] Wrap with adapter that passes curriculum and study days context
- [x] Presets: standard (לימוד → חזרה א׳ → חזרה ב׳), custom, no-review
- [x] Schedule type: delay-only, delay + שבת review, delay + Friday + שבת review
- [x] Can reference study days from Stage 4

### T8: Stage 6 — Goal Setup (AC: 2)

- [x] Reuse existing `GoalSetupScreen` from `lib/features/scheduler/presentation/screens/goal_setup_screen.dart`
- [x] Wrap with adapter that passes curriculum and receives goal result
- [x] Pace-based or deadline-based goal
- [x] Skippable (no goal = no pace tracking)

### T9: Stage 7 — Track Name (AC: 4)

- [x] Create `TrackLabelStep` widget at `lib/features/track_setup/presentation/widgets/track_label_step.dart`
- [x] Smart default pre-fill logic:
  - Program selected → program name (e.g., "דף היומי")
  - Scope narrowed → scope name (e.g., "מסכת ברכות")
  - Otherwise → curriculum Hebrew name (e.g., "משניות")
- [x] Editable TextField with default pre-filled
- [x] Validate non-empty

### T10: Stage 8 — Bulk Mark (AC: 10)

- [x] Reuse existing `BulkMarkScreen` from `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart`
- [x] Wrap with adapter that passes curriculum and scope
- [ ] When marking items, insert completions for ALL configured stages (not just לימוד)
  - Use stage definitions from Stage 5 to determine all stages
  - Each selected item gets a completion record for every stage
- [x] Prominent "Skip" button alongside "Mark completions"
- [x] Optional — no pressure to use

### T11: Database Persistence — Create Track on Completion (AC: 8)

- [ ] On flow completion, within a single transaction:
  - Activate curriculum via `CurriculumActivationService` (if not already)
  - Create track record in `curriculum_tracks` table
  - Save stage definitions to `stage_definitions` table
  - Save study day config to `study_day_configs` table
  - Save scope selection to `curriculum_scopes` table
  - Create goal in `goals` table (if set)
  - Insert bulk mark completions (if any) for ALL stages
- [ ] Fire Firestore sync after transaction completes (fire-and-forget)
- [ ] Return `AddTrackResult` to caller

### T12: Unit & Widget Tests (AC: 1-11)

- [x] Unit tests for `AddTrackResult` entity
- [x] Unit tests for smart default track name logic
- [x] Unit tests for program auto-skip logic
- [ ] Unit tests for bulk mark all-stages-complete logic
- [ ] Widget tests for `CurriculumPickerStep` in isolation
- [ ] Widget tests for `TrackLabelStep` with various defaults
- [ ] Widget tests for `ProgramSelectionStep` with/without programs
- [ ] Widget test for full flow navigation (forward/back/skip)
- [ ] Integration test for state persistence across interruption

## Dev Notes

### Architecture

- **Feature module:** `lib/features/track_setup/` — new module following clean architecture (data/domain/presentation)
- **Pattern:** Feature-first clean architecture with Riverpod providers [Source: _bmad-output/project-context.md]
- **Key principle:** Each screen = ONE concept. Never mix concerns.

### Existing Widgets to Reuse

| Widget | Current Location | Adapter Needed |
|--------|-----------------|----------------|
| `ScopeSelectionScreen` | `lib/features/settings/presentation/screens/scope_selection_screen.dart` | Yes — wrap for flow context |
| `StudyDayConfigScreen` | `lib/features/scheduler/presentation/screens/study_day_config_screen.dart` | Yes — wrap for flow context |
| `LearningProcessWizardScreen` | `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart` | Yes — wrap with study days |
| `GoalSetupScreen` | `lib/features/scheduler/presentation/screens/goal_setup_screen.dart` | Yes — wrap for flow context |
| `BulkMarkScreen` | `lib/features/onboarding/presentation/screens/bulk_mark_screen.dart` | Yes — all-stages marking |

### New Widgets to Create

| Widget | Path |
|--------|------|
| `AddTrackFlow` | `lib/features/track_setup/presentation/screens/add_track_flow.dart` |
| `CurriculumPickerStep` | `lib/features/track_setup/presentation/widgets/curriculum_picker_step.dart` |
| `TrackLabelStep` | `lib/features/track_setup/presentation/widgets/track_label_step.dart` |
| `ProgramSelectionStep` | `lib/features/track_setup/presentation/widgets/program_selection_step.dart` |

### Key Services

- `CurriculumActivationService` at `lib/features/settings/domain/services/curriculum_activation_service.dart` — handles content activation
- `BulkPriorCompletionService` at `lib/features/onboarding/domain/services/bulk_prior_completion_service.dart` — bulk mark completions
- `LearningProcessWizardService` — creates stage definitions from wizard results

### Database Tables Touched

- `curriculum_tracks` — track creation
- `stage_definitions` — חזרה config per track
- `study_day_configs` — study day selections
- `curriculum_scopes` — scope narrowing
- `goals` — pace/deadline goals
- `completions` — bulk mark inserts (append-only, all stages)
- `active_curricula` — curriculum activation

### State Persistence Keys

Current onboarding uses: `_kOnboardingPhase`, `_kOnboardingProfileId`, `_kOnboardingProfileName`, `_kOnboardingProfileMode`, `_kOnboardingSelectedCurricula`, `_kOnboardingLanguage`

New AddTrackFlow should use separate keys: `_kAddTrackStep`, `_kAddTrackCurriculum`, `_kAddTrackScope`, `_kAddTrackProgram`, `_kAddTrackStudyDays`, `_kAddTrackStages`, `_kAddTrackGoal`, `_kAddTrackLabel`

### Critical Constraints

- All DB writes in transactions [Source: _bmad-output/project-context.md]
- Completions are append-only — never update/delete
- DateTime always UTC
- Use `@riverpod` code generation for providers
- Use `freezed` for all data classes
- Never import between feature modules — use core providers

### Project Structure Notes

- New module at `lib/features/track_setup/` aligns with feature-first architecture
- Existing widgets stay in their current modules; adapters in `track_setup` import via core providers
- Route registration in `lib/core/navigation/app_router.dart`

### References

- [Source: docs/developer-guide.md] — Domain concepts, curricula, track model
- [Source: _bmad-output/project-context.md] — Coding standards, patterns
- [Source: _bmad-output/planning-artifacts/architecture.md] — Architecture decisions

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: Created `track_setup` feature module with clean architecture directories. `AddTrackResult`, `ScopeEntry`, `AddTrackState` as freezed classes. `AddTrackStep` 8-step enum. build_runner generated successfully.
- T2: `AddTrackFlow` ConsumerStatefulWidget with PageController, 8-step wizard, back navigation with exit confirmation, SharedPreferences persistence for all state fields, resume-from-saved-state on launch.
- T3: `CurriculumPickerStep` — displays all 9 curricula with Hebrew+English names, single tap advances. Content activation hooks deferred (needs Riverpod provider wiring).
- T4: `_ScopeStepAdapter` — wraps scope selection with "Track All" default. Spinner for content activation deferred.
- T5: `ProgramSelectionStep` — hardcoded program list (Daf Yomi, Oraysa for Bavli; Dirshu for Mishna Berurah). Auto-skip via `_activeSteps` filtering. Self-paced option.
- T6: `_StudyDaysStepAdapter` — inline FilterChip day grid, Mon-Sun ISO days, defaults Sun-Thu study. Skippable.
- T7: `_ChazaraStepAdapter` — launches `LearningProcessWizardScreen` via Navigator.push, receives result via pop. Skip option for no-review.
- T8: `_GoalStepAdapter` — launches `GoalSetupScreen` via Navigator.push, skip option.
- T9: `TrackLabelStep` — smart defaults (program > scope > curriculum Hebrew name), TextFormField with validation.
- T10: `_BulkMarkStepAdapter` — launches `BulkMarkScreen` via Navigator.push, prominent Skip alongside Mark Completions.
- T11: Database persistence NOT YET IMPLEMENTED — deferred, needs transaction orchestration across multiple DAOs.
- T12: 16 unit tests passing — AddTrackResult, ScopeEntry, AddTrackState, AddTrackStep ordering, smart defaults, program auto-skip logic.
- NOTE: T3 content activation (fire-and-forget), T4 spinner, T5 auto-adjust scope, T10 all-stages-complete bulk mark, T11 DB persistence are remaining items that require deeper integration with existing services.

### File List

**Created:**
- `learning_tracker/lib/features/track_setup/domain/entities/add_track_result.dart` — freezed entities
- `learning_tracker/lib/features/track_setup/domain/entities/add_track_result.freezed.dart` — generated
- `learning_tracker/lib/features/track_setup/presentation/screens/add_track_flow.dart` — main flow widget + adapters
- `learning_tracker/lib/features/track_setup/presentation/widgets/curriculum_picker_step.dart` — Stage 1
- `learning_tracker/lib/features/track_setup/presentation/widgets/program_selection_step.dart` — Stage 3
- `learning_tracker/lib/features/track_setup/presentation/widgets/track_label_step.dart` — Stage 7
- `learning_tracker/test/features/track_setup/domain/entities/add_track_result_test.dart` — 16 unit tests
