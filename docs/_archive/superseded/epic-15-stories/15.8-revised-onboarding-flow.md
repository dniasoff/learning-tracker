# Story 15.8 -- Revised Onboarding Flow (DNI-116)

## Story Overview

**As a** parent or adult learner,
**I want** an onboarding flow that collects learner profile information (name + mode), introduces the learning process wizard per curriculum, and uses child-appropriate language when in child mode,
**So that** the setup experience is personalized and the review process is configured during onboarding rather than discovered later.

### Current Flow
```
Welcome -> Account Creation -> Mode Selection -> Curriculum Selection
  -> Import -> Bulk Mark -> Goal Setup -> [Rewards Setup (child only)] -> Dashboard
```

### Revised Flow (Adult)
```
Welcome -> Account Creation -> Profile Creation (name + mode)
  -> Curriculum Selection -> Import -> Learning Process Wizard (per curriculum)
  -> Bulk Mark -> Goal Setup -> Dashboard
```

### Revised Flow (Child)
```
Welcome -> Account Creation -> Profile Creation (child's name + mode)
  -> Curriculum Selection -> Import -> Learning Process Wizard (per curriculum)
  -> Bulk Mark -> Goal Setup -> Rewards Setup -> Handoff Screen -> Dashboard
```

The existing `ModeSelectionScreen` is replaced by a new `ProfileCreationScreen` that combines the name input and mode toggle into a single step. The Learning Process Wizard is a new step (per curriculum) that walks the user through configuring stages (review process). The Handoff Screen is a new child-mode-only terminal step.

---

## Acceptance Criteria

### AC1: Profile Creation Screen replaces Mode Selection
- [ ] `ModeSelectionScreen` is no longer part of the onboarding flow
- [ ] New `ProfileCreationScreen` displays "Who is this for?" / "Add a learner" heading
- [ ] Screen contains a name text field (required, validated non-empty)
- [ ] Screen contains a Child/Adult mode toggle (segmented button or cards)
- [ ] On Continue, profile is persisted via `UserProfileService.setUserMode()` with the entered name as `displayName`
- [ ] `AccountCreationScreen` navigates to `ProfileCreationRoute` instead of `ModeSelectionRoute`

### AC2: Child-Mode Language Throughout
- [ ] Curriculum selection header reads "What is [name] learning?" in child mode, "Select your curricula" in adult mode
- [ ] Bulk mark header reads "Mark [name]'s prior completions" in child mode
- [ ] Goal setup header reads "Set a learning goal for [name]" in child mode
- [ ] Learning process wizard reads "How does [name] review?" in child mode, "How do you review?" in adult mode

### AC3: Learning Process Wizard (Per Curriculum)
- [ ] After import completes, a wizard screen is shown for each imported curriculum (sequentially)
- [ ] Wizard displays the current stage configuration (default: Learn, Chazara 1, Chazara 2)
- [ ] User can add/remove/rename stages and set delay days (reuses stage editor logic)
- [ ] User can accept defaults with a single tap ("Use defaults" / "Looks good" button)
- [ ] Wizard is skipped if only 1 curriculum and user taps "Use defaults"

### AC4: Handoff Screen (Child Mode Only)
- [ ] After goal setup + rewards setup, child mode shows a handoff screen
- [ ] Displays "Setup complete! [Name]'s learning is all set up"
- [ ] "Add another learner" button loops back to Profile Creation
- [ ] "Start learning" button navigates to `AppShellRoute` (Dashboard)
- [ ] Adult mode skips the handoff screen entirely (goes straight to Dashboard)

### AC5: "Add Another Learner" Loop
- [ ] Tapping "Add another learner" on the handoff screen navigates to `ProfileCreationRoute`
- [ ] The new learner goes through the full sub-flow: Profile -> Curriculum -> Import -> Wizard -> Bulk Mark -> Goals -> Rewards -> Handoff
- [ ] Each learner's data is persisted independently under their own profile record

### AC6: State Persistence / Resume
- [ ] Onboarding state (current step + accumulated data) is persisted to local storage (SharedPreferences or Drift table)
- [ ] If the app is killed mid-onboarding, re-launching resumes at the last completed step
- [ ] Completing onboarding clears the persisted state

### AC7: Backward Compatibility
- [ ] Existing users who have already completed onboarding are not affected
- [ ] The `RestoreGuard` and `AuthGuard` continue to function correctly
- [ ] Google sign-in returning user logic in `AccountCreationScreen` still handles the existing-mode + active-curricula check

---

## Flow Diagrams

