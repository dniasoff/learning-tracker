# Onboarding Flow -- Manual Test Scenarios

**Feature area:** Onboarding (Epic 9)
**Scenario prefix:** OB
**Prerequisites:**

- Read `01-product-overview.md` for product context and the 9-curriculum reference table
- Complete all auth scenarios in `02-auth-and-accounts.md` -- onboarding begins
  immediately after account creation, so you need a working auth flow first
- Have at least two test accounts ready: one cloud-born (online signup) and one
  local-born (airplane mode signup)

**Relevant FRs:** FR75-FR81, FR106-FR109, FR110-FR113

---

## What This Tests and Why It Matters

Onboarding is the make-or-break flow. If a user finishes account creation but
gets confused, stuck, or bored during setup, they never come back. The app has
no value until the user has at least one curriculum active with a personal track
and default stages configured. Everything downstream -- the daily task list, the
scheduler, chazara timing, progress tracking, gamification -- depends on
onboarding producing a correct initial state.

### The Onboarding Flow

After account creation the user walks through these steps:

1. **Mode selection** -- Child or Adult. Determines gamification level, UI
   density, celebration style, and whether parent mode is available.
2. **Curriculum selection** -- Pick one or more of the 9 curricula (minimum 1
   required). This is the only non-skippable step beyond mode selection.
3. **Learning process wizard** -- For each selected curriculum, optionally pick
   a named program preset (e.g., Oraysa for Bavli, Daf Yomi, Mishnah Yomis).
   Skipping means default stages apply (Learn, Chazara 1 +1d, Chazara 2 +7d).
4. **Goal setup** -- Per curriculum: deadline mode (pick English or Hebrew
   calendar date, app calculates daily load) or pace mode (user sets rate like
   "1 daf per day", app calculates projected completion). Skippable.
5. **Bulk mark prior completions** -- Mark items already learned before using
   the app. Skippable.
6. **Rewards setup (child mode only)** -- Parent configures initial mystery
   reward with point threshold. Skippable.
7. **Study day configuration** -- Set which days are for new learning vs.
   review-only vs. off. Skippable (defaults apply).

Each step except curriculum selection can be skipped. The app creates a personal
track automatically for every selected curriculum and initializes default stages
(Learn, Chazara 1 +1d, Chazara 2 +7d) unless a program preset overrides them.

### The 9 Available Program Presets

| Preset | Curriculum | Stages | Tests? |
|--------|-----------|--------|--------|
| Oraysa | Bavli | Learn > Next-Day Review > Weekly Review (Fri/Shabbos) > Back-20 Review | No |
| Dirshu Kinyan Torah | Bavli | Learn > 1st Review +1d > 2nd Review +7d > 3rd Review +30d | Yes (monthly) |
| Dirshu Amud HaYomi | Bavli | Learn (half-daf) > 1st Review +1d > 2nd Review +7d > 3rd Review +30d | Yes (monthly) |
| Dirshu Kinyan Yerushalmi | Yerushalmi | Learn > 1st Review +1d > 2nd Review +7d > 3rd Review +30d | Yes (monthly) |
| Dirshu Daf HaYomi B'Halacha | Mishna Berurah | Learn > 1st Review +1d > 2nd Review +14d | Yes (bimonthly) |
| Dirshu Kinyan Chochma | Mussar | Learn > 1st Review +1d > 2nd Review +7d > 3rd Review +30d | No |
| Daf Yomi | Bavli | Learn (daily only) | No |
| Mishnah Yomis | Mishnayos | Learn (daily only) | No |
| Nach Yomi | Nach | Learn (daily only) | No |

---

## Test Scenarios

