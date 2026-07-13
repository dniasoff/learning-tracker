# Parent Mode -- Manual Test Scenarios

**Document:** 10
**Feature Area:** PIN access, reward catalog, point configuration, track management, analytics, child-only enforcement
**Created:** 2026-04-13
**FRs Covered:** FR60, FR61, FR62, FR63, FR64, FR65, FR66, FR67, FR97, FR98, FR99, FR100, FR101

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with a **child mode** account
2. At least one curriculum is active with some completions recorded
3. Parent PIN has NOT been set yet (for PIN setup scenarios PARENT-01 through PARENT-03)
4. For lockout scenarios (PARENT-10 through PARENT-12), note the configured cooldown period
5. A separate adult mode account is available for PARENT-28 through PARENT-30
6. Multiple curricula active for cross-curriculum scenarios

**Parent mode is the administrative backbone of child accounts.** It controls
the incentive system, manages tracks, and provides the analytics parents need
to stay engaged with their child's learning. Security is critical -- a child
should never be able to access parent mode, change their own reward thresholds,
or manipulate point values.

---

## What & Why

### PIN Security Model

Parent mode is protected by a 4-digit PIN. The PIN is hashed with bcrypt
(FR97) and stored in flutter_secure_storage -- never in plain SQLite, never
in SharedPreferences, and never synced to Firestore (FR99). This means:

- Each device has its own PIN. If the parent sets up a second device, they
  set a new PIN on that device independently.
- The PIN cannot be extracted from the database even if someone has file-level
  access to the device.
- There is no "forgot PIN" recovery via the server. Recovery requires
  reinstalling the app or a local reset mechanism.

The 5-attempt lockout with cooldown (FR66, FR101) prevents brute-force
attempts by the child. A 4-digit PIN has 10,000 combinations -- without
lockout, a determined child could try all of them. With lockout and cooldown,
the child gets 5 attempts before being locked out for a configurable period.

### Reward Catalog Management

Parents add, edit, and delete mystery rewards (FR61). Each reward has a
description and a point threshold. The child sees the threshold and a
progress bar but NOT the reward description until the parent reveals it.
This gives parents fine-grained control over incentives -- they can create
rewards that match their child's interests, adjust thresholds based on
difficulty, and remove rewards that are no longer relevant.

### Analytics: Staying Engaged