### Adult Flow (Text-Based)
```
[WelcomeScreen]
     |
     v
[AccountCreationScreen]  -- email/password or Google
     |
     v
[ProfileCreationScreen]  -- name + mode=adult  (NEW)
     |
     v
[OnboardingScreen: selection phase]  -- pick curricula
     |
     v
[OnboardingScreen: importing phase]  -- import all selected
     |
     v
[LearningProcessWizardScreen]  -- per curriculum, configure stages  (NEW)
     |  (repeats for each curriculum)
     v
[OnboardingScreen: bulkMark phase]  -- per curriculum
     |  (repeats for each curriculum)
     v
[OnboardingScreen: goalSetup phase]  -- per curriculum
     |  (repeats for each curriculum)
     v
[AppShellRoute -> DashboardScreen]
```

### Child Flow (Text-Based)
```
[WelcomeScreen]
     |
     v
[AccountCreationScreen]
     |
     v
[ProfileCreationScreen]  -- child's name + mode=child  (NEW)
     |
     v
[OnboardingScreen: selection phase]  -- "What is [name] learning?"
     |
     v
[OnboardingScreen: importing phase]
     |
     v
[LearningProcessWizardScreen]  -- "How does [name] review?"  (NEW)
     |  (repeats for each curriculum)
     v
[OnboardingScreen: bulkMark phase]  -- "Mark [name]'s prior completions"
     |
     v
[OnboardingScreen: goalSetup phase]  -- "Set a learning goal for [name]"
     |
     v
[OnboardingScreen: rewardsSetup phase]
     |
     v
[HandoffScreen]  -- "Setup complete! [Name]'s learning is all set up"  (NEW)
     |
     +--[ "Add another learner" ]---> [ProfileCreationScreen] (loops)
     |
     +--[ "Start learning" ]---> [AppShellRoute -> DashboardScreen]
```

---

## Screen Specifications

### ProfileCreationScreen (NEW)

**Route:** `/profile-creation`
**File:** `lib/features/onboarding/presentation/screens/profile_creation_screen.dart`

**Layout:**
- AppBar: "Add a Learner"
- Heading: "Who is this for?"
- Subheading: "Enter the learner's name and choose a mode."
- `TextFormField` for name (label: "Learner's Name", prefixIcon: `Icons.person_outline`)
  - Validator: non-empty, trimmed, max 50 chars
- Mode selector: two `_ModeCard` widgets (reuse pattern from current `ModeSelectionScreen`)
  - Child card: icon `Icons.child_care`, "Full gamification, mystery rewards, parent oversight"
  - Adult card: icon `Icons.person`, "Streamlined tracking, self-directed"
- Continue button (enabled when name non-empty + mode selected)

**Behavior:**
- On Continue: calls `UserProfileService.setUserMode(firebaseUid, displayName: name, mode: selectedMode)`
- Stores selected name + mode in a `profileCreationResultProvider` (or passes via route args) so downstream screens can read the learner name for child-mode language
- Navigates to `OnboardingRoute`

**State needed downstream:** `learnerName` (String) and `userMode` (UserMode) -- stored in a Riverpod `StateProvider` or `keepAlive` provider so all onboarding screens can read it.

### LearningProcessWizardScreen (NEW)

**Route:** Not a top-level route; pushed via `Navigator.of(context).push<WizardResult>(...)` from `OnboardingScreen` (same pattern as `BulkMarkScreen` and `GoalSetupScreen`).
**File:** `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart`

**Layout:**
- AppBar: "Review Process -- [curriculum.displayNameEn]"
- Heading: child mode -> "How does [name] review?", adult -> "How do you review?"
- Subheading: "Configure the stages for reviewing [curriculum]. You can change this later in Settings."
- List of current stages (initially the defaults: Learn, Chazara 1, Chazara 2) displayed as reorderable cards
  - Each card shows: stage name, delay days, edit icon, delete icon (stage 1 "Learn" is protected)
- "Add Stage" button at bottom of list
- Footer buttons:
  - "Use Defaults" (OutlinedButton) -- pops with null result (keep defaults)
  - "Save" (FilledButton) -- pops with `WizardResult` containing the modified stage list

**Behavior:**
- Reads existing stages via `stageListProvider(curriculumId)` (they are seeded during import)
- Modifications use `StageDefinitionRepository` methods (addStage, updateStage, deleteStage, reorderStages)
- Changes are persisted immediately (same as `StageEditorScreen`)
- Returns `WizardResult` (or null for "use defaults") to `OnboardingScreen`

**Reuse:** Most of the stage editing logic from `StageEditorScreen` can be extracted into a shared widget (`StageEditorWidget`) that both `StageEditorScreen` and `LearningProcessWizardScreen` use.

