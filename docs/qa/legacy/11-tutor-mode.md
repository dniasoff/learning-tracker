# Tutor Mode -- Manual Test Scenarios

> ⚠️ **Superseded — 2026-07-13 (supersedes the 2026-04-19 note below).** The design this document tests — a self-service, `TutorPinGuard`-gated, strictly **read-only** dashboard set up from Settings — no longer exists in code. It was replaced by a grant-based invite/accept/revoke model (`lib/features/tutoring/`): a creator-parent invites a tutor by email, the tutor accepts, and PIN entry now runs through the typed `PinGuard(PinScope.tutor(profileId))` guard (`lib/core/navigation/guards/pin_guard.dart`) rather than a dedicated `TutorPinGuard`. Tutors are also no longer strictly read-only — the parent can grant write permissions (goals, stages, rewards, study days, points, bulk-prior completions) via `TutorPermissions`; only live-forward completion marking (`canMarkLiveCompletion`) is permanently blocked. This was substantial new investment (see `docs/planning/tutor-mode-brief.md`, 2026-05-20; `tutor-talmid-view-plan`, 2026-05-26; `tutor-edit-propagation-plan`, 2026-05-28) — the "deprioritized, no new investment" status below is no longer accurate. **The scenarios in this document describe the original, now-superseded Epic 11 design and are kept for historical reference only; do not use them to test current tutor-mode behavior.** See [`../../planning/tutor-mode-brief.md`](../../planning/tutor-mode-brief.md) for the current design.
>
> ⚠️ **Original status — 2026-04-19 (historical):** Tutor Mode (Epic 11) is **shipped and fully wired** in code — all 5 routes, `TutorPinGuard` active, 7 screens in `lib/features/tutor_mode/`. However, the feature has been **deprioritized** from the v1 roadmap and marketing. Bugs are not actively pursued, and no onboarding flow promotes it. Use these scenarios for regression testing if you touch tutor-mode code, but don't treat gaps in the test coverage as blocking for v1. See [`../../_archive/scrapped-ideas/tutor-mode-epic-11.md`](../../_archive/scrapped-ideas/tutor-mode-epic-11.md) for context.

**Document:** 11
**Feature Area:** Tutor PIN setup, read-only enforcement, completion history, chazara view, on-track status, schedule view, child + adult support
**Created:** 2026-04-13
**FRs Covered:** FR68, FR69, FR70, FR71, FR72, FR73, FR74, FR98, FR99, FR100

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding with at least one curriculum activated (e.g., Mishnayos)
2. Have at least 10-15 completions recorded across multiple stages (Learn, Chazara 1, Chazara 2) so tutor views have data to display
3. Have access to a **child account** and an **adult account** for cross-account testing (TUTOR-17 through TUTOR-20)
4. Know the parent PIN (if child account) -- tutor PIN setup may require parent access
5. A second person (or second test pass) to simulate the tutor's perspective

---

## What & Why

### Why Tutor Mode Matters

Many learners work with a private tutor (rebbi, melamed, or chavrusah partner)
who meets with them weekly or bi-weekly. Before each session, the tutor needs
to quickly understand what happened since the last meeting: what was completed,
what is due for chazara, and whether the learner is on track. Without this
visibility, the first 10-15 minutes of every session are wasted on verbal
catch-up.

Tutor mode provides a PIN-protected, **read-only** window into the learner's
progress. The tutor enters their own 4-digit PIN (separate from the parent
PIN), and sees completion history, chazara queues, on-track status, and
schedule recommendations -- but cannot modify any data. This protects against
accidental completions or schedule changes while the tutor is browsing.

### Key Design Decisions

