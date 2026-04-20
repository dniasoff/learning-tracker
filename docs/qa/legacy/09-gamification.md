# Gamification & Rewards -- Manual Test Scenarios

**Document:** 09
**Feature Area:** Points, streaks, mystery rewards, celebrations, Shabbos/Yom Tov streak awareness
**Created:** 2026-04-13
**FRs Covered:** FR52, FR53, FR54, FR55, FR56, FR57, FR58, FR59, FR62

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with at least one curriculum activated
2. At least one completion exists (to have a baseline point total)
3. Child mode is active for mystery reward scenarios (GAM-13 through GAM-19)
4. Adult mode account available for adult reward scenarios (GAM-20, GAM-21)
5. Parent mode PIN is set up for reward catalog management scenarios
6. Device location/zmanim configured for Shabbos/Yom Tov streak scenarios

---

## What & Why

### Why Gamification Matters

The primary users of this app are children learning Torah. Gamification transforms
a potentially tedious daily obligation into something a child looks forward to.
Points, streaks, and mystery rewards provide the extrinsic motivation loop that
keeps a child engaged day after day, week after week, until the intrinsic value
of learning takes over.

For adult users, gamification is toned down or optional -- adults are
self-motivated, and excessive animations or reward mechanics would feel
patronizing. The system must serve both audiences from a single codebase.

### Points: Per-Curriculum, Configurable

Points accumulate per curriculum, not globally. A child doing Mishnayos and
Chumash earns separate point totals for each. Point values are configurable
per stage per curriculum (FR62) -- parents can increase Chazara points to
incentivize review, or reduce Learn points if the child is rushing through
material. Default values are Learn = 10, Chazara 1 = 5, Chazara 2 = 3.

### Streaks: Global, Shabbos/Yom Tov Aware

Streaks are global -- any completion in any curriculum counts toward the
streak. The streak tracks consecutive days of learning. Critically, Shabbos
and Yom Tov days do not break the streak (FR53). The app uses kosher_dart
for Hebrew calendar and zmanim calculations to determine when Shabbos/Yom Tov
starts and ends. A child who learns Sunday through Friday, rests on Shabbos,
and learns again on Sunday should see their streak continue unbroken.

### Mystery Rewards: Parent-Controlled Motivation

