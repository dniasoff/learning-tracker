# Settings & Account Management -- Manual Test Scenarios

**Document:** 13
**Feature Area:** Mode switch, curriculum activation, notification prefs, data export/import, sign out, account deletion, password change, provider linking, upgrade to cloud
**Created:** 2026-04-13
**FRs Covered:** FR5, FR81, FR85, FR86, FR87, FR95, FR96, FR102, FR103, FR104, FR105

> ⚠️ **Local-born scenarios stale -- 2026-07-13.** Per the 2026-06-14 product decision,
> offline/local-born accounts are now **credential-less** (no email, no password, no
> account-level name) -- created via an explicit "no internet, create an offline
> account?" prompt and re-entered through the **Account Picker**, not email/password
> sign-in. Every local-born scenario in this document that assumes a password no
> longer applies as written (including SET-13, SET-18, SET-20, SET-23, SET-25 through
> SET-29); the "Local-born has no cloud operations" note above still holds
> conceptually. Cloud-born scenarios (SET-21, SET-22, SET-24) are unaffected. Current
> behavior: `signup_screen.dart` and `upgrade_to_cloud_service.dart`. Design record:
> `../../planning/loop-progress.md`, "ONBOARDING REWORK" entries (2026-06-14 to
> 2026-06-15).

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with at least one curriculum activated
2. Have both a cloud-born and a local-born test account available
3. For export/import tests: have at least 20+ completions, active streaks, and configured goals across at least two curricula
4. For provider linking tests: have a Google account available that is NOT already linked to another app account
5. For notification tests: device notification permissions are granted to the app

**Settings is the most sensitive surface in the app after completions.** Every
action here mutates account-level state -- mode, credentials, data -- and
several operations are irreversible. Bugs here can lock users out of their
accounts or destroy data.

---

## What & Why

### Why Settings Tests Matter

Settings contains the highest concentration of destructive operations in the
app: account deletion, sign out, data import (which overwrites local state),
and password changes. Each of these must work exactly right on the first
attempt because users cannot easily recover from a half-completed operation.

### Key Invariants

