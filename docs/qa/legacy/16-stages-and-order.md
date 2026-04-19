# Configurable Stages & Learning Order -- Manual Test Scenarios

**Document:** 16
**Feature Area:** Stage configuration (add/edit/delete/reorder), schedule types (delay/weekly/rolling), learning order customization
**Created:** 2026-04-13
**FRs Covered:** FR21, FR22, FR23, FR24, FR25, FR26, FR27, FR28, FR29, FR30

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with at least **Mishnayos** activated
2. Personal track is active
3. Content has been imported (Sefaria seed data is available)
4. At least one curriculum has the default stage configuration (Learn + Chazara 1 + Chazara 2)
5. For per-curriculum independence tests (STAGE-16, STAGE-17), activate a second curriculum (e.g., Gemara Bavli)
6. For sync tests (STAGE-25), use a cloud-born account with a second device or emulator available

---

## What & Why

### Why Stages Matter

Stages define the multi-step review cycle that powers the entire scheduling
engine. Every curriculum has a sequence of stages that a content item passes
through: first the learner studies it (Learn), then reviews it at increasing
intervals (Chazara 1, Chazara 2, etc.). The scheduler uses stage definitions
to decide what appears on the daily task list and when.

The default configuration -- Learn (0 days), Chazara 1 (+1 day), Chazara 2
(+7 days) -- works well for most learners. But different curricula and
different learners have different needs. Someone learning Gemara may want a
30-day chazara stage that Mishnayos does not need. Someone with a weekly
Friday review session may want a stage tied to a day of the week rather than
a delay count.

Stage customization (FR21) lets users tailor the review cycle per curriculum.
This is powerful but must be handled carefully: the "Learn" stage is protected
(FR23) because without it there is no entry point into the cycle. Changes
apply only to future scheduling (FR24) so that historical data remains
consistent. And for cloud-born users, stage definitions sync to Firestore
(FR26) so that a second device sees the same configuration.

### Three Schedule Types

Each stage (after Learn) can use one of three schedule types:

| Type | Meaning | Example |
|---|---|---|
| **Delay** | Due N days after the previous stage was completed | Chazara 1: due 1 day after Learn completion |
| **Weekly** | Due on specific days of the week, regardless of when the previous stage was completed | Review every Friday |
| **Rolling** | Keep the last N completed items always in rotation, cycling through them | Always have the 20 most recently learned items in active review |

### Why Learning Order Matters

Learning order determines the sequence in which items are studied within a
curriculum. By default this is the natural Sefaria order (FR28): Berachos
before Peah, Perek 1 before Perek 2, Mishna 1 before Mishna 2. But a learner
may want to skip ahead, follow a teacher's custom syllabus, or start with
a specific masechta. Drag-and-drop reordering (FR27) lets users define their
own sequence. The bookmark advances according to this custom order (FR30),
and the user can always reset to the default (FR29).

### Core Invariants