Mystery rewards (FR55-FR57) are a parent-controlled incentive system. Parents
define rewards (e.g., "ice cream trip", "new sefer", "extra screen time") with
point thresholds. The child sees a progress bar filling toward an unknown
reward -- the mystery element adds excitement. When the threshold is reached,
the parent reveals the reward. This gives parents direct control over the
incentive structure while keeping the child engaged.

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (GAM-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Points Accumulation -- FR52 (P0)

---

#### GAM-01 | P0 | Points awarded on Learn stage completion

**Preconditions:** A curriculum is active with default point values (Learn = 10). Note the current point total for the curriculum.

**Steps:**
1. Open the daily task list
2. Note the current point total for the curriculum
3. Complete a Learn stage for any item
4. Observe the points popup and the updated total

**Expected:**
- Points popup shows "+10" (or the configured Learn value)
- The curriculum's point total increases by exactly 10
- The point total on the dashboard reflects the new value

**Pass/Fail:** [ ]

---

#### GAM-02 | P0 | Points awarded correctly per stage

**Preconditions:** Default point values: Learn = 10, Chazara 1 = 5, Chazara 2 = 3. An item is available at each stage.

**Steps:**
1. Note the curriculum point total
2. Complete a Learn stage -- verify +10
3. Complete a Chazara 1 stage (for a previously learned item) -- verify +5
4. Complete a Chazara 2 stage (for a previously reviewed item) -- verify +3
5. Verify the total increased by exactly 18

**Expected:**
- Each stage awards exactly the configured number of points
- The running total is mathematically correct (original + 18)
- Points popup values match the stage configuration

**Pass/Fail:** [ ]

---

#### GAM-03 | P0 | Points are per-curriculum, not global

**Preconditions:** Two curricula are active (e.g., Mishnayos and Chumash). Note each curriculum's point total.

**Steps:**
1. Note the point total for Mishnayos and Chumash separately
2. Complete a Learn stage item in Mishnayos (+10)
3. Check the Mishnayos point total -- should increase by 10
4. Check the Chumash point total -- should be unchanged
5. Complete a Learn stage item in Chumash (+10)
6. Check the Chumash point total -- should increase by 10
7. Check the Mishnayos point total -- should be unchanged from step 3

**Expected:**
- Each curriculum maintains its own independent point total
- Completing items in one curriculum does not affect another curriculum's points
- Both totals are visible and clearly labeled per curriculum

**Pass/Fail:** [ ]

---

#### GAM-04 | P1 | Points persist across app restart

**Preconditions:** A curriculum has a known point total (e.g., 50 points).

**Steps:**
1. Note the exact point total
2. Force-close the app
3. Reopen the app
4. Navigate to the curriculum's point display

**Expected:**
- The point total is identical to what it was before the restart
- No points were lost or duplicated

**Pass/Fail:** [ ]

---

#### GAM-05 | P1 | Bulk completion awards points for every item

**Preconditions:** At least 5 consecutive uncompleted items available. Default Learn = 10 points.

**Steps:**
1. Note the current point total
2. Enter multi-select mode and select 5 items
3. Bulk complete all 5 as Learn stage
4. Check the point total

**Expected:**
- Point total increased by exactly 50 (5 items x 10 points)
- A summary popup or notification shows the total points earned in the bulk operation

**Pass/Fail:** [ ]

---

### Point Configuration -- FR62 (P1)

---

#### GAM-06 | P1 | Parent changes point values per stage

**Preconditions:** Parent mode is accessible. A curriculum is active with default point values.

**Steps:**
1. Enter parent mode (enter PIN)
2. Navigate to point configuration for a curriculum
3. Change Learn stage points from 10 to 15
4. Change Chazara 1 points from 5 to 8
5. Save the configuration
6. Exit parent mode
7. Complete a Learn stage -- observe points awarded
8. Complete a Chazara 1 stage -- observe points awarded

**Expected:**
- Learn stage now awards 15 points (not the previous 10)
- Chazara 1 now awards 8 points (not the previous 5)
- The change takes effect immediately for new completions
- Previously earned points are NOT retroactively recalculated

**Pass/Fail:** [ ]

---

#### GAM-07 | P1 | Point configuration is per-curriculum

**Preconditions:** Two curricula active. Parent mode accessible.

**Steps:**
1. Enter parent mode
2. Change Mishnayos Learn points to 20
3. Leave Chumash Learn points at the default (10)
4. Save and exit parent mode
5. Complete a Learn stage in Mishnayos -- observe points
6. Complete a Learn stage in Chumash -- observe points

**Expected:**
- Mishnayos awards 20 points for Learn
- Chumash awards 10 points for Learn (default, unchanged)
- Each curriculum independently maintains its own point configuration

**Pass/Fail:** [ ]

---

#### GAM-08 | P2 | Point values accept reasonable ranges

**Preconditions:** Parent mode accessible.

**Steps:**
1. Enter parent mode
2. Try setting Learn points to 0
3. Try setting Learn points to 1
4. Try setting Learn points to 100
5. Try setting Learn points to a negative number
6. Try setting Learn points to a non-integer (e.g., 5.5)

**Expected:**
- 0 is accepted (parent may want to disable points for a stage)
- 1 and 100 are accepted (reasonable range)
- Negative numbers are rejected with a validation message
- Non-integers are either rejected or rounded to the nearest integer
- The input field provides clear feedback on invalid values

**Pass/Fail:** [ ]

---

### Streaks -- FR53, FR54 (P0)

---

#### GAM-09 | P0 | First completion of the day starts or extends the streak

**Preconditions:** The user either has no streak (day 0) or an existing streak. No completions have been recorded today.

**Steps:**
1. Note the current streak count and max streak
2. Complete any item (any stage, any curriculum)
3. Observe the streak counter

**Expected:**
- Streak counter increments by 1
- If this is day 1, streak shows "1 day"
- Max streak updates if the current streak exceeds the previous max
- The increment happens on the FIRST completion only

**Pass/Fail:** [ ]

---

#### GAM-10 | P0 | Multiple completions on the same day do not increment streak further

**Preconditions:** At least one completion has already been recorded today (streak already incremented).

**Steps:**
1. Note the current streak count
2. Complete 3 more items
3. Check the streak count after each completion

**Expected:**
- The streak count remains the same as after the first completion of the day
- Additional completions do not add to the streak
- The streak represents consecutive DAYS, not consecutive completions

**Pass/Fail:** [ ]

---

#### GAM-11 | P0 | Shabbos does not break the streak

**Preconditions:** The user has an active streak (e.g., 5 days). It is currently Erev Shabbos. Device location is configured for accurate zmanim.

**Steps:**
1. Complete at least one item on Friday before Shabbos begins
2. Note the streak count (e.g., 6)
3. Do NOT use the app during Shabbos
4. After Shabbos ends (Motzaei Shabbos or Sunday), complete an item
5. Check the streak count

**Expected:**
- The streak is NOT broken -- it continues from where it was (e.g., now 7)
- Shabbos is recognized as a rest day that does not count against the streak
- The app uses kosher_dart zmanim to determine Shabbos boundaries accurately

**Pass/Fail:** [ ]

---

#### GAM-12 | P0 | Yom Tov does not break the streak

**Preconditions:** The user has an active streak. A Yom Tov is approaching (or simulate by adjusting the date). Multi-day Yom Tov preferred for testing (e.g., Sukkos -- 2+ days).

**Steps:**
1. Complete at least one item the day before Yom Tov
2. Note the streak count
3. Do NOT use the app during the entire Yom Tov period (1-3 days depending on the Yom Tov)
4. After Yom Tov ends, complete an item
5. Check the streak count

**Expected:**
- The streak is NOT broken across the entire Yom Tov period
- Multi-day Yom Tov (e.g., first days of Pesach) does not break the streak
- Chol HaMoed days between Yom Tov days are treated as regular days (streak should be maintained by learning on Chol HaMoed, or streak protection applies if they are configured as rest days)

**Pass/Fail:** [ ]

---

#### GAM-13 | P1 | Current streak and max streak are both displayed

**Preconditions:** User has a current streak and a max streak (max may be higher if a previous streak was longer).

**Steps:**
1. Navigate to the streak display (dashboard or gamification section)
2. Verify both values are shown

**Expected (FR54):**
- Current streak is displayed (e.g., "Current: 7 days")
- Max streak is displayed (e.g., "Best: 14 days")
- If current streak equals max streak, both show the same value
- The display is clear and the two values are distinguishable

**Pass/Fail:** [ ]

---

#### GAM-14 | P1 | Streak breaks after missing a non-Shabbos/Yom Tov day

**Preconditions:** User has an active streak (e.g., 5 days). It is a regular weekday (not Shabbos or Yom Tov).

**Steps:**
1. Note the current streak (e.g., 5)
2. Do NOT complete any items for the entire day (let the day pass without any completions)
3. The next day, complete an item
4. Check the streak count

**Expected:**
- The streak resets to 1 (not 6)
- The max streak retains its previous value (e.g., if max was 14, it stays 14)
- The day without completions caused the streak to break because it was not Shabbos/Yom Tov

**Pass/Fail:** [ ]

---

### Mystery Rewards -- FR55, FR56, FR57 (P0)

---

#### GAM-15 | P0 | Mystery reward progress bar shows points toward next reward

**Preconditions:** Child mode is active. At least one mystery reward has been configured by the parent with a point threshold (e.g., 100 points). Current points are below the threshold.

**Steps:**
1. Navigate to the rewards or gamification screen
2. Locate the mystery reward progress bar
3. Note the current fill level relative to the threshold

**Expected (FR55):**
- A progress bar is visible showing how close the child is to the next reward
- The bar shows current points relative to the threshold (e.g., "45/100")
- The reward itself is hidden (mystery) -- the child does not know what the reward is
- The progress bar updates in real-time as points are earned

**Pass/Fail:** [ ]

---

#### GAM-16 | P0 | Progress bar updates after earning points

**Preconditions:** Mystery reward is configured with a threshold of 100 points. Current points are at 85.

**Steps:**
1. Note the progress bar fill level (85/100)
2. Complete a Learn stage (+10 points)
3. Observe the progress bar

**Expected:**
- Progress bar updates to reflect the new total (95/100)
- The bar visibly fills further
- If an animation exists, it is smooth and satisfying

**Pass/Fail:** [ ]

---

#### GAM-17 | P0 | Notification when mystery reward threshold is reached

**Preconditions:** Mystery reward threshold is set to 100 points. Current points are at 92.

**Steps:**
1. Complete enough items to push the total past 100 points (e.g., one Learn stage = +10, total = 102)
2. Observe the notification or celebration

**Expected (FR56):**
- A notification or celebration is triggered when the threshold is reached or exceeded
- The notification clearly indicates a mystery reward has been earned
- The reward is NOT yet revealed -- only the fact that it was earned is communicated
- The progress bar shows full (or overflowing)

**Pass/Fail:** [ ]

---

#### GAM-18 | P0 | Parent reveals mystery reward when earned

**Preconditions:** A mystery reward has been earned (threshold reached). Parent mode is accessible.

**Steps:**
1. Enter parent mode (enter PIN)
2. Navigate to the earned rewards section
3. Find the earned mystery reward
4. Tap to reveal the reward to the child
5. Exit parent mode
6. As the child, observe the revealed reward

**Expected (FR57):**
- In parent mode, earned rewards are listed with a "reveal" action
- After the parent reveals the reward, the child can see what the reward is
- The reveal includes the reward description (e.g., "Ice cream trip!")
- The reward cannot be un-revealed once shown

**Pass/Fail:** [ ]

---

#### GAM-19 | P1 | Multiple mystery rewards with different thresholds

**Preconditions:** Parent has configured 3 mystery rewards with thresholds at 50, 150, and 300 points.

**Steps:**
1. Start with 0 points
2. Earn 50+ points -- observe first reward notification
3. Continue earning to 150+ points -- observe second reward notification
4. Continue earning to 300+ points -- observe third reward notification

**Expected:**
- Each reward triggers independently when its threshold is reached
- Progress bars (if shown for multiple rewards) track each reward separately
- Earning one reward does not consume or reset points -- points continue accumulating
- All three rewards can be earned and revealed independently

**Pass/Fail:** [ ]

---

### Adult Rewards -- FR58 (P1)

---

#### GAM-20 | P1 | Adult mode -- user manages own rewards

**Preconditions:** App is in adult mode. Points have been accumulated.

**Steps:**
1. Navigate to the rewards or gamification section
2. Look for reward management options
3. Add a personal reward with a point threshold (e.g., "Buy a new sefer" at 200 points)
4. Save the reward

**Expected (FR58):**
- Adult users can add, edit, and delete their own rewards
- No parent mode is needed -- adults manage rewards directly
- The reward appears with a progress bar showing points toward the threshold
- The adult can reveal/claim the reward themselves when earned

**Pass/Fail:** [ ]

---

#### GAM-21 | P1 | Adult mode -- minimal gamification UI

**Preconditions:** App is in adult mode.

**Steps:**
1. Complete a Learn stage
2. Observe the completion feedback
3. Navigate to the gamification/rewards section
4. Compare the UI to child mode (if both modes have been tested)

**Expected (FR59):**
- Completion feedback is subtle and minimal (no large celebrations)
- Points may be shown but without flashy animations
- Streak display is present but understated
- The overall tone is respectful and not childish
- Rewards section is functional but not gamified with excessive visual flair

**Pass/Fail:** [ ]

---

### Celebrations & Feedback -- FR59 (P1)

---

#### GAM-22 | P1 | Child mode -- celebratory animation on completion

**Preconditions:** App is in child mode. A pending item is available.

**Steps:**
1. Complete a Learn stage from the daily task list
2. Observe the completion animation

**Expected (FR59):**
- A satisfying, celebratory animation plays (confetti, stars, or similar)
- The animation is engaging and fun for a child
- Points popup is prominent and exciting
- The animation is not so long that it slows down rapid completions

**Pass/Fail:** [ ]

---

#### GAM-23 | P1 | Child mode -- milestone celebration at streak thresholds

**Preconditions:** Child mode. User's streak is about to reach a milestone (e.g., 7 days, 30 days, 100 days).

**Steps:**
1. Complete the first item of the day to push the streak to the milestone value
2. Observe the celebration

**Expected:**
- A special milestone celebration plays (larger animation, special message)
- The milestone is clearly announced (e.g., "7 day streak!")
- The celebration is distinct from the regular completion animation
- The milestone value is highlighted in the streak display

**Pass/Fail:** [ ]

---

#### GAM-24 | P1 | Switching from child to adult mode changes celebration style

**Preconditions:** App is currently in child mode. Completions have been tested in child mode.

**Steps:**
1. Go to settings and switch to adult mode
2. Complete a Learn stage
3. Observe the completion feedback

**Expected:**
- The celebratory child-mode animation is replaced with subtle adult-mode feedback
- Points may still be shown but without flashy effects
- The transition is immediate -- no restart required
- Switching back to child mode restores the full celebrations

**Pass/Fail:** [ ]

---

### Edge Cases (P2)

---

#### GAM-25 | P2 | Streak display after extended Yom Tov gap (3+ days)

**Preconditions:** User has a streak. A multi-day Yom Tov period is upcoming or can be simulated (e.g., Rosh Hashana + Shabbos = 3 consecutive rest days).

**Steps:**
1. Complete an item the day before Yom Tov begins
2. Note the streak count
3. Do not use the app for 3 days (the entire Yom Tov + Shabbos period)
4. After the rest period, complete an item
5. Check the streak count

**Expected:**
- The streak is NOT broken despite 3 consecutive days of inactivity
- All 3 days are recognized as Shabbos/Yom Tov rest days
- The streak continues as if the gap did not exist
- The streak display does not show any anomaly (e.g., no "3 days missed" warning)

**Pass/Fail:** [ ]

---

#### GAM-26 | P2 | Points and streak survive across app update

**Preconditions:** Known point totals and streak count. App update is available (or simulate by reinstalling).

**Steps:**
1. Note the exact point totals for each curriculum and the streak count
2. Update the app to a newer version
3. Open the app and check point totals and streak

**Expected:**
- All point totals are preserved exactly
- Streak count is preserved exactly
- Max streak is preserved
- Mystery reward progress is preserved
- No data migration issues

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Gamification |
|---|---|---|
| **Completions** | 04 - Learning & Completions | Every completion triggers point accumulation and streak evaluation. Points are awarded atomically with the completion transaction. |
| **Parent Mode** | 10 - Parent Mode | Parents configure point values (FR62) and manage the mystery reward catalog (FR61). |
| **Dashboard** | 08 - Dashboard & Progress | Dashboard displays streak counter, point totals, and reward progress. |
| **Notifications** | 12 - Notifications | Streak protection alerts (FR83) and reward earned notifications (FR84) tie into gamification. |
| **Onboarding** | 03 - Onboarding | Parents configure initial mystery rewards during child account setup (FR80). |
| **Settings** | 13 - Settings | Child/adult mode toggle changes the gamification presentation style. |
