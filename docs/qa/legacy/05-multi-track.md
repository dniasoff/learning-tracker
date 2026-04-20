# Multi-Track Learning -- Manual Test Scenarios

**Document:** 05
**Feature Area:** Multi-track lifecycle, bookmark independence, completion routing, track management
**Created:** 2026-04-13
**FRs Covered:** FR8, FR9, FR10, FR11, FR12, FR46, FR63

---

## Prerequisites

Before running these scenarios:

1. Complete Learning scenarios (document 04) with at least **Mishnayos** activated
2. Personal track is active (always present after onboarding)
3. Content has been imported (Sefaria seed data is available)
4. At least one curriculum has a configured goal with stages (Learn + Chazara 1 + Chazara 2)
5. For parent-mode scenarios (TRACK-21 through TRACK-23), have a parent account with an associated child account

---

## What & Why

### Why Multi-Track Matters

Learning doesn't happen in a single context. A child may learn Mishnayos
independently at home (personal track), cover different material in school
(school track), and review yet another section with a tutor (tutor track).
Each context has its own pace, its own place in the curriculum, and its own
completion history. The multi-track system keeps these contexts separate so
that progress in one never overwrites or confuses progress in another.

### Three Track Types

| Track | Presence | Who manages | Dashboard access |
|---|---|---|---|
| **Personal** | Mandatory, always present | User (or parent for child) | Full read/write |
| **School** | Optional, manually activated | User or parent (FR9, FR63) | Full read/write |
| **Tutor** | Optional, manually activated | User or parent (FR9, FR63) | Read-only for tutor (via PIN) |

Each curriculum can have up to **3 tracks simultaneously** (FR8): one personal,
one school, and one tutor. Tracks are per-curriculum -- activating a school
track on Mishnayos does not affect Bavli.

### Track Lifecycle

A track moves through these states:

```
activate --> active --> deactivate (data preserved, hidden from scheduler)
                          |
                          v
                       archive (hidden from dashboard + scheduler, data preserved)
                          |
                          v
                       unarchive (restored to active state)
```

The **personal track cannot be deactivated or archived**. It is always present
for every active curriculum.

### Core Invariants

