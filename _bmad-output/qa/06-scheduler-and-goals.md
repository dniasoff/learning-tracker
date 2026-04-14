# Smart Scheduler & Goals -- Manual Test Scenarios

**Document:** 06
**Feature Area:** Smart scheduling, goal management, pace tracking, chazara scheduling, study days, daily load cap
**Created:** 2026-04-13
**FRs Covered:** FR31, FR32, FR33, FR34, FR35, FR36, FR37, FR38, FR39, FR40, FR41, FR42, FR43, FR43b, FR47, FR48

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with at least **one curriculum** activated (Mishnayos recommended)
2. Personal track is active with a goal set (deadline or pace)
3. Content has been imported (Sefaria seed data is available)
4. At least one curriculum has configured stages (Learn + Chazara 1 + Chazara 2 at minimum)
5. For cross-curriculum scenarios (SCHED-34 through SCHED-36), activate a second curriculum

---

## What & Why

### The Scheduler Is the Product

The smart scheduler is the app's #1 value proposition. It answers the question
every Torah learner faces daily: **"What should I learn today?"** Without it,
the app is just a logbook. With it, the app becomes a personal learning coach
that balances new material against review obligations, adapts to the learner's
actual pace, and respects the rhythm of the Jewish week.

### 3-Phase Engine

The scheduler runs **for the personal track only** (FR37). School and tutor
tracks are externally paced and do not generate scheduler tasks.

1. **Data Loading.** Reads completions, stage definitions, content tree, goals,
   and study day configuration from the local database.
2. **Analysis.** Calculates pace using a 7-day rolling average, determines
   what is overdue, due today, and upcoming. Compares actual pace against
   goal pace.
3. **Task Assembly.** Produces an ordered daily task list with strict priority:
   overdue chazara > scheduled chazara > new learning.

### Goal Types

- **Deadline mode** (FR38): "Finish all Mishnayos by [date]." The scheduler
  divides remaining items by remaining days to calculate daily load. Supports
  both Gregorian and Hebrew calendar dates (FR39) via kosher_dart.
- **Pace mode** (FR38): "2 mishnayos per day" or "5 amudim per week." The
  app follows the specified pace and calculates a projected completion date
  (FR48).
- **No-goal mode** (FR43): Chazara-only. No new learning is pushed. The
  scheduler generates review tasks for already-learned items but does not
  advance the bookmark.

### Study Days (FR43b)

Configurable per curriculum. The learner designates which days of the week
allow new learning (e.g., Sunday--Thursday) and which are review-only
(e.g., Friday and Shabbos). Any combination is valid.

### Pace Tracking (FR42, FR47)

The scheduler computes a 7-day rolling average and compares it against the
goal pace. The result is displayed as "X days ahead," "on pace," or "X days
behind." When the learner falls behind, daily load increases adaptively
(FR32). When ahead, load decreases.

### Daily Load Cap (FR36)

A configurable maximum number of tasks per day. Even if more items are due,
the cap is respected and excess items roll to the next day.

### Cross-Curriculum Composition (FR35)

Tasks from all active curricula are merged into a single unified daily plan.
Each curriculum contributes independently; completing a task in one curriculum
does not affect another.

### 3 Schedule Types

Stage definitions support three scheduling strategies (story 15.5):

1. **Delay** (default): Item appears N days after previous stage completion.
   E.g., delay_days=3 means the item appears exactly 3 days later.
2. **Weekly**: Items appear on specific days of the week. E.g., all items
   completed during the week appear for review on Friday.