| Invariant | FR | Description |
|---|---|---|
| **Learn stage protected** | FR23 | The Learn stage (stage_order=1, delay_days=0) cannot be deleted. It is the entry point of every review cycle. |
| **Future-only changes** | FR24 | Stage edits apply to future scheduling only. Existing completions are never modified or reinterpreted. |
| **Per-curriculum isolation** | FR21 | Stage definitions are scoped to a single curriculum. Editing Mishnayos stages has no effect on Bavli. |
| **Default stages** | FR22 | Every curriculum starts with Learn (0d), Chazara 1 (+1d), Chazara 2 (+7d). |
| **Custom order respected** | FR30 | Scheduler and bookmark advancement use custom learning order when set. |
| **Max 10 stages** | FR21 | A curriculum cannot have more than 10 stages. |

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (STAGE-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Default Stages (P0)

---

#### STAGE-01 | P0 | Default stages exist after onboarding

**Preconditions:** Fresh onboarding completed with Mishnayos activated. No stage customization has been performed.

**Steps:**
1. Navigate to the stage configuration screen for Mishnayos (Settings > Curricula > Mishnayos > Stages, or equivalent)
2. Observe the list of stages

**Expected:**
- Exactly 3 stages are listed in order:
  1. Learn -- delay 0 days
  2. Chazara 1 -- delay +1 day
  3. Chazara 2 -- delay +7 days
- All three stages have the "delay" schedule type
- The Learn stage has a visual indicator that it is protected (e.g., lock icon, non-deletable)

**Pass/Fail:** [ ]

---

#### STAGE-02 | P0 | Default stages display correct Hebrew names

**Preconditions:** Same as STAGE-01. App language includes Hebrew stage labels.

**Steps:**
1. Navigate to the stage configuration screen for any active curriculum
2. Observe the stage names displayed

**Expected:**
- Stage 1 displays: לימוד (Learn)
- Stage 2 displays: חזרה א׳ (Chazara 1)
- Stage 3 displays: חזרה ב׳ (Chazara 2)
- Names render correctly with no encoding artifacts or missing characters

**Pass/Fail:** [ ]

---

### Add Custom Stage (P0)

---

#### STAGE-03 | P0 | Add a delay-type stage

**Preconditions:** Mishnayos has default 3 stages. Stage configuration screen is open.

**Steps:**
1. Tap the "Add Stage" button
2. Enter stage name: "Chazara 3"
3. Select schedule type: Delay
4. Set delay to 30 days
5. Confirm / save

**Expected:**
- A fourth stage "Chazara 3" appears in the stage list at position 4
- The stage shows schedule type "Delay" with "+30 days"
- The stage persists after navigating away and returning to the configuration screen
- The scheduler will include this stage for future Learn completions (verify by completing an item and checking that Chazara 3 eventually appears in the task list after 30 days, or verify via the item's stage progression view)

**Pass/Fail:** [ ]

---

#### STAGE-04 | P0 | Add a weekly-type stage

**Preconditions:** Stage configuration screen is open for any curriculum.

**Steps:**
1. Tap "Add Stage"
2. Enter stage name: "Friday Review"
3. Select schedule type: Weekly
4. Select day(s): Friday
5. Confirm / save

**Expected:**
- The new stage appears in the list with schedule type "Weekly" and day "Friday" displayed
- The configuration UI shows the day picker (not a delay number input)
- The stage is saved and persists across navigation

**Pass/Fail:** [ ]

---

#### STAGE-05 | P0 | Add a rolling-type stage

**Preconditions:** Stage configuration screen is open for any curriculum.

**Steps:**
1. Tap "Add Stage"
2. Enter stage name: "Active Review"
3. Select schedule type: Rolling
4. Set window size to 20 items
5. Confirm / save

**Expected:**
- The new stage appears in the list with schedule type "Rolling" and window "20 items" displayed
- The configuration UI shows a numeric input for window size (not a delay or day picker)
- The stage is saved and persists across navigation

**Pass/Fail:** [ ]

---

#### STAGE-06 | P0 | Maximum 10 stages enforced

**Preconditions:** A curriculum already has 10 stages configured (add stages until 10 are present).

**Steps:**
1. Attempt to tap "Add Stage" to add an 11th stage

**Expected:**
- The action is blocked
- A message explains the maximum of 10 stages per curriculum has been reached
- No 11th stage is created
- The "Add Stage" button is either disabled or shows the limit message on tap

**Pass/Fail:** [ ]

---

### Edit Stage (P1)

---

#### STAGE-07 | P1 | Change delay value on existing stage

**Preconditions:** Mishnayos has default stages. At least one item has been completed through Learn and Chazara 1 already (to verify FR24).

**Steps:**
1. Navigate to stage configuration for Mishnayos
2. Tap to edit "Chazara 1"
3. Change the delay from 1 day to 3 days
4. Save the change
5. Check the existing completion history for items already reviewed at Chazara 1
6. Complete a new Learn item and observe when Chazara 1 is scheduled for it

**Expected:**
- The stage list shows Chazara 1 with "+3 days" delay
- Existing completions are unaffected -- items that already completed Chazara 1 at the old 1-day delay remain unchanged in history (FR24)
- The newly completed Learn item has its Chazara 1 scheduled for 3 days from now (not 1 day)

**Pass/Fail:** [ ]

---

#### STAGE-08 | P1 | Change schedule type from delay to weekly

**Preconditions:** A non-Learn stage exists with delay schedule type.

**Steps:**
1. Edit the stage
2. Change schedule type from "Delay" to "Weekly"
3. Observe the configuration UI

**Expected:**
- The delay input (number of days) disappears or is replaced
- A day-of-week picker appears, allowing selection of one or more days
- After selecting a day and saving, the stage shows the new schedule type
- Previous delay configuration is no longer shown for this stage

**Pass/Fail:** [ ]

---

#### STAGE-09 | P1 | Existing completions unaffected by stage edit (FR24)

**Preconditions:** Multiple items have been completed through at least Chazara 1. Note down 2-3 specific completion dates and items.

**Steps:**
1. Edit Chazara 1 -- change delay from 1 day to 14 days
2. Navigate to the completion history for the items noted in preconditions
3. Verify dates and stage associations

**Expected:**
- All previously recorded completions retain their original dates
- No completions are rescheduled, removed, or duplicated
- Stage progression history for completed items shows the original timing
- Only future scheduling of Chazara 1 uses the new 14-day delay

**Pass/Fail:** [ ]

---

### Delete Stage (P0)

---

#### STAGE-10 | P0 | Delete a non-Learn stage

**Preconditions:** Mishnayos has at least the 3 default stages. Stage configuration screen is open.

**Steps:**
1. Select "Chazara 2" for deletion (swipe, long-press, or tap delete icon)
2. Confirm the deletion when prompted

**Expected:**
- "Chazara 2" is removed from the stage list
- Only 2 stages remain: Learn and Chazara 1
- The deletion persists after navigating away and returning
- The scheduler no longer schedules Chazara 2 for future items

**Pass/Fail:** [ ]

---

#### STAGE-11 | P0 | Cannot delete the Learn stage (FR23)

**Preconditions:** Stage configuration screen is open for any curriculum.

**Steps:**
1. Attempt to delete the "Learn" (לימוד) stage -- try all available deletion methods (swipe, long-press, delete icon)

**Expected:**
- The deletion is blocked entirely
- An error message or visual indicator explains that the Learn stage is protected and cannot be deleted
- The Learn stage remains in position 1
- No delete affordance is shown for the Learn stage (preferred), OR the affordance exists but the action is refused with explanation

**Pass/Fail:** [ ]

---

#### STAGE-12 | P1 | Existing completions preserved after stage deletion

**Preconditions:** Several items have completions recorded for Chazara 2. Note specific items and dates.

**Steps:**
1. Delete "Chazara 2" from the stage configuration
2. Navigate to completion history for the items noted in preconditions
3. Check whether the historical Chazara 2 completions still appear

**Expected:**
- Historical completions for the deleted stage are preserved in the completion history
- The completion records are not deleted or modified
- The items show they were reviewed at the now-deleted stage with original dates intact
- The stage name may appear as "deleted stage" or similar in history, or retain its original name

**Pass/Fail:** [ ]

---

### Reorder Stages (P1)

---

#### STAGE-13 | P1 | Reorder non-Learn stages via drag-and-drop

**Preconditions:** At least 3 stages exist beyond Learn (e.g., Chazara 1, Chazara 2, Chazara 3). Stage configuration screen is open.

**Steps:**
1. Drag "Chazara 2" above "Chazara 1" (swap their positions)
2. Release and confirm the reorder
3. Navigate away and return to the stage configuration screen

**Expected:**
- Stage order is now: Learn, Chazara 2, Chazara 1, Chazara 3
- The new order persists after navigation
- Future stage progression for new completions follows the updated order (Chazara 2 before Chazara 1)

**Pass/Fail:** [ ]

---

#### STAGE-14 | P1 | Learn stage cannot be moved from position 1

**Preconditions:** Stage configuration screen is open. Multiple stages exist.

**Steps:**
1. Attempt to drag the Learn stage to a different position (e.g., position 2 or 3)

**Expected:**
- The Learn stage cannot be dragged (drag handle is absent or disabled), OR
- The drag is permitted but the stage snaps back to position 1 on release
- Learn always remains as the first stage in the sequence
- An explanatory message may appear if the user attempts the drag

**Pass/Fail:** [ ]

---

### Reset to Defaults (P1)

---

#### STAGE-15 | P1 | Reset stages to defaults (FR25)

**Preconditions:** Mishnayos stages have been customized (extra stages added, delays changed, stages deleted or reordered).

**Steps:**
1. Navigate to stage configuration for Mishnayos
2. Tap "Reset to Defaults" (or equivalent option)
3. Confirm the reset when prompted

**Expected:**
- Stages revert to exactly 3 defaults: Learn (0d), Chazara 1 (+1d), Chazara 2 (+7d)
- All custom stages are removed
- All delay/schedule type modifications are reverted
- Stage order is restored to the default sequence
- Existing completions for previously-existing stages remain in history (FR24 still applies)

**Pass/Fail:** [ ]

---

### Per-Curriculum Independence (P1)

---

#### STAGE-16 | P1 | Custom stages on one curriculum do not affect another

**Preconditions:** Both Mishnayos and Gemara Bavli are activated. Neither has been customized.

**Steps:**
1. Navigate to Mishnayos stage configuration
2. Add a "Chazara 3" stage with +30 day delay
3. Navigate to Gemara Bavli stage configuration
4. Observe the stages listed

**Expected:**
- Gemara Bavli still has exactly the 3 default stages: Learn, Chazara 1, Chazara 2
- No "Chazara 3" appears on Bavli
- Mishnayos shows 4 stages including the new Chazara 3

**Pass/Fail:** [ ]

---

#### STAGE-17 | P1 | Editing stages on one curriculum leaves others unaffected

**Preconditions:** Both Mishnayos and Gemara Bavli have default stages.

**Steps:**
1. Edit Mishnayos Chazara 1 delay from 1 day to 5 days
2. Delete Mishnayos Chazara 2
3. Navigate to Gemara Bavli stage configuration

**Expected:**
- Bavli Chazara 1 still shows +1 day delay (not 5 days)
- Bavli Chazara 2 still exists and is unchanged
- Changes made to Mishnayos are completely isolated

**Pass/Fail:** [ ]

---

### Learning Order -- Defaults and Customization (P0)

---

#### STAGE-18 | P0 | Default learning order follows natural Sefaria order (FR28)

**Preconditions:** Mishnayos is activated. No custom learning order has been set. Content items are imported.

**Steps:**
1. Navigate to the learning order configuration for Mishnayos (or browse the content in learning-order view)
2. Observe the sequence of items

**Expected:**
- Items appear in natural Sefaria order: Seder Zeraim > Masechta Berachos > Perek 1 > Mishna 1, then Mishna 2, etc.
- No gaps or out-of-sequence items
- The order matches the canonical Sefaria structure

**Pass/Fail:** [ ]

---

#### STAGE-19 | P0 | Drag-and-drop to customize learning order (FR27)

**Preconditions:** Mishnayos learning order screen is open. Default Sefaria order is displayed.

**Steps:**
1. Identify items at positions 1-5 (e.g., Berachos 1:1 through 1:5)
2. Drag item at position 3 to position 1
3. Release and observe the new order
4. Navigate away and return to the learning order screen

**Expected:**
- The item previously at position 3 is now at position 1
- Other items shift down accordingly
- The custom order persists after navigation
- A visual indicator shows that custom ordering is active (not default)

**Pass/Fail:** [ ]

---

#### STAGE-20 | P0 | Bookmark advances per custom order (FR30)

**Preconditions:** A custom learning order is set for Mishnayos (STAGE-19 completed). The bookmark is at the first item in the custom order.

**Steps:**
1. Note the first 3 items in the custom order (e.g., positions 1, 2, 3)
2. Complete the Learn stage for the item at position 1
3. Observe where the bookmark advances to
4. Complete the Learn stage for the next item
5. Observe bookmark advancement again

**Expected:**
- After completing position 1, the bookmark advances to the item at position 2 in the CUSTOM order (not the default Sefaria order)
- After completing position 2, the bookmark advances to position 3 in the custom order
- The daily task list reflects the custom order for new Learn items

**Pass/Fail:** [ ]

---

#### STAGE-21 | P0 | Reset learning order to default (FR29)

**Preconditions:** Mishnayos has a custom learning order set (STAGE-19 completed).

**Steps:**
1. Navigate to the learning order configuration for Mishnayos
2. Tap "Reset to Default" (or equivalent)
3. Confirm the reset
4. Observe the item sequence

**Expected:**
- Items return to natural Sefaria order
- Custom ordering is fully removed
- The visual indicator for "custom order" is no longer shown
- The bookmark position may or may not change (it tracks the same item, but the item's position in the sequence returns to its natural location)

**Pass/Fail:** [ ]

---

### Learning Order -- Edge Cases (P2)

---

#### STAGE-22 | P2 | Reorder items mid-curriculum with existing completions

**Preconditions:** Mishnayos has several items already completed (Learn stage). The bookmark is at, say, item 20 in Sefaria order. Items 1-19 have been completed.

**Steps:**
1. Open learning order configuration
2. Move an uncompleted item (e.g., item 50) to position 21 (right after the bookmark)
3. Save the custom order
4. Complete the current bookmark item (item 20)
5. Observe where the bookmark advances

**Expected:**
- The bookmark advances to item 50 (now at position 21 in the custom order), not to item 21 in Sefaria order
- Previously completed items (1-19) are unaffected -- their completion records remain intact
- The custom order only affects future bookmark advancement

**Pass/Fail:** [ ]

---

#### STAGE-23 | P2 | Reorder in one curriculum does not affect others

**Preconditions:** Both Mishnayos and Gemara Bavli are activated. Default learning order on both.

**Steps:**
1. Customize the learning order for Mishnayos (move several items)
2. Navigate to Gemara Bavli learning order view

**Expected:**
- Bavli items remain in default Sefaria order
- No items from Mishnayos appear in Bavli's order
- The custom order indicator is absent on Bavli

**Pass/Fail:** [ ]

---

#### STAGE-24 | P2 | Large reorder -- drag item across many positions

**Preconditions:** Mishnayos learning order screen is open with many items visible (or scrollable).

**Steps:**
1. Scroll to approximately item 100 in the list
2. Drag that item to position 5 (near the top of the list)
3. Release and save
4. Navigate away and return

**Expected:**
- The item is now at position 5
- All intermediate items (previously at positions 5-99) shift down by one
- The operation completes without lag, crash, or data corruption
- The reorder persists correctly after navigation
- Scrolling through the list remains smooth

**Pass/Fail:** [ ]

---

### Sync (P2)

---

#### STAGE-25 | P2 | Stage changes sync to Firestore for cloud-born (FR26)

**Preconditions:** Cloud-born account is active. Two devices (or device + emulator) are signed into the same account. Both devices show default stages for Mishnayos.

**Steps:**
1. On Device A, add a "Chazara 3" stage with +30 day delay to Mishnayos
2. Wait for sync to complete (observe sync indicator on Device A)
3. On Device B, navigate to Mishnayos stage configuration
4. Observe the stage list

**Expected:**
- Device B shows 4 stages including the newly added "Chazara 3" with +30 day delay
- The stage configuration matches Device A exactly
- No duplicate stages or sync conflicts
- If Device B was offline during the change, the stage appears after Device B reconnects and syncs

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Stages & Learning Order |
|---|---|---|
| **Scheduler** | 06 - Scheduling & Review | The scheduler reads stage definitions to determine what to schedule and when. Delay, weekly, and rolling schedule types each produce different scheduling behavior. Stage changes directly affect future task list generation. |
| **Learning & Completions** | 04 - Learning & Completions | Completions are recorded per stage. Stage progression (Learn before Chazara 1 before Chazara 2) is enforced during completion. Bookmark advancement follows the learning order defined here. |
| **Sync & Multi-Device** | 14 - Sync & Multi-Device | Stage definitions and custom learning orders sync to Firestore for cloud-born users (FR26). Sync uses last-write-wins for mutable configuration like stages. |