| Invariant | FR | Description |
|---|---|---|
| **Personal permanence** | FR8 | Personal track is mandatory and cannot be removed, deactivated, or archived. |
| **Track cap** | FR8 | Maximum 3 tracks per curriculum (personal + school + tutor). No duplicates of the same type. |
| **Independent bookmarks** | FR10 | Each track maintains its own bookmark per curriculum. Advancing one track's bookmark never moves another's. |
| **No cross-track duplication** | FR11 | The same content item's stage cannot be completed under multiple tracks within a curriculum. If Personal completed "Berachos 1:1" Learn stage, School cannot complete the same item+stage. Different stages of the same item are fine. |
| **Track attribution** | FR12 | Every completion is attributed to exactly one track. If only personal track is active, attribution is automatic. If multiple tracks are active, the user picks. |
| **Data preservation** | FR9 | Deactivation and archiving preserve all completion history. Nothing is lost. |

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (TRACK-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Personal Track Fundamentals (P0)

---

#### TRACK-01 | P0 | Personal track exists for each active curriculum after onboarding

**Preconditions:** Onboarding completed with at least Mishnayos activated. If a second curriculum (e.g., Bavli) was activated, both should be checked.

**Steps:**
1. Navigate to the curriculum detail screen for Mishnayos
2. Open the track management section (settings or track list)
3. Verify the personal track is listed
4. If a second curriculum is active, repeat for that curriculum

**Expected:**
- Each active curriculum shows exactly one personal track
- The personal track is marked as the default/mandatory track
- The personal track's bookmark is positioned where onboarding left it
- No school or tutor tracks are present unless previously activated

**Pass/Fail:** [ ]

---

#### TRACK-02 | P0 | Attempt to deactivate personal track is blocked

**Preconditions:** Personal track is active for Mishnayos.

**Steps:**
1. Navigate to the track management section for Mishnayos
2. Select the personal track
3. Attempt to deactivate it (tap deactivate / toggle off / swipe to remove)

**Expected:**
- The deactivation action is blocked (button is disabled, or action is rejected with an error)
- A message explains that the personal track is mandatory and cannot be deactivated
- The personal track remains active and unchanged

**Pass/Fail:** [ ]

---

#### TRACK-03 | P0 | Attempt to archive personal track is blocked

**Preconditions:** Personal track is active for Mishnayos.

**Steps:**
1. Navigate to the track management section for Mishnayos
2. Select the personal track
3. Attempt to archive it

**Expected:**
- The archive action is blocked (option not available or action rejected)
- A message explains that the personal track cannot be archived
- The personal track remains active and unchanged

**Pass/Fail:** [ ]

---

### School Track Lifecycle (P0)

---

#### TRACK-04 | P0 | Activate school track for Mishnayos

**Preconditions:** Mishnayos is active with only the personal track. Personal bookmark is at a known position (e.g., Perek 3, Mishna 1).

**Steps:**
1. Navigate to the track management section for Mishnayos
2. Tap "Add Track" or equivalent
3. Select "School" as the track type
4. Confirm activation

**Expected:**
- School track is created and appears in the track list
- School track's bookmark initializes at the beginning of the curriculum (e.g., Berachos 1:1), NOT at the personal track's current position
- The personal track's bookmark is unchanged (still at Perek 3)
- The curriculum now shows 2 active tracks
- The daily task list may now include items from the school track's position

**Pass/Fail:** [ ]

---

#### TRACK-05 | P0 | Mark items complete on school track

**Preconditions:** TRACK-04 completed. School track is active for Mishnayos with bookmark at beginning.

**Steps:**
1. Navigate to the daily task list or content browser
2. Locate an item at the school track's bookmark position (e.g., Berachos 1:1)
3. Tap to mark the Learn stage complete
4. If a track picker appears, select "School"
5. Verify the completion record

**Expected:**
- Completion is recorded with trackType='school'
- Points are awarded normally
- The school track's bookmark advances to the next item
- The personal track's bookmark is unchanged
- The completion appears in history attributed to the school track

**Pass/Fail:** [ ]

---

#### TRACK-06 | P0 | Deactivate school track preserves data

**Preconditions:** TRACK-05 completed. School track has at least one completion recorded.

**Steps:**
1. Navigate to the track management section for Mishnayos
2. Select the school track
3. Tap "Deactivate" or equivalent
4. Confirm the deactivation

**Expected:**
- School track is removed from the active tracks list
- School track no longer appears in the daily task list or scheduler
- The track picker no longer shows school as an option for new completions
- Previously recorded school completions are still visible in completion history
- The personal track is completely unaffected
- No data is deleted -- bookmark position and all completions are preserved internally

**Pass/Fail:** [ ]

---

#### TRACK-07 | P0 | Reactivate school track restores state

**Preconditions:** TRACK-06 completed. School track is deactivated with preserved data.

**Steps:**
1. Navigate to the track management section for Mishnayos
2. Look for a "Reactivate" or "Add Track" option for school
3. Reactivate the school track

**Expected:**
- School track reappears in the active tracks list
- Bookmark is at the position where it was when deactivated (not reset to beginning)
- All previous school completions are still attributed to the school track
- The track picker once again includes school as an option
- The daily task list includes school track items based on the restored bookmark

**Pass/Fail:** [ ]

---

#### TRACK-08 | P0 | Archive school track hides it from dashboard and scheduler

**Preconditions:** School track is active with completions. Note the current bookmark position.

**Steps:**
1. Navigate to the track management section for Mishnayos
2. Select the school track
3. Tap "Archive" or equivalent
4. Confirm the action
5. Check the dashboard
6. Check the daily task list

**Expected:**
- School track is no longer visible on the dashboard
- School track items do not appear in the daily task list
- School track does not appear in the track picker for new completions
- The track management section shows the track as archived (if it shows archived tracks)
- Completion data is preserved -- school completions still appear in full history views
- The personal track is unaffected

**Pass/Fail:** [ ]

---

#### TRACK-09 | P0 | Unarchive school track restores to active state

**Preconditions:** TRACK-08 completed. School track is archived.

**Steps:**
1. Navigate to the track management section for Mishnayos
2. Locate the archived school track (may require toggling "show archived" or similar)
3. Tap "Unarchive" or equivalent
4. Confirm the action

**Expected:**
- School track returns to active state
- Bookmark is at the same position it was before archiving
- All completions are intact and attributed to the school track
- School track reappears on the dashboard
- School track items return to the daily task list
- Track picker includes school again

**Pass/Fail:** [ ]

---

### Tutor Track Lifecycle (P1)

---

#### TRACK-10 | P1 | Activate tutor track prompts PIN setup

**Preconditions:** Mishnayos is active. No tutor track exists. Personal track (and optionally school track) is active.

**Steps:**
1. Navigate to the track management section for Mishnayos
2. Tap "Add Track" or equivalent
3. Select "Tutor" as the track type
4. Observe the setup flow

**Expected:**
- A tutor PIN setup screen appears before the track is finalized
- The user must set a PIN (e.g., 4-digit code) for tutor access
- After PIN is set, the tutor track is created and appears in the track list
- The tutor track's bookmark initializes at the beginning of the curriculum
- The PIN is stored securely (device-local, never synced -- per FR98/FR99)

**Pass/Fail:** [ ]

---

#### TRACK-11 | P1 | Mark items complete on tutor track

**Preconditions:** TRACK-10 completed. Tutor track is active for Mishnayos.

**Steps:**
1. Navigate to the daily task list or content browser
2. Locate an item at the tutor track's bookmark position
3. Tap to mark the Learn stage complete
4. Select "Tutor" in the track picker
5. Verify the completion record

**Expected:**
- Completion is recorded with trackType='tutor'
- Points are awarded normally
- The tutor track's bookmark advances
- Other tracks' bookmarks are unchanged
- The completion appears in history attributed to the tutor track

**Pass/Fail:** [ ]

---

#### TRACK-12 | P1 | Deactivate and archive tutor track preserves data

**Preconditions:** TRACK-11 completed. Tutor track has at least one completion.

**Steps:**
1. Deactivate the tutor track (same flow as TRACK-06)
2. Verify completions are preserved
3. Archive the tutor track (same flow as TRACK-08)
4. Verify completions are still preserved
5. Unarchive the tutor track
6. Verify bookmark and completions are restored

**Expected:**
- Same preservation behavior as school track (TRACK-06 through TRACK-09)
- Deactivation hides track from scheduler but preserves data
- Archiving hides track from dashboard but preserves data
- Unarchiving restores everything to the pre-deactivation state
- Tutor PIN remains valid through the entire lifecycle

**Pass/Fail:** [ ]

---

### Bookmark Independence (P0)

---

#### TRACK-13 | P0 | New school track bookmark starts at beginning regardless of personal position

**Preconditions:** Personal track is active for Mishnayos with bookmark at Perek 3 (or any non-starting position).

**Steps:**
1. Note the personal track's current bookmark position (e.g., Perek 3, Mishna 1)
2. Activate a school track for Mishnayos
3. Check the school track's bookmark position

**Expected:**
- School track's bookmark starts at the very beginning of the curriculum (Berachos 1:1)
- Personal track's bookmark remains at Perek 3, Mishna 1
- The two bookmarks are visually distinguishable in the UI

**Pass/Fail:** [ ]

---

#### TRACK-14 | P0 | Advancing school bookmark does not move personal bookmark

**Preconditions:** TRACK-13 completed. Personal bookmark at Perek 3, school bookmark at beginning.

**Steps:**
1. Complete 10+ Learn-stage items on the school track, advancing the school bookmark to approximately Perek 5
2. After each completion, verify the personal bookmark has not moved
3. Navigate to the curriculum detail screen and check both bookmarks

**Expected:**
- School bookmark is now at approximately Perek 5
- Personal bookmark remains exactly at Perek 3, Mishna 1
- No cross-contamination between bookmark positions
- Each track's progress display shows its own independent position

**Pass/Fail:** [ ]

---

#### TRACK-15 | P0 | Each track's bookmark shown independently in UI

**Preconditions:** At least 2 tracks active for Mishnayos with bookmarks at different positions.

**Steps:**
1. Navigate to the curriculum detail screen for Mishnayos
2. Locate the bookmark indicators for each active track
3. Verify each track's bookmark is displayed separately
4. If a tutor track is also active, verify its bookmark is shown as well

**Expected:**
- Each active track's bookmark position is clearly visible and labeled (e.g., "Personal: Perek 3", "School: Perek 5")
- Bookmarks are visually distinguishable (different colors, labels, or sections)
- Tapping or selecting a track filters the view to show that track's position and progress
- No ambiguity about which bookmark belongs to which track

**Pass/Fail:** [ ]

---

### Multi-Track Completion Routing (P0)

---

#### TRACK-16 | P0 | Two tracks active triggers track picker on completion

**Preconditions:** Personal and school tracks are both active for Mishnayos. An item is available for completion.

**Steps:**
1. Navigate to the daily task list
2. Tap an item to mark it complete
3. Observe what happens before the completion is recorded

**Expected:**
- A track picker appears presenting "Personal" and "School" as options
- The user must select a track before the completion proceeds
- After selecting a track, the completion is recorded under that track
- The completion animation and points appear as normal
- The selected track's bookmark advances (if Learn stage)
- The other track's bookmark does not advance

**Pass/Fail:** [ ]

---

#### TRACK-17 | P0 | Three tracks active shows all three in track picker

**Preconditions:** Personal, school, and tutor tracks are all active for Mishnayos. An item is available for completion.

**Steps:**
1. Navigate to the daily task list
2. Tap an item to mark it complete
3. Observe the track picker

**Expected:**
- Track picker presents all 3 options: "Personal", "School", and "Tutor"
- Each option is clearly labeled and tappable
- Selecting any one of the three records the completion under that track
- Only the selected track's bookmark advances

**Pass/Fail:** [ ]

---

#### TRACK-18 | P0 | Same item+stage cannot be completed under multiple tracks (FR11)

**Preconditions:** Personal and school tracks are active for Mishnayos. An item (e.g., Berachos 1:1) has been completed for the Learn stage under the personal track.

**Steps:**
1. Navigate to the content browser
2. Locate the item that was already completed for Learn stage under personal track (Berachos 1:1)
3. Attempt to mark the same item's Learn stage complete again
4. If a track picker appears, select "School"

**Expected:**
- The completion is **blocked**
- An error or informational message explains that this item's Learn stage has already been completed (under the personal track)
- No duplicate completion is recorded
- The school track's data is unchanged
- Note: completing a *different* stage (e.g., Chazara 1) of the same item under the school track should still be allowed, as long as Learn was completed first (per stage progression rules)

**Pass/Fail:** [ ]

---

### Track-Specific Progress (P1)

---

#### TRACK-19 | P1 | Progress view shows track attribution for each completion (FR46)

**Preconditions:** Multiple completions exist across personal and school tracks for the same curriculum.

**Steps:**
1. Navigate to the per-curriculum progress/history view
2. Examine individual completion entries
3. Look for track attribution indicators

**Expected:**
- Each completion entry shows which track it belongs to (e.g., a label, icon, or color indicating "Personal" vs "School" vs "Tutor")
- Completions can be filtered by track
- The attribution matches what was selected at the time of completion
- Track attribution is preserved for completions made under tracks that are now deactivated or archived

**Pass/Fail:** [ ]

---

#### TRACK-20 | P1 | Dashboard shows aggregated progress across all tracks

**Preconditions:** Completions exist under multiple tracks for the same curriculum.

**Steps:**
1. Navigate to the main dashboard
2. Locate the summary card for Mishnayos
3. Check the progress metrics (total completions, percentage, etc.)

**Expected:**
- The dashboard aggregates completions from all tracks (personal + school + tutor)
- Total completion count includes completions from all active and deactivated tracks
- Progress percentage reflects the union of all completed items regardless of track
- The aggregated view does not double-count items (each item+stage counts once, per FR11)

**Pass/Fail:** [ ]

---

### Parent Track Management (P1)

---

#### TRACK-21 | P1 | Parent adds school track for child's curriculum (FR63)

**Preconditions:** Parent account is active with an associated child account. Child has Mishnayos active with only the personal track. Parent has entered parent mode via PIN.

**Steps:**
1. Enter parent mode (PIN entry)
2. Navigate to the child's curriculum management
3. Select Mishnayos
4. Add a school track for the child

**Expected:**
- School track is created on the child's Mishnayos curriculum
- School bookmark initializes at the beginning of the curriculum
- The child's personal track is unaffected
- When the child next opens the app, they see the school track in their track list
- The child can now make completions under the school track

**Pass/Fail:** [ ]

---

#### TRACK-22 | P1 | Parent removes school track for child with data preservation

**Preconditions:** TRACK-21 completed. Child's school track has at least one completion recorded.

**Steps:**
1. Enter parent mode
2. Navigate to the child's curriculum management for Mishnayos
3. Deactivate the school track
4. Confirm the action

**Expected:**
- School track is deactivated (hidden from child's scheduler and task list)
- All school track completion data is preserved
- The child's personal track is unaffected
- A confirmation message warns that this will hide the track but preserve data
- If the parent later reactivates the school track, all data is restored

**Pass/Fail:** [ ]

---

#### TRACK-23 | P1 | Parent adds tutor track with PIN setup flow

**Preconditions:** Parent account is active with an associated child. Child has Mishnayos active.

**Steps:**
1. Enter parent mode
2. Navigate to the child's curriculum management for Mishnayos
3. Add a tutor track
4. Complete the tutor PIN setup flow

**Expected:**
- Tutor PIN setup screen appears during the track creation flow
- Parent sets the tutor PIN (separate from the parent PIN, per FR98)
- Tutor track is created on the child's Mishnayos curriculum
- The tutor can now use the PIN to access the read-only tutor dashboard
- The child can make completions under the tutor track
- Tutor PIN is stored device-locally and securely (per FR99)

**Pass/Fail:** [ ]

---

### Cross-Curriculum Tracks (P2)

---

#### TRACK-24 | P2 | School track on multiple curricula operates independently

**Preconditions:** Mishnayos and Bavli are both active. School tracks are activated for both curricula.

**Steps:**
1. Activate a school track for Mishnayos (if not already active)
2. Activate a school track for Bavli
3. Advance the Mishnayos school bookmark by completing several items
4. Check the Bavli school bookmark

**Expected:**
- Bavli school bookmark remains at its starting position, unaffected by Mishnayos school completions
- Each curriculum's school track has its own independent bookmark
- Completions on Mishnayos school track do not appear in Bavli's history
- The track management section for each curriculum shows its own school track independently

**Pass/Fail:** [ ]

---

#### TRACK-25 | P2 | Deactivating school track on one curriculum does not affect another

**Preconditions:** TRACK-24 completed. School tracks are active for both Mishnayos and Bavli, each with at least one completion.

**Steps:**
1. Deactivate the school track for Mishnayos only
2. Check the Bavli school track status
3. Make a completion on the Bavli school track

**Expected:**
- Mishnayos school track is deactivated (hidden from scheduler, data preserved)
- Bavli school track remains fully active and functional
- Completions can still be made on the Bavli school track
- Bavli school bookmark continues to advance normally
- The two curricula's track states are completely independent

**Pass/Fail:** [ ]

---

## Cross-Feature References

This document focuses on multi-track management. Related test scenarios appear in:

| Document | Relationship |
|---|---|
| **04 - Learning & Completions** | Core completion mechanics; multi-track completion routing originates there (LEARN-06 through LEARN-08, LEARN-21 through LEARN-23) |
| **06 - Scheduler** | Scheduler must respect active tracks and generate tasks per track per curriculum |
| **08 - Dashboard** | Dashboard aggregation across tracks; track attribution display (FR46) |
| **10 - Parent Mode** | Parent PIN entry, child management, track creation by parent (FR63) |
| **11 - Tutor Mode** | Tutor PIN, read-only dashboard access, tutor track completion flow |
