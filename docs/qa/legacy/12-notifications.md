# Notifications & Reminders -- Manual Test Scenarios

**Document:** 12
**Feature Area:** Daily reminders, streak protection alerts, reward notifications, per-type enable/disable, configurable times, Shabbos/Yom Tov quiet mode, Android notification channels
**Created:** 2026-04-13
**FRs Covered:** FR82, FR83, FR84, FR85, FR86, FR87

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding with at least one curriculum activated
2. Have at least a 2-day streak so streak-related scenarios have data to work with
3. Configure a mystery reward with a low point threshold (e.g., 20 points) so the reward notification can be triggered quickly
4. For Shabbos/Yom Tov scenarios: know the upcoming Shabbos times for your configured location, or set a test location where Shabbos is imminent
5. **Android 13+ device:** Notification runtime permission will be requested. Have a device/emulator running API 33+ for permission-related scenarios
6. **Emulator note:** Local notifications generally work on emulators, but timing accuracy may differ from physical devices. Test NOTIF-12, NOTIF-13, and all Shabbos scenarios on a physical device if possible

**Important:** Notification timing scenarios (NOTIF-01 through NOTIF-05) require waiting for scheduled times. Set test times close to the current time (e.g., 2 minutes from now) to avoid long waits.

---

## What & Why

### Why Notifications Matter

Learning Torah is a daily commitment. The biggest threat to sustained learning
is not difficulty -- it is forgetting. A learner who misses one day often misses
two, and a broken streak quickly turns into an abandoned habit. Notifications
serve as gentle, well-timed nudges that keep the learner engaged without being
intrusive.

All notifications in this app are **local** -- generated and scheduled entirely
on-device using `flutter_local_notifications`. There is no cloud messaging
(FCM/APNs). This is a deliberate architectural choice: local notifications work
offline, do not require a server, and respect the learner's privacy.

### Three Notification Types

| Type | Default Time | Purpose | Android Channel |
|---|---|---|---|
| **Daily Reminder** (FR82) | 7:00 PM | "Time to learn!" -- prompts the learner to start their daily session | `daily_reminders` |
| **Streak Protection** (FR83) | 9:00 PM | "You haven't learned today -- your streak is at risk!" -- last-chance alert | `streak_alerts` |
| **Reward Earned** (FR84) | Instant | "Mystery reward earned!" -- fires immediately when a point threshold is crossed | `rewards` |

### Android Notification Channels

Android 8.0+ (API 26+) requires notification channels. The app creates three
channels so users can control each notification type independently through
Android system settings, even beyond the in-app controls. Channel IDs must be
stable -- once created, changing the ID creates a new channel and orphans the
old one.

### Shabbos/Yom Tov Quiet Mode