### HandoffScreen (NEW)

**Route:** Not a top-level route; shown as a phase within `OnboardingScreen` or pushed as a screen.
**File:** `lib/features/onboarding/presentation/screens/handoff_screen.dart`

**Layout:**
- No AppBar (or minimal, no back button)
- Large check icon (`Icons.check_circle_outline`, size 80, primary color)
- Heading: "Setup complete!"
- Subheading: "[Name]'s learning is all set up"
- Two buttons:
  - "Add another learner" (OutlinedButton) -- navigates to `ProfileCreationRoute`
  - "Start learning" (FilledButton) -- navigates to `AppShellRoute`

---

## Architecture & Design Notes

### Onboarding State Machine

The current `OnboardingScreen` uses a private `_ScreenPhase` enum to manage its internal state machine. This story adds two new phases:

```dart
enum _ScreenPhase {
  selection,        // Curriculum selection (existing)
  importing,        // Curriculum import (existing)
  wizard,           // Learning Process Wizard -- NEW
  bulkMark,         // Bulk mark prior completions (existing)
  goalSetup,        // Goal setup (existing)
  rewardsSetup,     // Rewards setup, child only (existing)
  handoff,          // Handoff screen, child only -- NEW
  done,             // Transition to dashboard (existing)
  error,            // Import error (existing)
}
```

**Transition after import success:**
```
importing -> wizard -> bulkMark -> goalSetup -> rewardsSetup (child) -> handoff (child) -> done
importing -> wizard -> bulkMark -> goalSetup -> done (adult)
```

### Onboarding Context Provider

Create a `keepAlive` Riverpod provider to hold the current onboarding context:

```dart
@Riverpod(keepAlive: true)
class OnboardingContext extends _$OnboardingContext {
  @override
  OnboardingContextState build() => const OnboardingContextState();

  void setLearnerProfile(String name, UserMode mode) { ... }
  void clearOnComplete() { ... }
}

@freezed
class OnboardingContextState with _$OnboardingContextState {
  const factory OnboardingContextState({
    String? learnerName,
    UserMode? userMode,
  }) = _OnboardingContextState;
}
```

This provider is read by `OnboardingScreen` to determine:
- What language variant to use (child vs adult)
- The learner name for personalized strings
- Whether to show handoff screen

### Route Guard Updates

The `AccountCreationScreen._signUpWithEmail()` and `_signUpWithGoogle()` methods currently push `ModeSelectionRoute()`. These must be changed to push `ProfileCreationRoute()`.

The existing Google sign-in returning-user check (`existingMode != null && active.isNotEmpty -> AppShellRoute`) remains unchanged, since returning users skip onboarding entirely.

### State Persistence Strategy

Use a Drift table `onboarding_progress` to persist onboarding state:

```dart
class OnboardingProgress extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firebaseUid => text()();
  TextColumn get currentStep => text()();           // enum name
  TextColumn get learnerName => text().nullable()();
  TextColumn get userMode => text().nullable()();
  TextColumn get selectedCurricula => text().nullable()(); // JSON list
  IntColumn get wizardIndex => integer().withDefault(const Constant(0))();
  IntColumn get bulkMarkIndex => integer().withDefault(const Constant(0))();
  IntColumn get goalSetupIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
}
```

On each phase transition in `OnboardingScreen`, write the current state to this table. On screen init, check if a row exists for the current user and resume from that step.

### Child-Mode Language Utility

Create a helper class or extension:

```dart
class OnboardingStrings {
  final String? learnerName;
  final UserMode mode;

  String get curriculumSelectionTitle =>
    mode == UserMode.child
      ? 'What is $learnerName learning?'
      : 'Choose which curricula to track';

  String get wizardTitle =>
    mode == UserMode.child
      ? 'How does $learnerName review?'
      : 'How do you review?';

  String goalSetupTitle(String curriculumName) =>
    mode == UserMode.child
      ? 'Set a learning goal for $learnerName'
      : 'Set a goal for $curriculumName';

  String get bulkMarkTitle =>
    mode == UserMode.child
      ? "Mark $learnerName's prior completions"
      : 'Mark prior completions';
}
```

---

## Implementation Steps

