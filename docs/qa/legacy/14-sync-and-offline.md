# Sync & Offline -- Manual Test Scenarios

**Document:** 14
**Feature Area:** Push-on-write, pull-on-launch, foreground listeners, conflict resolution, retry with backoff, device restore, offline core features, local-born no sync, content DB lifecycle
**Created:** 2026-04-13
**FRs Covered:** FR88, FR89, FR90, FR91, FR92, FR93, FR94, NFR23, NFR24, NFR25, NFR26, NFR27

---

## Prerequisites

Before running these scenarios:

1. Complete onboarding (document 03) with at least one curriculum activated
2. Have a **cloud-born** test account with meaningful data (20+ completions, active streaks, configured goals)
3. Have a **local-born** test account with meaningful data
4. Have **two physical devices** (or one device + emulator) signed in to the same cloud-born account for multi-device tests
5. Have reliable control over network state (airplane mode toggle, or a Wi-Fi network you can disconnect)
6. Content DB seed file (`seed.db.gz`) is available in the APK assets

**Sync is invisible when it works and catastrophic when it doesn't.** A user
who loses a 200-day streak or months of completion data due to a sync bug will
never trust the app again. These tests verify that the offline-first contract
holds: local SQLite is always the source of truth, sync is a non-blocking
background projection, and no user action ever waits on the network.

---

## What & Why

### Architecture Overview

The app follows a strict **offline-first** model:

- **Local SQLite is the source of truth** (NFR24). Every read and write goes
  to SQLite first. The app never queries Firestore directly for rendering.
- **Sync is a background projection** for cloud-born users only. Local-born
  users have zero sync operations -- no push, no pull, no listeners.
- **Two databases:** Content DB (read-only, bundled, replaced on app update)
  and User DB (read-write, synced for cloud-born).

### Conflict Resolution Strategies (FR92)

| Data Type | Strategy | Rule |
|---|---|---|
| Profile settings (name, avatar, mode) | Last-write-wins (LWW) | Higher `updatedAt` wins |
| Completions / progress markers | Merge-forward | Union of completed items; if either side says "done", it's done |
| Streaks | Event log, reduced to state | Append-only events; each device reduces independently and converges |
| XP / gamification | Event log, reduced to state | Same as streaks -- events are source of truth |
| Bookmarks, goals, configs | LWW by `updatedAt` | User edits are infrequent |

### Key Invariants

| Invariant | FR/NFR | Description |
|---|---|---|
| **Identical UX offline** | NFR23 | Core features (completions, browsing, scheduling, gamification) work identically with no network. |
| **SQLite is source of truth** | NFR24 | App never waits on Firestore for any user-facing operation. |
| **Non-blocking sync** | NFR25 | Sync runs in the background. No spinner, no "waiting for server" on any user action. |
| **Auto-sync on reconnect** | NFR26 | When connectivity returns, sync resumes automatically without user intervention. |
| **Battery-efficient** | NFR27 | Sync respects Android battery saver mode. |
| **Local-born = zero sync** | -- | Local-born accounts never contact Firestore. No push, no pull, no listeners. |
| **Zero data loss for progress** | FR92 | Merge-forward for completions guarantees no completed item is ever lost. |

---

## Test Scenarios

### Format

Each scenario follows this structure:

| Field | Description |
|---|---|
| **ID** | Unique identifier (SYNC-XX) |
| **Priority** | P0 (must pass), P1 (should pass), P2 (nice to verify) |
| **Title** | Short description |
| **Preconditions** | State required before starting |
| **Steps** | Numbered actions to perform |
| **Expected** | What should happen |
| **Pass/Fail** | Checkbox for recording result |

---

### Offline Core Features -- FR88, NFR23 (P0)

---

#### SYNC-01 | P0 | All core features work without network (cloud-born)

**Preconditions:** Cloud-born account with data. App is online and synced.

**Steps:**
1. Enable airplane mode
2. Open the daily task list -- verify it loads
3. Mark an item as Learn complete -- verify it records
4. Browse the content hierarchy -- verify content loads
5. Check the dashboard -- verify stats display
6. Check streaks and points -- verify they update
7. Open completion history -- verify past completions display

