# Story 18.3: Wire Add Track Flow into All Entry Points (DNI-181)

Status: review

## Story

As a learner,
I want every "add track" entry point in the app to launch the same AddTrackFlow widget,
so that I get a consistent experience whether adding tracks during onboarding, from settings, or from empty states.

## Acceptance Criteria

**AC-1:** Learn screen empty state says "Add Track" not "Browse Curricula" and launches AddTrackFlow
**AC-2:** Dashboard empty state has "Add Track" CTA launching AddTrackFlow
**AC-3:** Settings has "Manage Tracks" entry replacing old "Curricula" entry
**AC-4:** Track Management Hub lists all active tracks with add/archive/reactivate
**AC-5:** Archive preserves data, hides from dashboard + scheduler
**AC-6:** Reactivate restores archived track
**AC-7:** After AddTrackFlow completes from any entry point, user returns to originating screen with new track visible
**AC-8:** Old "Browse Curricula" text removed from codebase entirely
**AC-9:** Old School/Tutor track type toggle UI removed

## Tasks / Subtasks

### T1: Create Track Management Hub Screen (AC: 4, 5, 6)

- [x] Create `TrackManagementHubScreen` at `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart`
- [x] List active tracks grouped by curriculum using `activeTracksProvider`
- [x] Each track shows: label, curriculum (Hebrew), program, scope summary via `TrackListTile`
- [x] FAB "Add Track" button sets `_addingTrack = true`, embeds `AddTrackFlow` inline
- [x] Long-press track shows confirmation dialog for archive
- [x] "Show Archived" FilterChip toggle in AppBar reveals archived tracks
- [x] Tap archived track shows "Reactivate" confirmation dialog
- [x] Cannot archive last active track (shows snackbar)
- [x] Empty state: "No tracks yet" + "Add Your First Track" CTA

### T2: Create TrackListTile Widget (AC: 4)

- [x] Create `TrackListTile` at `lib/features/track_setup/presentation/widgets/track_list_tile.dart`
- [x] Display track label, Hebrew curriculum name, program info, scope summary
- [x] Chevron arrow for navigation affordance

### T3: Create Track Management Providers (AC: 4)

- [x] Create `activeTracksProvider` and `archivedTracksProvider` as StreamProviders
- [x] Both watch `activeProfileIdProvider` and use `trackDao` stream queries
- [x] File: `lib/features/track_setup/presentation/providers/track_management_providers.dart`

### T4: Add archived_at Column to Tracks Table (AC: 5)

- [x] Add `archivedAt` nullable DateTime column to `curriculum_tracks` table
- [x] Add `archiveTrack()` and `unarchiveTrack()` methods to `TrackDao`
- [x] Add schema migration in `app_database.dart`

### T5: Wire Learn Screen Empty State (AC: 1, 8)

- [x] Change message from "No active curricula" to "No active tracks"
- [x] Change subtitle from "Add a curriculum..." to "Add a track to start learning."
- [x] Change button label from "Browse Curricula" to "Add Track"
- [x] Change navigation to `TrackManagementHubRoute` instead of `CurriculumListRoute`
- [x] Remove "Browse curricula" AppBar search tooltip

### T6: Wire Dashboard Empty State (AC: 2)

- [x] Change `_EmptyDashboard` CTA from "Set Up Your Learning" to "Add Track"
- [x] Change navigation from `OnboardingRoute` to `TrackManagementHubRoute`
- [x] Update subtitle text

### T7: Wire Settings Screen (AC: 3)

- [x] Remove old "Curricula" ListTile entry
- [x] Keep "Manage Tracks" entry routing to `TrackManagementHubRoute`

### T8: Register Routes (AC: 4)

- [x] Register `TrackManagementHubRoute` at `/settings/tracks` in `app_router.dart`
- [x] Add `authGuard` to the route
- [x] Regenerate `app_router.gr.dart` via build_runner

### T9: Delete Old Track Management Screen (AC: 9)

- [x] Delete `lib/features/settings/presentation/screens/track_management_screen.dart`
- [x] Delete `test/features/settings/presentation/screens/track_management_screen_test.dart`
- [x] Remove old route and import from `app_router.dart`

### T10: Update Tests (AC: 1-9)

- [x] Update `learning_screen_test.dart` for new empty state text
- [x] Update `settings_screen_test.dart` for "Manage Tracks" entry
- [x] Add tests for `TrackManagementHubScreen` in epic_18 test file
- [x] Update `epic_04_multi_track_test.dart` for new screen references

## Dev Notes

### Architecture

- **Track Management Hub** replaces per-curriculum toggle with a unified track list
- **AddTrackFlow** is embedded inline in the hub (not navigated to), same as in onboarding
- **Archive** uses nullable `archivedAt` timestamp column — archived tracks hidden from scheduler/dashboard
- **Reactive UI** via StreamProviders watching Drift stream queries

### Key Files