### Full Flow -- Happy Path (P0)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-01 | P0 | Cloud-born adult, complete full onboarding end-to-end | Cloud-born account freshly created (online). Auth flow completed per `02-auth-and-accounts.md`. | 1. On mode selection screen, tap **Adult**. 2. On curriculum selection, tap **Mishnayos** (amber highlight). Tap **Continue**. 3. On learning process wizard, tap **Skip** (use default stages). 4. On goal setup, select **Deadline** mode. Tap the date picker, switch to **Hebrew** tab, pick a date ~6 months out. Tap **Confirm**. 5. On bulk mark, tap **Skip**. 6. On study day config, accept defaults. Tap **Finish**. 7. Observe the dashboard. | Dashboard loads with a Mishnayos curriculum card. Daily tasks are populated by the scheduler. No gamification prompts (adult mode). Streak counter visible. No mystery reward progress bar. The daily load preview shown in step 4 matches what the scheduler now recommends. | [ ] |
| OB-02 | P0 | Cloud-born child, complete full onboarding with rewards | Cloud-born account freshly created. Parent present to help. | 1. Tap **Child** on mode selection. 2. Select **Mishnayos**. Tap **Continue**. 3. Skip learning process wizard (default stages). 4. On goal setup, select **Deadline** mode with an English (Gregorian) date ~3 months out. Confirm. 5. Skip bulk mark. 6. On rewards setup, configure a mystery reward: set a name (e.g., "Pizza night") and point threshold (e.g., 500 pts). Tap **Save**. 7. Accept default study days. Tap **Finish**. 8. Observe the dashboard. | Dashboard shows Mishnayos card with child-mode styling (larger touch targets, warmer palette). Mystery reward progress bar is visible (0/500 pts). Daily tasks populated. Gamification elements (points display, celebration-style UI) present. | [ ] |
| OB-03 | P0 | Local-born (airplane mode), complete full onboarding offline | Device in airplane mode. Local-born account created per `02-auth-and-accounts.md`. | 1. Tap **Adult** on mode selection. 2. Select **Chumash**. Tap **Continue**. 3. Skip preset. 4. Select **Pace** mode: "1 perek per day". Confirm. 5. Skip bulk mark. 6. Accept default study days. Tap **Finish**. 7. Observe dashboard. 8. Check device network traffic (Android Studio Profiler or equivalent) -- verify zero outbound network calls during entire onboarding. | Dashboard loads with Chumash card. Projected completion date calculated and displayed. All data stored in local SQLite. No network requests made. App behaves identically to cloud-born flow except sync indicator shows offline state. | [ ] |

---

### Mode Selection (P0)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-04 | P0 | Child mode selection enables gamification throughout onboarding | Fresh account, on mode selection screen. | 1. Tap **Child**. 2. Proceed through curriculum selection (pick any). 3. Observe all subsequent onboarding screens. 4. Complete onboarding. 5. Check settings for parent mode availability. | All onboarding screens after mode selection use child-mode styling: warmer colors, larger elements, encouraging language. Rewards setup step appears (would not appear in adult mode). After onboarding, settings show a "Parent Mode" option with PIN setup. | [ ] |
| OB-05 | P0 | Adult mode selection provides streamlined UI | Fresh account, on mode selection screen. | 1. Tap **Adult**. 2. Proceed through curriculum selection (pick any). 3. Observe all subsequent onboarding screens. 4. Complete onboarding. 5. Check settings. | All screens use adult-mode styling: neutral palette, standard touch targets (48dp), data-focused language. No rewards setup step appears. No mystery reward prompts anywhere. Settings do not show "Parent Mode" option. | [ ] |

---

