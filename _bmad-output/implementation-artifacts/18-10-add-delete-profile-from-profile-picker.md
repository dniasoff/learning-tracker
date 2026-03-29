# Story 18.10: Add & Delete Profile from Profile Picker (DNI-175)

Status: review

## Story

As a user,
I want to add and delete profiles directly from the profile picker screen,
so that I can manage learners without going through onboarding or settings.

## Acceptance Criteria

**AC-1: Add profile from picker**
**Given** the user is on the profile picker screen
**When** they tap a "+" button (shown after existing profile cards)
**Then** a dialog appears to enter name, select mode, and choose avatar
**And** tapping "Create" adds the profile to the grid immediately

**AC-2: Long-press to show management options**
**Given** the user is on the profile picker screen
**When** they long-press a profile card
**Then** a context menu or bottom sheet appears with "Rename" and "Delete" options

**AC-3: Rename profile**
**Given** the user selects "Rename" from the long-press menu
**When** they enter a new name and confirm
**Then** the profile name is updated with duplicate validation (per DNI-174)

**AC-4: Delete profile with confirmation**
**Given** the user selects "Delete"
**When** they confirm the deletion
**Then** the profile and ALL associated data are permanently deleted

**AC-5: Cascade delete — all associated data removed**
**Given** a profile has data across 16 tables with profileId
**When** the profile is deleted
**Then** ALL 16 tables are cleaned up in a single transaction

**AC-6: Cannot delete last profile**
**Given** only one profile exists
**When** the user attempts to delete it
**Then** deletion is prevented with message: "You must have at least one profile"

**AC-7: Max profiles enforced**
**Given** 10 profiles exist (max)
**When** the user taps "+"
**Then** the add action is disabled or shows a max-reached message

**AC-8: Profile picker updates reactively**
**Given** a profile is added or deleted
**When** the operation completes
**Then** the grid updates without navigation or manual refresh via `profileListStreamProvider`

## Tasks / Subtasks

### T1: Fix Cascade Delete — Add 6 Missing Tables (AC: 5)

- [x] Add cascade deletes to `ProfileRepositoryImpl.deleteProfile()` for:
  - `curriculumScopes`
  - `learningLedger`
  - `studyDayConfigs`
  - `profilePrograms`
  - `rewardPools`
  - `testScores`
- [x] Now covers all 16 tables with `profileId` in a single transaction

### T2: Add LastProfileException Guard (AC: 6)

- [x] Add `LastProfileException` class to `profile_repository.dart`
- [x] In `deleteProfile()`, check `countProfilesForAccount()` before deleting
- [x] Throw `LastProfileException` if count == 1

### T3: Add _AddProfileCard to Picker Grid (AC: 1, 7, 8)

- [x] Add `_AddProfileCard` as last item in `GridView.builder` (`itemCount: profiles.length + 1`)
- [x] "+" icon card with "Add Profile" label
- [x] Tapping opens add profile dialog
- [x] Disabled or shows error at max 10 profiles

### T4: Add Profile Dialog (AC: 1)

- [x] Dialog/bottom sheet with name TextField, mode SegmentedButton, avatar selection
- [x] "Create" calls `profileRepository.createProfile()`
- [x] Duplicate name validation (per DNI-174)

### T5: Long-Press Context Menu (AC: 2, 3, 4)

- [x] Add `GestureDetector` with `onLongPress` to `_ProfileCard`
- [x] Show bottom sheet or modal with "Rename" and "Delete" options
- [x] Rename opens dialog with pre-filled name, calls `updateProfile()`
- [x] Delete shows confirmation dialog with data loss warning

### T6: Reactive Grid Updates (AC: 8)

- [x] Switch from `profileListProvider` to `profileListStreamProvider` for reactive updates
- [x] Grid updates automatically on add/delete/rename

### T7: Tests (AC: 1-8)

- [x] Test cascade delete covers all 16 tables
- [x] Test last-profile guard prevents deletion
- [x] Test profile repository with `LastProfileException`
- [x] Update existing profile repository tests for Hebrew display names

## Dev Notes

### Architecture

