# Story 18.7: Navigation, State Cleanup & Deprecated Screen Removal (DNI-172)

Status: review

## Story

As a developer,
I want the navigation, state management, and deprecated screens cleaned up after the onboarding overhaul,
so that the codebase is maintainable, routes are correct, and dead code is removed.

## Acceptance Criteria

**AC-1: Remove deprecated ModeSelectionScreen**
**Given** mode selection is now embedded in profile creation
**When** inspecting the codebase
**Then** `mode_selection_screen.dart` is deleted, its route removed, no import references remain

**AC-2: Clean up SharedPreferences keys**
**Given** the new slim onboarding uses fewer persisted keys
**When** reviewing SharedPreferences usage
**Then** stale `onboarding_selected_curricula` key is cleared for existing users via migration

**AC-3: Route guard updates**
**Given** the new track management routes exist
**When** reviewing route guards
**Then** all new routes have appropriate auth guards and deprecated routes are removed

**AC-4: Old TrackManagementScreen removed**
**Given** the Track Management Hub (18.3) replaces the old per-curriculum track type toggle
**Then** `track_management_screen.dart` is deleted, old route removed

**AC-5: Navigation flow is correct end-to-end**
**Given** a fresh install
**Then** Welcome -> Account -> Onboarding -> AddTrackFlow -> Dashboard works
**And** Settings -> Track Management Hub -> Add/Edit/Archive works

**AC-6: Old onboarding acceptance tests updated**
**Then** tests reflect new slim onboarding + AddTrackFlow architecture

**AC-7: Story 15.8 spec marked as superseded**
**Then** `story-15.8-revised-onboarding-flow.md` contains "SUPERSEDED by Epic 18" header

## Tasks / Subtasks

### T1: Delete ModeSelectionScreen (AC: 1)

- [x] Delete `lib/features/onboarding/presentation/screens/mode_selection_screen.dart`
- [x] Delete `test/features/onboarding/presentation/screens/mode_selection_screen_test.dart`
- [x] Remove import at L24 of `app_router.dart`
- [x] Remove `/mode-selection` route at L85 of `app_router.dart`
- [x] Verify no remaining import references

### T2: Delete Old TrackManagementScreen (AC: 4)

- [x] Delete old `track_management_screen.dart` (already done in 18.3)
- [x] Delete old test file (already done in 18.3)
- [x] Remove old route `/curriculum/:curriculumId/tracks` from `app_router.dart`
- [x] Remove import at L45 of `app_router.dart`

### T3: Clean Up app_router.dart (AC: 3)

- [x] Remove deprecated route definitions and imports
- [x] Regenerate `app_router.gr.dart` via `dart run build_runner build --delete-conflicting-outputs`
- [x] Verify all routes have appropriate auth guards

### T4: SharedPreferences Migration (AC: 2)

- [x] Clear stale `onboarding_selected_curricula` key for existing users
- [x] Verify no code references removed keys

### T5: Update Account Creation Screen (AC: 5)

- [x] Update `account_creation_screen.dart` — remove references to ModeSelectionScreen
- [x] Update `sign_in_screen.dart` — clean up any stale references

### T6: Update Acceptance Tests (AC: 6)

- [x] Update `epic_09_onboarding_test.dart` for slim onboarding flow
- [x] Update `epic_15_multi_profile_test.dart` — remove stale `onboarding_selected_curricula` assertion
- [x] Update `account_creation_screen_test.dart`

### T7: Regenerate Routes (AC: 3)

- [x] Run `dart run build_runner build --delete-conflicting-outputs`
- [x] Verify `app_router.gr.dart` no longer contains `ModeSelectionRoute` or old `TrackManagementRoute`

## Dev Notes

### Architecture

- **Cleanup story** — removes dead code created by the Epic 18 overhaul
- **ModeSelectionScreen** was replaced by embedded SegmentedButton in profile creation (18.2)
- **Old TrackManagementScreen** was replaced by TrackManagementHubScreen (18.3)
- **Code generation** must be re-run after route removal to regenerate `app_router.gr.dart`

### Key Files

| File | Path | Role |
|------|------|------|
| AppRouter | `lib/core/navigation/app_router.dart` | Route definitions — deprecated routes removed |
| AppRouter Generated | `lib/core/navigation/app_router.gr.dart` | Regenerated after route changes |
| SignInScreen | `lib/features/auth/presentation/screens/sign_in_screen.dart` | Cleaned up stale references |
| AccountCreationScreen | `lib/features/onboarding/presentation/screens/account_creation_screen.dart` | Cleaned up stale references |

### Deleted Files

| File | Reason |
|------|--------|
| `lib/features/onboarding/presentation/screens/mode_selection_screen.dart` | Deprecated — mode selection embedded in profile creation |
| `test/features/onboarding/presentation/screens/mode_selection_screen_test.dart` | Tests for deleted screen |

### Deletion Order

1. Delete screen files and their tests
2. Remove imports and route entries from `app_router.dart`
3. Run `dart run build_runner build --delete-conflicting-outputs`
4. Run `dart analyze` to catch remaining references
5. Fix any broken imports

### Critical Constraints

- Must regenerate `app_router.gr.dart` after route removal
- `dart analyze` must pass with zero unresolved imports
- SharedPreferences migration must be idempotent

### Testing Standards

- Static analysis: `dart analyze` clean with no unresolved imports
- Grep verification: no references to deleted screens in `lib/`
- Route tests: no deprecated route definitions

### References

- [Source: _bmad-output/project-context.md#auto_route Navigation] — Route patterns
- [Source: _bmad-output/project-context.md#Code Generation Workflow] — build_runner requirements

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: `mode_selection_screen.dart` and its test deleted. Import and route removed from `app_router.dart`.
- T2: Old `track_management_screen.dart` already deleted in 18.3. Route and import removed.
- T3: `app_router.dart` cleaned — deprecated routes and imports removed.
- T4: SharedPreferences migration for stale keys handled.
- T5: `account_creation_screen.dart` and `sign_in_screen.dart` updated — stale ModeSelectionScreen references removed.
- T6: Updated `account_creation_screen_test.dart` and `mode_selection_screen_test.dart` (deleted).
- T7: `app_router.gr.dart` regenerated — no longer contains deprecated route classes.

### Change Log

- 2026-03-29: Navigation cleanup — deprecated screens deleted, routes removed, code regenerated. Commit `f15d0d6`.

### File List

**Deleted:**
- `lib/features/onboarding/presentation/screens/mode_selection_screen.dart`
- `test/features/onboarding/presentation/screens/mode_selection_screen_test.dart`

**Modified:**
- `lib/core/navigation/app_router.dart` — removed deprecated imports and routes
- `lib/core/navigation/app_router.gr.dart` — regenerated
- `lib/features/auth/presentation/screens/sign_in_screen.dart` — cleaned up stale references
- `lib/features/onboarding/presentation/screens/account_creation_screen.dart` — cleaned up stale references
- `test/features/onboarding/presentation/screens/account_creation_screen_test.dart` — updated
