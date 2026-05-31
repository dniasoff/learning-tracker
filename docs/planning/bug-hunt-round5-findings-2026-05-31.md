# Round-5 bug hunt — 9 confirmed / 11 candidates

> **Status: RESOLVED — all 9 fixed.** Committed green to `dev` (`make ci` +9062, `format-check` clean), via parallel sub-agents on disjoint files:
> - **R5-1** (high) bookmarks: outbox `_key()` now includes `track_type` (matches the Firestore docId `${curriculumId}_${trackType}`) — no more bookmark sync-key collisions.
> - **R5-2** (med) PIN: the Parent-PIN tile (reachable on a child's own Settings) is now gated behind parent-mode authentication.
> - **R5-3** (high) tracks: `purgeHistory` now enqueues a sync tombstone so the wipe replicates (no orphaned history on other devices).
> - **R5-4/5** (med, l10n) day names: locale-aware via `DateFormat` for Sun–Fri; day 6 keeps the app's term **"Shabbos"** (en) / "שבת" (he) via the new `dayNameShabbos` key (NOT regressed to "Saturday").
> - **R5-6** (high) content nav: browse tree no longer returns empty at max-browse-depth (deep-link to the deepest level renders the items instead of "No content").
> - **R5-7/8/9** (med, l10n) settings tutoring section: 'TALMID PROFILES' → `profilePickerTalmidProfiles`, 'Pending — tap to accept' → new `statusPendingTapToAccept` key, 'Accept' → `acceptInviteAccept`.
>
> 2 candidates rejected by adversarial verify (export-data validation + error-message claims — not real defects).
## [high/bookmarks] Bookmark outbox entity key missing track_type component
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/sync/data/outbox_sync_write_facade.dart`
- Symptom: The _key() method in OutboxSyncWriteFacade derives a stable entity key for bookmarks, but it only includes curriculum_id, missing the track_type component. Multiple bookmarks for the same curriculum but different track types will have identical outbox entity keys (e.g., both 'bereshit'), violating the design principle that entityKey should be unique per Firestore document.
- Root cause: The _key() method (lines 287-299) checks for 'track_id' and 'curriculum_id' fields to build the entity key, but bookmarks payload includes 'track_type' (not 'track_id'). The method doesn't check for 'track_type', so it only captures curriculum_id in the key, unlike the Firestore gateway which correctly constructs docId as '${curriculumId}_${trackType}'.
- Reachability: Any user creating or updating bookmarks for multiple track types (personal, teacher, etc.) in the same curriculum will trigger this bug. The production path: setBookmark() calls _syncBookmark() which calls _syncEngine?.pushBookmark(bookmark.toFirestore()), passing a payload with 'track_type' instead of 'track_id'; then OutboxSyncWriteFacade.pushBookmark() calls _key(bookmark) which produces an incorrect key missing track_type.
- Fix: Update the _key() method in OutboxSyncWriteFacade to include track_type in the entity key derivation. Add a check for 'track_type' field after the 'track_id' check at line 292-294: if (payload['track_type'] != null) { parts.add(payload['track_type'].toString()); } This ensures the entity key matches the Firestore document ID '${curriculumId}_${trackType}' and maintains consistency with the design principle stated in the bookmark_merger.dart comment that entityKey should mirror the deterministic Firestore doc-id.

## [medium/pin-security] PIN change dialog accessible without prior parent-mode authentication
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/settings/presentation/screens/settings_screen.dart`
- Symptom: Lines 587-615: The 'Parent PIN' tile in _ParentalControlsSection calls showParentPinChangeDialog() without requiring that the current session is PIN-authenticated. Any user who can access SettingsScreen can reach this dialog.
- Root cause: The PIN change flow only requires knowledge of the current PIN (first step of the change dialog), but does not require prior parent-mode authentication. Unlike PIN-gated parent-mode routes (which use pinGuard), the Settings PIN tile has no gate preventing an unauthorized user (including a child on their own profile) from attempting PIN changes. The dialog itself will reject incorrect PIN entries, but the ability to even attempt the change without being in an authenticated parent session is a weak design.
- Reachability: High - SettingsScreen is accessible to any authenticated user (including children on their own profiles) via the AppShell route with guards [authGuard, restoreGuard, profileGuard]. The PIN tile appears for child profiles (line 536 checks !isChildProfile returns false for parents viewing children, showing the section). Once in Settings, line 594-604 directly calls showParentPinChangeDialog() with no pre-check.
- Fix: Require PIN authentication before allowing access to the PIN change dialog. Either: (1) Gate the PIN tile with a call to showParentPinVerificationDialog() first (verify current PIN in a gate), then open the change dialog, OR (2) Add a custom guard to check that parentPinAuthenticatedProfileId matches the active profile before rendering/enabling the PIN tile, OR (3) Make PIN management (setup/change) require explicit re-verification, not relying on prior session state.

## [high/track-detail-edit] purgeHistory does not sync wipe to Firestore, leaving orphaned data on other devices
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/core/database/daos/track_dao.dart`
- Symptom: When user selects 'Delete and wipe history' on a synced device, the purgeHistory call stamps completion_events with purgedAt but does NOT push an outbox row to Firestore. Other devices see the track still present with completions intact.
- Root cause: purgeHistory (line 391) lacks the sync outbox.insertOutboxRow call that deleteTrackAndData performs (line 234). The method hard-deletes local rows but leaves no distributed tombstone for sync replication.
- Reachability: User selects 'Delete and wipe history' in TrackDetailScreen._showDeleteDialog (track_detail_screen.dart:647) or TrackManagementHubScreen._showDeleteDialog (track_management_hub_screen.dart:255), calling dao.purgeHistory(track.id).
- Fix: Add outbox.insertOutboxRow call in purgeHistory transaction with entityKind=track and payload documenting the wipe (similar to deleteTrackAndData lines 234-248). Include track.profileId and track.id.

## [high/track-detail-edit] Hardcoded English day names in track edit screen cause Hebrew-locale leak
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/tracks/setup/presentation/screens/edit_track_screen.dart`
- Symptom: When Hebrew-locale user edits a track and views the study days section, day names always display in English (Sunday, Monday, etc.) instead of Hebrew or locale-appropriate text.
- Root cause: _dayName method (lines 804-813) uses hardcoded English strings: 'Sunday', 'Monday', 'Tuesday', etc. There are no corresponding localization keys in app_en.arb or app_he.arb. The switch statement ignores locale entirely.
- Reachability: User enters EditTrackScreen, loads _buildStudyDaysSection which calls _dayName(kStepStudyDayNumbers[i]) for each day (line 634). This renders the title via StudyDayCard which displays the hardcoded English name.
- Fix: Add localization keys dayMonday, dayTuesday, etc. to app_en.arb and app_he.arb. Replace the switch statement with ref.watch(AppLocalizations) and use l10n.dayMonday (etc) or use DateFormat('EEEE', localeName).format() for automatic locale handling.

## [high/track-detail-edit] Identical hardcoded English day-name leak in step_study_days.dart
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/tracks/setup/presentation/steps/step_study_days.dart`
- Symptom: During onboarding / Add Track flow, when user configures study days, Hebrew-locale users see hardcoded English day names (Sunday, Monday, etc.) in StudyDaysEditable._dayName.
- Root cause: _dayName method (lines 113-124) is identical to edit_track_screen.dart: hardcoded English strings with no localization, no locale awareness.
- Reachability: User navigates to Add Track, completes the flow and reaches StudyDaysEditable. ListView.builder calls _dayName(kStepStudyDayNumbers[index]) to populate StudyDayCard titles (line 78).
- Fix: Same as above: add localization keys and replace hardcoded switch with l10n method calls. Both files should use identical day-name resolution for consistency.

## [high/content-nav] Browse tree returns empty at max-browse depth, showing 'No content' instead of browseable items
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/content_browsing/presentation/screens/content_hierarchy_screen.dart`
- Symptom: When user drills down to maxBrowseDepth (e.g., Perek level in Mishnayos), the screen shows 'No content available' instead of showing the items at that level that should open the reader on tap
- Root cause: Line 331 in _groupItemsByNextLevel: `if (currentDepth >= maxBrowseDepth) return const [];` returns an empty list before building the synthetic items that represent the browseable rows at the current depth. The check conflates 'stop drilling deeper' (correct) with 'show nothing' (wrong).
- Reachability: High: User navigates to any curriculum with maxBrowseDepth < depth (all except Bavli/Yerushalmi), drills down to the max-browse level, and sees 'No content available' instead of rows that should open the text reader
- Fix: At line 331, instead of returning empty when currentDepth >= maxBrowseDepth, allow the method to continue and return the grouped items. The _handleItemTap logic at line 390 already correctly routes chapter-level items (via _isChapterLevelRef) to the reader. The guard should only prevent **drilling further**, not prevent **displaying items at the current level**. Suggested change: remove the early return at line 331, or adjust it to `if (currentDepth > maxBrowseDepth)` (strict greater-than instead of greater-than-or-equal).

## [medium/settings-toggles] Hardcoded English 'TALMID PROFILES' label in tutoring section
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/settings/presentation/screens/settings_screen.dart`
- Symptom: Hebrew locale users see hardcoded English 'TALMID PROFILES' label in the pending/active tutor grants section of Settings screen
- Root cause: Line 659 uses hardcoded string literal 'TALMID PROFILES' instead of l10n. The l10n key `profilePickerTalmidProfiles` exists but is not used.
- Reachability: Settings screen → Pending tutor invites section header (shown when user has tutored profiles). Visible to Hebrew locale users with active/pending tutor grants.
- Fix: Replace line 659 `'TALMID PROFILES'` with `l10n.profilePickerTalmidProfiles`

## [medium/settings-toggles] Hardcoded English 'Pending — tap to accept' and 'Tutoring' status labels
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/settings/presentation/screens/settings_screen.dart`
- Symptom: Hebrew locale users see hardcoded English status text in tutor grant tiles: 'Pending — tap to accept' for pending invites and 'Tutoring' for active grants
- Root cause: Line 722 uses ternary with hardcoded English strings `'Pending — tap to accept'` and `'Tutoring'` instead of l10n keys. Available l10n keys: `statusPending`, `tutoredChildrenStatusTutoring` exist but not used.
- Reachability: Settings screen → _TutorGrantTile widget → status text display. Visible for each tutored profile in the list when user has tutoring grants.
- Fix: Replace line 722 with l10n-based text: `isPending ? l10n.statusPending : l10n.tutoredChildrenStatusTutoring` (may need to adjust exact l10n key names or compose multi-part string for 'tap to accept' part)

## [medium/settings-toggles] Hardcoded English 'Accept' button text in tutor grant tile
- File: `/home/daniel/repos/learning-tracker/learning_tracker/lib/features/settings/presentation/screens/settings_screen.dart`
- Symptom: Hebrew locale users see hardcoded English 'Accept' button label on pending tutor invite tiles in Settings
- Root cause: Line 744 uses hardcoded string literal `'Accept'` for FilledButton instead of l10n. The key `acceptInviteAccept` is available in l10n but not used here.
- Reachability: Settings screen → _TutorGrantTile widget → Accept button (shown only for pending grants, i.e., when `isPending == true` on line 733)
- Fix: Replace line 744 `child: const Text('Accept')` with `child: Text(l10n.acceptInviteAccept)` (requires adding l10n to the widget context)


---
## Rejected: 2
- [export-data] Missing completionEvents in validation required sections causes silent data loss — /home/daniel/repos/learning-tracker/learning_tracker/lib/features/settings/domain/services/data_export_import_service.dart
- [export-data] Hardcoded English error messages in export validation (i18n leak) — /home/daniel/repos/learning-tracker/learning_tracker/lib/features/settings/domain/services/data_export_import_service.dart
