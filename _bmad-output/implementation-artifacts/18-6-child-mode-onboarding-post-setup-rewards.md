# Story 18.6: Child Mode Onboarding & Post-Setup Rewards

Status: ready-for-dev

## Story

As a parent setting up learning for my child,
I want the onboarding handoff screen to work correctly with the new slim flow,
and I want to set up rewards from parent mode after onboarding — not during track setup,
so that onboarding stays focused and rewards are a separate, optional activity.

## Acceptance Criteria

**AC-1: No rewards during track setup**
**Given** a child-mode track is being created (onboarding or settings)
**When** the Add Track flow completes
**Then** there is no rewards setup step — the flow ends at bulk mark

**AC-2: Onboarding handoff screen (child mode)**
**Given** a child-mode user completes their first track during onboarding
**When** the AddTrackFlow returns
**Then** the handoff screen shows: "[Name]'s learning is all set up!"
**And** offers: "Start Learning" → Dashboard, "Add Another Track" → AddTrackFlow again, "Add Another Learner" → back to profile creation

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
**Then** it goes back to profile creation in onboarding (not AddTrackFlow)
**And** the new learner gets their own profile and track setup

**AC-6: Points initialization per track**
**Given** a new child-mode track is created
**When** the track setup completes
**Then** point configuration is initialized with defaults for the new track
**And** the gamification system recognizes the new track

**AC-7: Rewards accessible from parent mode**
**Given** a parent wants to set up rewards
**When** they navigate to Parent Mode
**Then** the existing reward catalog management is available
**And** works independently of track setup / onboarding

## Tasks / Subtasks

### T1: Verify No Rewards in AddTrackFlow (AC: 1)

- [ ] Confirm AddTrackFlow (18.1) has no rewards setup step
- [ ] Verify for both adult and child mode — no rewards step in either
- [ ] If any rewards logic exists in AddTrackFlow, remove it

### T2: Update Handoff Screen for Slim Onboarding (AC: 2, 3)

- [ ] Update handoff screen in `onboarding_screen.dart` for new slim flow:
  - Display: "[Name]'s learning is all set up!"
  - Button: "Start Learning" → Dashboard
  - Button: "Add Another Track" → re-launch AddTrackFlow
  - Button: "Add Another Learner" → back to profileCreation phase
- [ ] Add subtle rewards prompt: "You can set up rewards later in Parent Mode"
- [ ] Handoff only shown during onboarding (`isOnboarding: true`), not settings flow

### T3: Handoff Screen Not in Settings (AC: 4)

- [ ] Ensure AddTrackFlow with `isOnboarding: false` returns directly to caller
- [ ] No handoff screen when adding tracks from Track Management Hub
- [ ] Verify navigation: Settings → Track Hub → Add Track → (complete) → Track Hub

### T4: Add Another Learner Loop (AC: 5)

- [ ] "Add Another Learner" resets to `profileCreation` phase in onboarding
- [ ] Clear current profile context (new profile will be created)
- [ ] Previous learner's tracks/data remain intact
- [ ] New profile creation flow starts fresh

### T5: Points Initialization for Child Tracks (AC: 6)

- [ ] When a child-mode track is created, initialize `point_configs` table with defaults
- [ ] Default point values per stage (e.g., לימוד = 10, חזרה א׳ = 5, חזרה ב׳ = 3)
- [ ] Use `SuggestedThresholdsService` for initial reward thresholds if needed
- [ ] Ensure gamification providers recognize new track immediately

### T6: Verify Rewards in Parent Mode (AC: 7)

- [ ] Confirm existing reward management screens in parent mode still function:
  - `RewardsSetupScreen` at `lib/features/onboarding/presentation/screens/rewards_setup_screen.dart`
  - Parent dashboard reward management
- [ ] Rewards work independently of track setup
- [ ] No regression in existing reward CRUD

### T7: Tests (AC: 1-7)

- [ ] Widget test: AddTrackFlow has no rewards step (child mode)
- [ ] Widget test: handoff screen shows correct buttons and rewards prompt
- [ ] Widget test: "Add Another Learner" returns to profile creation
- [ ] Widget test: handoff NOT shown when adding from settings
- [ ] Unit test: point_configs initialized for new child track
- [ ] Integration test: full child-mode onboarding flow end-to-end

## Dev Notes

### Architecture

- **Dependencies:** 18.1 (AddTrackFlow) and 18.2 (Slim Onboarding)
- **Handoff logic stays in OnboardingScreen** — it's a global onboarding concern, not a track concern
- **Rewards screens already exist** in parent mode — no new screens needed

### Key Files

| File | Action |
|------|--------|
| `lib/features/onboarding/presentation/screens/onboarding_screen.dart` | Modify — update handoff phase |
| `lib/features/onboarding/presentation/screens/rewards_setup_screen.dart` | Verify — still works |
| Point config initialization logic | Modify — hook into track creation |

### Points System

- `point_configs` table: per-curriculum, per-stage point values
- `SuggestedThresholdsService`: calculates reward thresholds based on curriculum size
- Points accumulate per track in `completions` table (points column)

### Critical Constraints

- Rewards are NEVER part of track setup — only in Parent Mode
- "Add Another Learner" creates a NEW profile, not just a new track
- Points initialization must happen atomically with track creation

### References

- [Source: docs/developer-guide.md#user-modes-adult-vs-child]
- [Source: _bmad-output/project-context.md]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
