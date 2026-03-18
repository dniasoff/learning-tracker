# Story 15.9 — Program Management in Settings (DNI-117)

## Story Overview

**As a** parent or adult user,
**I want to** change my learning program, add new curricula, and request programs from Settings,
**so that** I can adapt my learning journey post-onboarding without manual stage editing.

This story replaces the manual `StageEditorScreen` with a program-driven model. Users change programs per-curriculum through the same wizard flow used during onboarding. The old stage editor (add/edit/reorder/delete individual stages) is deprecated; programs now fully control stage definitions.

### Key Flows

1. **Change Program** — per-curriculum, from Settings or parent mode. Shows current program, launches wizard on change, preserves existing completions, creates new stage definitions, triggers bulk mark for new stages.
2. **Replace Stage Editor** — `StageEditorScreen` and its route are removed. `CurriculumSettingsScreen` links to "Change Program" instead of "Manage Stages."
3. **Request New Program** — "Don't see your program?" link opens a pre-filled email via `url_launcher`.
4. **Add New Curriculum** — post-onboarding, users can add a curriculum from Settings using the same selection -> import -> wizard -> bulk mark -> goal flow as onboarding.

---

## Acceptance Criteria

### AC1: Change Program Entry Point
- [ ] Each active curriculum in Settings shows "You're following [Program Name]" with a "Change Program" button.
- [ ] Tapping "Change Program" launches the program wizard (same component used in onboarding).
- [ ] Available from Settings (adult mode) and parent mode screens.

### AC2: Program Wizard Reuse
- [ ] The program wizard screen is a shared component, not duplicated between onboarding and settings.
- [ ] Wizard accepts a `CurriculumId` and optional `currentProgramId` to pre-select the current program.
- [ ] On completion, returns the selected program definition (stage names, delay days, order).

### AC3: Completion Preservation on Program Change
- [ ] When the user changes programs, existing completion records in the `completions` table are NOT deleted.
- [ ] Old stage definitions are soft-deleted or replaced; completions referencing old stage IDs remain intact.
- [ ] New stage definitions are created per the new program's configuration.
- [ ] A confirmation dialog warns: "Changing your program will update your learning stages. Your existing progress will be preserved."

### AC4: Bulk Mark for New Stages
- [ ] After program change, the `BulkMarkScreen` is presented so the user can mark prior completions for the new stages.
- [ ] The bulk mark flow reuses the existing `BulkMarkScreen` and `BulkPriorCompletionService`.
- [ ] The user can skip the bulk mark step.

### AC5: Stage Editor Removal
- [ ] `StageEditorScreen` is no longer accessible from any navigation path.
- [ ] `StageEditorRoute` is removed from `AppRouter.routes`.
- [ ] `CurriculumSettingsScreen` replaces the "Manage Stages" tile with "Change Program."

### AC6: Request New Program
- [ ] A "Don't see your program?" link is visible on the program wizard screen.
- [ ] Tapping it launches the device email client with:
  - **To:** `support@learningtracker.app` (or configured address)
  - **Subject:** `Program Request`
  - **Body template:** "I'd like to request a new program for [curriculum].\n\nProgram name: \nDescription: \nStages needed: "
- [ ] Uses `url_launcher` package with `mailto:` URI scheme.

### AC7: Add New Curriculum from Settings
- [ ] An "Add a curriculum" tile appears in the Settings Active Curricula section when fewer than 5 curricula are active.
- [ ] Tapping it launches the curriculum selection flow (filtered to inactive curricula only).
- [ ] After selection: import -> program wizard -> bulk mark -> goal setup, mirroring onboarding.
- [ ] On completion, the new curriculum appears in the active curricula list.

### AC8: Navigation & Error Handling
- [ ] Back navigation at any wizard step returns to the previous step (not Settings).
- [ ] Network errors during import show retry option.
- [ ] Program change can be cancelled at any step without side effects.

---

## Screen Specifications