- **Cascade delete** now covers all 16 tables with `profileId` in a single transaction
- **LastProfileException** prevents orphan accounts (must have at least 1 profile)
- **Reactive UI** via `profileListStreamProvider` (Drift stream query)
- **Grid layout:** `_AddProfileCard` as `itemCount + 1` in `SliverGridDelegateWithFixedCrossAxisCount`

### Key Files

| File | Path | Role |
|------|------|------|
| ProfilePickerScreen | `lib/features/profiles/presentation/screens/profile_picker_screen.dart` | Modified — add card, long-press, dialogs |
| ProfileRepositoryImpl | `lib/features/profiles/data/repositories/profile_repository_impl.dart` | Fixed cascade + last-profile guard |
| ProfileRepository | `lib/features/profiles/domain/repositories/profile_repository.dart` | Added `LastProfileException` |
| ProfileRepositoryTest | `test/features/profiles/data/repositories/profile_repository_impl_test.dart` | Extended tests |
| Multi-Profile Test | `test/story_acceptance/epic_15_multi_profile_test.dart` | Updated for new exceptions |

### All 16 Tables with profileId (Cascade Delete)

| Table | Previously Covered | Added in This Story |
|-------|-------------------|-------------------|
| completions | Yes | - |
| bookmarks | Yes | - |
| goals | Yes | - |
| rewards | Yes | - |
| stageDefinitions | Yes | - |
| streaks | Yes | - |
| learningOrder | Yes | - |
| pointConfigs | Yes | - |
| activeCurricula | Yes | - |
| curriculumTracks | Yes | - |
| curriculumScopes | **No** | **Added** |
| learningLedger | **No** | **Added** |
| studyDayConfigs | **No** | **Added** |
| profilePrograms | **No** | **Added** |
| rewardPools | **No** | **Added** |
| testScores | **No** | **Added** |

### Critical Constraints

- Cascade delete must be in a single DB transaction
- `LastProfileException` prevents deleting the only profile
- `MaxProfilesExceededException` prevents exceeding 10 profiles
- Deleting selected profile must clear `selectedProfileIdProvider`
- Duplicate name validation applies to both add and rename (per DNI-174)

### Testing Standards

- Repository tests for all cascade delete tables
- Guard tests for last-profile and max-profiles
- Widget tests for add/rename/delete flows

### References

- [Source: _bmad-output/project-context.md#drift Database Patterns] — Transactions, cascade
- [Source: docs/developer-guide.md#User Modes: Adult vs Child] — Profile management

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: Added 6 missing cascade deletes to `ProfileRepositoryImpl.deleteProfile()` — now covers all 16 tables with `profileId`. Single transaction.
- T2: Added `LastProfileException` class and guard in `deleteProfile()` — throws if count == 1.
- T3: Added `_AddProfileCard` as last grid item in `ProfilePickerScreen`. Disabled at max 10.
- T4: Add profile dialog with name, mode, avatar selection. Creates via repository with duplicate validation.
- T5: Long-press context menu on `_ProfileCard` — "Rename" and "Delete" options with dialogs.
- T6: Switched to `profileListStreamProvider` for reactive grid updates.
- T7: Tests for cascade delete, last-profile guard, Hebrew display names.

### Change Log

- 2026-03-29: Test fixes for LastProfileException + Hebrew display names. Commits `b99ef79`, `7fc3c88`.
- 2026-03-29: Add/rename/delete profiles from picker. Commit `e33df32`.
- 2026-03-29: Cascade delete fix + last-profile guard. Commit `224561b`.

### File List

**Modified:**
- `lib/features/profiles/presentation/screens/profile_picker_screen.dart` — add card, long-press, dialogs, reactive stream
- `lib/features/profiles/data/repositories/profile_repository_impl.dart` — 6 missing cascade deletes + last-profile guard
- `lib/features/profiles/domain/repositories/profile_repository.dart` — added `LastProfileException`
- `test/features/profiles/data/repositories/profile_repository_impl_test.dart` — extended tests
- `test/story_acceptance/epic_15_multi_profile_test.dart` — updated for new exceptions
- `test/features/track_setup/presentation/widgets/curriculum_picker_step_test.dart` — updated for Hebrew names
