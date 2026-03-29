# Story 18.5: Track Editing from Settings (DNI-170)

Status: review

## Story

As a learner,
I want to edit individual settings of an existing track (scope, chazara stages, goals, study days) from the Track Management Hub,
so that I can adjust my learning configuration as my needs evolve without creating a new track.

## Acceptance Criteria

**AC-1: Track detail screen shows current configuration**
**Given** the user taps a track in the Track Management Hub
**When** the `TrackDetailScreen` loads
**Then** it displays sections for: label, curriculum name (Hebrew, read-only), program (read-only), scope summary, chazara stages list, goal summary, study days grid
**And** each editable section has a chevron or edit icon

**AC-2: Edit track label**
**Given** the user taps the track label section
**When** an AlertDialog with a pre-filled TextField appears
**Then** on confirm, the label is updated in the DB and the track list refreshes

**AC-3: Edit scope**
**Given** the user taps "Edit Scope"
**When** the ScopeSelectionScreen opens with existing selections pre-checked
**Then** on save, the curriculum_scopes table is updated

**AC-4: Edit chazara configuration**
**Given** the user taps "Edit Chazara"
**When** the LearningProcessWizardScreen opens
**Then** the user can modify stages and on confirm, stage_definitions are updated

**AC-5: Edit goals**
**Given** the user taps "Edit Goal"
**When** the GoalSetupScreen opens with existingGoal parameter
**Then** on save, the goal is updated and pace providers are invalidated

**AC-6: Edit study days**
**Given** the user taps "Edit Study Days"
**When** the StudyDayConfigScreen opens with current config
**Then** on save, study day configs are updated and scheduler providers are invalidated

**AC-7: Changes take effect immediately**
**Given** the user edits any track setting
**When** they return to the dashboard
**Then** the scheduler reflects the updated configuration via Riverpod provider invalidation

## Tasks / Subtasks

### T1: Create TrackDetailScreen (AC: 1)

- [x] Create `lib/features/track_setup/presentation/screens/track_detail_screen.dart`
- [x] Display 6 sections: label, curriculum, scope, chazara, goal, study days
- [x] Read-only fields (curriculum, program) have no edit affordance
- [x] Editable fields have chevron/edit icon indicating tappable

### T2: Wire Navigation from Hub (AC: 1)

- [x] Replace placeholder `_onTrackTap()` snackbar in `TrackManagementHubScreen` with navigation to `TrackDetailScreen`
- [x] Register `TrackDetailRoute` in `app_router.dart`
- [x] Regenerate `app_router.gr.dart` via build_runner

### T3: Edit Label Dialog (AC: 2)

- [x] AlertDialog with TextField pre-filled with current label
- [x] On confirm, update label in `curriculum_tracks` table
- [x] Invalidate `activeTracksProvider`

### T4: Edit Scope Navigation (AC: 3)

- [x] Navigate to `ScopeSelectionScreen` with curriculum context
- [x] Existing scope selections pre-checked via `_loadExistingScopes()`
- [x] On save, update `curriculum_scopes` table

### T5: Edit Chazara Navigation (AC: 4)

- [x] Navigate to `LearningProcessWizardScreen`
- [x] On confirm, update stage_definitions via `LearningProcessWizardService.applyWizardResult()`
- [x] Invalidate stage-related and scheduler providers

### T6: Edit Goal Navigation (AC: 5)

- [x] Navigate to `GoalSetupScreen` with `existingGoal` parameter
- [x] On save, update goal and invalidate pace providers

### T7: Edit Study Days Navigation (AC: 6)

- [x] Navigate to `StudyDayConfigScreen` — already reads from `studyDayConfigsProvider`
- [x] On save, invalidate scheduler providers

### T8: Provider Invalidation (AC: 7)

- [x] Label edit invalidates `activeTracksProvider`
- [x] Scope edit invalidates scope providers
- [x] Chazara edit invalidates `stageListProvider`, `stageEditorProvider`, `allDailyTasksProvider`
- [x] Goal edit invalidates `dashboardPaceStatusProvider`, scheduler providers
- [x] Study days edit invalidates `studyDayConfigsProvider`, `allDailyTasksProvider`

## Dev Notes

### Architecture

- **TrackDetailScreen** is a read-only overview with edit entry points — each section taps to its dedicated edit screen
- **Existing edit mode support:** `GoalSetupScreen` already has `existingGoal` param; `StudyDayConfigScreen` reads from provider; `ScopeSelectionScreen` has `_loadExistingScopes()`
- **Track identifier:** Composite key `(profileId, curriculumId, trackType)` from `CurriculumTrack` Drift view

### Key Files

| File | Path | Role |
|------|------|------|
| TrackDetailScreen | `lib/features/track_setup/presentation/screens/track_detail_screen.dart` | New — read-only overview with edit entry points |
| TrackManagementHubScreen | `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart` | Modified — `_onTrackTap()` wired |
| AppRouter | `lib/core/navigation/app_router.dart` | Modified — TrackDetailRoute added |
| ScopeSelectionScreen | `lib/features/settings/presentation/screens/scope_selection_screen.dart` | Existing — used for scope edit |
| LearningProcessWizardScreen | `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart` | Existing — used for chazara edit |
| GoalSetupScreen | `lib/features/scheduler/presentation/screens/goal_setup_screen.dart` | Existing — already has edit mode |
| StudyDayConfigScreen | `lib/features/scheduler/presentation/screens/study_day_config_screen.dart` | Existing — already has edit mode |

### Provider Invalidation Map

| Edit Type | Providers to Invalidate |
|-----------|------------------------|
| Label | `activeTracksProvider` |
| Scope | `activeTracksProvider`, curriculum scope providers |
| Chazara stages | `stageListProvider`, `stageEditorProvider`, `allDailyTasksProvider` |
| Goal | `dashboardPaceStatusProvider`, scheduler providers |
| Study days | `studyDayConfigsProvider`, `allDailyTasksProvider` |

### Critical Constraints

- Changes take effect immediately via Riverpod provider invalidation — no app restart needed
- Firestore sync fires as fire-and-forget after each edit (existing pattern)
- `GoalSetupScreen` and `StudyDayConfigScreen` already support edit mode — minimal changes needed

### Testing Standards

- Widget tests for TrackDetailScreen rendering and edit navigation
- Verify provider invalidation triggers after each edit type

### References

- [Source: docs/developer-guide.md#Core Domain Model: The Track] — Track properties
- [Source: _bmad-output/project-context.md#Riverpod State Management] — Provider invalidation patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: `TrackDetailScreen` created with 6 sections. Label, curriculum (read-only), scope, chazara, goal, study days. Each editable section has chevron/edit icon.
- T2: `_onTrackTap()` placeholder in `TrackManagementHubScreen` replaced with `context.router.push(TrackDetailRoute(...))`. Route registered in `app_router.dart`.
- T3-T7: Edit navigation wired for all 5 editable sections — label dialog, scope, chazara, goal, study days.
- T8: Provider invalidation implemented for each edit type.

### Change Log

- 2026-03-29: Initial implementation — TrackDetailScreen with edit navigation from hub. Commit `8b37a0a`.

### File List

**Created:**
- `lib/features/track_setup/presentation/screens/track_detail_screen.dart`

**Modified:**
- `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart` — wired `_onTrackTap()`
- `lib/core/navigation/app_router.dart` — added TrackDetailRoute
- `lib/core/navigation/app_router.gr.dart` — regenerated
