# Story 18.2: User Onboarding — Profile + Language Only (DNI-179)

Status: review

## Story

As a new user,
I want onboarding to collect only my profile name, mode (adult/child), and language preference,
so that I can get to learning quickly without being overwhelmed by track configuration during initial setup.

## Acceptance Criteria

**AC-1:** OnboardingScreen has exactly 2 input screens (profile + language) — nothing else
**AC-2:** After language, launches Add Track Flow (18.1) as a separate embedded widget
**AC-3:** After first track completes, "Add another track?" prompt with two buttons
**AC-4:** "Start Learning" goes to Dashboard (adult) or handoff then Dashboard (child)
**AC-5:** Back from Add Track Flow screen 1 returns to language selection
**AC-6:** Profile + language saved to SharedPreferences for resume on interruption
**AC-7:** The `_ScreenPhase` enum contains ONLY: `profileCreation`, `languageSelection`, `addTrack`, `addAnotherPrompt`, `handoff`, `done`

## Tasks / Subtasks

### T1: Gut OnboardingScreen — Remove All Track Phases (AC: 1, 7)

- [x] Remove all old phases from `_ScreenPhase` enum: `pathSelection`, `calendarProgramList`, `calendarProgramConfirm`, `startTrackingFrom`, `selection`, `importing`, `learningProcessWizard`, `scopeSelection`, `bulkMark`, `goalSetup`, `studyDays`, `rewardsSetup`
- [x] Replace with slim 6-phase enum: `profileCreation`, `languageSelection`, `addTrack`, `addAnotherPrompt`, `handoff`, `done`
- [x] Remove `_kOnboardingSelectedCurricula` SharedPreferences key
- [x] Remove all build methods for deleted phases

### T2: Screen 1 — Profile Creation (AC: 1)

- [x] Keep `_buildProfileCreation()` — name TextField + Adult/Child SegmentedButton
- [x] `childAwareText()` helper for mode-specific prompts
- [x] Continue button disabled until name is non-empty
- [x] On continue, advance to language selection phase

### T3: Screen 2 — Language Selection (AC: 1)

- [x] Keep `_buildLanguageSelection()` — 6 language options (he, he_plain, en, fr, es, it)
- [x] Hebrew with nikud selected by default
- [x] On continue, create profile in DB via `_createProfile()`, advance to addTrack phase

### T4: Embed AddTrackFlow After Language (AC: 2, 5)

- [x] `_buildAddTrack()` renders `AddTrackFlow` widget inline (not navigated to)
- [x] Pass `profileId`, `isOnboarding: true`, `isChildMode` from profile creation
- [x] Hide AppBar during addTrack phase
- [x] `onCancel` callback returns to `languageSelection` phase
- [x] `onComplete` callback receives `AddTrackResult`, increments track count

### T5: Add Another Track Prompt (AC: 3)

- [x] `_buildAddAnotherPrompt()` shows "Your track [label] is ready!" with track count
- [x] "Add Another Track" button resets to `addTrack` phase
- [x] "Start Learning" button calls `_onStartLearning()`

### T6: Handoff & Navigation (AC: 4)

- [x] `_onStartLearning()` routes to handoff phase for child mode, dashboard for adult
- [x] `_buildHandoff()` renders child mode handoff screen
- [x] `_navigateToDashboard()` checks profile count: 2+ profiles goes to ProfilePickerRoute, else AppShellRoute
- [x] Clear all SharedPreferences state on successful navigation

### T7: State Persistence (AC: 6)

- [x] `_saveState()` persists phase, profileId, profileName, profileMode, language
- [x] `_tryResumeFromSavedState()` restores state on widget init
- [x] `_clearSavedState()` removes all keys on flow completion
- [x] 5 SharedPreferences keys: `onboarding_phase`, `onboarding_profile_id`, `onboarding_profile_name`, `onboarding_profile_mode`, `onboarding_language`

### T8: Update Tests (AC: 1-7)

- [x] Update `onboarding_screen_test.dart` for slim 6-phase flow
- [x] Verify no track/curriculum/goal/chazara logic in OnboardingScreen

## Dev Notes

### Architecture

- **Pattern:** Slim orchestrator that delegates track setup to `AddTrackFlow` (18.1)
- **Separation:** User onboarding (who are you?) is fully separate from track setup (what do you want to learn?)
- **State:** SharedPreferences for persistence across interruptions, local state for in-memory flow

### Key Files

| File | Path | Role |
|------|------|------|
| OnboardingScreen | `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Main screen — slim 6-phase flow (534 lines) |
| Onboarding Providers | `lib/features/onboarding/presentation/providers/onboarding_providers.dart` | Service providers |
| AddTrackFlow | `lib/features/track_setup/presentation/screens/add_track_flow.dart` | Embedded track setup widget |
| Onboarding Test | `test/features/onboarding/presentation/screens/onboarding_screen_test.dart` | Widget tests |

### Key Integration Points

- `AddTrackFlow` is embedded as a child widget (not navigated to) via `_buildAddTrack()`
- `onComplete` callback receives `AddTrackResult` and increments track count
- `onCancel` callback returns to language selection phase
- AppBar hidden during `_ScreenPhase.addTrack`
- Navigation after completion depends on profile count: 2+ profiles goes to ProfilePickerRoute, else AppShellRoute

### Critical Constraints

- No track-related SharedPreferences keys in OnboardingScreen — AddTrackFlow manages its own (prefixed `add_track_*`)
- All 5 providers in `onboarding_providers.dart` still actively used
- Profile creation via `ref.read(profileRepositoryProvider).createProfile()`

### Testing Standards

- Widget tests for critical UI flows [Source: docs/_archive/tooling-notes/project-context.md]
- Test loading, error, and success states
- Use ProviderScope for Riverpod access in widget tests

### References

- [Source: docs/developer-guide.md#Onboarding: The Critical UX Challenge] — Onboarding design
- [Source: docs/_archive/tooling-notes/project-context.md#Framework-Specific Rules] — Riverpod patterns

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: Gutted `OnboardingScreen` — removed 12 old phases, replaced with slim 6-phase enum. Removed `_kOnboardingSelectedCurricula` key.
- T2-T3: Profile creation and language selection screens preserved with minor cleanup.
- T4: `_buildAddTrack()` embeds `AddTrackFlow` inline with `isOnboarding: true`. AppBar hidden during addTrack phase.
- T5: "Add another track?" prompt with track count and two action buttons.
- T6: Navigation logic — child mode handoff, profile count check for picker vs shell route.
- T7: SharedPreferences persistence trio implemented: save/resume/clear.
- T8: Tests updated for slim flow.

### Change Log

- 2026-03-28: Initial implementation — slim 6-phase onboarding with AddTrackFlow delegation. Commit `eb6e361`.

### File List

**Modified:**
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` — gutted and rewritten for slim flow
- `test/features/onboarding/presentation/screens/onboarding_screen_test.dart` — updated for new phases
