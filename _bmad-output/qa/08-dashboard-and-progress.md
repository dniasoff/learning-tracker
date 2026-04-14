# Dashboard & Progress -- Manual Test Scenarios

**Document:** 08
**Feature Area:** Dashboard summary cards, pace status, projected completion, per-curriculum progress, track attribution, completion history, review counts, charts, streak calendar, learning journey, child vs adult mode
**Created:** 2026-04-13
**FRs Covered:** FR44, FR45, FR46, FR47, FR48, FR49, FR49b, FR50, FR51

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with at least **Mishnayos** activated
2. At least 10-20 completions recorded across different items and stages (use document 04 scenarios first)
3. At least one curriculum has a goal with a deadline set
4. For multi-track scenarios, activate School or Tutor tracks in addition to Personal
5. For child/adult mode comparison, have access to one account of each type (or ability to switch modes)
6. For streak scenarios, have completions on at least 3 consecutive days

---

## What & Why

### Why the Dashboard Matters

The dashboard is where the learner answers the question: "How am I doing?"
Without it, completions are just invisible ticks in a database. The dashboard
turns raw data into motivation -- showing progress bars filling up, streaks
growing, and pace staying on track. For children, the dashboard is the
primary motivational surface between completion celebrations. For adults,
it is the evidence that daily consistency is compounding into real progress.

### Dashboard Components

The dashboard has several distinct components, each serving a different need:

1. **Summary cards (FR44).** One card per active curriculum, showing at-a-glance
   status. These are the first thing the user sees. They must load instantly
   and convey the essential state: how much is done, how much remains, and
   whether you are on track.

2. **Pace status (FR47).** For curricula with deadlines, the system calculates
   whether the learner is ahead, on-pace, or behind. This drives urgency
   without panic -- "3 days ahead" is reassuring, "5 days behind" is a
   signal to catch up.

3. **Projected completion (FR48).** Based on current pace, when will the
   learner finish? This turns an abstract goal ("finish Mishnayos by Pesach")
   into a concrete projection ("at this rate, you'll finish 2 weeks early").

4. **Track attribution (FR46).** Each completion is tagged with which track
   (Personal, School, Tutor) contributed it. The dashboard shows this
   breakdown so the learner and parent can see where learning is happening.

5. **Completion history (FR49).** A log of all completions with filters by
   curriculum, track, stage, and date range. This is the audit trail that
   proves learning happened.

6. **Review counts (FR49b).** Per-item counts showing "learned 1x, reviewed
   10x". These accumulate over the app's lifetime and never reset.

7. **Charts (FR50).** Completions-over-time graphs and cumulative progress
   visualizations. These reveal trends that individual completions cannot.

8. **Streak calendar (FR51).** A calendar view highlighting days with learning
   activity. The visual pattern of filled days is a powerful motivator --
   nobody wants to break a solid streak of green squares.

### Child vs Adult Mode