| Invariant | FR | Description |
|---|---|---|
| **Mode switch preserves data** | FR81 | Switching between child and adult mode changes only the UI/UX layer. All completions, bookmarks, streaks, points, and goals are preserved intact. |
| **Curriculum deactivation preserves progress** | FR5 | Deactivating a curriculum hides it from the UI but all completion data, bookmarks, and review counts are retained. Re-activating restores the exact prior state. |
| **Export is complete** | FR95 | JSON export includes all 11 tables -- no data is silently omitted. |
| **Import is atomic** | FR96 | Import either fully succeeds or fully rolls back. No partial import states. |
| **Sign out clears session, not data** | FR102 | Local data is preserved after sign out so re-sign-in restores everything. |
| **Account deletion is total** | FR103 | Firestore data, Firebase Auth account, and local data are all deleted. Nothing is recoverable. |
| **Local-born has no cloud operations** | -- | Password change, provider linking, and sign out behave differently (or are absent) for local-born accounts. |

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (SET-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Mode Switch -- FR81 (P0)

---

#### SET-01 | P0 | Switch from child mode to adult mode

**Preconditions:** App is in child mode. At least 10 completions exist. Streaks and points are active. Note current point total, streak count, bookmark positions, and completion count.

**Steps:**
1. Navigate to Settings
2. Locate the mode switch option (child/adult toggle)
3. Switch to adult mode
4. Confirm the switch if a confirmation dialog appears

**Expected:**
- Mode changes to adult immediately
- All completion data is preserved (same count as before)
- Point total is unchanged
- Streak count is unchanged
- Bookmark positions for all curricula are unchanged
- UI transitions to adult styling (subtle animations, minimal gamification chrome)
- Completion feedback changes to adult style (subtle/none vs celebratory)

**Pass/Fail:** [ ]

---

#### SET-02 | P0 | Switch from adult mode to child mode

**Preconditions:** App is in adult mode. Note current data state.

**Steps:**
1. Navigate to Settings
2. Switch to child mode
3. Confirm if prompted

**Expected:**
- Mode changes to child immediately
- All completion data, points, streaks, and bookmarks are preserved
- UI transitions to child styling (celebratory animations, full gamification chrome)
- Mystery rewards section becomes visible (if parent has configured rewards)

**Pass/Fail:** [ ]

---

#### SET-03 | P1 | Mode switch persists across app restart

**Preconditions:** Just completed SET-01 or SET-02 (mode was switched).

**Steps:**
1. Note the current mode
2. Force-close the app completely
3. Reopen the app
4. Navigate to Settings and check the mode

**Expected:**
- The mode is still set to the value chosen before the restart
- No revert to default or onboarding mode

**Pass/Fail:** [ ]

---

#### SET-04 | P1 | Mode switch syncs to Firestore (cloud-born)

**Preconditions:** Cloud-born account. App is online. Mode is currently child.

**Steps:**
1. Switch mode to adult
2. Wait for sync to complete (observe sync indicator)
3. Sign in on a second device (or clear app data and re-sign-in)
4. Check the mode on the second device

**Expected:**
- The mode change is synced to Firestore
- The second device shows adult mode after pull-on-launch
- LWW conflict resolution applies if both devices change mode simultaneously

**Pass/Fail:** [ ]

---

### Curriculum Activation & Deactivation -- FR5 (P0)

---

#### SET-05 | P0 | Deactivate a curriculum -- progress is preserved

**Preconditions:** Mishnayos curriculum is active with at least 20 completions, a bookmark at a known position, and configured goals. Note all values.

**Steps:**
1. Navigate to Settings > Curricula (or equivalent)
2. Deactivate Mishnayos
3. Confirm if prompted
4. Verify Mishnayos is no longer visible in the daily task list or dashboard

**Expected:**
- Mishnayos disappears from the daily task list, dashboard, and content browser
- No completion data is deleted (verify via data export if needed)
- No error or crash occurs
- Other active curricula are unaffected

**Pass/Fail:** [ ]

---

#### SET-06 | P0 | Re-activate a curriculum -- exact state is restored

**Preconditions:** SET-05 completed. Know the pre-deactivation values for Mishnayos.

**Steps:**
1. Navigate to Settings > Curricula
2. Re-activate Mishnayos
3. Check bookmark position, completion count, goals, and configured stages

**Expected:**
- Mishnayos reappears in the daily task list, dashboard, and content browser
- Bookmark is at the exact same position as before deactivation
- All completions are intact (same count)
- Goals and deadlines are preserved
- Configured stages (Learn, Chazara 1, Chazara 2) are preserved
- Review counts are intact

**Pass/Fail:** [ ]

---

#### SET-07 | P1 | Deactivate all curricula -- app handles gracefully

**Preconditions:** Multiple curricula active.

**Steps:**
1. Deactivate all curricula one by one
2. Attempt to deactivate the last remaining curriculum

**Expected:**
- The app either prevents deactivating the last curriculum (minimum one required per FR77) or handles the zero-curricula state gracefully
- No crash occurs
- If prevented, a clear message explains that at least one curriculum must remain active

**Pass/Fail:** [ ]

---

### Notification Preferences -- FR85, FR86, FR87 (P1)

---

#### SET-08 | P1 | Disable daily learning reminder

**Preconditions:** Daily learning reminder is enabled (default). Notification time is set.

**Steps:**
1. Navigate to Settings > Notifications
2. Toggle off the daily learning reminder
3. Wait past the configured reminder time (or set it to 1 minute from now for testing)

**Expected:**
- No daily learning reminder notification is delivered
- Other notification types (streak alert, mystery reward) are unaffected
- The toggle state persists across app restart

**Pass/Fail:** [ ]

---

#### SET-09 | P1 | Change notification time

**Preconditions:** Daily learning reminder is enabled.

**Steps:**
1. Navigate to Settings > Notifications
2. Change the reminder time from default (7:00 PM) to a time 2 minutes from now
3. Save the change
4. Wait for the new time to arrive

**Expected:**
- The notification fires at the newly configured time, not the old one
- The time picker shows the updated value when re-opened

**Pass/Fail:** [ ]

---

#### SET-10 | P1 | Shabbos/Yom Tov suppression

**Preconditions:** Notifications are enabled. Device date/time can be adjusted or it is currently Erev Shabbos.

**Steps:**
1. Enable Shabbos/Yom Tov notification suppression in settings (FR87)
2. Set a notification for a time that falls during Shabbos hours
3. Wait for the scheduled time

**Expected:**
- No notification is delivered during Shabbos/Yom Tov
- Notifications resume after Shabbos ends
- The suppression uses Hebrew calendar calculations (kosher_dart)

**Pass/Fail:** [ ]

---

### Data Export -- FR95 (P0)

---

#### SET-11 | P0 | Export progress data to JSON

**Preconditions:** Account has meaningful data: completions across multiple curricula, active streaks, configured goals, point history, multiple tracks.

**Steps:**
1. Navigate to Settings > Data > Export
2. Tap Export
3. Choose a save location (or accept the default)
4. Wait for the export to complete

**Expected:**
- A JSON file is created at the chosen location
- The file contains all 11 tables of user data
- The file size is reasonable (not empty, not suspiciously small)
- A success confirmation is shown
- No data is modified in the app by the export operation

**Pass/Fail:** [ ]

---

#### SET-12 | P1 | Exported JSON contains all data tables

**Preconditions:** SET-11 completed. Have the exported JSON file available.

**Steps:**
1. Open the exported JSON file in a text editor or JSON viewer
2. Verify all 11 tables are present
3. Spot-check completions: count matches in-app completion count
4. Spot-check bookmarks: positions match in-app bookmark positions
5. Spot-check streaks: current streak value matches

**Expected:**
- All 11 data tables are present in the JSON structure
- Completion records include item IDs, stages, tracks, and timestamps
- Bookmark positions are accurate
- Streak data matches the app's displayed values
- Goal configurations are included
- No sensitive data is exposed unintentionally (e.g., raw password hashes should not be in the export)

**Pass/Fail:** [ ]

---

#### SET-13 | P2 | Export while offline (local-born)

**Preconditions:** Local-born account with data. Device is offline.

**Steps:**
1. Enable airplane mode
2. Navigate to Settings > Data > Export
3. Perform the export

**Expected:**
- Export completes successfully (all data is local)
- The exported file is identical in structure to an online export
- No error about missing network connectivity

**Pass/Fail:** [ ]

---

### Data Import -- FR96 (P0)

---

#### SET-14 | P0 | Import progress data from JSON backup

**Preconditions:** Have a valid exported JSON file from SET-11. Create a fresh account (or clear existing data) so the import result is verifiable.

**Steps:**
1. Navigate to Settings > Data > Import
2. Select the JSON backup file
3. Confirm the import when prompted
4. Wait for the import to complete

**Expected:**
- All data from the JSON file is imported
- Completion counts match the source account
- Bookmark positions match the source account
- Streaks, points, and goals are restored
- A success confirmation is shown

**Pass/Fail:** [ ]

---

#### SET-15 | P0 | Import is atomic -- partial failure rolls back

**Preconditions:** Have a JSON backup file. Introduce a corruption (e.g., truncate the file mid-way, remove a required field, or use a file with invalid JSON).

**Steps:**
1. Note the current app state (completions, bookmarks, etc.)
2. Navigate to Settings > Data > Import
3. Select the corrupted file
4. Attempt the import

**Expected:**
- The import fails with a clear error message
- The app state is unchanged -- no partial data was written
- All pre-existing completions, bookmarks, and settings are intact
- The user can retry with a valid file

**Pass/Fail:** [ ]

---

#### SET-16 | P1 | Import with existing data -- merge or replace behavior

**Preconditions:** Account already has completions. Have a JSON backup file with different (overlapping and non-overlapping) data.

**Steps:**
1. Note current completion count and bookmark positions
2. Import the JSON backup
3. Observe the behavior: does the import merge or replace?
4. Check for duplicates in completion history

**Expected:**
- The app clearly communicates whether import will merge with or replace existing data
- If merge: existing completions are preserved, new ones are added, no duplicates
- If replace: existing data is wiped and fully replaced with import data
- No data corruption regardless of approach
- Bookmark positions are consistent with the final completion state

**Pass/Fail:** [ ]

---

### Sign Out -- FR102 (P0)

---

#### SET-17 | P0 | Sign out clears session but preserves data (cloud-born)

**Preconditions:** Cloud-born account. App has meaningful data. Note completion count and bookmark positions.

**Steps:**
1. Navigate to Settings > Account > Sign Out
2. Confirm sign out
3. Observe the sign-out behavior
4. Sign back in with the same credentials
5. Verify data is intact

**Expected:**
- Session is cleared -- the app shows the sign-in screen
- After re-sign-in, all data is restored from Firestore (pull-on-launch)
- Completion count matches pre-sign-out values
- Bookmark positions are correct
- Streaks and points are intact
- No data is lost

**Pass/Fail:** [ ]

---

#### SET-18 | P1 | Sign out for local-born account

**Preconditions:** Local-born account with data.

**Steps:**
1. Navigate to Settings > Account > Sign Out
2. Confirm sign out
3. Observe behavior
4. Sign back in with the local credentials

**Expected:**
- Session is cleared -- sign-in screen appears
- Local data is preserved on-device (not deleted on sign out)
- After re-sign-in with the same email/password, all data is accessible
- No Firestore operations occur (local-born has no cloud identity)

**Pass/Fail:** [ ]

---

### Account Deletion -- FR103 (P0)

---

#### SET-19 | P0 | Delete cloud-born account -- full cleanup

**Preconditions:** Cloud-born account with data in Firestore. This test is destructive -- use a test account.

**Steps:**
1. Navigate to Settings > Account > Delete Account
2. Read the confirmation dialog carefully
3. Confirm deletion (may require re-authentication)
4. Wait for the process to complete

**Expected:**
- Firestore data is deleted for this user
- Firebase Auth account is deleted
- Local data is cleared
- The app returns to the onboarding/sign-up screen
- Attempting to sign in with the old credentials fails (account no longer exists)

**Pass/Fail:** [ ]

---

#### SET-20 | P0 | Delete local-born account -- local data cleared

**Preconditions:** Local-born account with data. This test is destructive.

**Steps:**
1. Navigate to Settings > Account > Delete Account
2. Read the confirmation dialog
3. Confirm deletion

**Expected:**
- All local data (completions, bookmarks, streaks, settings) is cleared
- The local auth record is deleted
- The app returns to the onboarding/sign-up screen
- No Firestore operations occur
- No orphaned data remains in SQLite

**Pass/Fail:** [ ]

---

#### SET-21 | P1 | Account deletion requires confirmation and re-authentication

**Preconditions:** Signed-in account (cloud-born or local-born).

**Steps:**
1. Navigate to Settings > Account > Delete Account
2. Observe the confirmation flow

**Expected:**
- A clear warning is shown explaining that deletion is permanent and irreversible
- The warning specifies what will be deleted (all data, account, etc.)
- Re-authentication (password entry) is required before the deletion proceeds
- There is a cancel option that aborts without any changes
- The deletion button is visually distinct (red/destructive styling)

**Pass/Fail:** [ ]

---

### Password Change -- FR104 (P1)

---

#### SET-22 | P1 | Change password (cloud-born, email/password account)

**Preconditions:** Cloud-born account using email/password authentication (not Google Sign-In only).

**Steps:**
1. Navigate to Settings > Account > Change Password
2. Enter current password
3. Enter new password
4. Confirm new password
5. Submit the change

**Expected:**
- Password is updated in Firebase Auth
- The user remains signed in (session is not invalidated)
- Signing out and back in with the OLD password fails
- Signing out and back in with the NEW password succeeds
- All data remains intact after the password change

**Pass/Fail:** [ ]

---

#### SET-23 | P1 | Change password (local-born account)

**Preconditions:** Local-born account with email/password.

**Steps:**
1. Navigate to Settings > Account > Change Password
2. Enter current password
3. Enter new password and confirm
4. Submit the change

**Expected:**
- The argon2id hash in SQLite is updated to the new password
- The user remains signed in
- Signing out and back in with the new password succeeds
- The old password no longer works
- A reminder is shown that local-born passwords are unrecoverable if forgotten

**Pass/Fail:** [ ]

---

### Provider Linking -- FR105 (P1)

---

#### SET-24 | P1 | Link Google Sign-In to email/password account (cloud-born)

**Preconditions:** Cloud-born account created with email/password only. A Google account is available.

**Steps:**
1. Navigate to Settings > Account > Linked Providers (or similar)
2. Tap "Link Google Account"
3. Complete the Google Sign-In flow
4. Verify the link

**Expected:**
- Google Sign-In is now listed as a linked provider
- The user can sign out and sign back in using Google Sign-In
- Email/password sign-in still works
- Both methods access the same account and data
- No duplicate account is created

**Pass/Fail:** [ ]

---

#### SET-25 | P2 | Provider linking is not available for local-born accounts

**Preconditions:** Local-born account.

**Steps:**
1. Navigate to Settings > Account
2. Look for provider linking options

**Expected:**
- No provider linking option is visible for local-born accounts
- Local-born accounts support only email/password authentication
- No confusing or broken UI elements related to provider linking

**Pass/Fail:** [ ]

---

### Upgrade to Cloud -- Local-Born to Cloud-Born (P1)

---

#### SET-26 | P1 | Upgrade local-born to cloud -- no email collision

**Preconditions:** Local-born account with data. The email used does NOT exist as a Firebase Auth account. Device is online.

**Steps:**
1. Navigate to Settings > Account > Upgrade to Cloud
2. Confirm the upgrade
3. Wait for the process to complete
4. Verify the account is now cloud-born

**Expected:**
- Firebase Auth user is created with the same email and password
- Firestore sync is enabled -- local data is pushed to Firestore
- All completions, bookmarks, streaks, points, and goals are preserved
- The account now behaves as cloud-born (sync active, provider linking available)
- The upgrade is one-way -- no option to revert to local-born

**Pass/Fail:** [ ]

---

#### SET-27 | P1 | Upgrade local-born to cloud -- email collision, choose upload

**Preconditions:** Local-born account with data. The same email already exists as a Firebase Auth account (create one in advance). Device is online.

**Steps:**
1. Navigate to Settings > Account > Upgrade to Cloud
2. Observe the collision detection
3. Review the merge flow showing local vs cloud data
4. Choose "Upload local into cloud"
5. Sign in to the existing cloud account when prompted
6. Wait for the merge to complete

**Expected:**
- The collision is detected and clearly communicated
- The merge flow shows what data exists on each side
- After choosing upload: local data is merged into the cloud account per conflict resolution rules (§4.1)
- Completions use merge-forward (union), settings use LWW
- No data loss for progress data
- The account is now cloud-born with merged data

**Pass/Fail:** [ ]

---

#### SET-28 | P1 | Upgrade local-born to cloud -- email collision, choose keep cloud

**Preconditions:** Same as SET-27.

**Steps:**
1. Navigate to Settings > Account > Upgrade to Cloud
2. Observe the collision detection
3. Choose "Keep cloud, discard local"
4. Confirm the destructive action

**Expected:**
- Local data is cleared
- The user is signed in to the existing cloud account
- Cloud data is pulled down and becomes the active state
- A clear warning was shown before discarding local data
- The operation is not reversible

**Pass/Fail:** [ ]

---

#### SET-29 | P2 | Upgrade local-born to cloud -- cancel during collision flow

**Preconditions:** Same as SET-27.

**Steps:**
1. Navigate to Settings > Account > Upgrade to Cloud
2. Observe the collision detection
3. Choose "Cancel"

**Expected:**
- The local account is unchanged
- No Firebase Auth user is created or modified
- No data is lost or modified
- The user returns to settings in their original local-born state

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Settings |
|---|---|---|
| **Onboarding** | 03 - Onboarding | Mode and curriculum selections made during onboarding can be changed in settings. |
| **Notifications** | 12 - Notifications | Notification preferences are configured in settings. Shabbos suppression depends on Hebrew calendar. |
| **Sync & Offline** | 14 - Sync & Offline | Sign out, account deletion, and upgrade-to-cloud all interact with the sync layer. Mode and curriculum changes sync via LWW. |
| **Learning & Completions** | 04 - Learning & Completions | Mode switch changes completion feedback style. Curriculum deactivation hides but preserves completions. |
| **Gamification** | 09 - Gamification & Rewards | Mode switch toggles between full gamification (child) and minimal (adult). Points and streaks are preserved across mode switches. |
| **Dashboard** | 08 - Dashboard & Progress | Curriculum activation/deactivation changes what appears on the dashboard. |
| **Parent Mode** | 10 - Parent Mode | Mystery rewards are only configurable in child mode. Mode switch to adult may hide parent-facing features. |