**Expected:**
- Every core feature works identically to online mode
- No loading spinners waiting on network
- No error dialogs about missing connectivity
- Completions are recorded to local SQLite immediately
- Points and streaks update immediately
- Content browser shows all content (bundled in Content DB)

**Pass/Fail:** [ ]

---

#### SYNC-02 | P0 | All core features work without network (local-born)

**Preconditions:** Local-born account with data. Device is offline (or online -- should be identical for local-born).

**Steps:**
1. Ensure device is offline (airplane mode)
2. Repeat all steps from SYNC-01
3. Disable airplane mode
4. Repeat all steps again

**Expected:**
- Behavior is identical whether online or offline
- No sync-related indicators, banners, or messages appear (local-born users are always "offline")
- No Firestore operations are attempted regardless of network state

**Pass/Fail:** [ ]

---

#### SYNC-03 | P0 | App never blocks on network for user actions

**Preconditions:** Cloud-born account. App is online.

**Steps:**
1. Enable airplane mode mid-action: start marking an item complete, then toggle airplane mode during the tap
2. Navigate between screens rapidly while toggling airplane mode
3. Open settings and make changes while offline
4. Return to the task list and complete more items

**Expected:**
- No action ever shows a network-dependent spinner or "please wait"
- All writes go to local SQLite first -- the UI updates immediately
- If sync fails silently in the background, no user-visible error interrupts the flow
- The app remains responsive at all times

**Pass/Fail:** [ ]

---

### Push-on-Write -- FR89 (P0)

---

#### SYNC-04 | P0 | Local write is pushed to Firestore asynchronously

**Preconditions:** Cloud-born account. App is online and synced. Have Firestore console or second device available to verify.

**Steps:**
1. Mark an item as Learn complete
2. Observe the sync indicator (if visible)
3. Check Firestore (via console or second device) for the new completion record

**Expected:**
- The completion appears in Firestore within seconds
- The local UI updated immediately (before sync completed)
- No visible delay or spinner during the push

**Pass/Fail:** [ ]

---

#### SYNC-05 | P0 | Offline writes are queued and pushed when connectivity returns

**Preconditions:** Cloud-born account. App is online and synced.

**Steps:**
1. Enable airplane mode
2. Complete 5 items (Learn stage for each)
3. Change a setting (e.g., notification time)
4. Note all changes made while offline
5. Disable airplane mode
6. Wait for sync to complete

**Expected:**
- All 5 completions are pushed to Firestore after connectivity returns
- The setting change is pushed to Firestore
- No data is lost from the offline period
- Sync happens automatically without user action (NFR26)
- The order of operations is preserved

**Pass/Fail:** [ ]

---

#### SYNC-06 | P1 | Extended offline period (hours) -- all queued writes push on reconnect

**Preconditions:** Cloud-born account. App is online and synced.

**Steps:**
1. Enable airplane mode
2. Use the app normally for an extended period (1+ hours if practical, or simulate by making 50+ changes)
3. Complete items, change settings, modify goals
4. Disable airplane mode
5. Wait for sync to complete

**Expected:**
- All queued writes push to Firestore in order
- No writes are dropped or lost due to queue size
- Sync completes without error
- Firestore state matches local SQLite state after sync

**Pass/Fail:** [ ]

---

### Pull-on-Launch -- FR90 (P0)

---

#### SYNC-07 | P0 | App pulls latest data from Firestore on launch

**Preconditions:** Cloud-born account. Make changes on Device B (or via Firestore console) while the app is closed on Device A.

**Steps:**
1. On Device A, force-close the app
2. On Device B, complete 3 items and change a setting
3. Wait for Device B's changes to sync to Firestore
4. Open the app on Device A
5. Check for the 3 completions and the setting change

**Expected:**
- Device A pulls the latest data from Firestore on launch
- The 3 completions from Device B are now visible on Device A
- The setting change is reflected on Device A
- The pull happens in the background -- the app is usable immediately (local data renders first, then updates arrive)

**Pass/Fail:** [ ]

---

#### SYNC-08 | P1 | Pull-on-launch merges with local changes

**Preconditions:** Cloud-born account. Both devices have pending unsynced changes.

