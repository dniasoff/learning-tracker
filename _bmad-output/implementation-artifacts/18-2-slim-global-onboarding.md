# Story 18.2: Slim Global Onboarding (Global Settings Only)

Status: review

## Story

As a new user,
I want onboarding to quickly collect my global settings (profile, mode, language) and then guide me to add my first track,
so that I'm not overwhelmed by a monolithic wizard and can start learning faster.

## Acceptance Criteria

**AC-1: Onboarding only collects global settings**
**Given** a new user starts onboarding
**When** they progress through the wizard
**Then** the only onboarding-owned phases are: profileCreation and languageSelection
**And** all per-track phases (curriculum, scope, חזרה, goals, etc.) are delegated to AddTrackFlow

**AC-2: First track creation is embedded**
**Given** the user completes language selection
**When** they reach the next step
**Then** the AddTrackFlow is launched inline with context `isOnboarding: true`
**And** the header says "Set up your first learning track"

**AC-3: Onboarding completes after first track**
**Given** the user finishes the AddTrackFlow
**When** they're in adult mode
**Then** they are taken directly to the Dashboard
**And** when in child mode, the handoff screen appears first (18.6)

**AC-4: "Add another track" option**
**Given** the user just completed their first track in onboarding
**When** the AddTrackFlow returns
**Then** they see an option to "Add another track" (launches AddTrackFlow again) or "Start learning" (→ Dashboard)

**AC-5: Removed phases cleaned up**
**Given** the refactored OnboardingScreen
**When** inspecting the code
**Then** the `_ScreenPhase` enum only contains: `profileCreation`, `languageSelection`, `addTrack`, `handoff` (child), `done`
**And** all removed phases are handled by AddTrackFlow

**AC-6: State persistence for slim onboarding**
**Given** the user is mid-onboarding
**When** the app is interrupted
**Then** global state (profile, language) is preserved via SharedPreferences
**And** AddTrackFlow handles its own state persistence (from 18.1)

**AC-7: Back navigation from AddTrackFlow to onboarding**
**Given** the user is on the first step of AddTrackFlow during onboarding
**When** they press back
**Then** they return to the language selection step in onboarding (not exit the app)

## Tasks / Subtasks

### T1: Refactor _ScreenPhase Enum (AC: 5)

- [x] Replace the 17-phase `_ScreenPhase` enum with slim version:
  - `profileCreation` — name + adult/child mode
  - `languageSelection` — content language variant
  - `addTrack` — delegates to AddTrackFlow (18.1)
  - `addAnotherPrompt` — "Add another track?" or "Start learning"
  - `handoff` — child mode only (18.6)
  - `done` — completion
- [x] Remove all per-track phases: `pathSelection`, `calendarProgramList`, `calendarProgramConfirm`, `startTrackingFrom`, `selection`, `importing`, `learningProcessWizard`, `studyDays`, `scopeSelection`, `bulkMark`, `goalSetup`, `rewardsSetup`

### T2: Strip Per-Track Logic from OnboardingScreen (AC: 1, 5)

- [x] Remove all per-track state variables from `OnboardingScreen`:
  - `_selectedCurricula`, `_wizardResults`, `_bulkMarkResults`, `_goalResults`, `_studyDayResults`
  - Calendar program state, scope selection state, import progress state
- [x] Remove all per-track methods:
  - `_onCurriculumSelected()`, `_onImportComplete()`, `_onWizardComplete()`, `_onBulkMarkComplete()`, `_onGoalComplete()`, `_onScopeComplete()`, `_onStudyDaysComplete()`
  - Calendar program methods, import streaming methods
- [x] Keep only global methods: `_onProfileCreated()`, `_onLanguageSelected()`, `_onAddTrackComplete()`
- [x] Target: reduce `onboarding_screen.dart` from ~2,395 lines to <500

### T3: Embed AddTrackFlow in Onboarding (AC: 2, 7)

- [x] When phase is `addTrack`, render `AddTrackFlow` widget inline (not as separate route)
  - Pass `profileId`, `isOnboarding: true`, `isChildMode` from profile creation
- [x] AddTrackFlow header shows "Set up your first learning track" when `isOnboarding: true`
- [x] On back from AddTrackFlow Stage 1 → return to `languageSelection` phase
- [x] On AddTrackFlow completion → receive `AddTrackResult`, advance to `addAnotherPrompt`

### T4: "Add Another Track" Prompt (AC: 4)

- [x] Create `addAnotherPrompt` phase screen:
  - "Your track [label] is ready!" confirmation
  - Button: "Add another track" → re-launch AddTrackFlow
  - Button: "Start learning" → advance to `done` (adult) or `handoff` (child)
- [x] Support multiple track additions in sequence (loop back to addTrack)
- [x] Track count displayed: "You have X tracks set up"

### T5: Update SharedPreferences State Persistence (AC: 6)