3. **Rolling window**: The most recent N items that completed the previous
   stage are always in active rotation. E.g., rolling_window_size=20 means
   the last 20 completed items cycle through chazara continuously.

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (SCHED-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Daily Task Generation (P0)

---

#### SCHED-01 | P0 | Active curriculum with deadline goal produces daily tasks

**Preconditions:** One curriculum (e.g., Mishnayos) is active with a deadline goal set. Personal track is active. No completions yet.

**Steps:**
1. Open the app and navigate to the home screen / daily task list
2. Observe the task list

**Expected:**
- Daily tasks are visible on the dashboard
- Tasks include new learning items (Learn stage) for the curriculum
- The number of new learning items reflects the calculated daily load (total remaining items / days remaining)
- Each task shows the item reference (e.g., "Berachos 1:1") and stage (Learn)

**Pass/Fail:** [ ]

---

#### SCHED-02 | P0 | Daily tasks include mix of new learning and chazara

**Preconditions:** At least a few items have been learned on previous days. Chazara 1 is due for some items (delay_days elapsed). Deadline goal is active.

**Steps:**
1. Open the app on a day when both new learning and chazara are scheduled
2. Review the daily task list

**Expected:**
- Task list contains both new learning items (Learn stage) and chazara items (Chazara 1 or Chazara 2)
- Tasks are clearly labeled with their stage type
- The mix reflects the scheduler's balancing logic (FR33): chazara load does not completely crowd out new learning

**Pass/Fail:** [ ]

---

#### SCHED-03 | P0 | Task priority order is correct

**Preconditions:** Items exist in all three priority categories: overdue chazara (missed review day), scheduled chazara (due today), and new learning.

**Steps:**
1. Open the daily task list
2. Note the order of tasks from top to bottom

**Expected:**
- Overdue chazara items appear first (highest priority)
- Scheduled chazara items (due today, not overdue) appear next
- New learning items appear last (lowest priority)
- Within each priority group, items are ordered by curriculum learning order

**Pass/Fail:** [ ]

---

#### SCHED-04 | P0 | Complete all daily tasks and see confirmation

**Preconditions:** Daily task list has a manageable number of items (e.g., 3-5 total).

**Steps:**
1. Complete each task in the daily list one by one
2. After the last task is completed, observe the screen

**Expected:**
- An "all done" confirmation or completion state is shown
- No remaining tasks are listed for today
- The dashboard reflects updated progress

**Pass/Fail:** [ ]

---

### Deadline Goal (P0)

---

#### SCHED-05 | P0 | Set deadline goal with Gregorian date

**Preconditions:** Curriculum is active with no goal set (or existing goal removed). Substantial content remains (e.g., full Mishnayos: ~4,192 items).

**Steps:**
1. Navigate to goal settings for the curriculum
2. Select "Deadline" mode
3. Choose a Gregorian date (e.g., 6 months from today)
4. Save the goal

**Expected:**
- Goal is saved and displayed on the curriculum detail screen
- Daily load is calculated: total remaining items / days remaining
- The calculated daily load is shown (e.g., "23 mishnayos per day")
- Dashboard task list updates to reflect the new daily load

**Pass/Fail:** [ ]

---

#### SCHED-06 | P0 | Set deadline goal with Hebrew date

**Preconditions:** Same as SCHED-05.

**Steps:**
1. Navigate to goal settings for the curriculum
2. Select "Deadline" mode
3. Toggle to Hebrew calendar date picker
4. Choose a Hebrew date (e.g., Rosh Hashana of the coming year)
5. Save the goal

**Expected:**
- Hebrew date is accepted and stored correctly
- The corresponding Gregorian date is displayed alongside (or the Hebrew date is shown natively)
- Daily load calculation uses the correct number of days remaining based on the Hebrew date conversion (kosher_dart)
- Calculated daily load matches manual verification (total remaining / days to Hebrew date)

**Pass/Fail:** [ ]

---

#### SCHED-07 | P0 | Tight deadline shows high daily load with warning

**Preconditions:** Curriculum has many remaining items (e.g., 1,000+). No prior completions.

**Steps:**
1. Navigate to goal settings
2. Set a deadline 7 days from today
3. Save the goal

**Expected:**
- Daily load is calculated as a large number (e.g., 1000 items / 7 days = ~143 per day)
- A warning or indicator is shown that the pace is unrealistic or very demanding
- The goal is still saved (the app does not block unrealistic goals)

**Pass/Fail:** [ ]

---

#### SCHED-08 | P0 | Generous deadline shows low daily load

**Preconditions:** Curriculum has standard item count. No prior completions.

**Steps:**
1. Navigate to goal settings
2. Set a deadline 1 year from today
3. Save the goal

**Expected:**
- Daily load is calculated as a small number (e.g., 4,192 / 365 = ~11 per day, or even lower if some days are review-only)
- No warning about unrealistic pace
- Task list reflects the modest daily load

**Pass/Fail:** [ ]

---

#### SCHED-09 | P0 | Change deadline recalculates daily load immediately

**Preconditions:** SCHED-05 or SCHED-06 completed. A deadline goal is active.

**Steps:**
1. Navigate to goal settings
2. Change the deadline to a date 2 months closer
3. Save the updated goal
4. Return to the daily task list

**Expected:**
- Daily load increases (fewer days, same remaining items)
- The change is reflected immediately on the dashboard -- no app restart needed
- Task list shows the recalculated number of new learning items

**Pass/Fail:** [ ]

---

### Pace Goal (P0)

---

#### SCHED-10 | P0 | Set pace goal with daily rate

**Preconditions:** Curriculum is active with no goal set. Substantial content remains.

**Steps:**
1. Navigate to goal settings for the curriculum
2. Select "Pace" mode
3. Enter pace: 1 daf per day (or 1 mishna per day, depending on curriculum)
4. Save the goal

**Expected:**
- Goal is saved and displayed
- Projected completion date is calculated and shown (total remaining / daily pace)
- Daily task list shows exactly 1 new learning item (plus any due chazara)

**Pass/Fail:** [ ]

---

#### SCHED-11 | P0 | Set pace goal with weekly rate

**Preconditions:** Same as SCHED-10.

**Steps:**
1. Navigate to goal settings
2. Select "Pace" mode
3. Enter pace: 5 mishnayos per week
4. Save the goal

**Expected:**
- Goal is saved with weekly pace
- Projected completion date is calculated using the weekly rate
- Daily task list distributes the weekly pace across study days (e.g., 1/day on 5 study days)

**Pass/Fail:** [ ]

---

#### SCHED-12 | P0 | Change pace value updates projected completion date

**Preconditions:** SCHED-10 or SCHED-11 completed. A pace goal is active.

**Steps:**
1. Navigate to goal settings
2. Change the pace from 1/day to 3/day
3. Save the updated goal

**Expected:**
- Projected completion date moves significantly earlier (roughly 3x sooner)
- Daily task list updates to show 3 new learning items instead of 1
- The change takes effect immediately

**Pass/Fail:** [ ]

---

### No-Goal Mode (P1)

---

#### SCHED-13 | P1 | Remove goal enters chazara-only mode

**Preconditions:** A curriculum has an active goal and some items already learned (with chazara due).

**Steps:**
1. Navigate to goal settings
2. Remove or skip the goal (select "No goal" option)
3. Save
4. Return to the daily task list

**Expected:**
- No new learning items appear in the daily task list for this curriculum
- Chazara items for previously learned items still appear on schedule
- Bookmark does not advance
- The curriculum is still listed on the dashboard with its existing progress

**Pass/Fail:** [ ]

---

#### SCHED-14 | P1 | Switch from deadline goal to no-goal mode

**Preconditions:** Deadline goal is active. Multiple items have been learned. Chazara is due for some items.

**Steps:**
1. Navigate to goal settings
2. Switch from "Deadline" to "No goal"
3. Save
4. Check the daily task list over 2-3 days

**Expected:**
- New learning stops immediately -- no Learn-stage tasks appear
- Chazara tasks continue to appear on their scheduled days
- Pace tracking indicators (ahead/behind) are no longer shown (no goal to compare against)
- Previously earned progress is preserved

**Pass/Fail:** [ ]

---

### Chazara Scheduling (P0)

---

#### SCHED-15 | P0 | Chazara 1 appears after configured delay

**Preconditions:** Default stage configuration: Learn (0 days), Chazara 1 (+1 day), Chazara 2 (+7 days). An item was learned (Learn stage completed) today.

**Steps:**
1. Complete the Learn stage for an item today
2. Check the daily task list tomorrow (or set Chazara 1 delay_days to 0 for immediate testing)

**Expected:**
- The completed item appears in tomorrow's task list as a Chazara 1 task
- The item does NOT appear as Chazara 1 today (delay is +1 day)
- The Chazara 1 task is labeled with the correct stage name

**Pass/Fail:** [ ]

---

#### SCHED-16 | P0 | Chazara 2 appears after its configured delay

**Preconditions:** SCHED-15 completed. Chazara 1 has been completed for the item.

**Steps:**
1. Complete Chazara 1 for the item
2. Check the daily task list 7 days later (or adjust Chazara 2 delay_days for testing)

**Expected:**
- The item appears as a Chazara 2 task exactly 7 days after Chazara 1 completion
- It does not appear before the 7-day window
- After completing Chazara 2, the item is fully reviewed (no further stages unless additional stages are configured)

**Pass/Fail:** [ ]

---

#### SCHED-17 | P0 | Multiple items with staggered completions schedule correctly

**Preconditions:** Three items learned on three consecutive days (Day 1: item A, Day 2: item B, Day 3: item C). Default delay for Chazara 1 is +1 day.

**Steps:**
1. Learn item A on Day 1
2. Learn item B on Day 2
3. Learn item C on Day 3
4. Check task lists on Days 2, 3, and 4

**Expected:**
- Day 2: Chazara 1 for item A appears (plus new learning)
- Day 3: Chazara 1 for item B appears (plus new learning)
- Day 4: Chazara 1 for item C appears (plus new learning)
- Each item's chazara schedule is independent and based on its own completion date

**Pass/Fail:** [ ]

---

#### SCHED-18 | P0 | Overdue chazara appears at top of next day's tasks

**Preconditions:** Chazara 1 was due yesterday but was not completed (the learner missed a day or skipped the item).

**Steps:**
1. Confirm that a chazara item was due yesterday and was not completed
2. Open the daily task list today

**Expected:**
- The overdue chazara item appears at the top of the task list (highest priority)
- It is visually distinguished as overdue (e.g., different color, "overdue" label, or age indicator)
- Other scheduled tasks appear below it in normal priority order

**Pass/Fail:** [ ]

---

### 3 Schedule Types (P1)

---

#### SCHED-19 | P1 | Delay type schedules item after N days

**Preconditions:** A stage is configured with schedule_type = 'delay' and delay_days = 3. An item has completed the previous stage.

**Steps:**
1. Complete the previous stage for an item
2. Check the daily task list on days 1, 2, and 3 after completion

**Expected:**
- Days 1 and 2: The item does NOT appear for this stage
- Day 3: The item appears for this stage
- This is the default behavior and matches existing delay-based scheduling

**Pass/Fail:** [ ]

---

#### SCHED-20 | P1 | Weekly type schedules items on configured day

**Preconditions:** A stage is configured with schedule_type = 'weekly' and days_of_week includes Friday (day 5). Items were learned earlier in the current week.

**Steps:**
1. Complete the previous stage for several items on Sunday through Thursday
2. Open the daily task list on Friday

**Expected:**
- All items completed during the current week (Monday-based) appear as tasks for this stage on Friday
- delay_days is ignored for this stage
- Items are grouped/labeled appropriately

**Pass/Fail:** [ ]

---

#### SCHED-21 | P1 | Weekly type does NOT show items on non-configured days

**Preconditions:** Same stage configuration as SCHED-20 (weekly, Friday only). Items were learned earlier this week.

**Steps:**
1. Open the daily task list on Wednesday (not a configured day)

**Expected:**
- No tasks for the weekly-scheduled stage appear on Wednesday
- Other stages (delay-based, rolling) are unaffected and appear normally

**Pass/Fail:** [ ]

---

#### SCHED-22 | P1 | Rolling type keeps last N items in rotation

**Preconditions:** A stage is configured with schedule_type = 'rolling' and rolling_window_size = 20. At least 20 items have completed the previous stage.

**Steps:**
1. Open the daily task list
2. Count the number of items shown for this rolling stage

**Expected:**
- Exactly the 20 most recently completed items (from the previous stage) appear as tasks
- Items are always present regardless of date -- no delay-based due calculation
- Completing one of these items does not remove it from the window (it remains until pushed out by newer items)

**Pass/Fail:** [ ]

---

#### SCHED-23 | P1 | Rolling type drops oldest item when window exceeded

**Preconditions:** SCHED-22 state. Exactly 20 items are in the rolling window. A 21st item completes the previous stage.

**Steps:**
1. Complete the previous stage for a new (21st) item
2. Check the rolling stage task list

**Expected:**
- The 21st (newest) item is now in the rolling window
- The oldest item (the one that was first in the window) has been dropped
- The window still contains exactly 20 items

**Pass/Fail:** [ ]

---

### Pace Tracking (P0)

---

#### SCHED-24 | P0 | Completing more than target shows days ahead

**Preconditions:** Pace or deadline goal is active with a daily target of, say, 2 items per day. The learner has been completing 3 items per day for several days.

**Steps:**
1. Complete 3 items today (exceeding the target of 2)
2. Check the pace tracking indicator on the dashboard or curriculum detail

**Expected:**
- Status shows "X days ahead" (FR47)
- The number of days ahead is calculated based on cumulative excess completions
- The indicator is positive/encouraging in tone

**Pass/Fail:** [ ]

---

#### SCHED-25 | P0 | Completing exactly the target shows on pace

**Preconditions:** Goal is active. The learner has been consistently completing exactly the daily target.

**Steps:**
1. Complete exactly the target number of items for today
2. Check the pace tracking indicator

**Expected:**
- Status shows "on pace" (or equivalent phrasing)
- No ahead/behind indicator

**Pass/Fail:** [ ]

---

#### SCHED-26 | P0 | Missing a day shows days behind

**Preconditions:** Goal is active. The learner skipped yesterday entirely (no completions recorded).

**Steps:**
1. Open the app the day after a missed day
2. Check the pace tracking indicator

**Expected:**
- Status shows "1 day behind" (or more if multiple days were missed)
- The deficit is clearly communicated
- The daily task list reflects the increased load needed to catch up

**Pass/Fail:** [ ]

---

#### SCHED-27 | P0 | Falling behind increases daily load adaptively

**Preconditions:** Deadline goal is active. The learner is 3 days behind pace. Remaining items and remaining days are known.

**Steps:**
1. Check the daily task list after falling behind
2. Compare the number of new learning items to the original daily target

**Expected:**
- Daily load has increased to compensate for the deficit (FR32)
- The new daily load = remaining items / remaining days (recalculated)
- The increase is spread across remaining days, not dumped on one day

**Pass/Fail:** [ ]

---

#### SCHED-28 | P0 | Getting ahead decreases daily load

**Preconditions:** Deadline goal is active. The learner is several days ahead of pace.

**Steps:**
1. Check the daily task list after being consistently ahead
2. Compare the number of new learning items to the original daily target

**Expected:**
- Daily load has decreased (FR32) -- less pressure because the learner is ahead
- The decrease reflects the surplus: remaining items / remaining days is lower
- Chazara load is unaffected (review schedule is independent of pace)

**Pass/Fail:** [ ]

---

### Study Day Configuration (P1)

---

#### SCHED-29 | P1 | Review-only day shows only chazara

**Preconditions:** Study day configuration: Sunday-Thursday = new learning, Friday = review only. Items have been learned previously and chazara is due.

**Steps:**
1. Open the app on Friday
2. Review the daily task list

**Expected:**
- No new learning items (Learn stage) appear on Friday
- Chazara items that are due appear normally
- The day is visually indicated as a review-only day (FR43b)

**Pass/Fail:** [ ]

---

#### SCHED-30 | P1 | Off-day shows no tasks

**Preconditions:** Study day configuration includes Shabbos (Saturday) as an off-day (no new learning AND no chazara scheduled).

**Steps:**
1. Open the app on Shabbos
2. Check the daily task list

**Expected:**
- No tasks are scheduled for Shabbos
- The dashboard indicates it is an off-day
- Tasks that would have been due on Shabbos roll to the next active day

**Pass/Fail:** [ ]

---

#### SCHED-31 | P1 | Single active day concentrates all tasks

**Preconditions:** All days disabled except Sunday. A goal is active with a weekly pace target.

**Steps:**
1. Open the app on Sunday
2. Check the daily task list
3. Open the app on Monday through Shabbos

**Expected:**
- Sunday: All new learning for the week is concentrated on this day (full weekly load)
- Monday-Shabbos: No new learning tasks appear
- Chazara behavior follows the study day config (if review is allowed on other days, chazara appears; if not, chazara also concentrates on Sunday)

**Pass/Fail:** [ ]

---

### Daily Load Cap (P1)

---

#### SCHED-32 | P1 | Daily load cap limits tasks shown

**Preconditions:** Set max tasks per day to 10 (FR36). The scheduler would normally generate 15+ tasks (combination of new learning and chazara).

**Steps:**
1. Configure daily load cap to 10 in settings
2. Open the daily task list

**Expected:**
- No more than 10 tasks appear in the daily list
- Priority order is respected within the cap: overdue chazara first, then scheduled chazara, then new learning
- If the cap is reached by chazara alone, no new learning appears
- A note or indicator shows that additional tasks exist but are capped

**Pass/Fail:** [ ]

---

#### SCHED-33 | P1 | Excess items roll to next day

**Preconditions:** SCHED-32 state. 5 items were deferred due to the cap.

**Steps:**
1. Complete all 10 tasks today
2. Open the daily task list tomorrow

**Expected:**
- Tomorrow's list includes the 5 deferred items from today (in addition to any newly scheduled items)
- Deferred items retain their original priority
- The cap is applied again tomorrow -- if the total exceeds 10, items roll forward again

**Pass/Fail:** [ ]

---

### Cross-Curriculum Composition (P0)

---

#### SCHED-34 | P0 | Two curricula produce unified daily plan

**Preconditions:** Two curricula are active (e.g., Mishnayos and Gemara Bavli), each with its own goal. Personal track is active for both.

**Steps:**
1. Open the daily task list

**Expected:**
- Tasks from both curricula appear in a single unified list (FR35)
- Each task is labeled with its curriculum
- Tasks are ordered by priority (overdue chazara from either curriculum first, then scheduled chazara, then new learning)
- The daily load for each curriculum is calculated independently based on its own goal

**Pass/Fail:** [ ]

---

#### SCHED-35 | P0 | Three or more curricula are all represented

**Preconditions:** Three curricula are active with goals set for each.

**Steps:**
1. Open the daily task list
2. Verify that tasks from all three curricula are present

**Expected:**
- All three curricula contribute tasks to the daily plan
- No curriculum is omitted or crowded out
- Total task count respects the daily load cap (FR36) if configured

**Pass/Fail:** [ ]

---

#### SCHED-36 | P0 | Completing a task in one curriculum does not affect another

**Preconditions:** Two curricula are active with tasks in the daily list.

**Steps:**
1. Complete a task from Curriculum A (e.g., Mishnayos)
2. Observe the tasks for Curriculum B (e.g., Gemara Bavli)

**Expected:**
- Curriculum B's tasks are unchanged
- Curriculum B's pace tracking is unaffected
- Only Curriculum A's progress updates

**Pass/Fail:** [ ]

---

### Goal Modification (P1)

---

#### SCHED-37 | P1 | Change deadline recalculates scheduler immediately

**Preconditions:** A deadline goal is active. Some progress has been made.

**Steps:**
1. Navigate to goal settings
2. Change the deadline to a much closer date
3. Save and return to the daily task list

**Expected:**
- Daily load increases immediately to reflect the tighter deadline
- The recalculation accounts for existing progress (only remaining items are divided by remaining days)
- No app restart is needed

**Pass/Fail:** [ ]

---

#### SCHED-38 | P1 | Remove goal switches to no-goal mode

**Preconditions:** A deadline or pace goal is active.

**Steps:**
1. Navigate to goal settings
2. Remove the goal entirely
3. Save

**Expected:**
- New learning stops appearing in the daily task list
- Chazara for already-learned items continues on schedule
- Pace tracking indicators disappear (no goal to track against)
- The curriculum remains active and visible on the dashboard

**Pass/Fail:** [ ]

---

#### SCHED-39 | P1 | Add goal to previously no-goal curriculum

**Preconditions:** A curriculum is active with no goal set. Some items have been learned (via ad-hoc or bulk completion). Chazara is active.

**Steps:**
1. Navigate to goal settings for the curriculum
2. Set a deadline or pace goal
3. Save and return to the daily task list

**Expected:**
- New learning items begin appearing in the daily task list starting from the bookmark position
- The daily load is calculated correctly, accounting for already-completed items
- Chazara schedule for previously learned items is unaffected

**Pass/Fail:** [ ]

---

### Projected Completion (P1)

---

#### SCHED-40 | P1 | Projected completion date shown based on current pace

**Preconditions:** A pace or deadline goal is active. The learner has at least 7 days of completion history for a meaningful rolling average.

**Steps:**
1. Navigate to the curriculum detail or progress screen
2. Look for the projected completion date indicator

**Expected:**
- A projected completion date is displayed (FR48)
- The date is based on the 7-day rolling average pace, not the goal pace
- If actual pace differs from goal pace, the projected date differs from the goal date

**Pass/Fail:** [ ]

---

#### SCHED-41 | P1 | Pace increase moves projected date earlier

**Preconditions:** SCHED-40 completed. Note the current projected completion date.

**Steps:**
1. Increase learning pace: complete significantly more items than usual over 2-3 days
2. Check the projected completion date again

**Expected:**
- Projected completion date has moved earlier
- The 7-day rolling average reflects the increased pace
- The change is proportional to the pace increase

**Pass/Fail:** [ ]

---

#### SCHED-42 | P1 | Pace decrease moves projected date later

**Preconditions:** SCHED-40 completed. Note the current projected completion date.

**Steps:**
1. Decrease learning pace: complete fewer items than usual for 2-3 days (or skip a day)
2. Check the projected completion date again

**Expected:**
- Projected completion date has moved later
- The 7-day rolling average reflects the decreased pace
- If pace drops to zero, the projected date may show "N/A" or a very distant date

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Related Area | Document | Connection |
|---|---|---|
| Learning & Completions | [04-learning-and-completions.md](04-learning-and-completions.md) | Completions are the input data for the scheduler. Every task the scheduler generates results in a completion when the learner acts on it. |
| Dashboard | 08 (future) | Dashboard displays the unified daily task list, pace indicators, and projected dates that the scheduler computes. |
| Stage Definitions | 16 (future) | Stage configuration (delay_days, schedule_type, rolling_window_size) directly controls how the scheduler generates chazara tasks. |
| Notifications | 12 (future) | Notification system may trigger reminders based on scheduler state (overdue items, daily tasks available). |
| Auth & Sync | [02-auth-and-accounts.md](02-auth-and-accounts.md) | Goal and schedule data sync depends on auth tier. Cloud-born users sync goals across devices; local-born users store goals locally only. |
