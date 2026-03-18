# Story 15.6 — Learning Process Wizard (DNI-114)

## Story Overview

**As a** user completing onboarding,
**I want to** configure my chazarah/review schedule for each selected curriculum,
**so that** the scheduler generates the right daily tasks based on my learning program.

This wizard runs once per selected curriculum during onboarding, after curriculum import + bulk mark completes and before goal setup. Users choose one of three paths: follow a recognized program preset, build a custom schedule, or opt for no formal review (learn-only).

In child mode, all user-facing copy addresses the child by name (e.g., "How does Yossi review?").

---

## Acceptance Criteria

| # | Criterion | Verification |
|---|-----------|-------------|
| AC1 | Wizard appears once per selected curriculum, after bulk mark and before goal setup | Onboarding flow integration test |
| AC2 | Screen title adapts to user mode: "How do you review?" (adult) vs "How does [name] review?" (child) | Widget test with both modes |
| AC3 | Three path cards are shown: "Follow a program", "Custom schedule", "No formal review" | Widget test |
| AC4 | "Follow a program" shows preset cards filtered by curriculum type, each with name + description + stage summary | Widget test with mock presets |
| AC5 | Tapping a preset shows a confirmation summary; confirming stores preset ID and creates stages via `StageDefinitionRepository` | Integration test |
| AC6 | "Custom schedule" opens a 3-step builder (rounds, timing, preview) | Widget test |
| AC7 | Custom builder Step 1: slider for 1-5 chazarah rounds (plus mandatory Learn stage) | Widget test |
| AC8 | Custom builder Step 2: per-round timing — "X days later" number input OR "every [day of week]" picker | Widget test |
| AC9 | Custom builder Step 3: preview showing a concrete example with stage names and delay values | Widget test |
| AC10 | Custom schedule creates stages without storing a preset ID | Unit test on provider |
| AC11 | "No formal review" creates a single "Learn" stage (stageOrder=1, delayDays=0) and advances | Unit test |
| AC12 | Wizard handles multiple curricula sequentially (queue pattern matching bulk mark) | Integration test |
| AC13 | Back navigation within the wizard works correctly (custom builder steps, preset confirmation) | Widget test |
| AC14 | Previously-created default stages (from `initializeDefaults`) are replaced by the wizard's output | Unit test |

---

## Screen Specifications

### Screen A: Path Selection ("How do you review?")

```
┌─────────────────────────────────────────┐
│ [AppBar] "Mishnayos — Review Setup"     │
│          1 of 3 curricula               │
├─────────────────────────────────────────┤
│                                         │
│  How do you review?                     │
│  (or "How does Yossi review?" in child) │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ 📋 Follow a program             │    │
│  │ Choose a recognized chazarah    │    │
│  │ schedule                        │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ 🛠️ Custom schedule              │    │
│  │ Build your own review           │    │
│  │ rounds & timing                 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ ➡️ No formal review             │    │
│  │ Just track new learning         │    │
│  └─────────────────────────────────┘    │
│                                         │
└─────────────────────────────────────────┘
```

**Card style:** Follows existing `_ModeCard` / `_CurriculumCard` pattern from onboarding — `Card` with `InkWell`, `RoundedRectangleBorder(borderRadius: 12)`, elevation 1, curriculum-colored accent via `AppTheme.getCurriculumColor()`.

---

### Screen B: Program Preset Selection

```
┌─────────────────────────────────────────┐
│ [AppBar] ← "Select a Program"          │
├─────────────────────────────────────────┤
│                                         │
│  Popular programs for Mishnayos:        │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Mishnah Yomis                   │    │
│  │ 1 Mishnah per day, 3 chazarah  │    │
│  │ rounds                          │    │
│  │ Learn → Day 1 → Day 7 → Day 30 │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Kehati Cycle                    │    │
│  │ Chapter-based, 2 rounds         │    │
│  │ Learn → Day 3 → Day 14         │    │
│  └─────────────────────────────────┘    │
│                                         │
│  (scrollable list)                      │
└─────────────────────────────────────────┘
```

**Tap a card** -> navigates to confirmation screen (Screen B2).

---

### Screen B2: Preset Confirmation

```
┌─────────────────────────────────────────┐
│ [AppBar] ← "Confirm Program"           │
├─────────────────────────────────────────┤
│                                         │
│  Mishnah Yomis                         │
│                                         │
│  Stages:                                │
│  1. Learn          (new content)        │
│  2. Chazara 1      (1 day later)        │
│  3. Chazara 2      (7 days later)       │
│  4. Chazara 3      (30 days later)      │
│                                         │
│  "This program adds 4 stages to your   │
│   Mishnayos schedule."                  │
│                                         │
│           ┌───────────────┐             │
│           │   Confirm     │ (Filled)    │
│           └───────────────┘             │
│           ┌───────────────┐             │
│           │    Back       │ (Outlined)  │
│           └───────────────┘             │
│                                         │
└─────────────────────────────────────────┘
```

