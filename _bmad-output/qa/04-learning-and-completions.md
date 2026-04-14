# Learning & Completions -- Manual Test Scenarios

**Document:** 04
**Feature Area:** Learning completions, stage progression, bookmarks, points, review counts
**Created:** 2026-04-13
**FRs Covered:** FR11, FR13, FR14, FR15, FR15b, FR16, FR17, FR18, FR19, FR20, FR49, FR49b, FR110, FR111, FR112, FR113

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with at least **Mishnayos** activated
2. Personal track is active
3. Optionally activate School and/or Tutor tracks for multi-track scenarios (LEARN-06 through LEARN-08, LEARN-21 through LEARN-23)
4. Content has been imported (Sefaria seed data is available)
5. At least one curriculum has a configured goal with stages (Learn + Chazara 1 + Chazara 2)

**This is the most critical test document in the suite.** Completions are the
atomic interaction of the entire app. Every other feature -- scheduling,
gamification, dashboard, sync -- depends on completions being recorded correctly.

---

## What & Why

### Why Completions Matter

The "mark complete" action will be repeated **thousands of times** over the
app's lifetime. A learner doing daily Mishnayos may tap this button 3-10 times
per day, every day, for years. It must be reliable under every condition:
fresh install, low battery, interrupted mid-tap, offline, across app restarts.

If completions are unreliable, the entire app is worthless. No amount of
beautiful scheduling or gamification matters if the underlying data is wrong.

### Three Completion Contexts

Completions enter the system through three paths. Each has different UI and
different rules:

1. **Scheduled completion.** The daily task list presents items the scheduler
   has chosen. The user taps an item to mark it complete. If only the Personal
   track is active, the track is auto-assigned (no picker). This is the
   primary, most-frequent path.

2. **Ad-hoc completion.** The user browses the content hierarchy (e.g.,
   Mishnayos > Seder Zeraim > Masechta Berachos > Perek 1 > Mishna 1) and
   marks an item complete from the browser. This requires selecting a stage
   and, if multiple tracks are active, selecting a track. Ad-hoc completions
   do NOT advance the bookmark because they are out of sequence.

3. **Bulk completion.** The user multi-selects items, chooses a stage, and
   confirms a batch operation. Bulk completion advances the bookmark past all
   selected items if they are contiguous from the current bookmark position.

### Core Invariants

These invariants must hold at all times. Every scenario below tests one or
more of them.