| Decision | Rationale |
|---|---|
| **Separate PIN from parent** | The tutor is not the parent. They should not have access to parent controls (rewards, point configuration, track management). FR98. |
| **Read-only enforcement** | Tutors need to see data, not change it. A stray tap should never record a completion or modify a schedule. FR69, FR100. |
| **PIN never synced** | The tutor PIN is device-local only (FR99). If the learner uses multiple devices, the tutor PIN must be set up on each device independently. This is a deliberate security choice. |
| **Available for child AND adult** | Both children with tutors and adults with chavrusah partners benefit from this mode. FR74. |

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (TUTOR-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### PIN Setup & Authentication (P0)

---

#### TUTOR-01 | P0 | Set up tutor PIN for the first time

**Preconditions:** No tutor PIN has been configured yet. App is in normal (learner) mode.

**Steps:**
1. Navigate to Settings
2. Locate the "Tutor Mode" or "Tutor PIN" section
3. Tap "Set up tutor PIN"
4. Enter a 4-digit PIN (e.g., 5678)
5. Confirm the PIN by entering it a second time

**Expected:**
- The PIN setup flow accepts exactly 4 digits
- A confirmation re-entry is required
- After successful setup, the settings screen shows tutor PIN as "enabled" or "configured"
- The PIN is stored securely (flutter_secure_storage with bcrypt hashing, FR98)

**Pass/Fail:** [ ]

---

#### TUTOR-02 | P0 | Tutor PIN is separate from parent PIN

**Preconditions:** Child account with parent PIN already configured (e.g., 1234). Tutor PIN not yet set.

**Steps:**
1. Set up tutor PIN using a different 4-digit code (e.g., 5678)
2. Exit to the main screen
3. Enter parent mode using parent PIN (1234)
4. Verify parent mode is accessible
5. Exit parent mode
6. Enter tutor mode using tutor PIN (5678)
7. Verify tutor mode is accessible

**Expected:**
- Parent PIN and tutor PIN are independent -- each opens its respective mode
- Entering the parent PIN does NOT open tutor mode
- Entering the tutor PIN does NOT open parent mode
- Both PINs can coexist simultaneously on the same device

**Pass/Fail:** [ ]

---

#### TUTOR-03 | P0 | Enter tutor mode with correct PIN

**Preconditions:** Tutor PIN is configured (e.g., 5678).

**Steps:**
1. From the main screen, tap the tutor mode entry point (e.g., lock icon, menu option)
2. Enter the correct 4-digit tutor PIN
3. Observe the screen transition

**Expected:**
- The app transitions to tutor mode
- A visual indicator shows the app is in tutor mode (e.g., banner, icon, color change)
- Tutor-specific views are displayed (completion history, chazara queue, etc.)

**Pass/Fail:** [ ]

---

#### TUTOR-04 | P0 | Reject incorrect tutor PIN

**Preconditions:** Tutor PIN is configured (e.g., 5678).

**Steps:**
1. Tap the tutor mode entry point
2. Enter an incorrect PIN (e.g., 1111)
3. Observe the response

**Expected:**
- The app does NOT enter tutor mode
- An error message appears (e.g., "Incorrect PIN")
- The PIN entry field is cleared for retry
- The user remains on the current screen

**Pass/Fail:** [ ]

---

#### TUTOR-05 | P0 | Lockout after 5 failed PIN attempts

**Preconditions:** Tutor PIN is configured. No recent failed attempts.

**Steps:**
1. Attempt to enter tutor mode with an incorrect PIN -- attempt 1
2. Repeat with incorrect PIN -- attempt 2
3. Repeat -- attempt 3
4. Repeat -- attempt 4
5. Repeat -- attempt 5
6. Attempt a 6th entry

**Expected:**
- After the 5th failed attempt, the app locks out the tutor PIN entry (FR101)
- A message indicates the lockout and the cooldown period
- Further PIN entry is blocked until the cooldown expires
- The lockout does NOT affect normal app usage or parent PIN entry

**Pass/Fail:** [ ]

---

#### TUTOR-06 | P1 | Change tutor PIN

**Preconditions:** Tutor PIN is currently set to 5678.

**Steps:**
1. Navigate to Settings > Tutor PIN
2. Tap "Change PIN" (may require entering the current PIN first)
3. Enter the current PIN (5678) if prompted
4. Enter a new PIN (e.g., 9012)
5. Confirm the new PIN
6. Exit settings
7. Enter tutor mode with the new PIN (9012)
8. Try the old PIN (5678)

**Expected:**
- The PIN change is accepted
- The new PIN (9012) grants access to tutor mode
- The old PIN (5678) is rejected
- No data is lost during PIN change

**Pass/Fail:** [ ]

---

#### TUTOR-07 | P1 | Remove tutor PIN

**Preconditions:** Tutor PIN is configured.

**Steps:**
1. Navigate to Settings > Tutor PIN
2. Tap "Remove" or "Disable" tutor PIN
3. Confirm the removal (may require entering the current PIN)
4. Attempt to access tutor mode

**Expected:**
- The tutor PIN is removed
- Settings shows tutor PIN as "not configured"
- The tutor mode entry point is either hidden or shows the setup flow when tapped
- No crash or error when attempting to access tutor mode without a PIN

**Pass/Fail:** [ ]

---

### PIN Security (P0)

---

#### TUTOR-08 | P0 | Tutor PIN is never synced to Firestore

**Preconditions:** Cloud-born account with Firestore sync active. Tutor PIN is configured on Device A.

**Steps:**
1. Set up tutor PIN on Device A
2. Sign in to the same account on Device B
3. After full sync completes, attempt to enter tutor mode on Device B

**Expected:**
- Device B does NOT have a tutor PIN configured (FR99)
- Tutor mode on Device B shows the PIN setup flow, not a PIN entry prompt
- The PIN is strictly device-local and was not transferred via Firestore

**Pass/Fail:** [ ]

---

#### TUTOR-09 | P1 | Tutor PIN cannot be the same as parent PIN

**Preconditions:** Child account with parent PIN set to 1234. Tutor PIN not yet configured.

**Steps:**
1. Navigate to Settings > Tutor PIN setup
2. Enter 1234 as the tutor PIN (same as parent PIN)
3. Observe the response

**Expected:**
- The system rejects the PIN with a clear message (e.g., "Tutor PIN must be different from parent PIN")
- The user is prompted to choose a different PIN
- If the system allows the same PIN, this scenario FAILS -- the PINs must be distinct to prevent role confusion

**Pass/Fail:** [ ]

---

### Read-Only Enforcement (P0)

---

#### TUTOR-10 | P0 | Cannot mark completions in tutor mode

**Preconditions:** Tutor mode is active. A pending item exists in the daily task list.

**Steps:**
1. In tutor mode, navigate to the daily task list
2. Attempt to tap an item to mark it complete
3. Try any gesture: tap, long-press, swipe

**Expected:**
- The completion action is BLOCKED (FR69, FR100)
- Either the tap does nothing, or a message appears (e.g., "View only -- exit tutor mode to make changes")
- No completion record is created
- No points are awarded
- No bookmark is advanced

**Pass/Fail:** [ ]

---

#### TUTOR-11 | P0 | Cannot modify schedule in tutor mode

**Preconditions:** Tutor mode is active.

**Steps:**
1. Navigate to the schedule or daily task view
2. Attempt to reorder tasks (drag-and-drop)
3. Attempt to skip or snooze an item
4. Look for any edit controls

**Expected:**
- All modification controls are disabled or hidden in tutor mode
- No schedule changes are possible
- The view is strictly read-only

**Pass/Fail:** [ ]

---

#### TUTOR-12 | P0 | Cannot access parent controls in tutor mode

**Preconditions:** Tutor mode is active. Child account.

**Steps:**
1. Look for parent-mode features: reward catalog, point configuration, track management
2. Attempt to navigate to Settings sections that are parent-only
3. Try to add or remove a track

**Expected:**
- Parent-only sections are NOT accessible from tutor mode
- The tutor cannot modify rewards, points, track assignments, or any parent settings
- Tutor mode and parent mode are completely separate permission scopes

**Pass/Fail:** [ ]

---

#### TUTOR-13 | P0 | Cannot modify settings in tutor mode

**Preconditions:** Tutor mode is active.

**Steps:**
1. Attempt to navigate to app settings
2. Try to change notification preferences, learning goals, or curriculum configuration
3. Look for any writable control

**Expected:**
- Settings are either not accessible from tutor mode, or displayed as read-only
- No configuration changes can be made
- The tutor can only view, never modify

**Pass/Fail:** [ ]

---

### Tutor Views -- Completion History (P0)

---

#### TUTOR-14 | P0 | View completion history with timestamps

**Preconditions:** Tutor mode is active. At least 10 completions have been recorded with various items, stages, and dates.

**Steps:**
1. Navigate to the completion history view in tutor mode
2. Scroll through the entries
3. Verify the data displayed for each entry

**Expected (FR70):**
- All completions are listed with: item name, stage (Learn/Chazara 1/Chazara 2), timestamp
- Timestamps show date AND time
- Entries are in chronological order (most recent first)
- The tutor can see the full history, not just recent entries

**Pass/Fail:** [ ]

---

#### TUTOR-15 | P1 | Completion history shows track assignment

**Preconditions:** Tutor mode is active. Completions exist under multiple tracks (Personal, School).

**Steps:**
1. Open completion history in tutor mode
2. Locate entries from different tracks

**Expected:**
- Each completion entry shows which track it was recorded under
- The tutor can see the track distribution to understand how learning is split

**Pass/Fail:** [ ]

---

### Tutor Views -- Chazara Queue (P0)

---

#### TUTOR-16 | P0 | View items due for chazara review, grouped by urgency

**Preconditions:** Tutor mode is active. Multiple items have chazara stages due, some overdue and some upcoming.

**Steps:**
1. Navigate to the chazara review view in tutor mode
2. Observe the grouping and ordering

**Expected (FR71):**
- Items due for chazara are listed and grouped by urgency (e.g., overdue, due today, upcoming)
- Each item shows: name, stage due, days overdue (if applicable)
- The grouping helps the tutor prioritize which items to focus on in the session
- Overdue items are visually distinct (color, label, or section header)

**Pass/Fail:** [ ]

---

### Child Account + Adult Account (P0)

---

#### TUTOR-17 | P0 | Tutor mode available on child account

**Preconditions:** Child account with parent PIN configured. Tutor PIN configured.

**Steps:**
1. From the child account's main screen, access tutor mode
2. Enter the tutor PIN
3. Verify tutor mode loads with all expected views

**Expected (FR74):**
- Tutor mode is fully accessible on child accounts
- All tutor views (completion history, chazara queue, on-track status, schedule) are available
- Read-only enforcement is active

**Pass/Fail:** [ ]

---

#### TUTOR-18 | P0 | Tutor mode available on adult account

**Preconditions:** Adult account. Tutor PIN configured.

**Steps:**
1. From the adult account's main screen, access tutor mode
2. Enter the tutor PIN
3. Verify tutor mode loads with all expected views

**Expected (FR74):**
- Tutor mode is fully accessible on adult accounts
- All tutor views are available, same as on child accounts
- Read-only enforcement is active
- The adult account does not have parent mode (FR67), but tutor mode still works independently

**Pass/Fail:** [ ]

---

#### TUTOR-19 | P1 | Adult account -- tutor PIN setup without parent PIN

**Preconditions:** Adult account. No parent PIN exists (adult accounts do not have parent mode). Tutor PIN not yet configured.

**Steps:**
1. Navigate to Settings
2. Locate the tutor PIN setup
3. Set up the tutor PIN

**Expected:**
- Tutor PIN setup does not require a parent PIN on adult accounts
- The setup flow works independently of parent mode
- After setup, tutor mode is accessible with the configured PIN

**Pass/Fail:** [ ]

---

### Tutor Views -- On-Track Status & Progress (P1)

---

#### TUTOR-20 | P1 | View on-track status and progress metrics per curriculum

**Preconditions:** Tutor mode is active. At least one curriculum has a configured goal with a deadline. Some completions exist.

**Steps:**
1. Navigate to the progress or on-track status view in tutor mode
2. Observe the metrics displayed for each curriculum

**Expected (FR72):**
- On-track status is displayed per curriculum (e.g., "On track", "Behind", "Ahead")
- Progress metrics are visible: completion percentage, items completed vs total, current pace
- If a goal with a deadline is set, the view shows whether current pace will meet the deadline
- All data is read-only

**Pass/Fail:** [ ]

---

#### TUTOR-21 | P1 | Progress metrics update after learner completes items

**Preconditions:** Tutor mode was accessed and metrics were noted. The learner then completes several items in normal mode.

**Steps:**
1. Enter tutor mode and note the current progress metrics (e.g., 42% complete, 176 items)
2. Exit tutor mode
3. Complete 5 items in normal learner mode
4. Re-enter tutor mode
5. Check the progress metrics again

**Expected:**
- The metrics reflect the new completions (e.g., now 43% complete, 181 items)
- The data is current as of the moment tutor mode is entered
- No stale caching -- the tutor always sees up-to-date data

**Pass/Fail:** [ ]

---

### Tutor Views -- Schedule (P1)

---

#### TUTOR-22 | P1 | View schedule recommendations (read-only daily task view)

**Preconditions:** Tutor mode is active. The scheduler has generated a daily task list for today.

**Steps:**
1. Navigate to the schedule or daily task view in tutor mode
2. Review the listed tasks

**Expected (FR73):**
- The daily task list is displayed showing what the learner should work on
- Tasks show item name, stage, and curriculum
- The view is identical to the learner's task list but strictly read-only
- No completion buttons, checkboxes, or interactive completion controls are visible

**Pass/Fail:** [ ]

---

#### TUTOR-23 | P1 | Schedule view shows multiple curricula

**Preconditions:** Tutor mode is active. Two or more curricula are active with scheduled tasks.

**Steps:**
1. Open the schedule view in tutor mode
2. Verify tasks from multiple curricula are shown

**Expected:**
- Tasks from all active curricula appear in the daily plan
- Each task is labeled with its curriculum
- The tutor can see the full scope of the learner's daily workload

**Pass/Fail:** [ ]

---

### Exit & Session Behavior (P1)

---

#### TUTOR-24 | P1 | Exit tutor mode returns to normal learner mode

**Preconditions:** Currently in tutor mode.

**Steps:**
1. Tap the "Exit tutor mode" button or back navigation
2. Observe the transition

**Expected:**
- The app returns to normal learner mode
- The tutor mode visual indicator disappears
- All normal learner functionality is restored (completions, modifications, etc.)
- No data was modified during the tutor session

**Pass/Fail:** [ ]

---

#### TUTOR-25 | P1 | App backgrounded in tutor mode -- returns to PIN entry

**Preconditions:** Currently in tutor mode. App is in the foreground.

**Steps:**
1. Press the device home button to background the app
2. Wait 30-60 seconds
3. Reopen the app

**Expected:**
- The app either returns to the tutor mode session OR requires re-entering the tutor PIN
- If re-authentication is required, the tutor views are not briefly visible before the PIN prompt
- Session timeout behavior should be consistent and secure

**Pass/Fail:** [ ]

---

### Edge Cases (P2)

---

#### TUTOR-26 | P2 | Tutor mode with no completions recorded

**Preconditions:** Tutor PIN is configured. The account has NO completions (fresh setup).

**Steps:**
1. Enter tutor mode
2. Navigate to completion history
3. Navigate to chazara queue
4. Navigate to progress metrics

**Expected:**
- Completion history shows an empty state message (e.g., "No completions yet")
- Chazara queue shows an empty state (no items due)
- Progress metrics show 0% with appropriate messaging
- No crashes or errors on empty data

**Pass/Fail:** [ ]

---

#### TUTOR-27 | P2 | Tutor mode with only one curriculum active

**Preconditions:** Tutor mode active. Only one curriculum is activated (e.g., Mishnayos).

**Steps:**
1. Navigate through all tutor views
2. Verify curriculum-specific views display correctly

**Expected:**
- All views display data for the single active curriculum
- No empty or broken views due to missing second curriculum
- Curriculum selectors (if any) show only the one active curriculum

**Pass/Fail:** [ ]

---

#### TUTOR-28 | P2 | Tutor mode after track deletion

**Preconditions:** A School track was active and had completions. The track was then removed by the parent/user.

**Steps:**
1. Enter tutor mode
2. View completion history
3. Check if completions from the deleted track are still visible

**Expected:**
- Completions from the deleted track are still visible in history (immutability -- completions are never deleted)
- The track label may show as inactive or historical
- Progress metrics reflect only currently active tracks
- No crashes or missing data

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Tutor Mode |
|---|---|---|
| **Parent Mode** | 10 - Parent Mode | Parent mode uses a separate PIN and grants write access to settings. Tutor mode is strictly read-only. Both can coexist on the same device with different PINs. |
| **Learning & Completions** | 04 - Learning & Completions | Tutor mode displays completion data but cannot create completions. Completion history (FR70) is the primary tutor view. |
| **Scheduling** | 06 - Scheduling & Review | Tutor mode shows the schedule as read-only (FR73). Scheduler runs for personal track only (FR37) -- tutor sees this output. |
| **Multi-Track** | 05 - Multi-Track Management | Tutor mode shows progress across all tracks. Track management (add/remove) is a parent function, not tutor. |
| **Sync** | 14 - Sync & Multi-Device | Tutor PIN is device-local and never synced (FR99). Completion data viewed by the tutor does sync across devices. |
| **Gamification** | 09 - Gamification & Rewards | Tutor may see points and streaks in progress views but cannot modify reward settings. |