### Curriculum Selection (P0)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-06 | P0 | Single curriculum selection succeeds | On curriculum selection screen. | 1. Tap **Mishnayos** (it highlights/selects). 2. Tap **Continue**. | Proceeds to next onboarding step. Mishnayos is the only selected curriculum carried forward. | [ ] |
| OB-07 | P0 | Multiple curricula selection -- both appear on dashboard | On curriculum selection screen. | 1. Tap **Mishnayos** (highlights). 2. Tap **Talmud Bavli** (highlights). 3. Tap **Continue**. 4. Complete remaining onboarding for both curricula (skip optional steps). 5. Observe dashboard. | Dashboard shows two curriculum cards: Mishnayos (amber) and Bavli (blue). Each has its own personal track, default stages, and daily tasks. Cross-curriculum daily task list interleaves items from both. | [ ] |
| OB-08 | P0 | Zero curricula selected -- blocked from proceeding | On curriculum selection screen. No curricula tapped. | 1. Tap **Continue** without selecting any curriculum. | App prevents proceeding. An inline error or prompt appears: something like "Select at least one curriculum to continue." The Continue button is either disabled or shows validation feedback. User remains on the curriculum selection screen. | [ ] |
| OB-09 | P0 | All 9 curricula listed with correct names | On curriculum selection screen. | 1. Scroll through the full curriculum list. 2. Verify each entry shows both Hebrew and English names. | All 9 curricula are listed: Mishnayos / משניות, Talmud Bavli / תלמוד בבלי, Talmud Yerushalmi / תלמוד ירושלמי, Mishna Berurah / משנה ברורה, Chumash / חומש, Torah / תורה, Tanach / תנ"ך, Nach / נ"ך, Mussar / מוסר. Hebrew text renders correctly (RTL, Noto Sans Hebrew). No truncation or layout overflow. | [ ] |

---

### Learning Process Wizard (P1)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-10 | P1 | Named program preset auto-configures stages | Curriculum selection completed with **Bavli** selected. On learning process wizard screen for Bavli. | 1. The wizard shows available presets for Bavli: Oraysa, Dirshu Kinyan Torah, Dirshu Amud HaYomi, Daf Yomi. 2. Tap **Oraysa**. 3. Review the stages preview (should show: Learn, Next-Day Review, Weekly Review Fri/Shabbos, Back-20 Review). 4. Confirm selection. 5. Complete onboarding. 6. Navigate to the curriculum's stage configuration in settings. | Stages for Bavli are: (1) Learn -- daily, (2) Next-Day Review -- delay 1 day, (3) Weekly Review -- Fri/Shabbos, (4) Back-20 Review -- rolling window of 20. These replace the default 3-stage configuration. Stage names match the preset definition. | [ ] |
| OB-11 | P1 | Skip preset applies default stages | Curriculum selection completed with **Mishnayos** selected. On learning process wizard. | 1. Tap **Skip** or **Custom** (no preset). 2. Complete onboarding. 3. Navigate to stage configuration in settings. | Default 3 stages configured: (1) Learn, (2) Chazara 1 with +1 day delay, (3) Chazara 2 with +7 day delay. No `profile_programs` entry exists for this curriculum (verified in settings or by absence of program badge). | [ ] |
| OB-12 | P1 | Calendar-based program (Daf Yomi) enrolls correctly | Bavli selected. On learning process wizard. | 1. Tap **Daf Yomi**. 2. Observe any "where the program is today" indicator (e.g., "Daf Yomi is currently on Masechta X, Daf Y"). 3. Confirm selection. 4. Complete onboarding. 5. Check dashboard daily tasks. | Daf Yomi program enrolled. Dashboard shows today's daf as the daily task (matching the global Daf Yomi calendar cycle position). Only 1 stage exists (Learn -- daily). No chazara stages configured. The app computed the current daf locally from bundled calendar cycle data. | [ ] |

---