**Steps:**
1. On Device A, go offline and complete items A1, A2, A3
2. On Device B, complete items B1, B2, B3 (while online -- these sync to Firestore)
3. Force-close the app on Device A
4. Bring Device A online and open the app
5. Check that all 6 completions (A1-A3 + B1-B3) are present

**Expected:**
- Pull-on-launch merges Firestore data with local pending writes
- All 6 completions are present on Device A
- No completions are lost or duplicated
- Merge-forward applies: if both devices completed the same item, it appears once (not duplicated)

**Pass/Fail:** [ ]

---

#### SYNC-09 | P1 | Pull-on-launch when offline -- app uses local data

**Preconditions:** Cloud-born account. Device is offline.

**Steps:**
1. Force-close the app
2. Enable airplane mode
3. Open the app

**Expected:**
- The app launches normally using local SQLite data
- No error or delay from failed Firestore pull
- All local data is available and functional
- When connectivity returns later, pull will happen automatically

**Pass/Fail:** [ ]

---

### Foreground Listeners -- FR91 (P1)

---

#### SYNC-10 | P1 | Real-time updates from Firestore while app is in foreground

**Preconditions:** Cloud-born account. App is open and online on Device A. Device B is available.

**Steps:**
1. On Device A, have the app open (foregrounded)
2. On Device B, complete an item
3. Wait a few seconds
4. Check Device A for the new completion

**Expected:**
- Device A receives the update in near-real-time via Firestore listener
- The new completion appears on Device A without restarting or manually refreshing
- The UI updates smoothly (no full-screen reload)

**Pass/Fail:** [ ]

---

#### SYNC-11 | P1 | Listeners are paused when app is backgrounded

**Preconditions:** Cloud-born account. App is open and online.

**Steps:**
1. Background the app (press home button)
2. On Device B, make several changes
3. Wait 30 seconds
4. Foreground the app on Device A

**Expected:**
- Listeners were paused while backgrounded (battery efficiency, NFR25/NFR27)
- On foreground resume, the app catches up on missed changes
- All changes from Device B are now reflected on Device A
- No battery drain from maintaining listeners while backgrounded

**Pass/Fail:** [ ]

---

#### SYNC-12 | P2 | Listener reconnection after network interruption

**Preconditions:** Cloud-born account. App is foregrounded and online.

**Steps:**
1. Toggle airplane mode on for 10 seconds, then off
2. On Device B, make changes after Device A reconnects
3. Check Device A for the new changes

**Expected:**
- Listeners re-establish after network returns
- New changes from Device B are received in real-time
- No stale data remains from the disconnection period

**Pass/Fail:** [ ]

---

### Conflict Resolution -- FR92 (P0)

---

#### SYNC-13 | P0 | Completion conflict -- merge-forward (union)

**Preconditions:** Cloud-born account on two devices. Both are currently synced.

**Steps:**
1. On Device A, go offline
2. On Device B, go offline
3. On Device A, complete items X1, X2, X3 (Learn stage)
4. On Device B, complete items X4, X5, X6 (Learn stage)
5. Bring Device A online and wait for sync
6. Bring Device B online and wait for sync
7. Check both devices

**Expected:**
- Both devices end up with all 6 completions (X1-X6)
- Merge-forward (union) ensures: if either side says "done", it's done
- No completions are lost
- Bookmarks on both devices reflect the merged state

**Pass/Fail:** [ ]

---

#### SYNC-14 | P0 | Same item completed on both devices offline -- no duplicate

**Preconditions:** Cloud-born account on two devices. Item Y1 is pending on both devices.

**Steps:**
1. Take both devices offline
2. On Device A, complete Y1 (Learn stage)
3. On Device B, complete Y1 (Learn stage)
4. Bring Device A online, wait for sync
5. Bring Device B online, wait for sync
6. Check completion history on both devices

**Expected:**
- Y1 appears as completed exactly once (not duplicated)
- Merge-forward handles the overlap: "done" + "done" = "done" (once)
- Points are awarded once, not twice
- No error or conflict dialog is shown to the user

**Pass/Fail:** [ ]

---

#### SYNC-15 | P0 | Settings conflict -- LWW by updatedAt

**Preconditions:** Cloud-born account on two devices. Both synced.