---

### Screen C: Custom Schedule Builder

#### Step 1 of 3: Number of Rounds

```
┌─────────────────────────────────────────┐
│ [AppBar] ← "Custom Schedule"           │
│          Step 1 of 3                    │
├─────────────────────────────────────────┤
│                                         │
│  How many chazarah rounds?              │
│                                         │
│  (Learn stage is always included)       │
│                                         │
│  ┌───────────────────────────────┐      │
│  │  ◄ ════════●═══════ ►        │      │
│  │         3 rounds              │      │
│  └───────────────────────────────┘      │
│                                         │
│  Total stages: 4 (Learn + 3 reviews)   │
│                                         │
│           ┌───────────────┐             │
│           │    Next       │ (Filled)    │
│           └───────────────┘             │
│                                         │
└─────────────────────────────────────────┘
```

Slider: discrete, range 1–5, default 2.

#### Step 2 of 3: Per-Round Timing

```
┌─────────────────────────────────────────┐
│ [AppBar] ← "Custom Schedule"           │
│          Step 2 of 3                    │
├─────────────────────────────────────────┤
│                                         │
│  Set timing for each round:             │
│                                         │
│  Chazara 1                              │
│  ┌─────────────────────────────────┐    │
│  │ ○ X days later: [ 1 ]          │    │
│  │ ○ Every [day picker]           │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Chazara 2                              │
│  ┌─────────────────────────────────┐    │
│  │ ○ X days later: [ 7 ]          │    │
│  │ ○ Every [day picker]           │    │
│  └─────────────────────────────────┘    │
│                                         │
│  Chazara 3                              │
│  ┌─────────────────────────────────┐    │
│  │ ○ X days later: [ 30 ]         │    │
│  │ ○ Every [day picker]           │    │
│  └─────────────────────────────────┘    │
│                                         │
│  ┌──────┐        ┌───────────────┐      │
│  │ Back │        │     Next      │      │
│  └──────┘        └───────────────┘      │
└─────────────────────────────────────────┘
```

"X days later" is the default. Day-of-week picker uses `delayDays = 0` and stores the day as metadata (future expansion; for now, maps to a reasonable `delayDays` approximation).

#### Step 3 of 3: Preview

```
┌─────────────────────────────────────────┐
│ [AppBar] ← "Custom Schedule"           │
│          Step 3 of 3                    │
├─────────────────────────────────────────┤
│                                         │
│  Your schedule preview:                 │
│                                         │
│  Example: Learn "Berachos 1:1" today    │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ Today      │ Learn              │    │
│  │ Tomorrow   │ Chazara 1          │    │
│  │ +7 days    │ Chazara 2          │    │
│  │ +30 days   │ Chazara 3          │    │
│  └─────────────────────────────────┘    │
│                                         │
│  "You can adjust stages later in        │
│   Settings > Curriculum > Stages."      │
│                                         │
│  ┌──────┐        ┌───────────────┐      │
│  │ Back │        │    Confirm    │      │
│  └──────┘        └───────────────┘      │
└─────────────────────────────────────────┘
```

---

## Architecture & Design Notes

### Where the wizard fits in the onboarding flow

The existing `OnboardingScreen` manages a `_ScreenPhase` enum that drives a sequential flow. The wizard inserts as a new phase between `bulkMark` and `goalSetup`:

```
selection → importing → bulkMark → ** learningProcess ** → goalSetup → rewardsSetup → done
```

The `_ScreenPhase` enum gains a `learningProcess` value. Like `bulkMark`, the wizard runs per-curriculum using a queue + index pattern.

### Preset Data Model

Presets are defined as a static data structure (no database table needed for v1). A `LearningProcessPreset` model holds:

```dart
@freezed
abstract class LearningProcessPreset with _$LearningProcessPreset {
  const factory LearningProcessPreset({
    required String id,              // e.g., 'mishnah_yomis'
    required String name,
    required String description,
    required Set<CurriculumId> applicableCurricula,
    required List<PresetStage> stages,
  }) = _LearningProcessPreset;
}

@freezed
abstract class PresetStage with _$PresetStage {
  const factory PresetStage({
    required int stageOrder,
    required String stageName,
    required int delayDays,
  }) = _PresetStage;
}
```

A `learning_process_presets.dart` file provides a `const List<LearningProcessPreset> kLearningProcessPresets` with curated entries per curriculum type.

### Stage Creation Logic

All three paths converge on the same operation: **replace the current stages for the curriculum with the wizard's output**. This reuses `StageDefinitionRepository.resetToDefaults()` logic but with custom data:

1. Delete all existing stages for the curriculum (via `StageDao.deleteAllForCurriculum`)
2. Insert new stages from the wizard's selection
3. Push to Firestore via `_pushStages`

A new method `replaceStages(CurriculumId, List<({String name, int delayDays})>)` on `StageDefinitionRepository` encapsulates this.

### State Management

The wizard uses a `LearningProcessWizardNotifier` (Riverpod `Notifier`) that holds:

```dart
@freezed
abstract class LearningProcessWizardState with _$LearningProcessWizardState {
  const factory LearningProcessWizardState({
    required CurriculumId curriculumId,
    required LearningProcessPath selectedPath,  // program, custom, noReview
    String? selectedPresetId,
    @Default(2) int customRoundCount,
    @Default({}) Map<int, RoundTiming> customTimings,
    @Default(0) int customBuilderStep,           // 0, 1, 2
  }) = _LearningProcessWizardState;
}

enum LearningProcessPath { program, custom, noReview }

@freezed
abstract class RoundTiming with _$RoundTiming {
  const factory RoundTiming.daysLater(int days) = _DaysLater;
  const factory RoundTiming.dayOfWeek(int dayOfWeek) = _DayOfWeek;
}
```

The notifier exposes methods: `selectPath()`, `selectPreset()`, `setRoundCount()`, `setRoundTiming()`, `advanceStep()`, `goBackStep()`, `confirm()`.

`confirm()` calls `StageDefinitionRepository.replaceStages()` and returns the result to the onboarding coordinator.

### Child Mode Integration

The wizard reads the user mode from `UserProfileService.getUserMode()` (already available via `userProfileServiceProvider`) and the display name from the local profile DAO. If `UserMode.child`, copy adapts accordingly.

---

## Implementation Steps

### Step 1: Domain Models

1. Create `lib/features/onboarding/domain/models/learning_process_preset.dart` with `LearningProcessPreset` and `PresetStage` freezed models
2. Create `lib/features/onboarding/domain/models/round_timing.dart` with `RoundTiming` freezed union
3. Create `lib/features/onboarding/domain/data/learning_process_presets.dart` with curated preset data for each curriculum type

### Step 2: Repository Extension

4. Add `replaceStages(CurriculumId, List<({String name, int delayDays})>)` to `StageDefinitionRepository` interface
5. Implement in `StageDefinitionRepositoryImpl` — delete all + insert new + push

### Step 3: State Management

6. Create `lib/features/onboarding/presentation/providers/learning_process_wizard_provider.dart` with:
   - `LearningProcessWizardState` freezed model
   - `LearningProcessWizardNotifier` Riverpod notifier
   - Provider family keyed by `CurriculumId`

### Step 4: Wizard UI

7. Create `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart`:
   - `LearningProcessWizardScreen(curriculumId, userMode, childName?)` — StatefulWidget using ConsumerState
   - Internal phase management: `pathSelection` → `presetList` → `presetConfirm` | `customStep1` → `customStep2` → `customStep3`
   - Returns a result object to the caller (via `Navigator.pop`)

8. Build each sub-screen as private widget methods within the screen (same pattern as `OnboardingScreen._buildBulkMark` etc.):
   - `_buildPathSelection()` — three option cards
   - `_buildPresetList()` — filtered preset cards
   - `_buildPresetConfirmation()` — selected preset details + confirm button
   - `_buildCustomStep1()` — round count slider
   - `_buildCustomStep2()` — per-round timing config
   - `_buildCustomStep3()` — preview table + confirm button

### Step 5: Onboarding Integration

9. Add `learningProcess` to `_ScreenPhase` enum in `onboarding_screen.dart`
10. Add `_learningProcessQueue`, `_learningProcessIndex` fields (same pattern as `_bulkMarkQueue`)
11. Insert `_startLearningProcess()` call at the end of `_startBulkMark` completion (where it currently calls `_startGoalSetup`)
12. Add `_onLearningProcessResult()` handler that advances the queue or calls `_startGoalSetup()`
13. Add `_buildLearningProcess()` widget builder in the `build()` switch

### Step 6: Code Generation

14. Run `dart run build_runner build --delete-conflicting-outputs`

### Step 7: Tests

15. Write widget tests for the wizard screen
16. Write unit tests for the notifier
17. Write unit tests for `replaceStages`

---

## Dev Notes

### Multi-Step Wizard State Pattern

The wizard uses internal phase tracking (private enum) rather than routing, matching the established pattern in `OnboardingScreen` and `BulkMarkScreen`. This avoids auto_route complexity for transient onboarding sub-flows. The wizard is pushed via `Navigator.of(context).push<LearningProcessResult>(MaterialPageRoute(...))` from the onboarding coordinator, identical to how `BulkMarkScreen` and `GoalSetupScreen` are launched.

### Back Navigation