### Goal Setup (P0)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-13 | P0 | Deadline mode with English (Gregorian) date | On goal setup screen for a selected curriculum (e.g., Mishnayos). | 1. Tap **Deadline** mode. 2. Tap the date picker. 3. Ensure the **Gregorian** tab is active. 4. Select a date approximately 6 months from today. 5. Tap **Confirm**. 6. Observe the daily load preview. | The app calculates the number of remaining items in the curriculum, divides by the number of study days until the deadline, and displays a meaningful preview. Example: "3 mishnayos per day to finish by September 15, 2026." The Hebrew date equivalent is also shown (e.g., "1 Tishrei 5787"). Calculation accounts for configured study days (default: all days). | [ ] |
| OB-14 | P0 | Deadline mode with Hebrew calendar date | On goal setup screen. | 1. Tap **Deadline** mode. 2. Tap the date picker. 3. Switch to the **Hebrew** tab. 4. Select a Hebrew date (e.g., Erev Pesach, 14 Nissan). 5. Observe both dates displayed (Hebrew primary, Gregorian secondary). 6. Tap **Confirm**. | The Hebrew date is stored as the goal deadline. The Gregorian equivalent is shown below it for reference. Both dates are synchronized (changing one updates the other via `kosher_dart`). Daily load preview recalculates based on the selected date. Common presets (e.g., "Next Pesach", "Bar Mitzvah date") are available as shortcuts if implemented. | [ ] |
| OB-15 | P0 | Pace mode with projected completion | On goal setup screen. | 1. Tap **Pace** mode. 2. Enter a pace value: e.g., "1 daf per day" or "5 mishnayos per day". 3. Tap **Confirm**. 4. Observe the projected completion preview. | The app calculates the projected completion date from total remaining items divided by the specified pace. Preview shows: "At 5 mishnayos per day, projected completion: [Hebrew date] / [Gregorian date]." The scheduler will follow this user-specified pace exactly. | [ ] |
| OB-16 | P0 | Skip goal setup -- no-deadline mode | On goal setup screen. | 1. Tap **Skip**. 2. Complete remaining onboarding steps. 3. Check dashboard for the curriculum. | No deadline or pace goal is set. The curriculum card on the dashboard does not show a pace indicator or projected completion date. The scheduler still generates daily tasks (chazara recommendations based on completed items, sequential new learning). No "on-track" / "behind" indicators appear. | [ ] |
| OB-17 | P0 | Goal preview shows meaningful human-scale information | On goal setup screen. Set a deadline ~1 year from now for Mishnayos (~4,192 items). | 1. Select **Deadline** mode. 2. Pick a date ~1 year out. 3. Read the preview text carefully. | Preview uses human-scale framing, NOT raw totals. Correct: "~11 mishnayos per day to finish by [date]." Incorrect: "4,192 items remaining, 365 days." The preview should feel achievable and clear, not overwhelming. Units match the curriculum's leaf item name (mishnayos, dapim, pesukim, simanim, etc.). | [ ] |

---

### Bulk Mark Prior Completions (P1)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-18 | P1 | Bulk mark creates completion records | On bulk mark screen for a curriculum (e.g., Mishnayos). | 1. Select the stage: **Learned** (first stage). 2. The hierarchy browser appears (Seder > Masechta > Perek > Mishna). 3. Drill down to a specific perek. 4. Tap individual mishnayos to select them (checkmarks appear, count badge updates: "3 selected"). 5. Tap **"Mark 3 items complete"** button. 6. Confirm. 7. After onboarding, browse to the marked items in content view. | All 3 items show as completed for the Learn stage. Completion timestamps are recorded. The bookmark advances past the marked items (or to the next unmarked item). Progress bar reflects the marked completions. | [ ] |
| OB-19 | P1 | Large batch bulk mark with progress indicator | On bulk mark screen. | 1. Select stage: **Learned**. 2. Select a large batch: tap an entire masechta or multiple prakim (50+ items). Use "select all in perek" if available. 3. Tap **"Mark X items complete"**. 4. Observe the progress indicator during the write operation. | A real progress indicator appears (e.g., "Marking 73 of 147..."), not a spinner. The UI remains responsive during the batch write. After completion, a single summary animation plays (Tier 2 celebration, not per-item). An undo snackbar appears: "Marked 147 items complete - Undo". If undo is tapped, the entire batch is reverted. | [ ] |
| OB-20 | P1 | Skip bulk mark -- clean start | On bulk mark screen. | 1. Tap **Skip**. 2. Complete onboarding. 3. Check the curriculum's progress and bookmark position. | No pre-existing completions recorded. Progress shows 0% / "0 of X". Bookmark is at the very first item in the curriculum's learning order. The first daily task is the first item in the curriculum. | [ ] |

---