### 15.9.1: Curriculum Program Card (in Settings)

Replaces the simple `SwitchListTile` per-curriculum with an expanded card:

```
+--------------------------------------------------+
| [Icon] Mishnayos                         [Toggle]|
|   Following: Oraysa                               |
|   [Change Program]                                |
+--------------------------------------------------+
```

- **Current program name** shown as subtitle.
- **"Change Program"** text button navigates to the program wizard.
- Toggle still controls activation/deactivation (existing behavior preserved).

### 15.9.2: Program Wizard Screen (Shared)

A new screen reusable by both onboarding and settings:

```
+--------------------------------------------------+
| < Back          Select Program                    |
+--------------------------------------------------+
|                                                   |
|   Choose a learning program for Mishnayos         |
|                                                   |
|   [x] Oraysa (Learn, Chazara 1, Chazara 2)       |
|   [ ] Dirshu (Learn, Review 1, Review 2, Test)    |
|   [ ] Custom...                                   |
|                                                   |
|   Don't see your program? Request one >           |
|                                                   |
|                          [Continue]               |
+--------------------------------------------------+
```

- Lists available programs for the curriculum.
- Shows stage names as subtitle for each program.
- "Custom..." option allows defining custom stages (replaces old stage editor's functionality but in a wizard UX).
- Returns a `ProgramSelection` result on completion.

### 15.9.3: Add Curriculum Flow (from Settings)

Entry point is a new `ListTile` in the Active Curricula section:

```
+--------------------------------------------------+
|  + Add a curriculum                               |
+--------------------------------------------------+
```

- Only shown when `activeCurricula.length < CurriculumId.values.length`.
- Launches `AddCurriculumFlowScreen` which orchestrates: selection -> import -> wizard -> bulk mark -> goal.
- Reuses `CurriculumImportService`, `BulkMarkScreen`, `GoalSetupScreen`.

---

## Architecture & Design Notes

### Component Reuse Strategy

The core insight is that onboarding already has the full flow: selection -> import -> bulk mark -> goal. This story extracts the reusable pieces and adds the program wizard layer.

**Shared components (already exist):**
- `BulkMarkScreen` (`lib/features/onboarding/presentation/screens/bulk_mark_screen.dart`) — hierarchy browser + stage selector + confirmation + execution
- `BulkPriorCompletionService` (`lib/features/onboarding/domain/services/bulk_prior_completion_service.dart`) — resolves selections, creates completions, sets bookmarks
- `CurriculumImportService` (`lib/features/onboarding/domain/services/curriculum_import_service.dart`) — loads content, activates curriculum
- `GoalSetupScreen` (`lib/features/scheduler/presentation/screens/goal_setup_screen.dart`) — target % + date form

**New components:**
- `ProgramWizardScreen` — selects a learning program (set of stage definitions) for a curriculum
- `ProgramChangeService` — orchestrates: replace stage definitions, preserve completions, trigger bulk mark
- `AddCurriculumFlowScreen` — settings-initiated flow mirroring onboarding but for a single new curriculum
- `ProgramDefinition` model — name, list of stages with names and delay days

### Preserving Completions on Program Change

The `completions` table stores `stage_id` (int FK). When program changes:

1. Query existing `stage_definitions` for the curriculum to get current stage IDs.
2. Create new `stage_definitions` rows per the new program.
3. Do NOT delete old stage definitions — mark them inactive or let completions reference the old IDs.
4. Alternatively, use a migration strategy: map old stage IDs to new ones where names match (e.g., "Learn" -> "Learn"), leave unmatched completions referencing old IDs (they just won't appear in active stage lists).

The safest approach: **keep old stage definition rows** with an `is_active` flag. The `StageDefinitionRepository.getStagesForCurriculum` filters to `is_active = true`. Completions referencing old stage IDs are preserved but those stages no longer appear in the scheduler.

### Email Launching

Since `url_launcher` is not currently a dependency, it must be added to `pubspec.yaml`. The `mailto:` scheme works cross-platform:

```dart
final uri = Uri(
  scheme: 'mailto',
  path: 'support@learningtracker.app',
  queryParameters: {
    'subject': 'Program Request',
    'body': 'I\'d like to request a new program for ${curriculum.displayNameEn}.\n\n'
            'Program name: \n'
            'Description: \n'
            'Stages needed: ',
  },
);
await launchUrl(uri);
```

---

## Implementation Steps

### Phase 1: Data Layer — Program Definitions & Stage Migration

1. **Create `ProgramDefinition` model** (`lib/features/settings/domain/entities/program_definition.dart`):
   - `name` (String), `stages` (List of `{name, delayDays}`), `id` (String)
   - Freezed-generated

2. **Create `ProgramRepository`** (`lib/features/settings/domain/repositories/program_repository.dart`):
   - `getProgramsForCurriculum(CurriculumId)` -> hardcoded list per curriculum (Oraysa, Dirshu, etc.)
   - `getCurrentProgram(CurriculumId)` -> reads from user preferences / stage definitions

3. **Add `is_active` column to `stage_definitions` table** (Drift migration):
   - Default `true` for existing rows
   - `StageDefinitionRepository.getStagesForCurriculum` filters on `is_active = true`

4. **Create `ProgramChangeService`** (`lib/features/settings/domain/services/program_change_service.dart`):
   - `changeProgram(CurriculumId, ProgramDefinition)`:
     - Marks existing stages as `is_active = false`
     - Creates new stages per program definition
     - Returns list of new stage IDs for bulk mark

### Phase 2: Program Wizard Screen

5. **Create `ProgramWizardScreen`** (`lib/features/settings/presentation/screens/program_wizard_screen.dart`):
   - `@RoutePage()` with `CurriculumId` param
   - Lists available programs from `ProgramRepository`
   - Highlights current program
   - "Custom..." option opens inline stage name/delay editor
   - "Don't see your program?" link at bottom
   - Returns `ProgramSelection` via `Navigator.pop()`

6. **Add `ProgramWizardRoute` to `AppRouter`**:
   - Path: `/curriculum/:curriculumId/program`
   - Guarded by `authGuard`

7. **Create program wizard providers** (`lib/features/settings/presentation/providers/program_providers.dart`):
   - `programRepositoryProvider`
   - `currentProgramProvider(CurriculumId)`

### Phase 3: Change Program Flow

8. **Update `CurriculumSettingsScreen`**:
   - Replace "Manage Stages" tile with "Change Program" tile showing current program
   - On tap: navigate to `ProgramWizardRoute`
   - On wizard result: call `ProgramChangeService.changeProgram()`, then push `BulkMarkScreen`

9. **Update `SettingsScreen`** curriculum section:
   - Enhance each curriculum tile to show current program name
   - Add "Change Program" action

10. **Create change program confirmation dialog**:
    - Warns about stage changes
    - Shows what will change (old stages -> new stages)
    - Confirm/Cancel

### Phase 4: Add Curriculum from Settings

11. **Create `AddCurriculumFlowScreen`** (`lib/features/settings/presentation/screens/add_curriculum_flow_screen.dart`):
    - Phase-based `ConsumerStatefulWidget` (like `OnboardingScreen`)
    - Phases: `selection` -> `importing` -> `programWizard` -> `bulkMark` -> `goalSetup` -> `done`
    - Reuses `CurriculumImportService`, `BulkMarkScreen`, `GoalSetupScreen`
    - Filters curriculum list to show only inactive curricula

12. **Add "Add a curriculum" tile to `SettingsScreen`**:
    - Appears below the curriculum toggles
    - Hidden when all 5 curricula are active
    - Navigates to `AddCurriculumFlowScreen`

13. **Add `AddCurriculumFlowRoute` to `AppRouter`**:
    - Path: `/settings/add-curriculum`
    - Guarded by `authGuard`

### Phase 5: Request New Program (Email)

14. **Add `url_launcher` dependency** to `pubspec.yaml`
15. **Add email launch helper** (`lib/core/utils/email_launcher.dart`):
    - `launchProgramRequest(CurriculumId)` — constructs and launches mailto URI
16. **Wire up "Don't see your program?" link** in `ProgramWizardScreen`

### Phase 6: Remove Stage Editor

17. **Remove `StageEditorRoute` from `AppRouter.routes`**
18. **Remove `StageEditorScreen` import from `app_router.dart`**
19. **Update `CurriculumSettingsScreen`** — remove `StageEditorRoute` navigation
20. **Keep `StageEditorScreen` file temporarily** (can be deleted in a follow-up if no other references exist)
21. **Keep `StageEditorNotifier` and `stageEditorProvider`** — still needed internally for stage mutations during program change

### Phase 7: Testing & Cleanup

22. Run `dart run build_runner build --delete-conflicting-outputs` for code gen
23. Run `make analyze` and `make format-check`
24. Write acceptance tests (see Test Plan)
25. Run `make ci`

---

## Dev Notes

### Preserving Completions — Detailed Strategy

The `completions` table schema (from Drift):
```
completions(id, sefariaRef, curriculumId, stageId, trackType, completedAt, ...)
```

`stageId` references `stage_definitions.id`. When we deactivate old stages:
- The FK constraint is NOT violated because we are not deleting the `stage_definitions` row.
- Queries for "active" completions should join on `stage_definitions` where `is_active = true` IF we want to filter them out. But per AC3, completions should be preserved and visible.
- The simplest approach: completions with old stage IDs are simply historical. The progress/history screens already show `stageName` from the completion record or join with stage definitions. Ensure the join handles inactive stages gracefully (OUTER JOIN or store stage name on completion).

### Database Migration

Adding `is_active` to `stage_definitions` requires a Drift schema migration:
```dart
// In migrations
await m.addColumn(stageDefinitions, stageDefinitions.isActive);
```

Default value: `true`. No data migration needed.

### Email Launcher Platform Considerations

- `url_launcher` requires platform-specific setup for `mailto:` scheme.
- Android: no additional config (handled by intent system).
- iOS: add `mailto` to `LSApplicationQueriesSchemes` in `Info.plist`.
- Test with `canLaunchUrl()` before calling `launchUrl()` and show a snackbar if no email client is available.

### Wizard Should Support "Custom" Programs

The custom option in the wizard should allow defining:
- Number of stages (1-10, matching existing `StageLimitExceededException` at 10)
- Stage names and delay days for each
- This replaces the old `StageEditorScreen` functionality but within the wizard UX

### Provider Invalidation After Program Change

After changing a program, invalidate:
- `stageListProvider(curriculum)` — new stages
- `stageEditorProvider(curriculum)` — notifier state
- `allDailyTasksProvider` — scheduler recalculation
- Any completion-summary providers that depend on active stages

---

## Test Plan

### Unit Tests

| Test | Location | What it verifies |
|------|----------|-----------------|
| `ProgramChangeService.changeProgram` preserves completions | `test/features/settings/domain/services/program_change_service_test.dart` | Old completions remain in DB after stage swap |
| `ProgramChangeService.changeProgram` creates new stages | Same file | New stage definitions created per program |
| `ProgramChangeService.changeProgram` deactivates old stages | Same file | Old stages have `is_active = false` |
| `ProgramRepository.getProgramsForCurriculum` | `test/features/settings/domain/repositories/program_repository_test.dart` | Returns correct programs per curriculum |
| `email_launcher` constructs valid mailto URI | `test/core/utils/email_launcher_test.dart` | URI scheme, subject, body template |

### Widget Tests

| Test | Location | What it verifies |
|------|----------|-----------------|
| `ProgramWizardScreen` lists programs | `test/features/settings/presentation/screens/program_wizard_screen_test.dart` | Shows program names, highlights current |
| `ProgramWizardScreen` "Request" link | Same file | Link is rendered, tap triggers email |
| `SettingsScreen` shows "Add a curriculum" | `test/features/settings/presentation/screens/settings_screen_test.dart` | Tile visible when < 5 active |
| `SettingsScreen` hides "Add a curriculum" | Same file | Tile hidden when all 5 active |
| `CurriculumSettingsScreen` shows "Change Program" | `test/features/settings/presentation/screens/curriculum_settings_screen_test.dart` | Replaces old "Manage Stages" tile |

### Integration / Acceptance Tests

| Test | Tags | What it verifies |
|------|------|-----------------|
| Change program preserves completions | `story_15_9` | End-to-end: mark completions, change program, verify completions still exist |
| Add curriculum from settings completes full flow | `story_15_9` | Selection -> import -> wizard -> bulk mark -> goal |
| Stage editor route is inaccessible | `story_15_9` | Navigating to old `/curriculum/:id/stages` redirects or 404s |
| Program change triggers bulk mark | `story_15_9` | After wizard, bulk mark screen is presented |

### Manual Testing Checklist

- [ ] Change program for each curriculum type (Mishnayos, Bavli, etc.)
- [ ] Verify completions survive program change in progress screens
- [ ] Add a new curriculum from Settings (not onboarding)
- [ ] "Don't see your program?" opens email client on Android and iOS
- [ ] Cancel program change at each step — no side effects
- [ ] Custom program option creates correct stages
- [ ] Old stage editor URL no longer navigable

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/settings/domain/entities/program_definition.dart` | Freezed model for program (name, stages) |
| `lib/features/settings/domain/repositories/program_repository.dart` | Abstract repo for available programs |
| `lib/features/settings/data/repositories/program_repository_impl.dart` | Hardcoded program catalog per curriculum |
| `lib/features/settings/domain/services/program_change_service.dart` | Orchestrates stage swap, preserves completions |
| `lib/features/settings/presentation/screens/program_wizard_screen.dart` | Shared program selection wizard |
| `lib/features/settings/presentation/screens/add_curriculum_flow_screen.dart` | Post-onboarding add-curriculum flow |
| `lib/features/settings/presentation/providers/program_providers.dart` | Riverpod providers for program data |
| `lib/core/utils/email_launcher.dart` | Mailto URI builder + launcher |
| `test/features/settings/domain/services/program_change_service_test.dart` | Unit tests for program change |
| `test/features/settings/presentation/screens/program_wizard_screen_test.dart` | Widget tests for wizard |

## Files to Modify

| File | Change |
|------|--------|
| `lib/core/navigation/app_router.dart` | Remove `StageEditorRoute`, add `ProgramWizardRoute` and `AddCurriculumFlowRoute` |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Add "Add a curriculum" tile, enhance curriculum cards with program info |
| `lib/features/settings/presentation/screens/curriculum_settings_screen.dart` | Replace "Manage Stages" with "Change Program" |
| `lib/core/database/app_database.dart` | Add `is_active` column to `stage_definitions` table, migration |
| `lib/features/stages/domain/models/stage_definition.dart` | Add `isActive` field to Freezed model |
| `lib/features/stages/data/repositories/stage_definition_repository_impl.dart` | Filter by `is_active` in queries |
| `lib/features/stages/domain/repositories/stage_definition_repository.dart` | Add `deactivateStages(CurriculumId)` method |
| `lib/features/stages/presentation/providers/stage_providers.dart` | Unchanged but verify filtering works |
| `pubspec.yaml` | Add `url_launcher` dependency |
| `ios/Runner/Info.plist` | Add `mailto` to `LSApplicationQueriesSchemes` |
| `test/story_acceptance/epic_15_*_test.dart` | Add/activate story 15.9 acceptance tests |