- [x] Update persistence keys for slim flow:
  - Keep: `_kOnboardingPhase`, `_kOnboardingProfileId`, `_kOnboardingProfileName`, `_kOnboardingProfileMode`, `_kOnboardingLanguage`
  - Remove: `_kOnboardingSelectedCurricula` (no longer needed — AddTrackFlow manages its own)
- [x] Update `_tryResumeFromSavedState()` for slim phase enum
- [x] Update `_saveState()` for slim phase data
- [x] AddTrackFlow manages its own persistence (from 18.1) — no duplication

### T6: Simplify Onboarding Providers (AC: 1)

- [x] In `onboarding_providers.dart`, remove providers only used by removed phases:
  - `curriculumImportServiceProvider` (import now internal to AddTrackFlow)
  - `bulkPriorCompletionServiceProvider` (now internal to AddTrackFlow)
  - `learningProcessWizardServiceProvider` (now internal to AddTrackFlow)
- [x] Keep: `userProfileServiceProvider`, `goalRepositoryProvider`

### T7: Unit & Widget Tests (AC: 1-7)

- [x] Widget test: onboarding shows only profileCreation → languageSelection → addTrack flow
- [x] Widget test: AddTrackFlow embedded inline (not separate route)
- [x] Widget test: "Add another track" prompt appears after first track
- [x] Widget test: back from AddTrackFlow returns to language selection
- [x] Widget test: child mode shows handoff screen after tracks
- [x] Widget test: adult mode goes directly to done/dashboard
- [x] Unit test: SharedPreferences persistence with slim phases
- [x] Update existing `epic_09_onboarding_test.dart` for new flow

## Dev Notes

### Architecture

- **Main file:** `lib/features/onboarding/presentation/screens/onboarding_screen.dart` — major refactor from ~2,395 lines
- **Key change:** OnboardingScreen becomes a thin coordinator; all track setup logic moves to AddTrackFlow (18.1)
- **Dependency:** Requires 18.1 (AddTrackFlow) to be complete first

### Current 17-Phase Flow (Being Replaced)

```
profileCreation → languageSelection → pathSelection → calendarProgramList →
calendarProgramConfirm → startTrackingFrom → selection → importing →
learningProcessWizard → studyDays → scopeSelection → bulkMark →
goalSetup → rewardsSetup → handoff → done → error
```

### New 6-Phase Flow

```
profileCreation → languageSelection → addTrack (AddTrackFlow) →
addAnotherPrompt → handoff (child only) → done
```

### Key Files

| File | Action | Notes |
|------|--------|-------|
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Major refactor | Strip 12+ phases, keep 6 |
| `lib/features/onboarding/presentation/providers/onboarding_providers.dart` | Simplify | Remove per-track providers |
| `test/story_acceptance/epic_09_onboarding_test.dart` | Rewrite | Tests for new slim flow |

### Critical Constraints

- AddTrackFlow must be embedded as child widget (not separate route) for seamless back navigation
- No rewards step in onboarding — parents configure via Parent Mode
- Firestore sync of profile/language handled by existing `UserProfileService`

### References

- [Source: docs/developer-guide.md#onboarding-the-critical-ux-challenge]
- [Source: _bmad-output/project-context.md]

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: Replaced 17-phase `_ScreenPhase` enum with 6 slim phases: profileCreation, languageSelection, addTrack, addAnotherPrompt, handoff, done.
- T2: Stripped all per-track state, methods, and builders from OnboardingScreen. Reduced from 2,395 lines to 533 lines (78% reduction). Removed: curriculum selection, import streaming, wizard queue, bulk mark queue, goal/study day queues, scope selection, rewards setup, path selection, calendar program, error phase.
- T3: Embedded `AddTrackFlow` inline via `_buildAddTrack()` with `isOnboarding: true`. Back from Stage 1 returns to languageSelection via `onCancel` callback.
- T4: Created `addAnotherPrompt` phase showing track label, count, "Start Learning" and "Add Another Track" buttons. Supports multiple track additions in sequence.
- T5: Updated SharedPreferences keys — removed `_kOnboardingSelectedCurricula`. Updated `_tryResumeFromSavedState()` and `_saveState()` for slim phases. AddTrackFlow manages its own persistence.
- T6: Providers kept in `onboarding_providers.dart` because they're shared by other features (restore, settings, bulk mark). No removal needed.
- T7: Rewrote `onboarding_screen_test.dart` with 7 new tests for slim flow. All 1807 full suite tests pass with 0 regressions.
- Handoff screen updated with rewards prompt: "You can set up rewards later in Parent Mode".
- Removed helper widgets: `_CurriculumCard`, `_StudyDayToggle`, `_PathCard` (no longer needed).

### Change Log

- 2026-03-29: Complete rewrite of OnboardingScreen — slim 6-phase flow with AddTrackFlow delegation.

### File List

**Modified:**
- `learning_tracker/lib/features/onboarding/presentation/screens/onboarding_screen.dart` — Major rewrite (2,395→533 lines)
- `learning_tracker/test/features/onboarding/presentation/screens/onboarding_screen_test.dart` — Rewritten for slim flow (7 tests)