### Phase 1: ProfileCreationScreen + Route Wiring
1. Create `ProfileCreationScreen` at `lib/features/onboarding/presentation/screens/profile_creation_screen.dart`
2. Add `ProfileCreationRoute` to `app_router.dart` (path: `/profile-creation`)
3. Run `dart run build_runner build --delete-conflicting-outputs` to regenerate `app_router.gr.dart`
4. Update `AccountCreationScreen`: change `ModeSelectionRoute()` to `ProfileCreationRoute()` in both `_signUpWithEmail` and `_signUpWithGoogle`
5. Create `OnboardingContext` provider (`onboarding_context_provider.dart`) with `learnerName` and `userMode`
6. `ProfileCreationScreen` sets the context provider and navigates to `OnboardingRoute`

### Phase 2: Child-Mode Language
7. Create `OnboardingStrings` utility class at `lib/features/onboarding/domain/utils/onboarding_strings.dart`
8. Update `OnboardingScreen._buildSelection()` to read `OnboardingContext` and use `OnboardingStrings.curriculumSelectionTitle`
9. Update `_buildBulkMark()` to use `OnboardingStrings.bulkMarkTitle`
10. Update `_buildGoalSetup()` to use `OnboardingStrings.goalSetupTitle()`

### Phase 3: Learning Process Wizard
11. Extract stage editing logic from `StageEditorScreen` into a reusable `StageEditorWidget` at `lib/features/stages/presentation/widgets/stage_editor_widget.dart`
12. Create `LearningProcessWizardScreen` at `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart`
13. Add `wizard` phase to `_ScreenPhase` enum in `OnboardingScreen`
14. After import success, transition to wizard phase instead of directly to bulkMark
15. Implement `_buildWizard()` and `_startWizard()` methods in `OnboardingScreen` (same push-modal pattern as bulk mark)
16. Wire wizard queue: iterate through `_selected` curricula, showing wizard for each

### Phase 4: Handoff Screen
17. Create `HandoffScreen` widget at `lib/features/onboarding/presentation/screens/handoff_screen.dart`
18. Add `handoff` phase to `_ScreenPhase` enum
19. In `_startRewardsSetup()` / after rewards: for child mode, transition to handoff instead of done
20. For adult mode, keep existing behavior (skip rewards + handoff, go to done)
21. Implement "Add another learner" navigation: push `ProfileCreationRoute`, which re-enters the full sub-flow

### Phase 5: State Persistence
22. Create `OnboardingProgress` Drift table at `lib/core/database/tables/onboarding_progress.dart`
23. Add table to `AppDatabase`
24. Create `OnboardingProgressDao` with upsert/read/delete methods
25. Run `dart run build_runner build --delete-conflicting-outputs`
26. Update `OnboardingScreen` to write progress on each phase transition
27. Update `OnboardingScreen.initState()` to check for existing progress and resume

### Phase 6: Cleanup + Migration
28. Mark `ModeSelectionScreen` as deprecated (do not delete yet -- may be referenced in tests)
29. Remove `ModeSelectionRoute` from the onboarding flow in `app_router.dart` routes list (keep the import for backward compat during migration)
30. Update acceptance tests in `epic_09_onboarding_test.dart`

---

## Dev Notes

### Handling "Add Another Learner" Loop
- The handoff screen's "Add another learner" button should call `context.router.push(const ProfileCreationRoute())`.
- The new learner creates a separate `UserProfile` row in the database. The `UserProfileService.setUserMode()` currently keys on `firebaseUid`, so multiple learner profiles under one Firebase account requires a schema change: either a `learnerId` field or a separate `learners` table. **Decision needed:** Is multi-learner support per account in scope, or does "add another learner" mean sign out and create a new account? The requirements say "repeats from Profile Creation" which implies same account, so likely need a `learners` table or a `profileId` concept.
- **Recommendation:** For MVP, "Add another learner" creates a new `UserProfile` row with a generated `learnerId` (UUID) alongside the `firebaseUid`. The app maintains a `currentLearnerId` in SharedPreferences. The `OnboardingContext` tracks which learner is being set up. This is a bigger change and may warrant a sub-story.

### State Persistence Edge Cases
- If user kills app during import (async operation), resume should re-trigger import for curricula not yet in the local DB (check `CurriculumActivationService.getActiveCurricula()` to see which succeeded).
- If user kills app during wizard, resume from wizard for the first curriculum that hasn't been customized (check if stages differ from defaults or if a "wizard completed" flag is set).
- Clear `onboarding_progress` row when `_finishOnboarding()` is called.

### StageEditorWidget Extraction
The current `StageEditorScreen` has ~300 lines with mixed screen-level and editing logic. Extract into:
- `StageEditorWidget` -- the reorderable list + add/edit/delete dialogs (stateful widget)
- `StageEditorScreen` -- wraps `StageEditorWidget` in a `Scaffold` with `@RoutePage()`
- `LearningProcessWizardScreen` -- wraps `StageEditorWidget` with onboarding chrome (title, Use Defaults/Save buttons)

