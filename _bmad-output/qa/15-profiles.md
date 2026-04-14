# Profiles -- Manual Test Scenarios

**Document:** 15
**Feature Area:** Multi-profile management, profile switching, data isolation, cascade delete
**Created:** 2026-04-13
**FRs Covered:** FR76, FR81 (mode per profile), plus multi-profile architecture (max 10 profiles, profile picker, cascade delete across 11 profile-scoped tables)

---

## Prerequisites

Before running these scenarios:

1. Complete authentication (document 02) -- signed in with a cloud-born or local-born account
2. Complete onboarding (document 03) for at least one profile
3. At least one curriculum activated with some completions recorded
4. For cascade delete scenarios: a profile with data across multiple tables (completions, bookmarks, goals, tracks, stages, rewards, streaks, XP, learning order, study day configs, active curricula)

---

## What & Why

### Why Profiles Matter

Profiles allow a single account to serve multiple learners. A parent account might have profiles for three children, each with completely independent learning state. An adult might maintain separate profiles for different learning contexts.

The profile system is the **isolation boundary** for all learning data. Every profile-scoped table (11 tables total) keys on `profileId`. If profile isolation leaks, one learner's completions could corrupt another's progress. If cascade delete misses a table, orphaned data accumulates silently and can surface as ghost state in dashboards, schedulers, or sync.

### The 11 Profile-Scoped Tables

Every row in these tables belongs to exactly one profile. Cascade delete must clean all of them:

| Table | What it holds |
|---|---|
| `completions` | The sacred append-only learning log |
| `bookmarks` | Current position per track per curriculum |
| `goals` | Deadline/pace targets per curriculum |
| `curriculum_tracks` | Personal/school/tutor track definitions |
| `stage_definitions` | Custom chazara stage timing |
| `learning_order` | Drag-and-drop content ordering |
| `active_curricula` | Which curricula are turned on |
| `rewards` | Mystery reward catalog |
| `point_configs` | Per-stage point values |
| `study_day_configs` | Per-curriculum day-of-week schedules |
| `profile_programs` | Program associations (Daf Yomi, etc.) |

Additional profile-scoped tables that hold event data:

| Table | What it holds |
|---|---|
| `streak_events` | Daily streak log |
| `xp_events` | XP earning history |
| `reward_pools` | Earned reward state |
| `learning_ledger` | Siyum and milestone records |
| `test_scores` | Dirshu and test program scores |
| `curriculum_scopes` | Per-curriculum scope configuration |

### Core Invariants