| Invariant | FR | Description |
|---|---|---|
| **Immutability** | FR15 | Completed stages cannot be unmarked. The completions table is append-only (INSERT-only, never UPDATE, never DELETE). This is a core architectural decision, not a limitation. |
| **Duplicate prevention** | FR11 | The same content item's stage cannot be completed under multiple tracks within a curriculum. If Personal track completed "Mishnayos Perek 1 Mishna 1" Learn stage, School track cannot complete the same item+stage. Different stages are fine. |
| **Stage progression** | FR14 | Must complete stage N before stage N+1 for the same item. You cannot do Chazara 1 before Learn, or Chazara 2 before Chazara 1. |
| **Bookmark advancement** | FR17 | On first-stage (Learn) completion, the bookmark advances to the next item in learning order. |
| **Transaction safety** | FR20 | Completion record + bookmark update + points award happen in a single atomic SQLite transaction. All succeed or all fail -- never a partial state. |
| **Review count** | FR15b | The system permanently tracks the total review count per item (e.g., "learned 1x, reviewed 10x"). This count survives track deletion, scope changes, and curriculum deactivation. |
| **Points** | FR16 | Configurable per stage per curriculum. Default values: Learn = 10 points, Chazara 1 = 5 points, Chazara 2 = 3 points. |

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (LEARN-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Scheduled Completion -- Happy Path (P0)

---

#### LEARN-01 | P0 | Mark Learn stage complete from daily task list

**Preconditions:** Daily task list is populated with at least one item. Personal track is active. No completions exist yet for the target item.

**Steps:**
1. Open the app and navigate to the daily task list (home screen)
2. Identify the first item in the list (note the item name, e.g., "Berachos 1:1")
3. Tap the item to mark the Learn stage complete

**Expected:**
- Completion animation plays (child mode: celebratory; adult mode: subtle)
- Points popup appears showing points earned (default: 10 for Learn)
- Progress bar increments visibly
- The item's status in the task list updates to show Learn stage is done
- The item is no longer listed as a pending Learn task

**Pass/Fail:** [ ]

---

#### LEARN-02 | P0 | Bookmark advances after Learn stage completion

**Preconditions:** LEARN-01 completed. Note the item that was just completed (e.g., "Berachos 1:1").

**Steps:**
1. Navigate to the curriculum's bookmark indicator (visible on dashboard or curriculum detail screen)
2. Verify the bookmark position

**Expected:**
- Bookmark now points to the next item in learning order (e.g., "Berachos 1:2")
- The bookmark did not skip any items
- The next day's task list will include the new bookmark item for Learn stage

**Pass/Fail:** [ ]

---

#### LEARN-03 | P0 | Chazara 1 appears after configured delay and can be completed

**Preconditions:** LEARN-01 completed. Enough time has passed (or stage delay is set to 0/1 day for testing) so that Chazara 1 is scheduled.

**Steps:**
1. Wait for the configured Chazara 1 delay to elapse (or adjust stage timing to 0 days for testing)
2. Open the daily task list
3. Locate the item completed in LEARN-01 -- it should now appear with Chazara 1 due
4. Tap to mark Chazara 1 complete

**Expected:**
- Chazara 1 completion is recorded
- Points popup shows Chazara 1 points (default: 5)
- The item's review count updates (now "learned 1x, reviewed 1x")
- Bookmark does NOT advance (only Learn stage advances bookmark)

**Pass/Fail:** [ ]

---

#### LEARN-04 | P0 | Chazara 2 appears after configured delay and can be completed

**Preconditions:** LEARN-03 completed. Chazara 2 delay has elapsed.

**Steps:**
1. Wait for the configured Chazara 2 delay to elapse
2. Open the daily task list
3. Locate the item -- it should now appear with Chazara 2 due
4. Tap to mark Chazara 2 complete

**Expected:**
- Chazara 2 completion is recorded
- Points popup shows Chazara 2 points (default: 3)
- The item is now fully reviewed through all configured stages
- The item's review count updates (now "learned 1x, reviewed 2x")
- The item no longer appears in pending tasks (all stages done)

**Pass/Fail:** [ ]

---

#### LEARN-05 | P0 | Complete multiple items in sequence -- bookmark advances correctly each time

**Preconditions:** Bookmark is at a known position. At least 3 consecutive items are available for Learn stage.

**Steps:**
1. Note the current bookmark position (e.g., "Berachos 1:2")
2. Complete Learn stage for the item at the bookmark
3. Verify bookmark advances to "Berachos 1:3"
4. Complete Learn stage for "Berachos 1:3"
5. Verify bookmark advances to "Berachos 1:4"
6. Complete Learn stage for "Berachos 1:4"
7. Verify bookmark advances to "Berachos 1:5"

**Expected:**
- Each completion advances the bookmark by exactly one item
- No items are skipped
- Points are awarded for each completion
- All three completions appear in completion history

**Pass/Fail:** [ ]

---

### Track Auto-Assignment (P0)

---

#### LEARN-06 | P0 | Only personal track active -- no track picker shown

**Preconditions:** Only the Personal track is active (School and Tutor tracks are not enabled). Daily task list has a pending item.

**Steps:**
1. Open daily task list
2. Tap an item to mark it complete

**Expected:**
- Completion is recorded immediately with no track selection dialog
- The completion is auto-assigned to the Personal track
- Verify in completion history that the track is listed as "Personal"

**Pass/Fail:** [ ]

---

#### LEARN-07 | P0 | Personal + School tracks active -- track picker appears

**Preconditions:** Both Personal and School tracks are active for the curriculum. A pending item exists in the daily task list.

**Steps:**
1. Open daily task list
2. Tap an item to mark it complete
3. Observe the track picker dialog that appears
4. Select "Personal" (or "School")
5. Confirm the selection

**Expected:**
- A track picker dialog appears with exactly two options: Personal and School
- The user must choose before the completion is recorded
- After selection, the completion is recorded under the chosen track
- Points are awarded
- Bookmark advances (if Learn stage)

**Pass/Fail:** [ ]

---

#### LEARN-08 | P0 | All 3 tracks active -- track picker shows all 3 options

**Preconditions:** Personal, School, and Tutor tracks are all active for the curriculum.

**Steps:**
1. Open daily task list
2. Tap an item to mark it complete
3. Observe the track picker dialog

**Expected:**
- Track picker shows exactly three options: Personal, School, Tutor
- Each option is clearly labeled
- Selecting any one of them records the completion under that track

**Pass/Fail:** [ ]

---

### Ad-Hoc Completion from Content Browser (P1)

---

#### LEARN-09 | P1 | Browse to a leaf item and mark complete

**Preconditions:** Content browser is accessible. At least one item has NOT been completed yet.

**Steps:**
1. Navigate to the content browser
2. Drill down through the hierarchy: e.g., Mishnayos > Seder Zeraim > Berachos > Perek 1 > Mishna 5
3. Tap the item to open it
4. Tap the "mark complete" action
5. If a stage selector appears, choose "Learn"
6. If a track picker appears (multiple tracks active), select a track

**Expected:**
- A stage selector appears (showing available stages: Learn, Chazara 1, etc.)
- Only stages that are valid per progression rules are selectable (if Learn not done, only Learn is available)
- The completion is recorded
- Points are awarded

**Pass/Fail:** [ ]

---

#### LEARN-10 | P1 | Ad-hoc completion does NOT advance the bookmark

**Preconditions:** Bookmark is at a known position (e.g., "Berachos 1:5"). There is an uncompleted item further ahead in the sequence (e.g., "Berachos 2:1").

**Steps:**
1. Note the current bookmark position
2. Open content browser and navigate to an item that is NOT at the bookmark (e.g., "Berachos 2:1")
3. Mark it as Learn complete via the browser
4. Navigate back to the dashboard and check the bookmark position

**Expected:**
- The completion is recorded for "Berachos 2:1"
- The bookmark has NOT moved -- it still points to "Berachos 1:5"
- The bookmark only advances via sequential scheduled completions, not ad-hoc

**Pass/Fail:** [ ]

---

#### LEARN-11 | P1 | Ad-hoc Chazara 1 for an already-learned item

**Preconditions:** An item has Learn stage completed but Chazara 1 not yet done. The Chazara 1 delay may not have elapsed yet (but ad-hoc should still allow it).

**Steps:**
1. Open content browser and navigate to the item that has Learn done
2. Tap to mark complete
3. The stage selector should show Chazara 1 as available
4. Select Chazara 1

**Expected:**
- Chazara 1 completion is recorded
- Points for Chazara 1 are awarded
- Review count updates accordingly

**Pass/Fail:** [ ]

---

### Bulk Completion (P1)

---

#### LEARN-12 | P1 | Bulk complete 5 items -- bookmark advances past all 5

**Preconditions:** Bookmark is at a known position. The next 5 items in sequence are all uncompleted.

**Steps:**
1. Note the current bookmark position (e.g., "Berachos 1:5")
2. Enter multi-select mode in the daily task list or content browser
3. Select the 5 consecutive items starting from the bookmark position
4. Choose "Learn" stage
5. Confirm the bulk completion

**Expected:**
- All 5 items are marked as Learn complete
- Bookmark advances past all 5 items to the 6th item (e.g., "Berachos 2:4")
- Points are awarded for all 5 items (default: 5 x 10 = 50 points total)
- All 5 completions appear in completion history with the same timestamp (or very close)

**Pass/Fail:** [ ]

---

#### LEARN-13 | P1 | Bulk complete 20+ items -- progress indicator shown

**Preconditions:** At least 20 consecutive uncompleted items available.

**Steps:**
1. Enter multi-select mode
2. Select 20 or more consecutive items
3. Choose "Learn" stage
4. Confirm the bulk completion

**Expected:**
- A progress indicator (spinner, progress bar, or similar) appears during processing
- All items are recorded as complete once processing finishes
- Bookmark advances past all selected items
- Points are awarded for every item
- The UI remains responsive during bulk processing (no ANR)

**Pass/Fail:** [ ]

---

#### LEARN-14 | P1 | Bulk complete with multiple tracks active -- track selector first

**Preconditions:** At least two tracks active. Multiple uncompleted items available.

**Steps:**
1. Enter multi-select mode and select 3-5 items
2. Initiate bulk completion
3. Observe the order of dialogs

**Expected:**
- Track selector appears FIRST, before stage selection or confirmation
- After selecting a track, the stage selector or confirmation dialog appears
- All items in the batch are assigned to the same selected track
- Completions are recorded correctly

**Pass/Fail:** [ ]

---

### Stage Progression Enforcement (P0 -- Data Integrity)

---

#### LEARN-15 | P0 | Cannot complete Chazara 1 before Learn

**Preconditions:** An item exists that has NO completions at all (never been learned).

**Steps:**
1. Navigate to the item (via content browser or any path)
2. Attempt to mark Chazara 1 complete for this item

**Expected:**
- The system BLOCKS the attempt
- Chazara 1 is either not selectable (grayed out / hidden) or selecting it shows an error
- The error or UI clearly indicates that Learn must be completed first
- No completion record is created

**Pass/Fail:** [ ]

---

#### LEARN-16 | P0 | Cannot complete Chazara 2 before Chazara 1

**Preconditions:** An item has Learn stage completed but Chazara 1 is NOT completed.

**Steps:**
1. Navigate to the item
2. Attempt to mark Chazara 2 complete

**Expected:**
- The system BLOCKS the attempt
- Chazara 2 is either not selectable or selecting it shows an error
- The message indicates Chazara 1 must be completed first
- No completion record is created

**Pass/Fail:** [ ]

---

#### LEARN-17 | P0 | Sequential stage unlock: Learn enables Chazara 1 enables Chazara 2

**Preconditions:** An item with no completions.

**Steps:**
1. View the item -- verify only Learn is available
2. Complete Learn stage
3. View the item again -- verify Chazara 1 is now available but Chazara 2 is not
4. Complete Chazara 1 stage
5. View the item again -- verify Chazara 2 is now available
6. Complete Chazara 2 stage

**Expected:**
- At each step, only the correct next stage is unlocked
- Each completion unlocks exactly one additional stage
- After all three stages, the item shows as fully reviewed
- Review count reflects all completions (learned 1x, reviewed 2x)

**Pass/Fail:** [ ]

---

### Immutability (P0 -- Data Integrity)

---

#### LEARN-18 | P0 | No undo/unmark option exists anywhere for completed stages

**Preconditions:** An item has at least one stage completed.

**Steps:**
1. Navigate to the completed item in the daily task list
2. Look for any undo, unmark, delete, or remove completion option
3. Long-press the item
4. Check any context menus, overflow menus, or swipe gestures
5. Navigate to the item in the content browser and repeat
6. Check completion history for any delete or undo option

**Expected:**
- There is NO way to undo or unmark a completion anywhere in the app
- No swipe-to-delete, no context menu option, no edit button
- The completion is permanent and visible as such

**Pass/Fail:** [ ]

---

#### LEARN-19 | P0 | Completion persists across navigation

**Preconditions:** Just completed a stage for an item.

**Steps:**
1. Navigate away from the current screen (go to settings, another curriculum, etc.)
2. Navigate back to the item
3. Verify the completion status

**Expected:**
- The completion is still recorded
- The stage still shows as complete
- Points are still reflected in the total

**Pass/Fail:** [ ]

---

#### LEARN-20 | P0 | Completion persists across app restart

**Preconditions:** At least one completion exists. Note the item, stage, and point total.

**Steps:**
1. Force-close the app completely (remove from recents)
2. Reopen the app
3. Navigate to the completed item
4. Check completion status
5. Check point total

**Expected:**
- The completion is still recorded
- The stage still shows as complete
- Points total is unchanged
- Bookmark position is unchanged

**Pass/Fail:** [ ]

---

### Duplicate Prevention -- FR11 (P0 -- Data Integrity)

---

#### LEARN-21 | P0 | Same item+stage cannot be completed in two tracks

**Preconditions:** Personal and School tracks are both active. An item's Learn stage has been completed under the Personal track.

**Steps:**
1. Navigate to the item that was completed under Personal track
2. Attempt to complete the same item's Learn stage under the School track

**Expected:**
- The system BLOCKS the attempt
- An explanation message appears stating the item+stage is already completed in another track
- No duplicate completion record is created
- The existing Personal track completion is unaffected

**Pass/Fail:** [ ]

---

#### LEARN-22 | P0 | Same item, different stage, different track -- ALLOWED

**Preconditions:** An item's Learn stage is completed under Personal track. Chazara 1 has not been completed yet.

**Steps:**
1. Navigate to the item
2. Select Chazara 1 stage
3. If track picker appears, select School track
4. Confirm completion

**Expected:**
- The completion IS ALLOWED -- this is a different stage, so no conflict
- Chazara 1 is recorded under the School track
- The item now shows Learn (Personal) and Chazara 1 (School)
- Points are awarded

**Pass/Fail:** [ ]

---

#### LEARN-23 | P0 | Block message explains why the duplicate is prevented

**Preconditions:** Same as LEARN-21.

**Steps:**
1. Trigger the duplicate block (repeat LEARN-21 steps)
2. Read the error/block message carefully

**Expected:**
- The message clearly explains:
  - WHAT is blocked (this specific item's stage)
  - WHY it is blocked (already completed in another track)
  - WHICH track already has the completion (e.g., "Already completed under Personal track")
- The message is user-friendly, not a raw technical error

**Pass/Fail:** [ ]

---

### Bookmark Behavior (P0)

---

#### LEARN-24 | P0 | Initial bookmark is at first item in curriculum

**Preconditions:** Fresh curriculum activation with no completions. Default learning order.

**Steps:**
1. Activate a curriculum (or use a freshly activated one)
2. Check the bookmark position

**Expected:**
- Bookmark points to the very first item in the curriculum's learning order
- For Mishnayos with default order, this would be the first mishna of the first masechta in Seder Zeraim

**Pass/Fail:** [ ]

---

#### LEARN-25 | P0 | Learn completion advances bookmark to next item

**Preconditions:** Bookmark is at a known item. The item has not been completed.

**Steps:**
1. Note the bookmark position (item N)
2. Complete Learn stage for item N via the scheduled task list
3. Check the bookmark position

**Expected:**
- Bookmark now points to item N+1 in the learning order
- The advancement happened as part of the same transaction as the completion

**Pass/Fail:** [ ]

---

#### LEARN-26 | P0 | Out-of-order completion does not skip the bookmark

**Preconditions:** Bookmark is at item N (e.g., "Berachos 1:5"). Items N+3 and N+4 are uncompleted.

**Steps:**
1. Note the bookmark position (item N)
2. Use the content browser to complete Learn stage for item N+3 (out of order, ad-hoc)
3. Check the bookmark position

**Expected:**
- Bookmark has NOT moved -- it still points to item N
- The bookmark only advances when the item AT the bookmark position is completed via sequential learning
- Item N+3 is marked as complete, but the bookmark remains at item N

**Pass/Fail:** [ ]

---

#### LEARN-27 | P1 | Custom learning order -- bookmark follows custom order

**Preconditions:** User has set a custom learning order for the curriculum (e.g., reordered masechtos via drag-and-drop). Bookmark is at a known position in the custom order.

**Steps:**
1. Verify the custom learning order is active
2. Note the bookmark position in the custom order
3. Complete Learn stage for the item at the bookmark
4. Check the new bookmark position

**Expected:**
- Bookmark advances to the next item per the CUSTOM order, not the default order
- If the custom order is Masechta B then Masechta A, completing the last item in B moves the bookmark to the first item in A

**Pass/Fail:** [ ]

---

### Points & Feedback (P1)

---

#### LEARN-28 | P1 | Child mode -- completion shows satisfying animation and points

**Preconditions:** App is in child mode. A pending item is available.

**Steps:**
1. Complete a Learn stage from the daily task list
2. Observe the completion feedback

**Expected (FR110, FR111):**
- A satisfying, celebratory completion animation plays (not just a checkmark)
- Points popup appears showing points earned (e.g., "+10 points")
- The animation is engaging but not so long that it slows down rapid completion of multiple items
- Sound or haptic feedback may accompany the animation (if implemented)

**Pass/Fail:** [ ]

---

#### LEARN-29 | P1 | Adult mode -- completion shows subtle/minimal feedback

**Preconditions:** App is in adult mode. A pending item is available.

**Steps:**
1. Complete a Learn stage from the daily task list
2. Observe the completion feedback

**Expected (FR111):**
- Feedback is subtle and minimal -- a brief checkmark, color change, or small notification
- No large celebratory animations
- Points may be shown subtly or omitted depending on adult mode configuration
- The feedback is respectful of the adult user's time and does not feel childish

**Pass/Fail:** [ ]

---

#### LEARN-30 | P1 | Progress bar fills incrementally with each completion

**Preconditions:** A curriculum with visible progress bar. Note the current fill level.

**Steps:**
1. Note the current progress bar fill level (approximate percentage)
2. Complete one item's Learn stage
3. Observe the progress bar

**Expected (FR112):**
- The progress bar visibly increments after the completion
- The increment is proportional to the item count (1 item out of 4,192 for Mishnayos is small but should still be perceptible)
- The fill animation is smooth, not an abrupt jump

**Pass/Fail:** [ ]

---

#### LEARN-31 | P1 | First completion of the day increments streak counter

**Preconditions:** The user has an existing streak (or this is day 1). No completions have been recorded today yet.

**Steps:**
1. Note the current streak count
2. Complete any item (any stage)
3. Observe the streak counter

**Expected (FR113):**
- The streak counter increments by 1 (e.g., from 5 to 6)
- The increment happens on the FIRST completion of the day only
- Subsequent completions on the same day do not further increment the streak

**Pass/Fail:** [ ]

---

#### LEARN-32 | P1 | Correct points awarded per stage

**Preconditions:** Know the configured point values for the curriculum's stages. Default: Learn = 10, Chazara 1 = 5, Chazara 2 = 3.

**Steps:**
1. Note the current point total
2. Complete a Learn stage -- verify +10 points
3. Note the new total
4. Complete a Chazara 1 stage -- verify +5 points
5. Note the new total
6. Complete a Chazara 2 stage -- verify +3 points
7. Verify the running total matches: original + 10 + 5 + 3 = original + 18

**Expected:**
- Each stage awards exactly the configured number of points
- The running total is mathematically correct
- Points appear in the points popup AND in the total on the dashboard

**Pass/Fail:** [ ]

---

### Review Count (P1)

---

#### LEARN-33 | P1 | Review count after completing all stages

**Preconditions:** An item has no completions.

**Steps:**
1. Complete Learn stage for the item
2. Check the item's review count
3. Complete Chazara 1 for the item
4. Check the review count again
5. Complete Chazara 2 for the item
6. Check the review count again

**Expected (FR15b):**
- After Learn: "learned 1x, reviewed 0x" (or "learned 1x")
- After Chazara 1: "learned 1x, reviewed 1x"
- After Chazara 2: "learned 1x, reviewed 2x"
- The count is visible on the item's detail view and/or completion history

**Pass/Fail:** [ ]

---

#### LEARN-34 | P1 | Review count accumulates across multiple review cycles

**Preconditions:** An item has already been through one full cycle (Learn + Chazara 1 + Chazara 2). The item appears again in a subsequent review cycle (if configured for additional rounds).

**Steps:**
1. Check the item's current review count (should be "learned 1x, reviewed 2x" from the first cycle)
2. Complete another review cycle (Chazara stages) if the scheduler presents the item again
3. Check the review count

**Expected (FR15b):**
- The count accumulates: each additional review adds to the total
- E.g., after two full cycles: "learned 1x, reviewed 4x" (or similar, depending on how additional cycles are structured)
- The count persists permanently and never resets

**Pass/Fail:** [ ]

---

### Completion History -- FR49 (P1)

---

#### LEARN-35 | P1 | View completion history with timestamps

**Preconditions:** At least 5-10 completions have been recorded across different items and stages.

**Steps:**
1. Navigate to the completion history screen (FR49)
2. Scroll through the entries

**Expected:**
- All completions are listed
- Each entry shows: item name, stage, track, timestamp
- Entries are ordered by timestamp (most recent first, or configurable)
- Timestamps are accurate (match when you actually completed them)

**Pass/Fail:** [ ]

---

#### LEARN-36 | P1 | Filter completion history by curriculum

**Preconditions:** Completions exist in at least two curricula (e.g., Mishnayos and Bavli).

**Steps:**
1. Open completion history
2. Apply the curriculum filter -- select "Mishnayos"
3. Review the filtered results
4. Switch filter to "Bavli"
5. Review the filtered results

**Expected:**
- When filtered to Mishnayos: only Mishnayos completions appear
- When filtered to Bavli: only Bavli completions appear
- No cross-contamination between curricula
- The count of filtered entries matches the actual completions in that curriculum

**Pass/Fail:** [ ]

---

#### LEARN-37 | P1 | Filter completion history by track

**Preconditions:** Completions exist under at least two tracks (e.g., Personal and School).

**Steps:**
1. Open completion history
2. Filter by "Personal" track
3. Review the results
4. Filter by "School" track
5. Review the results

**Expected:**
- Each filter shows only completions from that track
- The track label on each entry matches the filter
- Removing the filter shows all completions again

**Pass/Fail:** [ ]

---

#### LEARN-38 | P1 | Filter completion history by date range

**Preconditions:** Completions exist across multiple days.

**Steps:**
1. Open completion history
2. Set a date range filter (e.g., "today only")
3. Review the results
4. Expand the date range (e.g., "last 7 days")
5. Review the results

**Expected:**
- Only completions within the selected date range appear
- Completions outside the range are excluded
- Edge cases: completions at midnight boundaries are handled correctly
- Clearing the date filter restores all completions

**Pass/Fail:** [ ]

---

### Transaction Safety -- FR20 (P2)

---

#### LEARN-39 | P2 | Completion under stress -- all-or-nothing

**Preconditions:** A pending item is available. Device is under some performance pressure (many apps open, low battery mode, etc.).

**Steps:**
1. Note the current state: bookmark position, point total, completion count
2. Mark an item as Learn complete
3. Immediately check all three: completion recorded, bookmark advanced, points awarded

**Expected:**
- All three updates happened atomically:
  - Completion IS recorded
  - Bookmark DID advance
  - Points WERE awarded
- There is no partial state where, e.g., points were awarded but the completion was not recorded
- If the transaction failed for any reason, NONE of the three updates should have happened

**Pass/Fail:** [ ]

---

#### LEARN-40 | P2 | Kill app immediately after completion -- state is consistent

**Preconditions:** A pending item is available. Note the pre-completion state.

**Steps:**
1. Mark an item as Learn complete
2. As soon as the completion animation begins, force-kill the app (swipe from recents and tap "close" or use the system force-stop)
3. Reopen the app
4. Check the state: was the completion recorded? Did the bookmark advance? Were points awarded?

**Expected:**
- One of two outcomes, both acceptable:
  - **Transaction committed:** All three updates are present (completion, bookmark, points). The app resumes in a fully consistent state.
  - **Transaction rolled back:** None of the three updates are present. The item is still pending, the bookmark did not move, and points were not awarded. The user can simply complete the item again.
- The UNACCEPTABLE outcome: partial state (e.g., completion recorded but bookmark not advanced, or points awarded but no completion record)

**Pass/Fail:** [ ]

---

### Multi-Curriculum (P1)

---

#### LEARN-41 | P1 | Independent bookmarks and progress per curriculum

**Preconditions:** At least two curricula are active (e.g., Mishnayos and Bavli). Each has some completions.

**Steps:**
1. Check the bookmark position for Mishnayos
2. Check the bookmark position for Bavli
3. Complete an item in Mishnayos
4. Verify Mishnayos bookmark advanced
5. Verify Bavli bookmark did NOT change
6. Complete an item in Bavli
7. Verify Bavli bookmark advanced
8. Verify Mishnayos bookmark did NOT change

**Expected:**
- Each curriculum maintains its own independent bookmark
- Completions in one curriculum have zero effect on another curriculum's state
- Points may be shared or separate (depending on configuration), but progress is independent

**Pass/Fail:** [ ]

---

#### LEARN-42 | P1 | Complete items in two curricula -- each has independent progress

**Preconditions:** Two curricula active with some completions in each.

**Steps:**
1. View the progress bar/percentage for Mishnayos
2. View the progress bar/percentage for Bavli
3. Complete 3 items in Mishnayos
4. Verify Mishnayos progress increased
5. Verify Bavli progress is unchanged

**Expected:**
- Progress is calculated independently per curriculum
- The progress percentage reflects items completed vs total items in that curriculum's scope
- Completing items in Mishnayos does not inflate Bavli's progress

**Pass/Fail:** [ ]

---

### Edge Cases (P2)

---

#### LEARN-43 | P2 | Complete the last item in a curriculum's scope -- siyum milestone

**Preconditions:** A curriculum (or a masechta within a curriculum) is nearly complete -- only 1-2 items remain. This may require significant setup or a small test scope.

**Steps:**
1. Complete the second-to-last item
2. Complete the very last item in the scope
3. Observe what happens

**Expected:**
- The completion is recorded normally
- A siyum or completion milestone is triggered (if implemented)
- The bookmark has no next item to advance to -- verify no crash or error
- The curriculum/masechta is marked as fully completed in the learning ledger
- Progress shows 100%

**Pass/Fail:** [ ]

---

#### LEARN-44 | P2 | Complete all items in a masechta -- masechta-level completion

**Preconditions:** All items in a single masechta have been completed through Learn stage (or all stages).

**Steps:**
1. Complete the final remaining item in the masechta
2. Check the learning ledger or curriculum progress view

**Expected:**
- The masechta is visually marked as complete (checkmark, color change, or badge)
- The learning ledger reflects masechta-level completion
- If the user has a goal tied to masechta completion, the goal is updated

**Pass/Fail:** [ ]

---

#### LEARN-45 | P2 | Offline completion syncs when connectivity returns (cloud-born)

**Preconditions:** The user is a cloud-born account (has Firestore sync enabled). The app is online and synced.

**Steps:**
1. Enable airplane mode on the device
2. Complete 3 items (Learn stage for each)
3. Verify all 3 completions are recorded locally (check completion history)
4. Disable airplane mode and wait for sync
5. Verify sync completes (check sync indicator or Firestore directly if possible)

**Expected:**
- All 3 completions are recorded locally immediately while offline
- Points and bookmark updates happen immediately (offline-first)
- When connectivity returns, the completions are pushed to Firestore (FR18)
- No data loss occurs
- No duplicate records are created during sync

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Completions |
|---|---|---|
| **Scheduler** | 06 - Scheduling & Review | Generates the daily task list that drives scheduled completions. Completion data feeds back into the scheduler's calculations for future days. |
| **Gamification** | 09 - Gamification & Rewards | Points, streaks, and mystery rewards are all triggered by completion events. |
| **Dashboard** | 08 - Dashboard & Progress | Dashboard progress bars, statistics, and at-a-glance status all derive from completion data. |
| **Sync** | 14 - Sync & Multi-Device | Completions sync to Firestore for cloud-born users. Sync uses additive merge -- completions from multiple devices are combined, never overwritten. |
| **Multi-Track** | 05 - Multi-Track Management | Track selection during completion determines which track gets credit. The no-duplicate rule (FR11) is enforced across tracks within a curriculum. |
| **Content Browser** | 07 - Content Browsing | The content browser is the entry point for ad-hoc completions. |
| **Catch-Up & Amnesty** | 15 - Catch-Up & Amnesty | When a learner falls behind, catch-up may rescope the remaining work, but existing completions are never modified (immutability). |