### Database Migration
Adding the `OnboardingProgress` table requires a Drift schema migration bump. Follow existing pattern in `AppDatabase` for `schemaVersion` increment and migration strategy.

---

## Test Plan

### Unit Tests

| Test | Description |
|------|-------------|
| `OnboardingStrings` child mode | Verify all string getters return child-mode variants with learner name |
| `OnboardingStrings` adult mode | Verify all string getters return adult-mode variants |
| `OnboardingProgressDao` upsert | Write and read back onboarding progress |
| `OnboardingProgressDao` delete | Clear progress on completion |
| `OnboardingContext` provider | Set learner profile, read it back, clear on complete |

### Widget Tests

| Test | Description |
|------|-------------|
| `ProfileCreationScreen` validation | Name required, mode required, Continue disabled until both filled |
| `ProfileCreationScreen` submission | Calls `UserProfileService.setUserMode` with correct args and navigates |
| `LearningProcessWizardScreen` defaults | "Use Defaults" pops with null result |
| `LearningProcessWizardScreen` edit | Add a stage, verify it appears, save pops with result |
| `HandoffScreen` renders | Shows learner name, both buttons present |
| `HandoffScreen` "Start learning" | Navigates to `AppShellRoute` |
| `HandoffScreen` "Add another learner" | Navigates to `ProfileCreationRoute` |
| `OnboardingScreen` child language | In child mode, verify title strings contain learner name |
| `OnboardingScreen` adult language | In adult mode, verify generic title strings |

### Integration / Acceptance Tests

| Test | Description |
|------|-------------|
| Adult full flow | Welcome -> Account -> Profile (adult) -> Curricula -> Import -> Wizard -> Bulk Mark -> Goal -> Dashboard |
| Child full flow | Welcome -> Account -> Profile (child) -> Curricula -> Import -> Wizard -> Bulk Mark -> Goal -> Rewards -> Handoff -> Dashboard |
| Resume after kill | Start onboarding, simulate kill at wizard step, relaunch, verify resumes at wizard |
| Add another learner | Complete child flow, tap "Add another learner", verify Profile Creation screen appears |

### Story Acceptance Test

Add tests to `test/story_acceptance/epic_15_revised_onboarding_test.dart` (new file, or extend `epic_09_onboarding_test.dart`).

---

## Files to Create

| File | Purpose |
|------|---------|
| `lib/features/onboarding/presentation/screens/profile_creation_screen.dart` | Profile creation (name + mode) |
| `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart` | Per-curriculum stage configuration wizard |
| `lib/features/onboarding/presentation/screens/handoff_screen.dart` | Child-mode completion/handoff screen |
| `lib/features/onboarding/presentation/providers/onboarding_context_provider.dart` | Riverpod provider for learner name + mode during onboarding |
| `lib/features/onboarding/domain/utils/onboarding_strings.dart` | Child/adult language utility |
| `lib/core/database/tables/onboarding_progress.dart` | Drift table for persisting onboarding state |
| `lib/core/database/daos/onboarding_progress_dao.dart` | DAO for onboarding progress |
| `lib/features/stages/presentation/widgets/stage_editor_widget.dart` | Extracted reusable stage editor widget |
| `test/story_acceptance/epic_15_revised_onboarding_test.dart` | Story acceptance tests (or extend epic_09) |

## Files to Modify

| File | Change |
|------|--------|
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Add `wizard` + `handoff` phases; read `OnboardingContext` for language; persist state on transitions |
| `lib/features/onboarding/presentation/screens/account_creation_screen.dart` | Navigate to `ProfileCreationRoute` instead of `ModeSelectionRoute` |
| `lib/features/onboarding/presentation/providers/onboarding_providers.dart` | Add `onboardingContextProvider`, `onboardingProgressDaoProvider` |
| `lib/core/navigation/app_router.dart` | Add `ProfileCreationRoute`, optionally `HandoffRoute` |
| `lib/core/navigation/app_router.gr.dart` | Regenerated by build_runner |
| `lib/core/database/app_database.dart` | Add `OnboardingProgress` table, bump schema version |
| `lib/features/stages/presentation/screens/stage_editor_screen.dart` | Extract editing logic to `StageEditorWidget`, use it here |
| `lib/features/onboarding/presentation/screens/mode_selection_screen.dart` | Deprecate (keep file, remove from flow) |
| `test/story_acceptance/epic_09_onboarding_test.dart` | Update existing onboarding tests for new flow |