### Study Day Configuration (P1)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-21 | P1 | Custom study day schedule | On study day configuration screen. | 1. Set **Sunday through Thursday** as new learning days (toggled on for new learning). 2. Set **Friday** as review/chazara only. 3. Set **Shabbos** as off (no tasks). 4. Confirm. 5. Complete onboarding. 6. Verify by checking what the scheduler generates for each day type (may need to wait for those days or check schedule preview). | On Sunday-Thursday: daily tasks include both new learning items and chazara items. On Friday: only chazara/review tasks appear, no new learning. On Shabbos: no tasks generated at all. The scheduler respects this configuration for all daily plan calculations. | [ ] |
| OB-22 | P1 | Default study days applied | On study day configuration screen. | 1. Accept defaults without changing anything. 2. Tap **Continue** or **Finish**. 3. Check the study day configuration in settings after onboarding. | Reasonable defaults are applied (all days active for both new learning and review, or a sensible preset like Sunday-Friday active, Shabbos off). The exact default should match what the product spec defines. Configuration is editable later in settings. | [ ] |

---

### Rewards Setup -- Child Mode Only (P1)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-23 | P1 | Configure initial mystery reward | Child mode selected. On rewards setup screen during onboarding. | 1. Enter a reward name (e.g., "Ice cream trip"). 2. Set the point threshold (e.g., 200 points). 3. Tap **Save** or **Add Reward**. 4. Complete onboarding. 5. Check the dashboard for the mystery reward progress bar. 6. Enter parent mode (set up PIN if prompted) and verify the reward appears in rewards management. | Mystery reward progress bar appears on the dashboard: "0 / 200 pts" with the reward name hidden from the child (mystery). In parent mode, the reward "Ice cream trip" with 200-point threshold is listed and editable. The reward is ready to be earned through learning completions. | [ ] |
| OB-24 | P1 | Skip rewards setup | Child mode selected. On rewards setup screen. | 1. Tap **Skip**. 2. Complete onboarding. 3. Observe dashboard. 4. Enter parent mode. | No mystery reward progress bar on the dashboard (or it shows an empty state: "No rewards set up yet"). Parent mode shows an option to add rewards later. Points still accumulate from completions even without a reward target. The child can still earn points; they just do not have a mystery reward to work toward yet. | [ ] |

---

### Post-Onboarding Verification (P0)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-25 | P0 | Dashboard loads with correct curriculum cards | Onboarding completed with 1+ curricula. | 1. Observe the dashboard immediately after onboarding finishes. 2. Count the curriculum cards. 3. Verify each card's color matches the curriculum identity color (Mishnayos=amber, Bavli=blue, Yerushalmi=cyan, Mishna Berurah=burgundy, Chumash=green, etc.). | One card per selected curriculum. Each card uses the correct curriculum identity color for its left border or accent. Cards show the curriculum name in Hebrew (primary) and English. Daily tasks are populated -- the scheduler has generated today's recommendations. The dashboard loads within 2 seconds (NFR1). | [ ] |
| OB-26 | P0 | Personal track exists for each curriculum | Onboarding completed with 2 curricula (e.g., Mishnayos + Bavli). | 1. Navigate to track management for Mishnayos (via settings or curriculum detail). 2. Verify a Personal track exists. 3. Navigate to track management for Bavli. 4. Verify a Personal track exists. | Each curriculum has exactly one track: Personal (mandatory, auto-created during onboarding). No School or Tutor tracks exist (those are added manually later). The personal track has a bookmark set to the first item (or past bulk-marked items if applicable). | [ ] |
| OB-27 | P0 | Default stages exist per curriculum | Onboarding completed (no preset selected -- skipped wizard). | 1. Navigate to stage configuration for a curriculum. 2. List all stages. | Three stages exist in order: (1) Learn, (2) Chazara 1 with delay of +1 day, (3) Chazara 2 with delay of +7 days. Stage order matches. Timing values are correct. If a preset WAS selected (e.g., Oraysa), the stages match that preset instead of the defaults. | [ ] |
| OB-28 | P0 | First completion after onboarding triggers correct feedback | Onboarding completed. Dashboard visible with daily tasks. | 1. Tap the first daily task card to mark it complete. 2. Observe the feedback animation. 3. Check points counter (child mode). 4. Check progress bar movement. 5. Check streak counter. | **Both modes:** Completion commits on tap (no confirmation dialog). Progress bar animates from 0% to first visible increment. Streak counter shows "1" (or increments if already started today). Undo snackbar appears briefly ("Marked complete - Undo"). **Child mode:** Celebration animation plays (card scales, curriculum color floods, confetti particles). Points popup appears (+X pts). Points counter increments. **Adult mode:** Subtle feedback (card slides out with checkmark, muted success color). Minimal or no points popup. Clean, data-focused acknowledgment. | [ ] |