Parent analytics (FR64, FR65) show on-track status, completion percentages,
streak data, and recent completions. This is how parents know if the system
is working. Without analytics, parents would have no way to know if their
child is actually learning or just opening the app. The analytics should be
clear, actionable, and not require Torah knowledge to interpret.

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (PARENT-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### PIN Setup -- FR60, FR97 (P0)

---

#### PARENT-01 | P0 | Set up parent PIN during onboarding

**Preconditions:** Child mode account. Parent PIN has not been set yet. In onboarding flow or first-time parent mode access.

**Steps:**
1. Navigate to parent mode (settings or onboarding prompt)
2. The app prompts to create a 4-digit PIN
3. Enter a 4-digit PIN (e.g., 1234)
4. Confirm the PIN by entering it again
5. Observe the confirmation message

**Expected:**
- The PIN setup screen accepts exactly 4 digits
- A confirmation re-entry is required (enter PIN twice)
- If the confirmation matches, the PIN is saved successfully
- A success message confirms the PIN is set
- The PIN is stored using bcrypt hashing in flutter_secure_storage (FR97)

**Pass/Fail:** [ ]

---

#### PARENT-02 | P0 | PIN confirmation mismatch is rejected

**Preconditions:** PIN setup screen is displayed.

**Steps:**
1. Enter a 4-digit PIN (e.g., 1234)
2. On the confirmation screen, enter a DIFFERENT PIN (e.g., 5678)
3. Observe the result

**Expected:**
- The mismatch is detected and an error message is shown
- The error message clearly states the PINs do not match
- The user is prompted to try again
- No PIN is saved

**Pass/Fail:** [ ]

---

#### PARENT-03 | P0 | PIN only accepts 4 digits

**Preconditions:** PIN setup screen is displayed.

**Steps:**
1. Try entering fewer than 4 digits (e.g., 123) and attempt to proceed
2. Try entering more than 4 digits (e.g., 12345)
3. Try entering non-numeric characters (e.g., letters, symbols)

**Expected:**
- Fewer than 4 digits: the "next" or "confirm" button is disabled or an error is shown
- More than 4 digits: input is truncated to 4 digits or additional input is ignored
- Non-numeric input: is rejected or input field only accepts numbers
- Only exactly 4 numeric digits are accepted

**Pass/Fail:** [ ]

---

### PIN Entry & Authentication -- FR60 (P0)

---

#### PARENT-04 | P0 | Enter correct PIN to access parent mode

**Preconditions:** Parent PIN has been set (e.g., 1234).

**Steps:**
1. Navigate to parent mode access point (settings or dedicated button)
2. Enter the correct 4-digit PIN
3. Observe the transition

**Expected:**
- Parent mode opens immediately upon correct PIN entry
- The parent mode UI is clearly distinct from the child's normal view
- All parent mode features are accessible (rewards, analytics, settings)

**Pass/Fail:** [ ]

---

#### PARENT-05 | P0 | Incorrect PIN is rejected with attempt count

**Preconditions:** Parent PIN is set. 0 failed attempts so far.

**Steps:**
1. Navigate to parent mode PIN entry
2. Enter an incorrect PIN (e.g., 0000 if PIN is 1234)
3. Observe the error feedback

**Expected:**
- The PIN is rejected with a clear "incorrect PIN" message
- The remaining attempt count is shown (e.g., "4 attempts remaining")
- The PIN entry field is cleared for the next attempt
- No partial access to parent mode

**Pass/Fail:** [ ]

---

#### PARENT-06 | P0 | Failed attempt counter increments correctly

**Preconditions:** Parent PIN is set. Start with 0 failed attempts.

**Steps:**
1. Enter an incorrect PIN -- observe "4 attempts remaining"
2. Enter another incorrect PIN -- observe "3 attempts remaining"
3. Enter another incorrect PIN -- observe "2 attempts remaining"
4. Enter another incorrect PIN -- observe "1 attempt remaining"
5. Do NOT enter a 5th incorrect PIN yet (save for lockout test)

**Expected:**
- Each failed attempt decrements the remaining counter by 1
- The counter is accurate and clearly displayed
- After 4 failures, the warning should be more prominent (e.g., "1 attempt remaining -- you will be locked out")

**Pass/Fail:** [ ]

---

#### PARENT-07 | P0 | Correct PIN after failed attempts resets counter

**Preconditions:** 3 failed PIN attempts have been recorded (2 remaining).

**Steps:**
1. Enter the CORRECT PIN
2. Parent mode opens
3. Exit parent mode
4. Attempt to enter parent mode again with an incorrect PIN
5. Observe the attempt counter

**Expected:**
- Entering the correct PIN grants access normally
- The failed attempt counter resets to 0 after a successful entry
- The next incorrect attempt shows "4 attempts remaining" (full 5 attempts available again)

**Pass/Fail:** [ ]

---

### PIN Lockout -- FR66, FR101 (P0)

---

#### PARENT-08 | P0 | 5 failed attempts triggers lockout

**Preconditions:** Parent PIN is set. Start with 0 failed attempts.

**Steps:**
1. Enter incorrect PIN -- attempt 1
2. Enter incorrect PIN -- attempt 2
3. Enter incorrect PIN -- attempt 3
4. Enter incorrect PIN -- attempt 4
5. Enter incorrect PIN -- attempt 5
6. Observe the lockout

**Expected (FR66, FR101):**
- After the 5th failed attempt, parent mode is locked
- A lockout message appears with the remaining cooldown time
- The PIN entry is disabled -- the user cannot attempt another PIN
- The cooldown timer counts down visibly (or at minimum, the user is told when to try again)

**Pass/Fail:** [ ]

---

#### PARENT-09 | P0 | Lockout persists across app restart

**Preconditions:** Parent mode is currently locked out (5 failed attempts, cooldown active).

**Steps:**
1. Force-close the app
2. Reopen the app
3. Attempt to access parent mode

**Expected:**
- The lockout is still active after the app restart
- The cooldown timer continues from where it was (not reset by restart)
- The user cannot bypass the lockout by restarting the app

**Pass/Fail:** [ ]

---

#### PARENT-10 | P0 | Lockout expires after cooldown period

**Preconditions:** Parent mode is locked out. Note the cooldown period.

**Steps:**
1. Wait for the full cooldown period to elapse
2. Attempt to access parent mode
3. Enter the correct PIN

**Expected:**
- After the cooldown period, the PIN entry is re-enabled
- The failed attempt counter is reset to 0 (full 5 attempts available)
- Entering the correct PIN grants access normally
- Parent mode functions are fully accessible

**Pass/Fail:** [ ]

---

#### PARENT-11 | P1 | Lockout timer displays remaining time clearly

**Preconditions:** Parent mode is locked out with an active cooldown.

**Steps:**
1. Observe the lockout screen
2. Note the time display format

**Expected:**
- The remaining cooldown time is displayed (e.g., "Try again in 15 minutes" or a countdown)
- The display updates in real-time (or at reasonable intervals)
- The message is clear and tells the parent how long to wait

**Pass/Fail:** [ ]

---

#### PARENT-12 | P1 | Second lockout after cooldown uses same cooldown duration

**Preconditions:** First lockout has expired. Parent mode is accessible again.

**Steps:**
1. After the first lockout expires, enter 5 more incorrect PINs
2. Observe the second lockout

**Expected:**
- The second lockout activates with the configured cooldown duration
- The lockout behavior is identical to the first lockout
- No permanent ban -- the parent can always eventually regain access

**Pass/Fail:** [ ]

---

### PIN Storage & Security -- FR97, FR99 (P0)

---

#### PARENT-13 | P0 | PIN is never synced to Firestore

**Preconditions:** Cloud-born account with sync enabled. Parent PIN is set.

**Steps:**
1. Set up parent PIN on Device A
2. Sign in to the same account on Device B
3. Attempt to access parent mode on Device B

**Expected (FR99):**
- Device B does NOT have the parent PIN from Device A
- Device B prompts to create a new PIN (or shows "no PIN set")
- The PIN is strictly device-local -- no sync occurred
- Checking Firestore directly (if possible) confirms no PIN data exists in cloud storage

**Pass/Fail:** [ ]

---

#### PARENT-14 | P1 | PIN change replaces the old PIN

**Preconditions:** Parent PIN is currently set (e.g., 1234). Parent mode is accessible.

**Steps:**
1. Enter parent mode with the current PIN
2. Navigate to PIN change option (in parent settings)
3. Enter the current PIN to confirm identity
4. Enter a new PIN (e.g., 5678)
5. Confirm the new PIN
6. Exit parent mode
7. Attempt to enter parent mode with the OLD PIN (1234)
8. Attempt to enter parent mode with the NEW PIN (5678)

**Expected:**
- The old PIN (1234) is rejected
- The new PIN (5678) is accepted
- The PIN change is immediate -- no restart required
- The failed attempt counter is at 0 after the change

**Pass/Fail:** [ ]

---

### Reward Catalog Management -- FR61 (P0)

---

#### PARENT-15 | P0 | Add a mystery reward with point threshold

**Preconditions:** Parent mode is active. No rewards have been configured yet.

**Steps:**
1. Navigate to the reward catalog section in parent mode
2. Tap "add reward" or equivalent
3. Enter a reward description (e.g., "Ice cream trip")
4. Enter a point threshold (e.g., 100)
5. Save the reward
6. Verify the reward appears in the catalog

**Expected (FR61):**
- The reward is saved with the description and threshold
- The reward appears in the catalog list
- The reward has a status of "not yet earned"
- From the child's view, the reward shows as a mystery with a progress bar but NO description

**Pass/Fail:** [ ]

---

#### PARENT-16 | P0 | Edit an existing reward

**Preconditions:** Parent mode is active. At least one reward exists in the catalog.

**Steps:**
1. Navigate to the reward catalog
2. Tap on an existing reward to edit it
3. Change the description (e.g., from "Ice cream trip" to "Pizza night")
4. Change the threshold (e.g., from 100 to 150)
5. Save the changes
6. Verify the updated values

**Expected:**
- The reward description updates to "Pizza night"
- The threshold updates to 150
- The progress bar (child view) reflects the new threshold
- If the child had progress toward the old threshold, the progress percentage recalculates

**Pass/Fail:** [ ]

---

#### PARENT-17 | P0 | Delete a reward

**Preconditions:** Parent mode is active. At least two rewards exist (to verify only the target is deleted).

**Steps:**
1. Navigate to the reward catalog
2. Select a reward to delete
3. Confirm the deletion (a confirmation dialog should appear)
4. Verify the reward is removed from the catalog
5. Verify the other reward(s) are unaffected

**Expected:**
- A confirmation dialog prevents accidental deletion
- After confirmation, the reward is permanently removed
- The deleted reward no longer appears in the child's view
- Remaining rewards are unaffected
- If the deleted reward was partially earned, the child's progress bar for it disappears

**Pass/Fail:** [ ]

---

#### PARENT-18 | P1 | Add multiple rewards with ascending thresholds

**Preconditions:** Parent mode is active. No rewards exist yet.

**Steps:**
1. Add reward A with threshold 50 ("Sticker pack")
2. Add reward B with threshold 150 ("New book")
3. Add reward C with threshold 500 ("Special outing")
4. Exit parent mode and view the child's reward display

**Expected:**
- All three rewards appear in the catalog
- From the child's view, progress bars show for each reward (or for the nearest unearned one)
- Each reward triggers independently when its threshold is reached
- Rewards are distinguishable (e.g., labeled as Reward 1, Reward 2, Reward 3 or shown as separate progress bars)

**Pass/Fail:** [ ]

---

#### PARENT-19 | P1 | Cannot save a reward with empty description or zero threshold

**Preconditions:** Parent mode is active. Adding a new reward.

**Steps:**
1. Try to save a reward with an empty description and a valid threshold
2. Try to save a reward with a valid description and a threshold of 0
3. Try to save a reward with both fields empty

**Expected:**
- Empty description: save is blocked with a validation message
- Zero threshold: either blocked or accepted with a warning (a 0-threshold reward would be instantly earned)
- Both empty: save is blocked
- Validation messages are clear and specific about what is missing

**Pass/Fail:** [ ]

---

### Track Management -- FR63 (P1)

---

#### PARENT-20 | P1 | Add a School track to a curriculum

**Preconditions:** Parent mode is active. A curriculum has only the Personal track active.

**Steps:**
1. Navigate to track management for the curriculum
2. Add the School track
3. Configure any required settings (e.g., school name)
4. Save
5. Exit parent mode
6. As the child, open the daily task list and complete an item
7. Observe if a track picker appears

**Expected (FR63):**
- The School track is added to the curriculum
- The child now sees a track picker when completing items (since 2 tracks are active)
- The School track appears as an option in the picker
- Existing Personal track completions are unaffected

**Pass/Fail:** [ ]

---

#### PARENT-21 | P1 | Remove a track from a curriculum

**Preconditions:** Parent mode is active. A curriculum has both Personal and School tracks active. Some completions exist under the School track.

**Steps:**
1. Navigate to track management for the curriculum
2. Remove the School track
3. Confirm the removal (a warning should appear about existing completions)
4. Save
5. Exit parent mode
6. As the child, verify the track picker no longer shows School

**Expected:**
- A warning is shown before removal, noting that completions exist under this track
- After removal, the School track is no longer available for new completions
- Existing School track completions are preserved (immutability) but the track is inactive
- If only Personal track remains, the track picker no longer appears (auto-assignment)

**Pass/Fail:** [ ]

---

#### PARENT-22 | P1 | Add a Tutor track to a curriculum

**Preconditions:** Parent mode is active. Curriculum has only the Personal track.

**Steps:**
1. Navigate to track management
2. Add the Tutor track
3. Save
4. Exit parent mode and verify the track is available

**Expected:**
- The Tutor track is added and available for completions
- Track picker shows all active tracks when completing items

**Pass/Fail:** [ ]

---

### Analytics Dashboard -- FR64, FR65 (P1)

---

#### PARENT-23 | P1 | View on-track status per curriculum

**Preconditions:** Parent mode is active. At least one curriculum has a goal with a deadline set. Some completions exist.

**Steps:**
1. Enter parent mode
2. Navigate to the analytics dashboard
3. Locate the on-track status indicator for the curriculum

**Expected (FR64):**
- On-track status is clearly displayed (e.g., "On track", "Behind", "Ahead")
- The status reflects the child's actual progress relative to the goal deadline
- Each active curriculum has its own on-track indicator
- The calculation accounts for Shabbos/Yom Tov non-learning days

**Pass/Fail:** [ ]

---

#### PARENT-24 | P1 | View completion percentage per curriculum

**Preconditions:** Parent mode is active. A curriculum has completions.

**Steps:**
1. Enter parent mode analytics
2. Locate the completion percentage for the curriculum

**Expected (FR64):**
- Completion percentage is displayed (e.g., "12% complete" or "500 of 4,192 items")
- The percentage matches the actual number of completed items vs total items in scope
- The display includes both a percentage and an absolute count

**Pass/Fail:** [ ]

---

#### PARENT-25 | P1 | View streak data in parent analytics

**Preconditions:** Parent mode is active. The child has an active streak.

**Steps:**
1. Enter parent mode analytics
2. Locate the streak information

**Expected (FR64):**
- Current streak is displayed
- Max streak is displayed
- The values match what the child sees on their dashboard

**Pass/Fail:** [ ]

---

#### PARENT-26 | P1 | View recent completions list

**Preconditions:** Parent mode is active. Multiple completions have been recorded recently.

**Steps:**
1. Enter parent mode analytics
2. Navigate to the recent completions section
3. Review the list

**Expected (FR64):**
- Recent completions are listed with item name, stage, track, and timestamp
- The list is ordered by most recent first
- The data matches the child's actual completion history
- The parent can see enough detail to verify the child's learning activity

**Pass/Fail:** [ ]

---

#### PARENT-27 | P1 | View detailed engagement metrics

**Preconditions:** Parent mode is active. The child has been using the app for several days with varied activity.

**Steps:**
1. Enter parent mode analytics
2. Navigate to detailed metrics (FR65)
3. Review engagement data

**Expected (FR65):**
- Detailed metrics are available (e.g., completions per day, average daily items, active curricula)
- Metrics provide actionable insight (parent can tell if engagement is increasing or declining)
- Data is presented clearly with charts or summaries
- Historical data spans the full usage period

**Pass/Fail:** [ ]

---

### Child-Only Enforcement -- FR67 (P0)

---

#### PARENT-28 | P0 | Parent mode is NOT available on adult accounts

**Preconditions:** App is in adult mode.

**Steps:**
1. Navigate to settings
2. Look for any parent mode entry point (button, menu item, section)
3. Search all screens for parent mode access

**Expected (FR67):**
- There is NO parent mode button, menu item, or entry point anywhere in the app
- The parent mode section is completely absent from adult accounts
- Adult users manage their own rewards directly (FR58) without needing parent mode

**Pass/Fail:** [ ]

---

#### PARENT-29 | P0 | Switching from child to adult mode removes parent mode access

**Preconditions:** App is in child mode with parent mode configured (PIN set, rewards created).

**Steps:**
1. Go to settings and switch to adult mode
2. Look for parent mode access
3. Navigate through all screens

**Expected:**
- After switching to adult mode, parent mode is no longer accessible
- The PIN, reward catalog, and parent analytics are hidden
- Switching back to child mode restores parent mode access with the existing PIN and rewards

**Pass/Fail:** [ ]

---

#### PARENT-30 | P0 | Adult account cannot access parent mode even via deep link or URL scheme

**Preconditions:** Adult mode account.

**Steps:**
1. If the app has any deep link or navigation scheme, attempt to navigate directly to a parent mode route
2. Attempt any programmatic or indirect way to reach parent mode

**Expected:**
- The app blocks access to parent mode regardless of the navigation method
- No crash or error -- the attempt is silently ignored or redirects to the main screen
- This is a security boundary: adult accounts have no parent mode code path

**Pass/Fail:** [ ]

---

### PIN Separation from Tutor PIN -- FR98 (P1)

---

#### PARENT-31 | P1 | Parent PIN and Tutor PIN are independent

**Preconditions:** Both parent PIN and tutor PIN have been set on the same device.

**Steps:**
1. Set parent PIN to 1234
2. Set tutor PIN to 5678
3. Attempt to enter parent mode with tutor PIN (5678)
4. Attempt to enter tutor mode with parent PIN (1234)

**Expected (FR98):**
- Parent mode rejects the tutor PIN (5678)
- Tutor mode rejects the parent PIN (1234)
- Each PIN only works for its intended mode
- The PINs are stored and validated independently

**Pass/Fail:** [ ]

---

#### PARENT-32 | P1 | Same PIN can be used for both parent and tutor

**Preconditions:** Setting up or changing PINs.

**Steps:**
1. Set parent PIN to 1234
2. Set tutor PIN to 1234 (same PIN)
3. Enter parent mode with 1234
4. Exit and enter tutor mode with 1234

**Expected:**
- The system allows the same PIN for both modes (no restriction against it)
- Each mode authenticates independently with its own PIN check
- Using the same PIN for both is the parent's choice (convenience vs security)

**Pass/Fail:** [ ]

---

### Parent Mode Session (P1)

---

#### PARENT-33 | P1 | Exit parent mode returns to child view

**Preconditions:** Currently in parent mode.

**Steps:**
1. Tap the "exit parent mode" button or navigate back
2. Observe the transition

**Expected:**
- Parent mode closes and the normal child view is displayed
- No parent mode features are accessible without re-entering the PIN
- The child cannot see any parent mode data that was on screen

**Pass/Fail:** [ ]

---

#### PARENT-34 | P1 | App backgrounding during parent mode requires re-authentication

**Preconditions:** Currently in parent mode.

**Steps:**
1. Press the home button to background the app
2. Wait 30 seconds (or the configured timeout)
3. Return to the app

**Expected:**
- The app requires the parent PIN to be re-entered before showing parent mode
- If the timeout has not elapsed, parent mode may resume without re-auth (implementation-dependent)
- The child cannot access parent mode by simply switching back to the app after the parent walked away

**Pass/Fail:** [ ]

---

### Edge Cases (P2)

---

#### PARENT-35 | P2 | Reward threshold lower than current points -- immediately earned

**Preconditions:** Parent mode is active. The child has 200 points in a curriculum.

**Steps:**
1. Add a new reward with a threshold of 50 points
2. Save and exit parent mode
3. Check the child's reward status

**Expected:**
- The reward is immediately marked as earned (since 200 > 50)
- A notification or indication shows the reward was earned upon creation
- The parent can reveal the reward immediately

**Pass/Fail:** [ ]

---

#### PARENT-36 | P2 | Parent analytics with no completions

**Preconditions:** Parent mode is active. A curriculum is active but has zero completions.

**Steps:**
1. Enter parent mode analytics
2. View the analytics for the curriculum with no completions

**Expected:**
- Analytics display gracefully with zero data (no crash, no blank screen)
- Shows "0% complete", "0 items completed", streak of 0
- On-track status may show "Not started" or equivalent
- The display is informative even with no data

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Parent Mode |
|---|---|---|
| **Gamification** | 09 - Gamification & Rewards | Parent mode configures the reward catalog (FR61) and point values (FR62) that drive the gamification system. |
| **Completions** | 04 - Learning & Completions | Parent analytics (FR64-65) are derived from completion data. Point values configured here determine points per completion. |
| **Multi-Track** | 05 - Multi-Track Management | Parents add/remove School and Tutor tracks (FR63) from parent mode. |
| **Tutor Mode** | 11 - Tutor Mode | Tutor PIN is stored separately from parent PIN (FR98). **Superseded 2026-07-13:** tutor access is no longer strictly read-only — the parent can grant a tutor write permissions (goals, stages, rewards, study days, points, bulk-prior completions) under the grant-based model; only live-forward completion marking is permanently blocked, and parent mode retains unrestricted write access. See [`11-tutor-mode.md`](11-tutor-mode.md). |
| **Onboarding** | 03 - Onboarding | Parents configure initial mystery rewards during child account onboarding (FR80). PIN may be set during onboarding. |
| **Settings** | 13 - Settings | Child/adult mode toggle (FR81) determines whether parent mode is available (FR67). |
| **Sync** | 14 - Sync & Multi-Device | PIN is device-local only and never synced (FR99). Reward catalog and point configuration DO sync for cloud-born accounts. |
