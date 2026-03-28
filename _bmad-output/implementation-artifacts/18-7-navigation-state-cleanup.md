# Story 18.7: Navigation, State Cleanup & Deprecated Screen Removal

Status: ready-for-dev

## Story

As a developer,
I want the navigation, state management, and deprecated screens cleaned up after the onboarding overhaul,
so that the codebase is maintainable, routes are correct, and dead code is removed.

## Acceptance Criteria

**AC-1: Remove deprecated ModeSelectionScreen**
**Given** mode selection is now embedded in profile creation
**When** inspecting the codebase
**Then** `mode_selection_screen.dart` is deleted
**And** its route (`/mode-selection`) is removed from `app_router.dart`

**AC-2: Clean up SharedPreferences keys**
**Given** the new slim onboarding uses fewer persisted keys
**When** reviewing SharedPreferences usage
**Then** unused keys from the old 17-phase wizard are removed
**And** a migration clears stale keys for existing users

**AC-3: Route guard updates**
**Given** the new track management routes exist
**When** reviewing route guards
**Then** all new routes have appropriate auth guards
**And** the AddTrackFlow route (if standalone) requires authentication

**AC-4: Old TrackManagementScreen removed or redirected**
**Given** the Track Management Hub (18.3) replaces the old per-curriculum track type toggle
**When** old routes are accessed
**Then** they redirect to the new Track Management Hub
**And** the old `track_management_screen.dart` is deleted if fully superseded

**AC-5: Navigation flow is correct end-to-end**
**Given** a fresh install
**When** testing the complete flow
**Then** Welcome → Account → Onboarding (profile + language) → AddTrackFlow → Dashboard works
**And** Settings → Track Management → Add/Edit/Archive works
**And** no dead-end routes or orphaned screens exist

**AC-6: Old onboarding acceptance tests updated**
**Given** the onboarding flow has fundamentally changed
**When** reviewing `epic_09_onboarding_test.dart`
**Then** tests are updated to reflect the new slim onboarding + AddTrackFlow architecture
**And** new tests cover the Track Management Hub flow

**AC-7: Story 15.8 spec marked as superseded**
**Given** Story 15.8 defined the previous onboarding flow
**When** reviewing planning docs
**Then** `_bmad-output/stories/story-15.8-revised-onboarding-flow.md` is marked as superseded by Epic 18

## Tasks / Subtasks

### T1: Remove Deprecated Screens (AC: 1, 4)

- [ ] Delete `lib/features/onboarding/presentation/screens/mode_selection_screen.dart`
- [ ] Delete `lib/features/settings/presentation/screens/track_management_screen.dart` (if not already removed by 18.3)
- [ ] Remove corresponding route entries from `app_router.dart`:
  - `/mode-selection` → `ModeSelectionRoute`
  - Old track management route
- [ ] Remove any imports referencing deleted files

### T2: Clean Up SharedPreferences Keys (AC: 2)

- [ ] Audit all `_kOnboarding*` keys in `onboarding_screen.dart`:
  - `_kOnboardingPhase` — keep (updated for slim phases)
  - `_kOnboardingProfileId` — keep
  - `_kOnboardingProfileName` — keep
  - `_kOnboardingProfileMode` — keep
  - `_kOnboardingSelectedCurricula` — remove (AddTrackFlow manages its own)
  - `_kOnboardingLanguage` — keep
- [ ] Write a one-time migration that clears stale keys on app update
- [ ] Grep codebase for any other SharedPreferences keys related to removed phases

### T3: Route Guard Updates (AC: 3)

- [ ] Verify new routes have appropriate guards:
  - Track Management Hub (`/settings/tracks`) → `AuthGuard`
  - Track Detail (`/settings/tracks/:trackId`) → `AuthGuard`
  - AddTrackFlow (if standalone route) → `AuthGuard`
- [ ] Verify existing guards on onboarding routes still correct
- [ ] Check `ChildModeGuard`, `ParentPinGuard` on parent-specific routes

### T4: Remove Orphaned Providers (AC: 1)

- [ ] Audit `onboarding_providers.dart` for unused providers after 18.2 refactor
- [ ] Remove any providers only referenced by deleted screens
- [ ] Check for unused imports across onboarding feature module

### T5: End-to-End Navigation Verification (AC: 5)

- [ ] Test fresh install flow: Welcome → Account → Onboarding → AddTrackFlow → Dashboard
- [ ] Test settings flow: Settings → Track Management → Add/Edit/Archive
- [ ] Test child mode: onboarding → handoff → dashboard
- [ ] Test profile picker: multiple profiles → correct routing
- [ ] Verify no dead-end routes or orphaned screens

### T6: Update Acceptance Tests (AC: 6)

- [ ] Rewrite `test/story_acceptance/epic_09_onboarding_test.dart` for slim flow
- [ ] Add tests for Track Management Hub navigation
- [ ] Add tests for AddTrackFlow integration
- [ ] Remove tests for deleted phases (17-phase wizard tests)

### T7: Mark Story 15.8 as Superseded (AC: 7)

- [ ] Find `_bmad-output/stories/story-15.8-revised-onboarding-flow.md` (if exists)
- [ ] Add header: "SUPERSEDED by Epic 18 — Onboarding & Track Management Overhaul"
- [ ] Update developer guide onboarding flow diagram (`docs/developer-guide.md` lines 383-400)

### T8: Dead Code Sweep (AC: 1)

- [ ] Run `flutter analyze` to find unused imports
- [ ] Grep for references to deleted class names (`ModeSelectionScreen`, old `TrackManagementScreen`)
- [ ] Remove any dead code paths in `OnboardingScreen` from removed phases
- [ ] Verify no circular dependency issues after cleanup

## Dev Notes

### Architecture

- **Dependencies:** 18.1, 18.2, 18.3 must ALL be complete first
- **This is a cleanup story** — no new features, just removing debt from the overhaul
- **Priority:** Low — intentionally last in the epic

### Files to Delete

- `lib/features/onboarding/presentation/screens/mode_selection_screen.dart`
- `lib/features/settings/presentation/screens/track_management_screen.dart` (if not deleted by 18.3)

### Files to Modify

- `lib/core/navigation/app_router.dart` — remove old routes
- `lib/features/onboarding/presentation/providers/onboarding_providers.dart` — remove unused
- `lib/features/onboarding/presentation/screens/onboarding_screen.dart` — dead code cleanup
- `test/story_acceptance/epic_09_onboarding_test.dart` — rewrite
- `docs/developer-guide.md` — update flow diagram

### SharedPreferences Keys Reference

Current keys in `onboarding_screen.dart`:
```dart
const _kOnboardingPhase = 'onboarding_phase';
const _kOnboardingProfileId = 'onboarding_profile_id';
const _kOnboardingProfileName = 'onboarding_profile_name';
const _kOnboardingProfileMode = 'onboarding_profile_mode';
const _kOnboardingSelectedCurricula = 'onboarding_selected_curricula';
const _kOnboardingLanguage = 'onboarding_language';
```

### References

- [Source: _bmad-output/project-context.md]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