---

### Interruption and Edge Cases (P2)

| ID | Priority | Title | Preconditions | Steps | Expected | Pass? |
|----|----------|-------|---------------|-------|----------|-------|
| OB-29 | P2 | Kill app mid-onboarding -- no partial state corruption | Account created. Onboarding started. Reached curriculum selection, selected Mishnayos. | 1. Force-close the app (swipe from recents or `adb shell am force-stop`). 2. Relaunch the app. 3. Observe what screen appears. 4. If onboarding resumes, verify previous selections are preserved. 5. If onboarding restarts, verify no orphaned data from the interrupted session. | **Either behavior is acceptable:** (a) Onboarding resumes from where it was interrupted, with Mishnayos still selected, OR (b) Onboarding restarts from the beginning with a clean state. **Unacceptable:** App crashes on relaunch. Dashboard appears with partial setup (e.g., curriculum selected but no track created). Database has orphaned or inconsistent records. User is stuck on a screen they cannot navigate away from. | [ ] |
| OB-30 | P2 | Back-navigate through onboarding preserves selections | On goal setup screen (partway through onboarding). Adult mode and Mishnayos already selected. | 1. Tap the system back button (or app back arrow). 2. Observe the previous screen (learning process wizard or curriculum selection). 3. Verify previous selections are still shown. 4. Tap back again to curriculum selection. 5. Verify Mishnayos is still highlighted/selected. 6. Navigate forward again through all steps. | Previous selections are preserved when navigating back. Mode selection still shows Adult. Curriculum selection still shows Mishnayos highlighted. No selections are lost. Navigating forward again does not create duplicate data. The entire back-forward journey is smooth and predictable. | [ ] |
| OB-31 | P2 | Onboarding with 5+ curricula -- performance and correctness | Fresh account, on curriculum selection screen. | 1. Select 5 curricula: Mishnayos, Bavli, Chumash, Mishna Berurah, Nach. 2. For each curriculum, skip the preset and accept defaults. 3. Skip goals, bulk mark, rewards. Accept default study days. 4. Tap **Finish**. 5. Observe dashboard load time. 6. Verify all 5 curriculum cards appear. 7. Scroll through daily tasks. | Dashboard loads within 2 seconds (NFR1) despite 5 active curricula. All 5 cards appear with correct identity colors. Each curriculum has a personal track with 3 default stages. Daily tasks are populated across all 5 curricula. Scrolling the task list is smooth (60fps, NFR5). No ANR (Application Not Responding) during the batch initialization. | [ ] |

---

## Cross-Feature References

Onboarding state feeds directly into multiple downstream features. When
investigating bugs in these areas, check whether the root cause is in the
onboarding setup:

- **Dashboard (08)** -- Curriculum cards, daily task list, streak counter, and
  reward progress all depend on onboarding having created valid tracks, stages,
  and goals.
- **Learning and Completion (04)** -- The completion flow assumes a personal
  track exists with at least one stage. If onboarding failed to create these,
  completions will error or produce unexpected behavior.
- **Scheduler (06)** -- The scheduler reads stage timing, goal deadlines, study
  day configuration, and bookmark positions -- all set during onboarding. Bad
  initial state produces bad daily plans.
- **Gamification (09)** -- Points, streaks, and mystery rewards depend on the
  user mode (child/adult) set during onboarding. If mode was not persisted
  correctly, gamification may behave inconsistently.
