# Story 18.6: Child Mode Onboarding & Post-Setup Rewards (DNI-171)

Status: review

## Story

As a parent setting up learning for my child,
I want the onboarding handoff screen to work correctly with the new slim flow, and I want to set up rewards from parent mode after onboarding,
so that onboarding stays focused and rewards are a separate, optional activity.

## Acceptance Criteria

**AC-1: No rewards during track setup**
**Given** a child-mode track is being created (onboarding or settings)
**When** the Add Track flow completes
**Then** there is no rewards setup step — the flow ends at bulk mark

**AC-2: Onboarding handoff screen (child mode)**
**Given** a child-mode user completes their first track during onboarding
**When** the AddTrackFlow returns
**Then** the handoff screen shows: "${name}'s learning is all set up"
**And** offers: "Start Learning" (Dashboard), "Add Another Track" (AddTrackFlow again), "Add Another Learner" (profile creation)

**AC-3: Handoff prompts for rewards setup**
**Given** the handoff screen appears
**When** the parent views it
**Then** there is a subtle prompt: "You can set up rewards later in Parent Mode"
**And** this is informational, not a blocking step

**AC-4: Handoff screen not shown in settings flow**
**Given** a parent adds a track from Settings (not onboarding)
**When** the AddTrackFlow completes
**Then** they return to the Track Management Hub — no handoff screen

**AC-5: Add another learner loop**
**Given** the parent taps "Add Another Learner" on the handoff screen
**When** the flow loops
**Then** it goes back to profile creation (not AddTrackFlow)

**AC-6: Points initialization per track**
**Given** a new child-mode track is created
**When** the track setup completes
**Then** point configuration is initialized with defaults for the new track

**AC-7: Rewards accessible from parent mode**
**Given** a parent wants to set up rewards
**When** they navigate to Parent Mode
**Then** the existing reward catalog management is available independently of track setup

## Tasks / Subtasks

### T1: Add "Add Another Track" Button to Handoff (AC: 2)

- [x] Add "Add Another Track" button to `_buildHandoff()` in `onboarding_screen.dart`
- [x] Button calls `_onAddAnotherTrack()` which resets to `_ScreenPhase.addTrack` without clearing profile context
- [x] Now 3 buttons on handoff: "Start Learning", "Add Another Track", "Add Another Learner"

### T2: Fix isChildMode in TrackManagementHub (AC: 4)

- [x] Replace hardcoded `isChildMode: false` in `TrackManagementHubScreen` with active profile mode check
- [x] Read from active profile provider instead of hardcoding

### T3: Verify No Rewards in AddTrackFlow (AC: 1)

- [x] Confirmed: `AddTrackStep` enum has no rewards-related value
- [x] No `RewardsSetupScreen` rendered in any AddTrackFlow step
- [x] Verified for both `isChildMode: true` and `isChildMode: false`

### T4: Handoff Rewards Prompt (AC: 3)

- [x] Handoff screen already shows "You can set up rewards later in Parent Mode" (italic text)
- [x] Verified prompt is informational only — no blocking action

### T5: Add Another Learner Loop (AC: 5)

- [x] `_addAnotherLearner()` clears profile context (`_nameController.clear()`, `_createdProfileId = null`, `_profileMode = 'adult'`)
- [x] Resets to `_ScreenPhase.profileCreation`
- [x] New learner gets independent profile and track setup

### T6: Points Initialization (AC: 6)

- [x] Verified `PointConfigDao.seedDefaults(curriculumId)` creates default point configs
- [x] Fallback defaults: `[10, 5, 3]` (Learn, Chazara 1, Chazara 2)
- [x] Points seeded during track creation for child-mode profiles

### T7: Verify Rewards in Parent Mode (AC: 7)

- [x] `RewardCatalogScreen` accessible at `/parent-mode/rewards` with proper guards
- [x] Works independently of onboarding state

## Dev Notes

### Architecture

- **Separation of concerns:** Rewards are NEVER part of track setup — only accessible from Parent Mode
- **"Add Another Learner" creates a NEW profile**, not just a new track
- **Points initialization** happens atomically with track creation for child-mode profiles
- **Handoff screen** is child-mode only — adults go directly to dashboard

### Key Files

| File | Path | Role |
|------|------|------|
| OnboardingScreen | `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Handoff screen at `_buildHandoff()` |
| TrackManagementHubScreen | `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart` | Fixed `isChildMode` hardcode |
| AddTrackFlow | `lib/features/track_setup/presentation/screens/add_track_flow.dart` | Verified no rewards step |
| PointConfigDao | `lib/core/database/daos/point_config_dao.dart` | `seedDefaults()` method |
| RewardCatalogScreen | `lib/features/parent_mode/presentation/screens/reward_catalog_screen.dart` | Independent rewards management |

### Key Integration Points

- `_buildHandoff()` (L464-516 of onboarding_screen.dart) renders 3 buttons + rewards prompt
- `isChildMode` in `TrackManagementHubScreen` now reads from active profile, not hardcoded
- `PointConfigDao.seedDefaults()` uses `stageDao.getStageDefinitionsByCurriculum()` for stage count
- Parent mode routes guarded by `authGuard + childModeGuard + parentPinGuard`

### Critical Constraints

- Rewards NEVER part of track setup
- "Add Another Learner" creates a NEW profile (not just track)
- Points initialization must happen for child-mode tracks regardless of entry point
- `_kOnboardingSelectedCurricula` key already removed in 18.2

### Testing Standards

- Widget tests for handoff screen content and navigation
- Verify no rewards UI in AddTrackFlow for child mode
- Unit tests for points initialization

### References

- [Source: docs/developer-guide.md#User Modes: Adult vs Child] — Child mode, points, rewards
- [Source: docs/_archive/tooling-notes/project-context.md#Critical Don't-Miss Rules] — Immutability, transactions

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: Added "Add Another Track" button to handoff screen. Three buttons now: Start Learning, Add Another Track, Add Another Learner.
- T2: Fixed `isChildMode` hardcode in `TrackManagementHubScreen` — now reads from active profile provider.
- T3: Verified AddTrackFlow has no rewards step for either mode.
- T4: Handoff rewards prompt already present and informational.
- T5: `_addAnotherLearner()` correctly clears context and resets to profileCreation.
- T6: Points initialization verified via `PointConfigDao.seedDefaults()`.
- T7: Parent mode rewards accessible independently at `/parent-mode/rewards`.

### Change Log

- 2026-03-29: Initial implementation — handoff button added, isChildMode fix. Commit `6052c72`.

### File List

**Modified:**
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` — added "Add Another Track" button to handoff
- `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart` — fixed isChildMode hardcode