**Steps:**
1. On Device A, go offline at time T1
2. On Device B, change the notification time to 8:00 PM at time T2 (T2 > T1)
3. On Device A (still offline), change the notification time to 6:00 PM at time T3 (T3 > T2)
4. Bring Device A online
5. Wait for sync to complete on both devices

**Expected:**
- The final value is 6:00 PM (Device A's change wins because T3 > T2)
- LWW by `updatedAt` resolves the conflict
- Both devices converge to the same setting value
- No conflict dialog is shown

**Pass/Fail:** [ ]

---

#### SYNC-16 | P1 | Streak conflict -- event log merge

**Preconditions:** Cloud-born account on two devices. User has a 10-day streak.

**Steps:**
1. Take both devices offline
2. On Device A, complete an item (extending streak to day 11 with event timestamp TA)
3. On Device B, complete an item (extending streak to day 11 with event timestamp TB)
4. Bring both devices online

**Expected:**
- Streak events from both devices are appended to the event log
- Each device independently reduces the event log to state
- Both devices converge to the same streak count (11 days)
- No duplicate streak day is counted
- No streak data is lost

**Pass/Fail:** [ ]

---

#### SYNC-17 | P1 | XP conflict -- event log merge

**Preconditions:** Cloud-born account on two devices. Both synced. Current XP is known.

**Steps:**
1. Take both devices offline
2. On Device A, earn 30 XP (3 completions at 10 points each)
3. On Device B, earn 20 XP (2 completions at 10 points each)
4. Bring both devices online and wait for sync

**Expected:**
- XP events from both devices are appended to the event log
- If the completions were for different items: total XP increases by 50 (30 + 20)
- If any completions overlapped (same item on both devices): merge-forward deduplicates, so XP reflects unique completions only
- Both devices converge to the same XP total

**Pass/Fail:** [ ]

---

### Retry with Backoff -- FR93 (P1)

---

#### SYNC-18 | P1 | Failed sync retries with exponential backoff

**Preconditions:** Cloud-born account. Simulate unreliable connectivity (toggle airplane mode rapidly or use a throttled network).

**Steps:**
1. Make a completion while connectivity is unstable
2. Observe the sync behavior (logs or sync indicator)
3. Allow the sync to eventually succeed

**Expected:**
- The sync engine retries after failure
- Retry intervals increase (exponential backoff, not rapid-fire retries)
- The sync eventually succeeds when stable connectivity returns
- No data is lost during the retry period
- Battery is not drained by aggressive retries (NFR25, NFR27)

**Pass/Fail:** [ ]

---

#### SYNC-19 | P2 | Backoff respects Android battery saver mode

**Preconditions:** Cloud-born account with pending unsynced changes. Device has battery saver mode available.

**Steps:**
1. Go offline and make several changes
2. Enable Android battery saver mode
3. Re-enable connectivity
4. Observe sync behavior

**Expected:**
- Sync still occurs but may be throttled or deferred per battery saver policies (NFR27)
- No aggressive background network activity that violates battery saver
- Data is not lost -- sync completes when battery saver is disabled or device is charging

**Pass/Fail:** [ ]

---

### Device Restore -- FR94 (P0)

---

#### SYNC-20 | P0 | New device sign-in restores full state from Firestore

**Preconditions:** Cloud-born account with extensive data (50+ completions, streaks, goals, multiple curricula). All data is synced to Firestore.

**Steps:**
1. Install the app on a new device (or clear app data to simulate)
2. Sign in with the cloud-born account credentials
3. Wait for the initial data pull to complete
4. Verify all data

**Expected:**
- All completions are restored (count matches the original device)
- All bookmark positions are correct
- Streak count and history are intact
- XP/points total is correct
- Goals and deadlines are preserved
- Curriculum activation states are restored
- Mode setting (child/adult) is restored
- Notification preferences are restored
- No data is missing or corrupted

**Pass/Fail:** [ ]

---

#### SYNC-21 | P1 | Device restore with Google Sign-In

**Preconditions:** Cloud-born account created with Google Sign-In. Data synced to Firestore.

**Steps:**
1. Install the app on a new device
2. Sign in using Google Sign-In
3. Wait for data restore
4. Verify all data matches the original device

**Expected:**
- Google Sign-In authenticates successfully
- Full data restore from Firestore occurs
- All data matches the original device (same checks as SYNC-20)

**Pass/Fail:** [ ]

---

#### SYNC-22 | P1 | Device restore is usable before full sync completes

**Preconditions:** Cloud-born account with large amounts of data.

**Steps:**
1. Install the app on a new device and sign in
2. Immediately begin using the app before the full sync finishes
3. Navigate to the task list, complete an item, browse content

**Expected:**
- The app is usable immediately with whatever local data exists (even if minimal)
- Data appears progressively as the sync pulls it down
- User actions during sync are not lost -- local writes are preserved
- No crash or undefined behavior from interacting during sync

**Pass/Fail:** [ ]

---

### Local-Born No Sync (P0)

---

#### SYNC-23 | P0 | Local-born account performs zero Firestore operations

**Preconditions:** Local-born account. Device is online.

**Steps:**
1. Use the app normally: complete items, change settings, browse content
2. Monitor network activity (via Android developer tools or Firestore console)
3. Check that no Firestore reads or writes occur

**Expected:**
- Zero Firestore operations are attempted
- No sync indicator is shown
- No "offline" banner is shown (local-born users are always "offline" -- it's their normal state)
- The app functions identically to a cloud-born user's offline experience

**Pass/Fail:** [ ]

---

#### SYNC-24 | P0 | Local-born account shows persistent "no backup" badge

**Preconditions:** Local-born account.

**Steps:**
1. Navigate to the profile/account area
2. Look for the "no backup" badge or indicator

**Expected:**
- A persistent "no backup" badge is visible in the profile area
- Tapping the badge opens the upgrade-to-cloud flow (see 13-settings.md SET-26 through SET-29)
- The badge is always visible -- not dismissible

**Pass/Fail:** [ ]

---

#### SYNC-25 | P1 | Local-born data loss on app uninstall is expected and warned

**Preconditions:** Local-born account with data.

**Steps:**
1. Note the current data state
2. Uninstall the app
3. Reinstall the app
4. Attempt to sign in with the previous local-born credentials

**Expected:**
- All local data is gone (SQLite database was deleted with the app)
- Sign-in fails because the local credentials no longer exist
- The user must create a new account
- This behavior was warned about during initial signup (hard warning, acknowledged by user)

**Pass/Fail:** [ ]

---

### Offline UX Surface (P1)

---

#### SYNC-26 | P1 | Cloud-born offline -- subtle top banner appears

**Preconditions:** Cloud-born account. App is online.

**Steps:**
1. Enable airplane mode
2. Observe the app UI

**Expected:**
- A subtle, non-dismissible top banner appears
- Banner text communicates: "Offline -- changes will sync when you're back" (or similar)
- The banner does not obstruct app usage
- All features remain fully functional beneath the banner

**Pass/Fail:** [ ]

---

#### SYNC-27 | P1 | Cloud-born online -- banner disappears when connectivity returns

**Preconditions:** SYNC-26 in progress (offline banner visible).

**Steps:**
1. Disable airplane mode
2. Wait for connectivity to restore and sync to complete
3. Observe the banner

**Expected:**
- The offline banner disappears automatically
- No user action is required to dismiss it
- Sync catches up in the background
- The app transitions smoothly from offline to online state

**Pass/Fail:** [ ]

---

#### SYNC-28 | P1 | Local-born -- no offline banner ever shown

**Preconditions:** Local-born account.

**Steps:**
1. Use the app with airplane mode on
2. Use the app with airplane mode off
3. Toggle repeatedly

**Expected:**
- No offline banner is ever shown for local-born accounts
- "Offline" is their permanent state -- showing a banner would be meaningless noise
- No sync-related UI elements appear at any time

**Pass/Fail:** [ ]

---

### Content DB Lifecycle (P1)

---

#### SYNC-29 | P1 | Content DB decompresses on first launch

**Preconditions:** Fresh install of the app. The APK contains `seed.db.gz` in assets.

**Steps:**
1. Install the app fresh
2. Open the app for the first time
3. After onboarding, navigate to the content browser
4. Browse through the content hierarchy (Mishnayos > Seder > Masechta > Perek)

**Expected:**
- Content DB is decompressed from `seed.db.gz` during first launch
- All content is browsable (no missing sections or empty hierarchies)
- Decompression does not cause an excessively long startup (user sees a progress indicator if needed)
- Content DB is stored as a separate SQLite file from User DB

**Pass/Fail:** [ ]

---

#### SYNC-30 | P1 | Content DB replaced on app update (version bump)

**Preconditions:** App is installed with content schema version N. A new APK is available with content schema version N+1.

**Steps:**
1. Note the current content (e.g., browse to a specific item)
2. Update the app to the new version
3. Open the app after the update
4. Browse the content hierarchy

**Expected:**
- Old Content DB is deleted and replaced with the new bundled version
- All content from the new version is available
- User DB (completions, bookmarks, progress) is unaffected by the content update
- No user data is lost during the content refresh

**Pass/Fail:** [ ]

---

#### SYNC-31 | P1 | Content DB and User DB are separate files

**Preconditions:** App is installed and has been used (completions exist).

**Steps:**
1. Use Android file explorer or `adb` to inspect the app's database directory
2. Verify two separate SQLite files exist (content DB and user DB)

**Expected:**
- Two distinct SQLite database files are present
- Content DB is read-only (no user data written to it)
- User DB contains completions, settings, profiles, etc.
- This separation ensures content updates (blow-and-replace) never affect user data

**Pass/Fail:** [ ]

---

#### SYNC-32 | P2 | Content DB corruption recovery

**Preconditions:** App is installed and functioning. Content DB can be intentionally corrupted (e.g., via `adb` write random bytes to the content DB file).

**Steps:**
1. Corrupt the content DB file
2. Open the app
3. Attempt to browse content

**Expected:**
- The app detects the corruption (SQLite integrity check or read failure)
- The app re-decompresses `seed.db.gz` to restore the content DB
- Content is available again after recovery
- User DB is unaffected -- no completions, bookmarks, or progress is lost
- If recovery fails, a clear error message is shown (not a crash)

**Pass/Fail:** [ ]

---

### Session Persistence -- Cloud-Born (P1)

---

#### SYNC-33 | P1 | Cloud-born session persists offline for extended period

**Preconditions:** Cloud-born account. App is online and synced.

**Steps:**
1. Sign in and verify the session is active
2. Enable airplane mode
3. Use the app over multiple days (or simulate by advancing device clock)
4. Re-open the app each "day"

**Expected:**
- The session remains valid for 30+ days offline
- The user is never forced to re-authenticate while offline
- All app features continue working
- On reconnect, re-authentication happens opportunistically in the background

**Pass/Fail:** [ ]

---

#### SYNC-34 | P2 | Firebase init does not block app startup

**Preconditions:** Cloud-born account. App is closed.

**Steps:**
1. Force-close the app
2. Open the app and measure startup time
3. Compare with airplane-mode startup (no Firebase connection possible)

**Expected:**
- App launches without waiting for `Firebase.initializeApp()` to complete
- Firebase initialization happens in the background after `runApp()`
- Startup time is comparable whether online or offline
- No visible delay from Firebase initialization

**Pass/Fail:** [ ]

---

## Cross-Feature References

| Feature Area | Document | Relationship to Sync |
|---|---|---|
| **Learning & Completions** | 04 - Learning & Completions | Completions are the primary data synced. Merge-forward ensures no completion is ever lost across devices. |
| **Settings** | 13 - Settings | Sign out, account deletion, and upgrade-to-cloud all interact with the sync layer. Settings changes sync via LWW. |
| **Gamification** | 09 - Gamification & Rewards | Streaks and XP use event-log sync with local reduction. Points must converge across devices. |
| **Dashboard** | 08 - Dashboard & Progress | Dashboard reads from local SQLite. After sync, dashboard stats update to reflect merged state. |
| **Onboarding** | 03 - Onboarding | Tier (cloud-born vs local-born) is set during onboarding based on network state. This determines whether sync is ever active. |
| **Catch-Up & Amnesty** | 17 - Catch-Up & Amnesty | Catch-up rescoping syncs via LWW. Existing completions (immutable) are unaffected by rescoping. |
| **Content Browsing** | 07 - Content Browsing | Content DB is bundled and never synced. Content browsing works identically online and offline. |