| File | Path | Role |
|------|------|------|
| TrackManagementHubScreen | `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart` | Hub with add/archive/reactivate (298 lines) |
| TrackListTile | `lib/features/track_setup/presentation/widgets/track_list_tile.dart` | Track summary display (98 lines) |
| TrackManagementProviders | `lib/features/track_setup/presentation/providers/track_management_providers.dart` | Stream providers for active/archived tracks |
| LearningScreen | `lib/features/learning/presentation/screens/learning_screen.dart` | Empty state CTA updated |
| DashboardScreen | `lib/features/dashboard/presentation/screens/dashboard_screen.dart` | Empty state CTA updated |
| SettingsScreen | `lib/features/settings/presentation/screens/settings_screen.dart` | "Curricula" entry removed, "Manage Tracks" kept |
| AppRouter | `lib/core/navigation/app_router.dart` | TrackManagementHubRoute registered |
| TrackDao | `lib/core/database/daos/track_dao.dart` | archiveTrack/unarchiveTrack methods |
| CurriculumTracks table | `lib/core/database/tables/curriculum_tracks.dart` | archivedAt column added |

### Database Changes

- `curriculum_tracks` table: added `archived_at INTEGER NULL` column via schema migration
- `TrackDao.archiveTrack()` sets `archivedAt` to current UTC timestamp
- `TrackDao.unarchiveTrack()` sets `archivedAt` to null

### Critical Constraints

- `CurriculumListRoute` NOT deleted — still used for browsing content, only removed as primary CTA
- Archive preserves all track data (completions, stages, goals) — just hides from scheduler
- Cannot archive the last active track (guard in hub screen)

### Testing Standards

- Widget tests for hub screen (empty state, active tracks, archive/reactivate)
- Verify "Browse Curricula" string removed from entire codebase
- Integration tests for end-to-end add track from each entry point

### References

- [Source: docs/developer-guide.md#Core Domain Model: The Track] — Track management concepts
- [Source: _bmad-output/project-context.md#drift Database Patterns] — Table schema, transactions

## Dev Agent Record

### Agent Model Used

Claude Opus 4.6 (1M context)

### Debug Log References

_None — clean implementation_

### Completion Notes List

- T1: `TrackManagementHubScreen` complete — 298 lines. Active/archived track lists, FAB add, long-press archive, FilterChip toggle, empty state CTA. Last-track protection via snackbar.
- T2: `TrackListTile` — 98 lines. Hebrew curriculum name primary, English secondary. Chevron navigation affordance.
- T3: `activeTracksProvider` + `archivedTracksProvider` as StreamProviders watching Drift queries.
- T4: `archivedAt` column added to `curriculum_tracks` table. Schema migration added. `archiveTrack()`/`unarchiveTrack()` DAO methods.
- T5: Learn screen empty state updated — "No active tracks" + "Add Track" button routing to `TrackManagementHubRoute`.
- T6: Dashboard `_EmptyDashboard` updated — "Add Track" button, routes to hub.
- T7: Settings screen — removed "Curricula" ListTile, kept "Manage Tracks".
- T8: `TrackManagementHubRoute` registered at `/settings/tracks` with `authGuard`.
- T9: Old `track_management_screen.dart` and test deleted. Old route removed.
- T10: Tests updated across learning screen, settings screen, epic_04, epic_18.

### Change Log

- 2026-03-29: Entry point wiring — learn screen, dashboard, settings screen updated. Old files deleted. Commit `07a1019`.
- 2026-03-28: Track Management Hub created with archive/reactivate support. Commit `6825eb4`.

### File List

**Created:**
- `lib/features/track_setup/presentation/screens/track_management_hub_screen.dart`
- `lib/features/track_setup/presentation/widgets/track_list_tile.dart`
- `lib/features/track_setup/presentation/providers/track_management_providers.dart`
- `lib/core/constants/hebrew_terms.dart`
- `test/core/constants/hebrew_terms_test.dart`
- `test/core/database/hebrew_migration_test.dart`

**Modified:**
- `lib/features/learning/presentation/screens/learning_screen.dart` — empty state CTA
- `lib/features/dashboard/presentation/screens/dashboard_screen.dart` — empty state CTA
- `lib/features/settings/presentation/screens/settings_screen.dart` — removed "Curricula" entry
- `lib/core/navigation/app_router.dart` — route registration + old route removal
- `lib/core/navigation/app_router.gr.dart` — regenerated
- `lib/core/database/daos/track_dao.dart` — archive/unarchive methods
- `lib/core/database/tables/curriculum_tracks.dart` — archivedAt column
- `lib/core/database/app_database.dart` — schema migration
- `test/features/learning/presentation/screens/learning_screen_test.dart`
- `test/features/settings/presentation/screens/settings_screen_test.dart`
- `test/story_acceptance/epic_04_multi_track_test.dart`
- `test/story_acceptance/epic_18_track_overhaul_test.dart`

**Deleted:**
- `lib/features/settings/presentation/screens/track_management_screen.dart`
- `test/features/settings/presentation/screens/track_management_screen_test.dart`
