# Story 18.3: Track Management Hub (ניהול מסלולים)

Status: ready-for-dev

## Story

As a learner,
I want a central place in Settings to view, add, edit, and archive my learning tracks,
so that I can manage my learning configuration at any time — not just during initial onboarding.

## Acceptance Criteria

**AC-1: Track list displays all active tracks**
**Given** the user navigates to Track Management in Settings
**When** the screen loads
**Then** all active personal tracks are listed, grouped by curriculum
**And** each track shows: label, curriculum name (Hebrew), program (if any), scope summary, streak

**AC-2: Add new track button**
**Given** the user is on the Track Management screen
**When** they tap "Add Track"
**Then** the AddTrackFlow (from 18.1) launches with `isOnboarding: false`
**And** on completion, the new track appears in the list

**AC-3: Archive/deactivate a track**
**Given** the user long-presses or swipes a track
**When** they select "Archive"
**Then** a confirmation dialog appears explaining data is preserved
**And** on confirm, the track is hidden from dashboard and scheduler
**And** the track can be reactivated later

**AC-4: Reactivate an archived track**
**Given** the user has archived tracks
**When** they toggle "Show archived"
**Then** archived tracks appear with a visual indicator (greyed out)
**And** tapping one offers "Reactivate" option

**AC-5: Edit track → navigates to track settings**
**Given** the user taps a track in the list
**When** the track detail opens
**Then** they see the track's current configuration
**And** can navigate to edit individual settings (Story 18.5)

**AC-6: Accessible from Settings screen**
**Given** the user is on the main Settings screen
**When** they look for track management
**Then** there is a prominent "Manage Tracks" entry
**And** it replaces the old per-curriculum track type toggles

**AC-7: Empty state for no tracks**
**Given** a user with no tracks (edge case — all archived)
**When** they view the Track Management screen
**Then** a friendly empty state appears with a prominent "Add your first track" CTA

## Tasks / Subtasks

### T1: Database Schema — Add Archive Support (AC: 3, 4)

- [ ] Add `archivedAt` nullable DateTime column to `curriculum_tracks` table
- [ ] Bump schema version and add migration
- [ ] Update `TrackDao` to support archive/unarchive:
  - `archiveTrack(profileId, curriculumId, trackType)` — sets `archivedAt` to now
  - `unarchiveTrack(profileId, curriculumId, trackType)` — sets `archivedAt` to null
  - `watchActiveTracks(profileId)` — where `archivedAt IS NULL AND isActive = true`
  - `watchArchivedTracks(profileId)` — where `archivedAt IS NOT NULL`
- [ ] Run `dart run build_runner build --delete-conflicting-outputs`

### T2: Track Management Hub Screen (AC: 1, 6, 7)

- [ ] Create `TrackManagementHubScreen` at `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart`
- [ ] List all active tracks grouped by curriculum
- [ ] Each track tile shows: label, curriculum name (Hebrew), program name, scope summary, streak count
- [ ] Create `TrackListTile` widget at `lib/features/track_setup/presentation/widgets/track_list_tile.dart`
- [ ] Empty state: friendly illustration + "Add your first track" CTA
- [ ] FAB or header button: "Add Track"

### T3: Add Track Integration (AC: 2)

- [ ] "Add Track" button launches `AddTrackFlow` with `isOnboarding: false`
- [ ] On AddTrackFlow completion, invalidate track list provider to refresh
- [ ] New track appears in list immediately

### T4: Archive & Reactivate (AC: 3, 4)

- [ ] Long-press or swipe on track → show archive option
- [ ] Confirmation dialog: "Archive this track? Your data and progress will be preserved. You can reactivate it later."
- [ ] On confirm: call `TrackDao.archiveTrack()`, invalidate providers
- [ ] Toggle "Show archived" in app bar or filter chip
- [ ] Archived tracks appear greyed out with "Reactivate" action
- [ ] Reactivate: call `TrackDao.unarchiveTrack()`, refresh list

### T5: Navigate to Track Detail (AC: 5)

- [ ] Tap on track → navigate to track detail screen (Story 18.5)
- [ ] Pass track ID and curriculum context
- [ ] For now, if 18.5 not yet implemented, show a placeholder or basic info screen

### T6: Settings Screen Integration (AC: 6)

- [ ] Add "Manage Tracks" entry to `SettingsScreen` in Learning section
- [ ] Replace old per-curriculum track type toggle navigation
- [ ] Route: `/settings/tracks` → `TrackManagementHubRoute`
- [ ] Register route in `app_router.dart`

### T7: Remove Old TrackManagementScreen (AC: 6)

- [ ] Delete `lib/features/settings/presentation/screens/track_management_screen.dart`
- [ ] Remove its route from `app_router.dart`
- [ ] Remove any references to School/Tutor track type toggles (V2 concern)

### T8: Providers (AC: 1, 3, 4)

- [ ] Create `activeTracksProvider` — watches all active (non-archived) tracks for current profile
- [ ] Create `archivedTracksProvider` — watches archived tracks
- [ ] Create `trackWithDetailsProvider.family(trackKey)` — enriched track info (streak, scope summary)
- [ ] Place in `lib/features/track_setup/presentation/providers/track_management_providers.dart`

### T9: Unit & Widget Tests (AC: 1-7)

- [ ] Unit tests for archive/unarchive DAO operations
- [ ] Unit tests for track list providers
- [ ] Widget test: track list displays grouped by curriculum
- [ ] Widget test: "Add Track" launches AddTrackFlow
- [ ] Widget test: archive confirmation dialog flow
- [ ] Widget test: reactivate from archived list
- [ ] Widget test: empty state renders with CTA
- [ ] Widget test: Settings screen shows "Manage Tracks"

## Dev Notes

### Architecture

- **New screen** in `lib/features/track_setup/` module (created by 18.1)
- **Dependency:** Requires 18.1 (AddTrackFlow) for "Add Track" functionality
- **Replaces:** `lib/features/settings/presentation/screens/track_management_screen.dart`

### Current Implementation Being Replaced

The existing `TrackManagementScreen` is a per-curriculum view that toggles Personal/School/Tutor track types. In V1, only Personal tracks exist, making this screen mostly a single always-on toggle. The new Hub shows ALL tracks across ALL curricula in one list.

### Key Files

| File | Action |
|------|--------|
| `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart` | Create |
| `lib/features/track_setup/presentation/widgets/track_list_tile.dart` | Create |
| `lib/features/track_setup/presentation/providers/track_management_providers.dart` | Create |
| `lib/features/settings/presentation/screens/settings_screen.dart` | Modify — add "Manage Tracks" |
| `lib/features/settings/presentation/screens/track_management_screen.dart` | Delete |
| `lib/core/navigation/app_router.dart` | Modify — add/remove routes |
| `lib/core/database/tables/curriculum_tracks.dart` | Modify — add archivedAt |
| `lib/core/database/app_database.dart` | Modify — schema migration |

### Critical Constraints

- Archive preserves all data (completions, goals, streaks) — just hides from dashboard/scheduler
- Must have at least 1 active track (prevent archiving the last one)
- Track list must refresh reactively via Riverpod stream providers

### References

- [Source: docs/developer-guide.md#core-domain-model-the-track]
- [Source: _bmad-output/project-context.md]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