| Invariant | Description |
|---|---|
| **Isolation** | Profile A's data is never visible to or affected by Profile B's actions |
| **Max 10** | An account cannot have more than 10 profiles |
| **Default profile** | The first profile is created during onboarding; it cannot be the last one deleted unless the account itself is deleted |
| **Independent mode** | Each profile has its own child/adult mode setting |
| **Cascade completeness** | Deleting a profile removes all rows in all profile-scoped tables |

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (PROF-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Default Profile Creation (P0)

---

#### PROF-01 | P0 | First profile created during onboarding

**Preconditions:** Fresh account, onboarding not yet completed.

**Steps:**
1. Complete the onboarding flow (mode selection, curriculum activation)
2. Navigate to the dashboard
3. Check the profile indicator or settings

**Expected:**
- A default profile exists with the name entered during onboarding
- The profile's mode matches the mode selected during onboarding (child or adult)
- The profile has an avatar (default index 0)
- `createdAt` timestamp is set
- All subsequent learning data is scoped to this profile's `profileId`

**Pass/Fail:** [ ]

---

### Add Profiles (P0)

---

#### PROF-02 | P0 | Add a second profile

**Preconditions:** One profile exists from onboarding. Signed in.

**Steps:**
1. Navigate to Settings > Profiles (or the profile management area)
2. Tap "Add Profile"
3. Enter a display name (e.g., "Shimon")
4. Select a mode (child or adult -- can differ from the first profile)
5. Choose an avatar
6. Confirm creation

**Expected:**
- A second profile is created with a distinct `profileId`
- The new profile has no learning data -- zero completions, no active curricula, no bookmarks
- The profile picker now appears at app launch (2+ profiles triggers the picker)
- The original profile's data is completely unaffected

**Pass/Fail:** [ ]

---

#### PROF-03 | P0 | Add profiles up to maximum (10)

**Preconditions:** One profile exists.

**Steps:**
1. Add profiles one at a time until 10 profiles exist
2. After the 10th profile is created, attempt to add an 11th

**Expected:**
- Profiles 2 through 10 are created without error
- Each has a unique `profileId` and independent empty learning state
- When attempting to create the 11th profile, the system blocks the action
- A clear error message appears: limit reached, cannot add more profiles
- The "Add Profile" button is disabled or hidden when at 10

**Pass/Fail:** [ ]

---

#### PROF-04 | P1 | New profile starts with clean slate

**Preconditions:** First profile has significant data -- completions, bookmarks, goals, rewards, streaks, XP.

**Steps:**
1. Create a second profile
2. Switch to the new profile
3. Check dashboard, completion history, streaks, XP, rewards, active curricula

**Expected:**
- Dashboard shows no data -- zero completions, zero streaks, zero XP
- No curricula are active (the new profile must go through its own curriculum activation)
- No bookmarks, goals, or tracks exist
- No rewards are configured
- The first profile's data has not changed

**Pass/Fail:** [ ]

---

### Profile Picker (P0)

---

#### PROF-05 | P0 | Profile picker shown at launch with 2+ profiles

**Preconditions:** Two or more profiles exist on the account.

**Steps:**
1. Force-close the app
2. Reopen the app
3. Observe the launch screen

**Expected:**
- The profile picker screen appears before the dashboard
- All profiles are listed with their display names and avatars
- Tapping a profile navigates to that profile's dashboard
- No profile data is loaded until a profile is selected

**Pass/Fail:** [ ]

---

#### PROF-06 | P0 | Profile picker not shown with single profile

**Preconditions:** Only one profile exists on the account.

**Steps:**
1. Force-close the app
2. Reopen the app

**Expected:**
- The app goes directly to the dashboard (no profile picker)
- The single profile is auto-selected

**Pass/Fail:** [ ]

---

#### PROF-07 | P1 | Profile picker remembers last used profile

**Preconditions:** Three profiles exist. The user last used Profile B.

**Steps:**
1. Switch to Profile B and use the app briefly
2. Force-close the app
3. Reopen the app
4. Observe the profile picker

**Expected:**
- Profile B is highlighted or shown as the most recently used profile
- All profiles are still selectable
- Tapping Profile B loads Profile B's data immediately

**Pass/Fail:** [ ]

---

### Switch Profiles (P0)

---

#### PROF-08 | P0 | Switch between profiles mid-session

**Preconditions:** Two profiles exist. Profile A is active with data. Profile B has its own data.

**Steps:**
1. While using Profile A, navigate to the profile switcher (settings or profile menu)
2. Select Profile B
3. Observe the dashboard and data

**Expected:**
- The dashboard immediately reflects Profile B's data (different completions, streaks, XP, curricula)
- Profile A's data is not visible anywhere
- The switch is seamless with no stale data flicker

**Pass/Fail:** [ ]

---

#### PROF-09 | P0 | Unsaved state on profile switch

**Preconditions:** Profile A is active. The user is in the middle of an action (e.g., editing a goal, browsing content).

**Steps:**
1. Navigate partway through a multi-step action (e.g., start editing a goal but don't save)
2. Switch to Profile B
3. Switch back to Profile A

**Expected:**
- The unsaved edit on Profile A is discarded (or the app prompts to save/discard before switching)
- Profile A's persisted data is intact
- No cross-contamination of in-progress state between profiles

**Pass/Fail:** [ ]

---

### Data Isolation (P0)

---

#### PROF-10 | P0 | Completions are isolated between profiles

**Preconditions:** Profile A has completions in Mishnayos. Profile B has the same curriculum active but different completions (or none).

**Steps:**
1. Switch to Profile A and note the completion count and specific completed items
2. Switch to Profile B and note the completion count
3. Complete an item on Profile B
4. Switch back to Profile A

**Expected:**
- Profile A's completion count has not changed
- The item completed on Profile B does not appear in Profile A's history
- Bookmarks are independent -- Profile A's bookmark is unaffected by Profile B's completion

**Pass/Fail:** [ ]

---

#### PROF-11 | P0 | Streaks and XP are isolated between profiles

**Preconditions:** Profile A has a 10-day streak and 500 XP. Profile B has a 3-day streak and 100 XP.

**Steps:**
1. Switch to Profile A -- verify streak = 10, XP = 500
2. Switch to Profile B -- verify streak = 3, XP = 100
3. Complete an item on Profile B (earning XP)
4. Switch back to Profile A

**Expected:**
- Profile A's streak and XP are unchanged
- Profile B's XP increased by the earned amount
- Neither profile's streak affects the other

**Pass/Fail:** [ ]

---

#### PROF-12 | P0 | Goals and tracks are isolated between profiles

**Preconditions:** Profile A has a Mishnayos deadline goal and a school track. Profile B has the same curriculum but no goal and only a personal track.

**Steps:**
1. Switch to Profile A -- verify goal and school track visible
2. Switch to Profile B -- verify no goal, personal track only
3. Add a goal on Profile B
4. Switch back to Profile A

**Expected:**
- Profile A's goal is unchanged (different deadline, different pace)
- Profile B's new goal does not appear on Profile A
- Track lists are independent per profile

**Pass/Fail:** [ ]

---

#### PROF-13 | P1 | Rewards are isolated between profiles

**Preconditions:** Profile A (child mode) has 3 mystery rewards configured. Profile B (child mode) has 1 reward.

**Steps:**
1. Switch to Profile A -- verify 3 rewards visible
2. Switch to Profile B -- verify 1 reward visible
3. Add a reward on Profile B
4. Switch back to Profile A

**Expected:**
- Profile A still has exactly 3 rewards
- Profile B now has 2 rewards
- Reward point thresholds are independent

**Pass/Fail:** [ ]

---

### Independent Modes (P0)

---

#### PROF-14 | P0 | Profiles can have different child/adult modes

**Preconditions:** Account with two profiles.

**Steps:**
1. Set Profile A to child mode
2. Set Profile B to adult mode
3. Switch to Profile A and complete an item -- observe feedback
4. Switch to Profile B and complete an item -- observe feedback

**Expected:**
- Profile A shows child-mode completion feedback (celebratory animation, full gamification)
- Profile B shows adult-mode completion feedback (subtle, minimal gamification)
- Mode is stored per-profile, not per-account
- Switching profiles changes the UI mode immediately

**Pass/Fail:** [ ]

---

#### PROF-15 | P1 | Change mode on a single profile without affecting others

**Preconditions:** Profile A is child mode. Profile B is adult mode.

**Steps:**
1. Switch to Profile A
2. Navigate to Settings > change mode to adult
3. Verify Profile A now shows adult-mode UI
4. Switch to Profile B
5. Verify Profile B is still in adult mode (unchanged)

**Expected:**
- Only Profile A's mode changed
- Profile B's mode, data, and UI are completely unaffected
- The mode change persists across app restart

**Pass/Fail:** [ ]

---

### Profile Edit (P1)

---

#### PROF-16 | P1 | Edit profile display name

**Preconditions:** A profile exists with name "Reuven."

**Steps:**
1. Navigate to Settings > Profile
2. Edit the display name to "Reuven Levi"
3. Save the change
4. Navigate back to the profile picker or dashboard

**Expected:**
- The profile name updates to "Reuven Levi" everywhere (picker, settings, any profile indicators)
- `updatedAt` timestamp is refreshed
- No other profile data is affected

**Pass/Fail:** [ ]

---

#### PROF-17 | P1 | Edit profile avatar

**Preconditions:** A profile exists with avatar index 0.

**Steps:**
1. Navigate to Settings > Profile
2. Change the avatar selection
3. Save the change

**Expected:**
- The avatar updates in the profile picker and any in-app profile indicators
- No other profile data is affected

**Pass/Fail:** [ ]

---

### Cascade Delete (P0)

---

#### PROF-18 | P0 | Delete a profile removes all profile-scoped data

**Preconditions:** Profile B has data in multiple tables: completions, bookmarks, goals, tracks, stage definitions, learning order, active curricula, rewards, point configs, study day configs, profile programs, streak events, XP events, reward pools, learning ledger entries.

**Steps:**
1. Note Profile B's `profileId`
2. Navigate to Settings > Profiles
3. Select Profile B
4. Tap "Delete Profile"
5. Confirm the deletion (expect a confirmation dialog with a warning)
6. Verify Profile B no longer appears in the profile list

**Expected:**
- Profile B is removed from the profile picker
- All rows in all profile-scoped tables with Profile B's `profileId` are deleted
- Specifically verify (if database inspection is available):
  - `completions` -- zero rows for this profileId
  - `bookmarks` -- zero rows
  - `goals` -- zero rows
  - `curriculum_tracks` -- zero rows
  - `stage_definitions` -- zero rows
  - `learning_order` -- zero rows
  - `active_curricula` -- zero rows
  - `rewards` -- zero rows
  - `point_configs` -- zero rows
  - `study_day_configs` -- zero rows
  - `profile_programs` -- zero rows
- Profile A's data is completely unaffected

**Pass/Fail:** [ ]

---

#### PROF-19 | P0 | Delete confirmation requires explicit action

**Preconditions:** At least two profiles exist.

**Steps:**
1. Navigate to profile deletion for a profile
2. Observe the confirmation dialog

**Expected:**
- A confirmation dialog appears with a clear warning about permanent data loss
- The profile name is shown in the warning
- The user must take an explicit action to confirm (not just dismiss)
- Canceling the dialog preserves the profile and all its data

**Pass/Fail:** [ ]

---

#### PROF-20 | P0 | Cannot delete the last remaining profile

**Preconditions:** Only one profile exists on the account.

**Steps:**
1. Navigate to profile management
2. Attempt to delete the sole remaining profile

**Expected:**
- The system blocks the deletion
- A message explains that at least one profile must exist
- The delete option is disabled or hidden for the last profile
- To fully remove all data, the user must delete their account (document 02)

**Pass/Fail:** [ ]

---

#### PROF-21 | P1 | After deleting a profile, active profile is unaffected

**Preconditions:** Three profiles exist: A (active), B, C. Profile B has data.

**Steps:**
1. While using Profile A, delete Profile B
2. Continue using Profile A -- navigate dashboard, check completions, streaks

**Expected:**
- Profile A's session continues uninterrupted
- All of Profile A's data is intact
- Profile B no longer appears in the profile picker
- Profile C is unaffected

**Pass/Fail:** [ ]

---

#### PROF-22 | P1 | Delete the currently active profile switches to another

**Preconditions:** Two profiles exist: A (active) and B.

**Steps:**
1. While using Profile A, delete Profile A
2. Observe what happens

**Expected:**
- After deletion, the app switches to Profile B (the remaining profile)
- Or the app returns to the profile picker if more than one profile remains
- No crash or undefined state
- The deleted profile's data is fully removed

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Profiles |
|---|---|---|
| **Auth & Accounts** | 02 - Auth & Accounts | Profiles exist within an account. Account deletion deletes all profiles. Tier (cloud/local) applies to the account, not individual profiles. |
| **Onboarding** | 03 - Onboarding | Onboarding creates the first profile. Mode selection during onboarding sets the initial profile's child/adult mode. |
| **Learning & Completions** | 04 - Learning & Completions | All completions are profile-scoped. The append-only invariant applies within a profile's data. |
| **Multi-Track** | 05 - Multi-Track | Tracks are profile-scoped. Each profile manages its own set of personal/school/tutor tracks independently. |
| **Sync** | 14 - Sync & Offline | Profile data syncs per-profile. Multi-device sync must maintain profile isolation across devices. |
| **Settings** | 13 - Settings | Profile management (add, edit, delete) is accessed through settings. Mode changes are per-profile settings. |
| **Parent Mode** | 10 - Parent Mode | Parent mode may manage rewards and tracks for a child-mode profile. |