The dashboard adapts to the user mode. Child mode is more visual, with
larger elements, celebration-oriented styling, and gamification prominently
displayed. Adult mode is data-dense, minimal, and respects the user's
preference for efficiency over decoration.

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (DASH-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Dashboard Summary Cards -- FR44 (P0)

---

#### DASH-01 | P0 | Dashboard shows summary card for each active curriculum

**Preconditions:** At least two curricula are activated (e.g., Mishnayos and Bavli). Some completions exist in each.

**Steps:**
1. Open the app and navigate to the dashboard
2. Observe the summary cards displayed

**Expected:**
- One summary card is visible for each active curriculum
- Each card shows the curriculum name
- Each card shows a progress indicator (bar, percentage, or count)
- Cards for curricula with no completions show 0% or empty progress
- Cards for curricula with completions show accurate progress

**Pass/Fail:** [ ]

---

#### DASH-02 | P0 | Summary card displays correct completion count and percentage

**Preconditions:** Mishnayos is activated with a known number of completions (e.g., 42 out of 4,192 items).

**Steps:**
1. Open the dashboard
2. Locate the Mishnayos summary card
3. Verify the completion count and/or percentage

**Expected:**
- The count matches the actual number of completed items (42)
- The percentage is mathematically correct (42 / 4,192 = ~1.0%)
- The total item count is accurate for the curriculum
- The numbers update immediately after new completions (no stale data)

**Pass/Fail:** [ ]

---

#### DASH-03 | P0 | Summary card updates immediately after a new completion

**Preconditions:** Dashboard is visible. A pending item is available for completion.

**Steps:**
1. Note the current progress shown on the summary card (e.g., 42 items, 1.0%)
2. Navigate to the daily task list
3. Complete one item (Learn stage)
4. Navigate back to the dashboard
5. Check the summary card

**Expected:**
- The completion count has incremented by 1 (now 43)
- The percentage has updated accordingly
- The progress bar has visibly advanced (even if the increment is small)
- No app restart or manual refresh is needed

**Pass/Fail:** [ ]

---

#### DASH-04 | P1 | Dashboard with single active curriculum shows one card

**Preconditions:** Only one curriculum is activated.

**Steps:**
1. Open the dashboard

**Expected:**
- Exactly one summary card is displayed
- The layout adapts to a single card (no awkward empty space or placeholder)
- All card details are accurate

**Pass/Fail:** [ ]

---

#### DASH-05 | P1 | Dashboard with many active curricula shows all cards

**Preconditions:** 4+ curricula are activated.

**Steps:**
1. Open the dashboard
2. Scroll if needed to see all cards

**Expected:**
- All activated curricula have a visible summary card
- Cards are scrollable if they overflow the screen
- No cards are hidden or truncated
- Each card is individually readable without overlap

**Pass/Fail:** [ ]

---

### Per-Curriculum Progress -- FR45 (P0)

---

#### DASH-06 | P0 | Per-curriculum progress shows hierarchy-level breakdown

**Preconditions:** Mishnayos is activated with completions spanning multiple sedarim/masechtos.

**Steps:**
1. From the dashboard, tap on the Mishnayos summary card (or navigate to the Mishnayos progress detail view)
2. Observe the hierarchy-level breakdown

**Expected:**
- Progress is broken down by hierarchy level (e.g., per-seder, per-masechta)
- Each seder shows its own completion percentage
- Each masechta within a seder shows its own completion percentage
- The breakdown is accurate and consistent with the summary card total

**Pass/Fail:** [ ]

---

#### DASH-07 | P0 | Hierarchy breakdown shows correct counts at each level

**Preconditions:** Known completions in a specific masechta (e.g., 15 items completed in Berachos out of its total).

**Steps:**
1. Open the per-curriculum progress view for Mishnayos
2. Navigate to Seder Zeraim > Masechta Berachos
3. Verify the completion count for Berachos

**Expected:**
- The count shows exactly 15 completed items
- The total items for Berachos is accurate
- The percentage matches (15 / total Berachos items)
- Parent levels (Seder Zeraim) aggregate correctly across all their child masechtos

**Pass/Fail:** [ ]

---

#### DASH-08 | P1 | Completed masechta shows 100% with visual indicator

**Preconditions:** All items in one masechta have been completed through at least the Learn stage (this may require bulk completion for testing).

**Steps:**
1. Open the per-curriculum progress view
2. Find the fully completed masechta

**Expected:**
- The masechta shows 100% completion
- A visual indicator distinguishes it from incomplete masechtos (checkmark, different color, badge)
- The parent seder's percentage reflects this completed masechta

**Pass/Fail:** [ ]

---

### Track Attribution -- FR46 (P1)

---

#### DASH-09 | P1 | Dashboard shows which track contributed each completion

**Preconditions:** Completions exist under multiple tracks (Personal and School) for the same curriculum.

**Steps:**
1. Open the per-curriculum progress view or completion history
2. Look for track attribution labels on completions

**Expected:**
- Each completion is labeled with its track (Personal, School, or Tutor)
- The attribution is accurate -- matches the track selected at completion time
- Track labels are visually distinct (color, icon, or label)

**Pass/Fail:** [ ]

---

#### DASH-10 | P1 | Track breakdown shows contribution per track

**Preconditions:** Same as DASH-09.

**Steps:**
1. Open the per-curriculum progress view
2. Look for a track breakdown section or toggle

**Expected:**
- The view shows how many completions came from each track
- E.g., "Personal: 30 items, School: 12 items"
- The sum of all tracks equals the total completions for the curriculum
- If only one track has been used, it shows 100% from that track

**Pass/Fail:** [ ]

---

#### DASH-11 | P1 | Track attribution persists after track removal

**Preconditions:** Completions exist under the School track. The user then removes the School track.

**Steps:**
1. Note the completion count attributed to the School track (e.g., 12 items)
2. Remove the School track via settings
3. Open the progress view or completion history
4. Check track attribution

**Expected:**
- Completions previously attributed to the School track retain their attribution
- The completions are not deleted or reassigned
- Historical records still show "School" as the track for those completions
- The total completion count is unchanged

**Pass/Fail:** [ ]

---

### Pace Status -- FR47 (P0)

---

#### DASH-12 | P0 | Pace status shows "on-pace" when meeting daily target

**Preconditions:** A curriculum has a goal with a deadline. The learner has been completing the expected daily load consistently.

**Steps:**
1. Open the dashboard
2. Locate the pace status indicator for the curriculum with a deadline

**Expected:**
- Pace status shows "on-pace" (or equivalent positive indicator)
- The indicator is green or otherwise positively styled
- The status is based on the ratio of items completed vs items needed by now to meet the deadline

**Pass/Fail:** [ ]

---

#### DASH-13 | P0 | Pace status shows "ahead" when exceeding daily target

**Preconditions:** A curriculum has a goal with a deadline. The learner has completed more than the required daily load (buffer built up).

**Steps:**
1. Complete several extra items beyond the daily recommendation
2. Open the dashboard
3. Check the pace status

**Expected:**
- Pace status shows "ahead" with the number of days ahead (e.g., "3 days ahead")
- The indicator is styled positively (green, checkmark, or similar)
- The "days ahead" count is accurate based on the surplus of completions

**Pass/Fail:** [ ]

---

#### DASH-14 | P0 | Pace status shows "behind" when under daily target

**Preconditions:** A curriculum has a goal with a deadline. The learner has missed some days or completed fewer items than required.

**Steps:**
1. Skip a day or two of learning (or simulate by having a deadline that requires more daily work than has been done)
2. Open the dashboard
3. Check the pace status

**Expected:**
- Pace status shows "behind" with the number of days behind (e.g., "5 days behind")
- The indicator is styled as a warning (yellow/orange/red, or similar)
- The "days behind" count is accurate based on the deficit

**Pass/Fail:** [ ]

---

#### DASH-15 | P1 | Pace status not shown for curricula without deadlines

**Preconditions:** A curriculum is set to no-deadline / self-paced mode (FR43).

**Steps:**
1. Open the dashboard
2. Locate the summary card for the no-deadline curriculum

**Expected:**
- No pace status (ahead/on-pace/behind) is shown for this curriculum
- The card still shows progress (items completed, percentage) but without pace pressure
- No error or "N/A" placeholder -- the pace section is simply absent or shows "self-paced"

**Pass/Fail:** [ ]

---

### Projected Completion Date -- FR48 (P1)

---

#### DASH-16 | P1 | Projected completion date displays for curricula with deadlines

**Preconditions:** A curriculum has a goal with a deadline and at least a week of completion data to establish a pace.

**Steps:**
1. Open the dashboard or per-curriculum progress view
2. Locate the projected completion date

**Expected:**
- A projected completion date is displayed (e.g., "Projected finish: 15 Nissan 5787")
- The date is based on the learner's current average daily pace
- The projection is reasonable given the remaining items and pace

**Pass/Fail:** [ ]

---

#### DASH-17 | P1 | Projected completion updates as pace changes

**Preconditions:** A curriculum has a projected completion date. The learner changes their pace significantly (e.g., doubles their daily output).

**Steps:**
1. Note the current projected completion date
2. Complete a large batch of items (significantly more than the daily average)
3. Check the projected completion date again

**Expected:**
- The projected date has moved earlier (reflecting the increased pace)
- The change is visible and proportional to the pace increase
- The projection recalculates based on the updated average pace

**Pass/Fail:** [ ]

---

#### DASH-18 | P1 | Projected completion shows "past deadline" warning

**Preconditions:** The learner is significantly behind such that the projected completion date is after the goal deadline.

**Steps:**
1. Open the dashboard
2. Check the projected completion date vs the goal deadline

**Expected:**
- The projected date is shown in a warning style (red, exclamation mark, or explicit warning text)
- The display makes it clear that the learner will miss the deadline at current pace
- The actual projected date is still shown (not just "late")

**Pass/Fail:** [ ]

---

### Completion History -- FR49 (P1)

---

#### DASH-19 | P1 | View completion history with all entries

**Preconditions:** At least 10 completions exist across different items, stages, and days.

**Steps:**
1. Navigate to the completion history screen
2. Scroll through the entries

**Expected:**
- All completions are listed
- Each entry shows: item name, stage (Learn/Chazara 1/Chazara 2), track, timestamp
- Entries are ordered by timestamp (most recent first)
- Timestamps are accurate

**Pass/Fail:** [ ]

---

#### DASH-20 | P1 | Filter completion history by curriculum

**Preconditions:** Completions exist in at least two curricula.

**Steps:**
1. Open completion history
2. Apply the curriculum filter -- select "Mishnayos"
3. Review the filtered results
4. Switch the filter to "Bavli"
5. Review the filtered results

**Expected:**
- When filtered to Mishnayos: only Mishnayos completions appear
- When filtered to Bavli: only Bavli completions appear
- Removing the filter shows all completions from all curricula
- The filtered count matches the actual completions in that curriculum

**Pass/Fail:** [ ]

---

#### DASH-21 | P1 | Filter completion history by track

**Preconditions:** Completions exist under at least two tracks.

**Steps:**
1. Open completion history
2. Filter by "Personal" track
3. Review the results
4. Filter by "School" track
5. Review the results

**Expected:**
- Each filter shows only completions from that track
- The track label on each entry matches the filter
- Removing the filter shows all completions

**Pass/Fail:** [ ]

---

#### DASH-22 | P1 | Filter completion history by date range

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
- Clearing the date filter restores all completions
- Edge case: completions near midnight boundaries are handled correctly

**Pass/Fail:** [ ]

---

#### DASH-23 | P2 | Filter completion history by stage

**Preconditions:** Completions exist for multiple stages (Learn, Chazara 1, Chazara 2).

**Steps:**
1. Open completion history
2. Filter by "Chazara 1" stage
3. Review the results

**Expected:**
- Only Chazara 1 completions appear
- Learn and Chazara 2 completions are excluded
- The stage label on each entry matches the filter

**Pass/Fail:** [ ]

---

#### DASH-24 | P2 | Combine multiple filters simultaneously

**Preconditions:** Sufficient completions across curricula, tracks, stages, and dates.

**Steps:**
1. Open completion history
2. Filter by curriculum = "Mishnayos" AND track = "Personal" AND date range = "last 7 days"
3. Review the results

**Expected:**
- Only completions matching ALL active filters appear
- Results are the intersection of all filters, not the union
- The count reflects the combined filtering
- Clearing one filter expands the results appropriately

**Pass/Fail:** [ ]

---

### Review Counts -- FR49b (P1)

---

#### DASH-25 | P1 | Per-item review count is visible and accurate

**Preconditions:** An item has been completed through multiple stages (Learn + Chazara 1 + Chazara 2).

**Steps:**
1. Navigate to the item's detail view (via content browser or completion history)
2. Look for the review count display

**Expected:**
- The review count shows "learned 1x, reviewed 2x" (for one full cycle)
- The count matches the actual number of completions in the log
- The display is clear and understandable

**Pass/Fail:** [ ]

---

#### DASH-26 | P1 | Review count accumulates across multiple cycles

**Preconditions:** An item has been through multiple review cycles (e.g., 2 full cycles of Learn + Chazara stages).

**Steps:**
1. View the item's review count
2. Verify it reflects all historical completions

**Expected:**
- The count accumulates (e.g., "learned 1x, reviewed 4x" after two full chazara cycles)
- The count never decreases
- The count persists permanently

**Pass/Fail:** [ ]

---

#### DASH-27 | P1 | Review count survives track deletion

**Preconditions:** An item has completions under the School track. The School track is then deleted.

**Steps:**
1. Note the review count for the item before track deletion
2. Delete the School track
3. Check the review count for the item

**Expected:**
- The review count is unchanged after track deletion
- Completions from the deleted track still contribute to the count
- The count is a permanent, lifetime metric that survives any configuration change

**Pass/Fail:** [ ]

---

### Charts -- FR50 (P1)

---

#### DASH-28 | P1 | Completions-over-time chart renders with data

**Preconditions:** At least 7 days of completion data exist.

**Steps:**
1. Navigate to the charts/analytics section of the dashboard
2. Locate the completions-over-time chart

**Expected:**
- A chart (bar chart, line chart, or similar) is displayed
- The x-axis represents time (days, weeks)
- The y-axis represents completion count
- Data points match actual daily completion counts
- The chart is readable and not distorted

**Pass/Fail:** [ ]

---

#### DASH-29 | P1 | Cumulative progress chart shows growth over time

**Preconditions:** At least 7 days of completion data exist.

**Steps:**
1. Locate the cumulative progress chart (if separate from completions-over-time)
2. Observe the trend

**Expected:**
- The chart shows a monotonically increasing line (cumulative completions never decrease)
- The current point on the line matches the total completion count
- The chart visually communicates progress growth

**Pass/Fail:** [ ]

---

#### DASH-30 | P2 | Chart with no data shows empty state

**Preconditions:** A newly activated curriculum with zero completions.

**Steps:**
1. Navigate to the charts section for the new curriculum

**Expected:**
- An empty state is shown (e.g., "No data yet" or an empty chart with zero values)
- No crash or error
- The empty state encourages the user to start learning

**Pass/Fail:** [ ]

---

### Streak Calendar -- FR51 (P0)

---

#### DASH-31 | P0 | Streak calendar highlights days with learning activity

**Preconditions:** Completions exist on at least 5 different days, including some consecutive days and some gaps.

**Steps:**
1. Navigate to the streak calendar view
2. Observe which days are highlighted

**Expected:**
- Days with at least one completion are highlighted (filled, colored, or marked)
- Days without completions are not highlighted
- The pattern of highlighted days accurately reflects the completion history
- The current month is displayed by default

**Pass/Fail:** [ ]

---

#### DASH-32 | P0 | Streak calendar shows current streak count

**Preconditions:** The learner has a current streak of at least 3 consecutive days.

**Steps:**
1. Open the streak calendar
2. Locate the streak counter

**Expected:**
- The current streak count is displayed prominently (e.g., "5-day streak")
- The count matches the actual number of consecutive days with completions ending today (or yesterday if today has no completions yet)
- The streak count is consistent with the highlighted days on the calendar

**Pass/Fail:** [ ]

---

#### DASH-33 | P0 | Streak breaks are visible on the calendar

**Preconditions:** The learner had a streak, then missed a day, then resumed.

**Steps:**
1. Open the streak calendar
2. Find the gap in the highlighted days

**Expected:**
- The missed day is clearly not highlighted
- The gap visually breaks the streak pattern
- The current streak count reflects only the days since the last gap
- The previous streak's highlighted days are still visible (historical data preserved)

**Pass/Fail:** [ ]

---

#### DASH-34 | P1 | Streak calendar navigates to previous months

**Preconditions:** Completions exist across at least 2 calendar months.

**Steps:**
1. Open the streak calendar (showing current month)
2. Navigate to the previous month
3. Observe the highlighted days

**Expected:**
- Previous month's data is displayed accurately
- Highlighted days match the completions from that month
- Navigation is smooth (swipe or arrows)
- Returning to the current month shows current data

**Pass/Fail:** [ ]

---

### Learning Journey / Coverage Map (P1)

---

#### DASH-35 | P1 | Coverage map shows completed vs remaining items visually

**Preconditions:** A curriculum has partial completions (some masechtos started, others untouched).

**Steps:**
1. Navigate to the learning journey or coverage map view
2. Observe the visual representation

**Expected:**
- Completed items or sections are visually distinct from remaining ones (different color, fill, or opacity)
- The map gives an at-a-glance view of where the learner has been and where they haven't
- The granularity is appropriate (masechta-level or perek-level, not individual items for large curricula)

**Pass/Fail:** [ ]

---

#### DASH-36 | P1 | Coverage map updates after new completions

**Preconditions:** Coverage map is visible. An item is about to be completed in a previously untouched section.

**Steps:**
1. Note the coverage map state
2. Complete items in a previously untouched masechta
3. Return to the coverage map

**Expected:**
- The newly touched masechta now shows as partially completed
- The visual update is accurate and immediate (no stale state)

**Pass/Fail:** [ ]

---

### Child vs Adult Mode (P1)

---

#### DASH-37 | P1 | Child mode dashboard shows gamification prominently

**Preconditions:** App is in child mode with completions and an active streak.

**Steps:**
1. Open the dashboard in child mode
2. Observe the layout and styling

**Expected:**
- Points total is prominently displayed
- Streak counter is large and celebratory
- Progress bars may have fun styling (colors, animations)
- Mystery reward progress is visible (if configured)
- The overall feel is engaging and motivating for a child

**Pass/Fail:** [ ]

---

#### DASH-38 | P1 | Adult mode dashboard shows minimal, data-focused layout

**Preconditions:** App is in adult mode with completions and an active streak.

**Steps:**
1. Open the dashboard in adult mode
2. Observe the layout and styling

**Expected:**
- Layout is clean and data-dense
- Points may be de-emphasized or hidden
- Streak is shown but without celebratory styling
- Charts and statistics are prioritized over decorative elements
- The overall feel is professional and efficient

**Pass/Fail:** [ ]

---

#### DASH-39 | P1 | Same data displays correctly in both modes

**Preconditions:** An account with completions. Ability to switch between child and adult mode.

**Steps:**
1. View the dashboard in child mode -- note the completion count, streak, progress percentage
2. Switch to adult mode (via settings)
3. View the dashboard again -- verify the same data values

**Expected:**
- All numerical values are identical between modes (same completions, same streak, same percentages)
- Only the visual presentation differs, not the underlying data
- Switching modes does not alter or lose any data

**Pass/Fail:** [ ]

---

### Dashboard Data Accuracy (P0)

---

#### DASH-40 | P0 | Dashboard data matches completion log exactly

**Preconditions:** At least 20 completions recorded. Access to completion history for manual counting.

**Steps:**
1. Open completion history and manually count completions for one curriculum
2. Open the dashboard and check the summary card for that curriculum
3. Compare the counts

**Expected:**
- The dashboard count matches the completion history count exactly
- No off-by-one errors
- No stale cache showing old data

**Pass/Fail:** [ ]

---

#### DASH-41 | P0 | Dashboard is accurate after app restart

**Preconditions:** Dashboard shows known values. Note all key metrics.

**Steps:**
1. Note: total completions, streak count, pace status, progress percentage
2. Force-close the app
3. Reopen the app
4. Navigate to the dashboard
5. Compare all metrics

**Expected:**
- All values are identical to pre-restart values
- No data loss or reset occurred
- The dashboard loads from SQLite (source of truth), not from a volatile cache

**Pass/Fail:** [ ]

---

#### DASH-42 | P0 | Dashboard is accurate after offline completions

**Preconditions:** Device is offline (airplane mode). Complete 3 items.

**Steps:**
1. Enable airplane mode
2. Complete 3 items
3. Navigate to the dashboard
4. Verify the completion count increased by 3
5. Verify the streak and pace updated correctly

**Expected:**
- Dashboard reflects all offline completions immediately
- No "pending sync" delay for local dashboard data
- All metrics are accurate based on SQLite local state

**Pass/Fail:** [ ]

---

### Edge Cases (P2)

---

#### DASH-43 | P2 | Dashboard with zero completions (fresh account)

**Preconditions:** A freshly onboarded account with curricula activated but no completions.

**Steps:**
1. Open the dashboard immediately after onboarding

**Expected:**
- Summary cards show 0% progress for all curricula
- Streak shows 0 or "no streak yet"
- Pace shows "on-pace" (no deficit yet) or neutral status
- No crashes, no "NaN", no division-by-zero errors
- The dashboard is functional and encourages the user to start

**Pass/Fail:** [ ]

---

#### DASH-44 | P2 | Dashboard handles very large completion counts

**Preconditions:** A curriculum with hundreds or thousands of completions (may require bulk completion for testing).

**Steps:**
1. Bulk-complete a large number of items (e.g., 500)
2. Open the dashboard
3. Verify the metrics

**Expected:**
- Large numbers display correctly (no overflow, no truncation)
- Progress percentage is accurate (e.g., 500/4192 = 11.9%)
- Charts handle the large data set without performance issues
- The dashboard loads within acceptable time (under 1 second)

**Pass/Fail:** [ ]

---

#### DASH-45 | P2 | Dashboard handles curriculum with all items completed

**Preconditions:** A curriculum (or a small test scope) has every item completed through all stages.

**Steps:**
1. Open the dashboard
2. Check the summary card for the fully completed curriculum

**Expected:**
- Progress shows 100%
- Pace status shows "complete" or equivalent (no longer tracking pace)
- Projected completion date is not shown or shows "completed on [date]"
- The card is styled to celebrate the achievement
- No errors from the scheduler or pace calculator

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Dashboard & Progress |
|---|---|---|
| **Learning & Completions** | 04 - Learning & Completions | Completions are the raw data that drives every dashboard metric. Completion count, stage progression, and points all feed into the dashboard. |
| **Gamification** | 09 - Gamification & Rewards | Points totals, streak counts, and mystery reward progress are displayed on the dashboard. Gamification data is tested in detail in document 09. |
| **Scheduling** | 06 - Scheduling & Review | Pace status (ahead/on-pace/behind) depends on the scheduler's target pace calculation. Projected completion date is derived from scheduler projections. |
| **Content Browsing** | 07 - Content Browsing | Per-curriculum hierarchy breakdowns in the progress view mirror the content browser's hierarchy structure. |
| **Parent Mode** | 10 - Parent Mode | Parents have their own analytics dashboard (FR64) that overlaps with but extends the learner dashboard. |
| **Tutor Mode** | 11 - Tutor Mode | Tutors view progress metrics (FR72) as read-only, using the same underlying data as the learner dashboard. |
| **Multi-Track** | 05 - Multi-Track Management | Track attribution on the dashboard depends on completions being correctly tagged with tracks. |
| **Catch-Up & Amnesty** | 17 - Catch-Up & Amnesty | Pace status changes after catch-up rescoping. The dashboard must reflect the new scope and recalculated pace. |