Jewish users observe Shabbos and Yom Tov by refraining from phone use. A
notification buzzing during Shabbos dinner is not just unwanted -- it is
religiously inappropriate. The app uses `kosher_dart` to calculate exact
Shabbos start/end times based on the user's location and suppresses all
notifications during these periods (FR87). This is configurable: some users
may want to disable quiet mode (e.g., they keep their phone off anyway).

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (NOTIF-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Daily Reminder -- FR82 (P0)

---

#### NOTIF-01 | P0 | Daily reminder fires at configured time

**Preconditions:** Daily reminders are enabled. Time is set to a testable value (e.g., 2 minutes from now). App is backgrounded or device is locked.

**Steps:**
1. Navigate to Settings > Notifications
2. Enable daily reminders (if not already enabled)
3. Set the reminder time to 2-3 minutes from the current time
4. Background the app (press Home) or lock the device
5. Wait for the configured time to arrive

**Expected:**
- A notification appears at the configured time
- The notification title/body conveys "time to learn" or similar motivational text
- The notification appears in the Android notification shade
- The notification uses the `daily_reminders` channel

**Pass/Fail:** [ ]

---

#### NOTIF-02 | P0 | Daily reminder does not fire if learning already completed today

**Preconditions:** Daily reminders enabled. Time set to a few minutes from now. At least one completion has been recorded TODAY.

**Steps:**
1. Complete at least one learning item today
2. Set daily reminder time to 2-3 minutes from now
3. Background the app
4. Wait for the configured time

**Expected:**
- The daily reminder does NOT fire (the learner already learned today)
- OR the reminder fires but acknowledges today's learning (e.g., "Great job today! Keep going tomorrow")
- The notification should not nag someone who has already done their work

**Pass/Fail:** [ ]

---

#### NOTIF-03 | P0 | Daily reminder fires every day at the same time

**Preconditions:** Daily reminders enabled with a fixed time. No completions on the test days.

**Steps:**
1. Set daily reminder to a specific time (e.g., 7:00 PM)
2. Do NOT complete any learning today
3. Verify the reminder fires today at 7:00 PM
4. Do NOT complete any learning tomorrow
5. Verify the reminder fires again tomorrow at 7:00 PM

**Expected:**
- The reminder fires on both days at the configured time
- The notification content is consistent
- The scheduling persists across days without needing to reopen the app

**Pass/Fail:** [ ]

---

### Streak Protection Alert -- FR83 (P0)

---

#### NOTIF-04 | P0 | Streak protection alert fires if no learning by configured time

**Preconditions:** Streak protection is enabled. Time set to a few minutes from now. The user has an active streak (at least 1 day). NO completions have been recorded today.

**Steps:**
1. Verify the user has an active streak
2. Ensure no completions are recorded today
3. Set streak protection alert time to 2-3 minutes from now
4. Background the app
5. Wait for the configured time

**Expected:**
- A streak protection notification appears
- The notification conveys urgency: "Your streak is at risk!" or similar
- The current streak count may be mentioned (e.g., "Your 12-day streak is at risk!")
- The notification uses the `streak_alerts` channel

**Pass/Fail:** [ ]

---

#### NOTIF-05 | P0 | Streak protection alert does NOT fire if learning completed today

**Preconditions:** Streak protection enabled. Time set to a few minutes from now. At least one completion recorded today.

**Steps:**
1. Complete at least one item today
2. Set streak protection time to 2-3 minutes from now
3. Background the app
4. Wait for the configured time

**Expected:**
- The streak protection alert does NOT fire
- The learner has already preserved their streak -- no alert needed

**Pass/Fail:** [ ]

---

#### NOTIF-06 | P1 | Streak protection fires at different time than daily reminder

**Preconditions:** Both daily reminder and streak protection are enabled with different times (e.g., reminder at 7:00 PM, streak at 9:00 PM).

**Steps:**
1. Set daily reminder to 7:00 PM
2. Set streak protection to 9:00 PM
3. Do NOT complete any learning today
4. Wait for both times to pass

**Expected:**
- The daily reminder fires at 7:00 PM
- The streak protection fires at 9:00 PM (2 hours later)
- Both are separate notifications with distinct messages
- They do not interfere with each other

**Pass/Fail:** [ ]

---

### Reward Earned Notification -- FR84 (P0)

---

#### NOTIF-07 | P0 | Instant notification when mystery reward earned

**Preconditions:** Reward notifications are enabled. A mystery reward is configured with a point threshold just above the current point total (e.g., current: 18 points, reward at 20 points). App may be in foreground or background.

**Steps:**
1. Note the current point total and the next reward threshold
2. Complete enough items to cross the reward threshold (e.g., complete 1 Learn item for 10 points to go from 18 to 28)
3. Observe the notification

**Expected:**
- A notification fires immediately when the threshold is crossed (FR84)
- The notification says "Mystery reward earned!" or similar
- The notification uses the `rewards` channel
- If the app is in the foreground, an in-app notification or banner may also appear

**Pass/Fail:** [ ]

---

#### NOTIF-08 | P1 | Reward notification fires when app is backgrounded

**Preconditions:** Reward threshold is about to be crossed. The app is backgrounded but a completion triggers the threshold (e.g., via a scheduled completion that was pending).

**Steps:**
1. Set up a reward threshold just above current points
2. Background the app
3. If possible, trigger the threshold crossing (this may require the app to process in the background, or test by returning to the app, completing the item, and immediately backgrounding again)

**Expected:**
- The reward notification appears in the notification shade even when the app is not in the foreground
- Tapping the notification opens the app

**Pass/Fail:** [ ]

---

### Enable/Disable Per Type -- FR85 (P0)

---

#### NOTIF-09 | P0 | Disable daily reminders -- only daily reminders stop

**Preconditions:** All three notification types are enabled. Times are set for testing.

**Steps:**
1. Navigate to Settings > Notifications
2. Disable "Daily Reminders"
3. Leave streak protection and reward notifications enabled
4. Background the app
5. Wait for the daily reminder time to pass
6. Trigger a streak protection alert (do not learn, wait for streak time)
7. Trigger a reward notification (cross a point threshold)

**Expected:**
- Daily reminder does NOT fire (disabled)
- Streak protection DOES fire (still enabled)
- Reward notification DOES fire (still enabled)
- Each type is independently controllable

**Pass/Fail:** [ ]

---

#### NOTIF-10 | P0 | Disable streak protection -- only streak alerts stop

**Preconditions:** All three types enabled.

**Steps:**
1. Disable "Streak Protection" in notification settings
2. Leave daily reminders and rewards enabled
3. Do not learn today
4. Wait for both daily reminder and streak protection times

**Expected:**
- Daily reminder DOES fire
- Streak protection does NOT fire (disabled)
- Reward notifications remain functional

**Pass/Fail:** [ ]

---

#### NOTIF-11 | P0 | Disable reward notifications -- only reward alerts stop

**Preconditions:** All three types enabled. A reward threshold is about to be crossed.

**Steps:**
1. Disable "Reward Notifications" in notification settings
2. Cross the reward point threshold by completing items
3. Observe

**Expected:**
- No reward notification appears (disabled)
- The reward IS still earned (the notification setting does not affect reward logic)
- Daily reminders and streak protection continue to work normally

**Pass/Fail:** [ ]

---

#### NOTIF-12 | P1 | Disable all notifications -- nothing fires

**Preconditions:** All three types are disabled in app settings.

**Steps:**
1. Disable all three notification types
2. Wait for configured times to pass
3. Cross a reward threshold

**Expected:**
- No notifications of any type fire
- The app continues to function normally otherwise
- Re-enabling any type restores that notification

**Pass/Fail:** [ ]

---

### Configure Notification Times -- FR86 (P1)

---

#### NOTIF-13 | P1 | Change daily reminder time

**Preconditions:** Daily reminders enabled. Currently set to 7:00 PM.

**Steps:**
1. Navigate to Settings > Notifications
2. Change daily reminder time from 7:00 PM to 8:30 PM
3. Save the change
4. Background the app
5. Verify no notification at 7:00 PM
6. Verify notification fires at 8:30 PM

**Expected:**
- The old time (7:00 PM) no longer triggers a notification
- The new time (8:30 PM) triggers the notification
- The change takes effect immediately without requiring app restart

**Pass/Fail:** [ ]

---

#### NOTIF-14 | P1 | Change streak protection time

**Preconditions:** Streak protection enabled. Currently set to 9:00 PM.

**Steps:**
1. Change streak protection time to 9:45 PM
2. Do not learn today
3. Verify no alert at 9:00 PM
4. Verify alert fires at 9:45 PM

**Expected:**
- The updated time is respected
- The old schedule is cancelled and replaced

**Pass/Fail:** [ ]

---

#### NOTIF-15 | P1 | Set streak time earlier than daily reminder time

**Preconditions:** Both notifications enabled.

**Steps:**
1. Set daily reminder to 8:00 PM
2. Set streak protection to 6:00 PM (earlier than daily reminder)
3. Do not learn today
4. Wait for both times

**Expected:**
- Streak protection fires at 6:00 PM
- Daily reminder fires at 8:00 PM
- The app does not enforce any ordering between the two times -- the user can set them however they want
- Both notifications are delivered correctly regardless of order

**Pass/Fail:** [ ]

---

### Shabbos/Yom Tov Quiet Mode -- FR87 (P0)

---

#### NOTIF-16 | P0 | Notifications suppressed during Shabbos

**Preconditions:** Shabbos quiet mode is enabled. Location is configured for zmanim calculation. A daily reminder is scheduled for a time that falls during Shabbos (e.g., Friday evening after candle lighting). kosher_dart is calculating zmanim correctly.

**Steps:**
1. Enable Shabbos/Yom Tov quiet mode in notification settings
2. Set daily reminder time to a time that will fall during Shabbos (e.g., 8:00 PM Friday)
3. Wait for Friday evening
4. Observe whether the notification fires

**Expected:**
- The notification does NOT fire during Shabbos
- The suppression window starts at candle lighting / shkiah (per configured zmanim) on Friday
- No notifications of any type fire during the Shabbos window

**Pass/Fail:** [ ]

---

#### NOTIF-17 | P0 | Notifications resume after Shabbos ends

**Preconditions:** Shabbos quiet mode is enabled. Shabbos has ended (after havdalah / tzeis hakochavim on Saturday night).

**Steps:**
1. Wait for motzaei Shabbos (Saturday night, after Shabbos ends per zmanim)
2. Set a notification time for shortly after Shabbos ends
3. Observe whether the notification fires

**Expected:**
- Notifications resume after Shabbos ends
- The first post-Shabbos notification fires at its scheduled time
- The suppression window is cleanly bounded by zmanim times

**Pass/Fail:** [ ]

---

#### NOTIF-18 | P0 | Notifications suppressed during Yom Tov

**Preconditions:** Shabbos/Yom Tov quiet mode is enabled. An upcoming Yom Tov is known (e.g., first day of Sukkos). Notifications are scheduled during Yom Tov hours.

**Steps:**
1. Verify Yom Tov dates are recognized by kosher_dart
2. Set notification times to fall during Yom Tov
3. Wait for Yom Tov to begin
4. Observe

**Expected:**
- Notifications are suppressed during Yom Tov, same as Shabbos
- Multi-day Yom Tov (e.g., two days of Rosh Hashana) suppresses for the entire duration
- Chol HaMoed days do NOT suppress notifications (only Yom Tov days proper)

**Pass/Fail:** [ ]

---

#### NOTIF-19 | P1 | Disable Shabbos quiet mode -- notifications fire on Shabbos

**Preconditions:** Shabbos quiet mode is currently enabled.

**Steps:**
1. Navigate to Settings > Notifications
2. Disable Shabbos/Yom Tov quiet mode
3. Set a notification for a time during Shabbos
4. Observe

**Expected:**
- Notifications fire even during Shabbos (quiet mode is off)
- The user has chosen to manage notifications themselves
- Re-enabling quiet mode restores suppression

**Pass/Fail:** [ ]

---

#### NOTIF-20 | P1 | Quiet mode uses correct zmanim for user's location

**Preconditions:** Shabbos quiet mode is enabled. User's location is configured (e.g., New York, Jerusalem, London -- cities with meaningfully different sunset times).

**Steps:**
1. Check the Shabbos start time displayed or used by the app for the configured location
2. Compare with a known-accurate zmanim source (e.g., MyZmanim.com, a local luach)
3. Verify the suppression window aligns with the correct local times

**Expected:**
- The app calculates Shabbos start/end times using kosher_dart for the configured location
- Times are within 1-2 minutes of a trusted external zmanim source
- The suppression window matches these calculated times

**Pass/Fail:** [ ]

---

### Android Notification Channels (P1)

---

#### NOTIF-21 | P1 | Three separate Android notification channels exist

**Preconditions:** App is installed on an Android 8.0+ device (API 26+).

**Steps:**
1. Open Android Settings > Apps > Learning Tracker > Notifications
2. View the notification channels listed

**Expected:**
- Three channels are visible:
  1. Daily Reminders (or similar name)
  2. Streak Alerts (or similar name)
  3. Rewards (or similar name)
- Each channel can be independently enabled/disabled at the system level
- Each channel has its own importance level, sound, and vibration settings

**Pass/Fail:** [ ]

---

#### NOTIF-22 | P1 | System-level channel disable overrides app setting

**Preconditions:** Daily reminders are enabled in the app. The "Daily Reminders" Android channel exists.

**Steps:**
1. Go to Android Settings > Apps > Learning Tracker > Notifications
2. Disable the "Daily Reminders" channel at the system level
3. Return to the app -- daily reminders are still "enabled" in app settings
4. Wait for the daily reminder time

**Expected:**
- The notification does NOT fire (system-level channel override)
- The app settings may show reminders as enabled, but Android blocks the channel
- Other notification types (streak, reward) still fire if their channels are enabled

**Pass/Fail:** [ ]

---

### Notification Tap Behavior (P1)

---

#### NOTIF-23 | P1 | Tapping daily reminder opens the daily task list

**Preconditions:** A daily reminder notification is visible in the notification shade.

**Steps:**
1. Tap the daily reminder notification
2. Observe which screen the app opens to

**Expected:**
- The app opens (or comes to foreground) and navigates to the daily task list / home screen
- The user is immediately ready to start learning
- The notification is dismissed from the shade after tapping

**Pass/Fail:** [ ]

---

#### NOTIF-24 | P1 | Tapping streak alert opens the daily task list

**Preconditions:** A streak protection notification is visible.

**Steps:**
1. Tap the streak protection notification
2. Observe which screen opens

**Expected:**
- The app opens to the daily task list so the user can quickly complete something to save their streak
- The notification is dismissed after tapping

**Pass/Fail:** [ ]

---

#### NOTIF-25 | P1 | Tapping reward notification opens reward screen or relevant view

**Preconditions:** A reward earned notification is visible.

**Steps:**
1. Tap the reward notification
2. Observe which screen opens

**Expected:**
- The app opens to the rewards screen, mystery reward reveal, or a relevant celebration view
- The user can see which reward they earned
- The notification is dismissed after tapping

**Pass/Fail:** [ ]

---

### Android 13+ Permission (P0)

---

#### NOTIF-26 | P0 | Runtime notification permission requested on Android 13+

**Preconditions:** Fresh install on an Android 13+ device (API 33+). Notification permission has NOT been granted yet.

**Steps:**
1. Launch the app for the first time (or clear app permissions)
2. Navigate to Settings > Notifications, or trigger a point where notifications are configured
3. Observe the system permission dialog

**Expected:**
- The app requests the `POST_NOTIFICATIONS` runtime permission
- A system dialog appears asking the user to allow or deny notifications
- If allowed: notifications work as expected
- If denied: the app gracefully handles the denial (see NOTIF-27)

**Pass/Fail:** [ ]

---

#### NOTIF-27 | P1 | Graceful degradation when notification permission denied

**Preconditions:** Android 13+ device. Notification permission has been denied.

**Steps:**
1. Deny the notification permission when prompted (or revoke it in system settings)
2. Navigate to the app's notification settings
3. Observe the UI

**Expected:**
- The app does NOT crash
- Notification settings are either disabled with an explanation ("Notifications are blocked by system settings") or guide the user to enable them in Android settings
- The app continues to function normally for all non-notification features
- No repeated permission prompts on every screen (respect the denial)

**Pass/Fail:** [ ]

---

### Edge Cases (P2)

---

#### NOTIF-28 | P2 | Notification scheduling survives app restart

**Preconditions:** Daily reminder is set for a future time today. App is force-closed.

**Steps:**
1. Set daily reminder to 30 minutes from now
2. Force-close the app (swipe from recents)
3. Do NOT reopen the app
4. Wait for the reminder time

**Expected:**
- The notification fires at the scheduled time even though the app was killed
- flutter_local_notifications uses Android's AlarmManager, which persists across app restarts
- If the notification does not fire, this indicates a scheduling persistence issue

**Pass/Fail:** [ ]

---

#### NOTIF-29 | P2 | Notification scheduling survives device reboot

**Preconditions:** Daily reminder is set for a future time. The device is rebooted.

**Steps:**
1. Set daily reminder to a time well in the future (e.g., 2 hours from now)
2. Reboot the device
3. Do NOT open the app after reboot
4. Wait for the reminder time

**Expected:**
- The notification fires at the scheduled time after reboot
- The app has a `BOOT_COMPLETED` receiver that reschedules notifications
- If the notification does not fire after reboot, this indicates missing boot receiver setup

**Pass/Fail:** [ ]

---

#### NOTIF-30 | P2 | Multiple rewards earned in quick succession

**Preconditions:** Two reward thresholds are close together (e.g., 50 points and 55 points). Current points are at 48.

**Steps:**
1. Complete several items rapidly to cross both thresholds in quick succession
2. Observe notifications

**Expected:**
- Two separate reward notifications are generated (one for each threshold)
- Both notifications appear in the shade (not collapsed into one)
- Neither notification is lost or swallowed
- Each notification references the correct reward

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Notifications |
|---|---|---|
| **Gamification & Rewards** | 09 - Gamification & Rewards | Reward earned notifications (FR84) are triggered by the gamification system when a point threshold is crossed. |
| **Learning & Completions** | 04 - Learning & Completions | Completions drive streak tracking. Streak protection alerts (FR83) check whether any completion was recorded today. |
| **Scheduling** | 06 - Scheduling & Review | The daily reminder (FR82) is conceptually tied to the scheduler -- it nudges the user to work on scheduled tasks. |
| **Settings** | 13 - Settings & Preferences | Notification preferences (enable/disable, times, quiet mode) are managed in the settings screen. |
| **Hebrew Calendar** | (kosher_dart) | Shabbos/Yom Tov quiet mode (FR87) depends on accurate zmanim calculations from kosher_dart. |
| **Onboarding** | 03 - Onboarding | Android 13+ notification permission may be requested during or shortly after onboarding. |
