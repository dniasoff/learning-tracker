# Story 18.5: Track Editing from Settings (עריכת מסלול)

Status: ready-for-dev

## Story

As a learner,
I want to edit individual settings of an existing track (scope, חזרה stages, goals, study days) from the Track Management Hub,
so that I can adjust my learning configuration as my needs evolve — without creating a new track.

## Acceptance Criteria

**AC-1: Track detail screen shows current configuration**
**Given** the user taps a track in the Track Management Hub
**When** the track detail screen loads
**Then** it displays: label, curriculum, program, scope summary, חזרה stages, goal, study days

**AC-2: Edit track label**
**Given** the user is on the track detail screen
**When** they tap the track label
**Then** an inline edit or dialog allows them to rename the track

**AC-3: Edit scope**
**Given** the user taps "Edit Scope" on the track detail
**When** the scope selection screen opens
**Then** it shows the current scope with existing selections pre-checked
**And** changes are saved on confirm

**AC-4: Edit חזרה configuration**
**Given** the user taps "Edit חזרה" on the track detail
**When** the learning process wizard opens
**Then** it shows the current stage configuration
**And** the user can modify presets, add/remove stages, adjust delays
**And** changes are saved on confirm

**AC-5: Edit goals**
**Given** the user taps "Edit Goal" on the track detail
**When** the goal setup screen opens
**Then** it shows the current goal (pace or deadline) pre-filled
**And** changes are saved on confirm

**AC-6: Edit study days**
**Given** the user taps "Edit Study Days" on the track detail
**When** the study day config screen opens
**Then** it shows the current day configuration pre-filled
**And** changes are saved on confirm

**AC-7: Changes take effect immediately**
**Given** the user edits a track setting
**When** they save and return to the dashboard
**Then** the scheduler reflects the updated configuration
**And** no restart or re-onboarding is required

## Tasks / Subtasks

### T1: Track Detail Screen (AC: 1)

- [ ] Create `TrackDetailScreen` at `lib/features/track_setup/presentation/screens/track_detail_screen.dart`
- [ ] Accepts `trackKey` parameter (profileId + curriculumId + trackType)
- [ ] Display sections:
  - Track label (tappable for edit)
  - Curriculum name (Hebrew, read-only)
  - Program (if any, read-only)
  - Scope summary (tappable → edit)
  - חזרה stages list (tappable → edit)
  - Goal summary (tappable → edit)
  - Study days grid (tappable → edit)
- [ ] Register route `/settings/tracks/:trackId` in `app_router.dart`

### T2: Add Edit Mode Support to Existing Step Widgets (AC: 3-6)

- [ ] Add `initialValue` parameter to `ScopeSelectionScreen` — pre-check existing scope
- [ ] Add `initialValue` parameter to `LearningProcessWizardScreen` — pre-fill current stages
- [ ] Add `initialValue` parameter to `GoalSetupScreen` — pre-fill current goal
- [ ] Add `initialValue` parameter to `StudyDayConfigScreen` — pre-fill current day config
- [ ] Each widget returns result on save (reuse existing result types)

### T3: Edit Track Label (AC: 2)

- [ ] Tap on label → show dialog with TextField pre-filled with current label
- [ ] On confirm: update track label in database
- [ ] Invalidate track providers to refresh UI

### T4: Edit Scope Flow (AC: 3)

- [ ] Tap "Edit Scope" → navigate to `ScopeSelectionScreen` with current scope pre-selected
- [ ] On save: update `curriculum_scopes` table
- [ ] Invalidate scope-related providers

### T5: Edit חזרה Flow (AC: 4)

- [ ] Tap "Edit חזרה" → navigate to `LearningProcessWizardScreen` with current config
- [ ] On save: update `stage_definitions` table
- [ ] Note: changing stages affects future scheduling but not past completions

### T6: Edit Goal Flow (AC: 5)

- [ ] Tap "Edit Goal" → navigate to `GoalSetupScreen` with current goal pre-filled
- [ ] On save: update `goals` table via `GoalRepository`
- [ ] Invalidate pace/progress providers

### T7: Edit Study Days Flow (AC: 6)

- [ ] Tap "Edit Study Days" → navigate to `StudyDayConfigScreen` with current config
- [ ] On save: update `study_day_configs` table
- [ ] Invalidate scheduler providers

### T8: Provider Invalidation for Immediate Effect (AC: 7)

- [ ] After any edit, invalidate relevant providers:
  - Track list providers (for Track Management Hub refresh)
  - Scheduler providers (for dashboard task recalculation)
  - Pace/progress providers (for dashboard metrics)
- [ ] No app restart required — Riverpod reactivity handles updates

### T9: Wire Track Management Hub → Detail (AC: 1)

- [ ] In `TrackManagementHubScreen`, tap on track → navigate to `TrackDetailScreen`
- [ ] Pass track identifier (composite key or encoded ID)

### T10: Tests (AC: 1-7)

- [ ] Widget test: track detail shows all current settings
- [ ] Widget test: edit label dialog saves and refreshes
- [ ] Widget test: edit scope navigates with pre-filled data
- [ ] Widget test: edit חזרה navigates with pre-filled data
- [ ] Widget test: edit goal navigates with pre-filled data
- [ ] Widget test: edit study days navigates with pre-filled data
- [ ] Integration test: edit → save → dashboard reflects change

## Dev Notes

### Architecture

- **Dependency:** Requires 18.1 (reusable step widgets) and 18.3 (Track Management Hub navigation)
- **Key pattern:** Reuse AddTrackFlow step widgets in edit mode via `initialValue` parameters
- **Existing widgets get edit mode, NOT new widgets**

### Key Files

| File | Action |
|------|--------|
| `lib/features/track_setup/presentation/screens/track_detail_screen.dart` | Create |
| `lib/features/settings/presentation/screens/scope_selection_screen.dart` | Modify — add initialValue |
| `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart` | Modify — add initialValue |
| `lib/features/scheduler/presentation/screens/goal_setup_screen.dart` | Modify — add initialValue |
| `lib/features/scheduler/presentation/screens/study_day_config_screen.dart` | Modify — add initialValue |
| `lib/core/navigation/app_router.dart` | Modify — add track detail route |

### Critical Constraints

- Changing חזרה stages only affects future scheduling, not past completions
- Changing scope doesn't delete existing completions outside new scope
- All edits within transactions for atomicity
- Firestore sync after each edit (fire-and-forget)

### References

- [Source: docs/developer-guide.md#core-domain-model-the-track]
- [Source: _bmad-output/project-context.md]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