Within the wizard, the back button behavior:
- Path selection: pops the wizard entirely (returns null result to onboarding, which skips to default stages)
- Preset list/confirmation: returns to path selection
- Custom builder steps: goes to previous step (step 0 returns to path selection)

Use `WillPopScope` / `PopScope` to intercept back and route to the correct internal state.

### Day-of-Week Timing

The `StageDefinition` model only has `delayDays` (int). Day-of-week scheduling is a v2 feature. For now, the day-of-week option in Step 2 computes an approximate `delayDays` value (e.g., "every Monday" for something learned on Wednesday = 5 days). The UI can show the picker, but the stored value is the computed delay. A future migration can add a `scheduleDayOfWeek` column.

### Preset ID Storage

The `StageDefinition` table does not have a `presetId` column. Store the selected preset ID in a new `curriculum_settings` key-value or as a field on the user profile. Alternatively, add an optional `presetId` column to `StageDefinitions` (on the first stage row for a curriculum). The simplest approach: add a `presetId` nullable text column to `StageDefinitions` and populate it only on stage order 1.

### Max Stages Guard

The existing 10-stage limit in `StageDefinitionRepositoryImpl` applies. Presets and custom schedules must not exceed 10 stages (Learn + up to 9 chazarah rounds). The custom builder slider caps at 5 rounds = 6 total stages, well within the limit.

---

## Test Plan

### Unit Tests

| Test | File | What it validates |
|------|------|-------------------|
| `replaceStages` deletes old + inserts new | `test/features/stages/data/repositories/stage_definition_repository_impl_test.dart` | AC14 |
| Notifier: selectPath updates state | `test/features/onboarding/presentation/providers/learning_process_wizard_provider_test.dart` | AC3 |
| Notifier: confirm with preset creates correct stages | Same file | AC5, AC10 |
| Notifier: confirm with noReview creates single Learn stage | Same file | AC11 |
| Notifier: custom round count bounds (1-5) | Same file | AC7 |
| Preset filtering by curriculum | `test/features/onboarding/domain/data/learning_process_presets_test.dart` | AC4 |

### Widget Tests

| Test | File | What it validates |
|------|------|-------------------|
| Path selection shows 3 cards | `test/features/onboarding/presentation/screens/learning_process_wizard_screen_test.dart` | AC3 |
| Adult mode shows "How do you review?" | Same file | AC2 |
| Child mode shows "How does [name] review?" | Same file | AC2 |
| Tapping "Follow a program" shows preset list | Same file | AC4 |
| Preset cards show name + description + stage summary | Same file | AC4 |
| Tapping preset shows confirmation | Same file | AC5 |
| Custom step 1 shows slider | Same file | AC7 |
| Custom step 2 shows timing controls per round | Same file | AC8 |
| Custom step 3 shows preview table | Same file | AC9 |
| Back nav from preset list returns to path selection | Same file | AC13 |
| Back nav from custom step 2 returns to step 1 | Same file | AC13 |

### Story Acceptance Test

Add a group to the appropriate epic acceptance test file (likely `test/story_acceptance/epic_15_*_test.dart`). The acceptance test should verify the end-to-end flow: wizard appears after bulk mark, user selects a preset, stages are created, wizard advances to next curriculum.

---

## Files to Create

| Path | Purpose |
|------|---------|
| `lib/features/onboarding/domain/models/learning_process_preset.dart` | Freezed preset + stage models |
| `lib/features/onboarding/domain/models/round_timing.dart` | Freezed union for timing options |
| `lib/features/onboarding/domain/data/learning_process_presets.dart` | Static curated preset list |
| `lib/features/onboarding/presentation/providers/learning_process_wizard_provider.dart` | Wizard state notifier |
| `lib/features/onboarding/presentation/screens/learning_process_wizard_screen.dart` | Wizard UI screen |
| `test/features/onboarding/presentation/providers/learning_process_wizard_provider_test.dart` | Notifier unit tests |
| `test/features/onboarding/presentation/screens/learning_process_wizard_screen_test.dart` | Widget tests |
| `test/features/onboarding/domain/data/learning_process_presets_test.dart` | Preset data validation tests |

## Files to Modify

| Path | Change |
|------|--------|
| `lib/features/stages/domain/repositories/stage_definition_repository.dart` | Add `replaceStages()` method |
| `lib/features/stages/data/repositories/stage_definition_repository_impl.dart` | Implement `replaceStages()` |
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Add `learningProcess` phase, queue, and handler |
| `lib/features/onboarding/presentation/providers/onboarding_providers.dart` | Add wizard-related providers if needed |
| `lib/core/database/tables/stage_definitions.dart` | Optionally add nullable `presetId` column |
| `test/features/stages/data/repositories/stage_definition_repository_impl_test.dart` | Add tests for `replaceStages()` |
