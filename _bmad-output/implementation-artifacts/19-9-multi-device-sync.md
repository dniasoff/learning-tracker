# Story 19.9: Multi-Device Sync & Efficient Real-Time Sync

Status: ready-for-dev

## Story

As a learner using the app on multiple devices,
I want my learning progress to stay in sync across all my devices efficiently,
so that I can switch between phone and tablet without losing data or draining battery.

## Acceptance Criteria

**AC-1: Device B receives Device A completions in real time**
**Given** Device A is the primary device with existing data
**And** Device B is a newly signed-in device that has completed restore
**When** the user marks an item complete on Device A
**Then** Device B receives the completion within 5 seconds via foreground listener
**And** the completion is merged into Device B's local DB using append-only strategy (no duplicates)

**AC-2: Device B receives Device A bookmark/settings changes via LWW**
**Given** Device A updates a bookmark (advances to next content item)
**When** Device B receives the bookmark update via foreground listener
**Then** Device B applies the update only if the remote `updated_at` is newer than local
**And** if local is newer, the remote update is discarded (last-write-wins)

**AC-3: Bidirectional sync — Device B writes propagate to Device A**
**Given** Device B marks a completion or updates a bookmark
**When** Device A has foreground listeners attached
**Then** Device A receives and merges the update using the same merge strategies
**And** no data is lost or duplicated

**AC-4: RestoreGuard skips for local-only (unauthenticated) users**
**Given** the user has never signed in (local-only mode, no Firebase auth)
**When** the app navigates through RestoreGuard
**Then** the guard resolves immediately without checking Firestore
**And** no restore screen is shown

**AC-5: RestoreGuard handles partial-data devices correctly**
**Given** Device B has some local data (e.g., user started fresh then signed in)
**When** RestoreGuard runs
**Then** it detects the device is NOT new (local data exists)
**And** normal pull-on-launch sync merges any missing remote data additively

**AC-6: Foreground listeners attach/detach on lifecycle**
**Given** the app transitions between foreground and background
**When** the app enters foreground
**Then** `SyncEngine.attachListeners()` is called and 8 Firestore snapshot listeners are active
**When** the app enters background
**Then** `SyncEngine.detachListeners()` cancels all 8 subscriptions to save quota and battery

**AC-7: Quota degradation fallback**
**Given** Firestore returns 3+ consecutive listener errors (quota exceeded)
**When** the error threshold is reached
**Then** all listeners are detached (`_quotaDegraded = true`)
**And** the app falls back to pull-on-launch-only sync
**And** a user-visible status message explains sync is degraded
**And** on next reconnect, `_quotaDegraded` is reset and listeners re-attempt

**AC-8: Battery-efficient offline queue flush**
**Given** the device reconnects after being offline
**When** the offline queue is flushed
**Then** in normal mode, all queued operations flush immediately
**And** in battery-saver mode, operations flush in batches of 5 with delays between batches
**And** flush uses exponential backoff on individual failures (max 5 retries per item)

**AC-9: Concurrent merge guard prevents data corruption**
**Given** a foreground listener fires while a pull-on-launch merge is in progress
**When** the listener callback runs for the same collection (e.g., completions)
**Then** the callback is skipped (`_mergingCompletions` guard returns early)
**And** no duplicate inserts or race conditions occur

**AC-10: Push-on-write with offline fallback**
**Given** the user completes an item while offline
**When** the completion is written to the local DB
**Then** the push is queued in the offline queue (SQLite `sync_queue` table)
**And** when connectivity returns, the queue flushes automatically via `_onReconnect()`

## Tasks / Subtasks

### T1: Audit & Harden Append-Only Merge for Completions and Ledger (AC: 1, 3, 9)

- [ ] Review `_mergeCompletions()` in `sync_engine.dart`:
  - Confirm composite-key uniqueness check: `completionExists(curriculumId, sefariaRef, stageId, trackType, completedAt)`
  - Verify this prevents duplicates even when the same completion arrives from both pull-on-launch AND foreground listener in quick succession
  - Add integration test: simulate listener firing during active pull-on-launch merge
- [ ] Review `_mergeLedgerEntries()`:
  - Confirm composite-key uniqueness check: `entryExists(profileId, curriculumId, unitIdentifier, trackType, completedAt)`
  - Same concurrency test as completions
- [ ] Verify merge guard booleans (`_mergingCompletions`, `_mergingLedgerEntries`) prevent re-entrant calls:
  - Trace: `_onCompletionsUpdate` checks `if (_mergingCompletions) return;` before proceeding
  - Confirm this is sufficient for Dart's single-threaded async model (it is, since Dart is cooperative)
- [ ] Add stress test: push 100 completions from Device A rapidly, verify Device B receives all 100 with zero duplicates

### T2: Audit & Harden LWW Merge for Bookmarks, Settings, Goals, Rewards (AC: 2, 3)

- [ ] Review `_mergeBookmarks()`:
  - Confirm `upsertBookmark()` DAO method compares `updated_at` timestamps
  - Verify the DAO only updates if `remote.updated_at > local.updated_at`
  - Trace the Firestore document ID format: `{curriculumId}_{trackType}` (deterministic, so upserts work)
- [ ] Review `_mergeSettings()`:
  - Confirm LWW comparison: `_getSettingsTimestamp(curriculumId)` vs `remote.updated_at`
  - Verify `_mergeStudyDayConfig()` also respects LWW
- [ ] Review `_mergeGoals()`:
  - Confirm `upsertGoal()` DAO compares `updated_at`
- [ ] Review `_mergeRewards()`:
  - Confirm `upsertReward()` DAO compares `updated_at` (or `earned_at` for earn state)
- [ ] Add test: Device A and Device B both update the same bookmark within 1 second — the one with later `updated_at` wins on both devices after sync
- [ ] Add test: Device A updates settings, Device B has older settings — Device B gets updated after listener fires

### T3: RestoreGuard Improvements for Local-Only & Partial-Data (AC: 4, 5)

- [ ] Modify `RestoreGuard` to skip entirely when user is not authenticated:
  - Current guard checks `completions.isEmpty && profiles.isEmpty`
  - Add early-exit: if `FirebaseAuth.instance.currentUser == null`, call `resolver.next()` immediately
  - This prevents unnecessary DB queries for local-only users
- [ ] Handle partial-data scenario:
  - Current logic: if local has ANY completions or profiles, guard passes through
  - This is correct for the "started fresh then signed in" case — pull-on-launch handles the merge
  - Add unit test confirming guard passes when local has 1 completion but 0 profiles
- [ ] Add unit test: unauthenticated user never sees restore screen
- [ ] Add unit test: `markRestoreComplete()` caches `_isNewDevice = false` so guard never re-checks

### T4: Foreground Listener Lifecycle Management (AC: 6, 7)

- [ ] Verify `attachListeners()` is called on app resume (foreground):
  - Trace the `WidgetsBindingObserver` or `AppLifecycleListener` that triggers this
  - Confirm all 8 listeners are attached: completions, bookmarks, settings, streak, goals, rewards, activeCurricula, ledger
- [ ] Verify `detachListeners()` is called on app pause (background):
  - Confirm all 8 `StreamSubscription`s are cancelled
  - Confirm subscription references are set to `null` after cancel
- [ ] Verify quota degradation path:
  - `_handleListenerError` increments `_consecutiveListenerErrors`
  - At `quotaErrorThreshold` (3), `_quotaDegraded = true` and `detachListeners()` is called
  - `attachListeners()` early-exits when `_quotaDegraded == true`
  - On reconnect (`_onReconnect`), `_quotaDegraded` is reset to `false` and listeners re-attach
- [ ] Add test: simulate 3 consecutive listener errors, verify listeners are detached
- [ ] Add test: after quota degradation, verify `_onReconnect()` resets and re-attaches
- [ ] Add test: verify `attachListeners()` is idempotent (calling twice does not create duplicate subscriptions)

### T5: Offline Queue & Battery-Efficient Flush (AC: 8, 10)

- [ ] Review `OfflineQueue.flush()`:
  - Verify it processes items in FIFO order
  - Verify `maxRetries` (5) is respected — items exceeding max retries are marked dead
  - Verify exponential backoff formula (confirm `dart:math` `pow(2, attempt)` or similar)
- [ ] Review battery-saver mode integration:
  - `_onReconnect()` checks `_isBatterySaverMode` and passes `batchSize: 5` to `flush()`
  - Verify `flush(batchSize:)` processes only N items per batch, then yields control
  - Confirm there is a delay between batches to avoid network bursts
- [ ] Review push-on-write offline path:
  - Each `push*` method checks `!_isOnline || _pushSuppressed`
  - If offline, enqueues to `OfflineQueue` via `enqueue*()`
  - Verify all 8 data types have enqueue methods: completion, bookmark, settings, streak, goal, reward, activeCurricula, ledgerEntry
- [ ] Add test: enqueue 20 items offline, reconnect in battery-saver mode, verify flush processes in batches of 5
- [ ] Add test: item fails 5 times with exponential backoff, verify it is marked dead and not retried

### T6: Multi-Device Integration Scenario Tests (AC: 1-3, 9, 10)

- [ ] **Scenario: New device full restore then real-time sync**
  1. Device A has 50 completions, 3 bookmarks, 2 settings, 1 goal
  2. Device B signs in → `RestoreGuard` redirects to restore screen
  3. `DeviceRestoreService.restore()` runs → pulls all data → imports curricula
  4. After restore, Device B attaches foreground listeners
  5. Device A marks a new completion → Device B receives it via listener within 5s
  6. Verify Device B has 51 completions, same bookmarks/settings/goals
- [ ] **Scenario: Simultaneous edits on two devices**
  1. Device A and Device B both have synced data
  2. Device A updates bookmark for curriculum X to item 50 at T=1
  3. Device B updates same bookmark to item 45 at T=2 (user went back)
  4. After sync: both devices should have item 45 (Device B's write is later)
  5. Verify via LWW: `updated_at` from Device B > Device A
- [ ] **Scenario: Offline gap then merge**
  1. Device A goes offline, marks 5 completions (queued)
  2. Device B marks 3 different completions (pushed immediately)
  3. Device A comes back online → queue flushes 5 completions
  4. Device A's listener receives Device B's 3 completions
  5. Both devices end up with 8 new completions, zero duplicates
- [ ] **Scenario: Push-permission-denied suppression**
  1. Firestore rules reject pushes (simulated)
  2. After 3 consecutive PERMISSION_DENIED errors, `_pushSuppressed` becomes true
  3. Subsequent pushes silently queue without attempting Firestore write
  4. On reconnect, suppression resets and queued items retry

### T7: Streak Cross-Device Consistency (AC: 1, 3)

- [ ] Verify streak is computed locally from completions (not synced as truth):
  - `_mergeStreak()` is a no-op — streak doc is a cache, not source of truth
  - After completions merge, local streak recalculation must run
  - Verify streak provider invalidation happens after completion merge
- [ ] Add test: Device A has 5-day streak, Device B restores → after completion merge, Device B computes same 5-day streak locally

### T8: Active Curricula Cross-Device Sync (AC: 1, 3)

- [ ] Review `_mergeActiveCurricula()`:
  - Currently additive only (activates remote curricula not present locally)
  - Does NOT deactivate local curricula missing from remote — this is intentional (prevent accidental data loss)
  - Verify `CurriculumId.values` mapping handles all known curricula
- [ ] Verify `listenToActiveCurricula()` stream triggers `_onActiveCurriculaUpdate`
- [ ] Add test: Device A activates a new curriculum → Device B receives and activates it
- [ ] Document: deactivation is NOT synced (user must deactivate on each device manually — safe default)

### T9: Curriculum Import Metadata for Cross-Device Skip (AC: 1)

- [ ] Review `FirestoreDataSource.pushCurriculumImportMetadata()` / `fetchCurriculumImportMetadata()`:
  - Stored at `users/{uid}/profiles/{profileId}/curriculum_imports/{curriculumId}`
  - Allows Device B to detect that curriculum content was already imported by Device A
  - `DeviceRestoreService` uses `CurriculumImportService.importAll()` which should check this metadata
- [ ] Verify `CurriculumImportService` checks Firestore metadata before re-importing from bundled assets
- [ ] Add test: Device A imports Mishnah, pushes metadata → Device B restore skips Sefaria import, uses bundled content

## Dev Notes

### Architecture

- **D4 Hybrid Push/Pull**: The existing sync architecture already supports multi-device via push-on-write, pull-on-launch, and foreground listeners. This story hardens and tests these paths for actual multi-device scenarios.
- **No new infrastructure required** — all merge strategies (append-only, LWW) and listener plumbing already exist in `SyncEngine`. This story is primarily about hardening, edge-case coverage, and efficiency.
- **Single-threaded safety**: Dart's cooperative async model means merge guards (`_mergingCompletions` etc.) are sufficient to prevent re-entrant merges. No mutexes needed.

### Merge Strategy Summary

| Data Type | Firestore Path | Strategy | ID Format |
|-----------|---------------|----------|-----------|
| Completions | `users/{uid}/profiles/{pid}/completions/{autoId}` | Append-only (composite key dedup) | Auto-generated |
| Learning Ledger | `users/{uid}/profiles/{pid}/learning_ledger/{autoId}` | Append-only (composite key dedup) | Auto-generated |
| Bookmarks | `users/{uid}/profiles/{pid}/bookmarks/{curriculumId}_{trackType}` | LWW by `updated_at` | Deterministic |
| Settings | `users/{uid}/profiles/{pid}/settings/{curriculumId}` | LWW by `updated_at` | Deterministic |
| Goals | `users/{uid}/profiles/{pid}/goals/{id}` | LWW by `updated_at` | From local ID |
| Rewards | `users/{uid}/profiles/{pid}/rewards/{id}` | LWW by `updated_at` | From local ID |
| Streak | `users/{uid}/profiles/{pid}/streak/data` | No-op (derived from completions) | Single doc |
| Active Curricula | `users/{uid}/profiles/{pid}/active_curricula/data` | Additive-only (no deactivation sync) | Single doc |
| Profile | `users/{uid}/profile/data` | LWW by `updated_at` | Single doc (account-level) |
| Curriculum Imports | `users/{uid}/profiles/{pid}/curriculum_imports/{curriculumId}` | Metadata cache | Deterministic |

### Multi-Device Flow: Device A (Primary) to Device B (New)

```
Device B sign-in:
  1. FirebaseAuth succeeds → user authenticated
  2. RestoreGuard detects empty local DB → redirects to DeviceRestoreScreen
  3. DeviceRestoreService.restore():
     a. SyncEngine.pullOnLaunch() — fetches all 8 collections in parallel
     b. Merge into local SQLite:
        - Completions: append-only insert (composite key dedup)
        - Bookmarks: LWW upsert
        - Settings: LWW with stage re-import
        - Goals/Rewards: LWW upsert
        - Streak: no-op (will be computed from completions)
        - Profile: LWW upsert
     c. Fetch active curricula list
     d. Import bundled content for each active curriculum
  4. RestoreGuard.markRestoreComplete() → guard caches _isNewDevice = false
  5. SyncEngine.attachListeners() — 8 snapshot listeners active
  6. Real-time sync begins: any change on Device A arrives within seconds
```

### RestoreGuard Decision Matrix

| Auth State | Local Data | Guard Behavior |
|------------|-----------|----------------|
| Not authenticated | Any | Pass through immediately (no Firestore, no restore) |
| Authenticated | Empty DB | Redirect to DeviceRestoreScreen |
| Authenticated | Has completions OR profiles | Pass through (pull-on-launch handles merge) |
| Authenticated | `_isNewDevice == false` (cached) | Pass through immediately (no DB query) |

### Foreground Listener Architecture

```
App Foreground:
  SyncEngine.attachListeners()
  ├── completionsSubscription   → _onCompletionsUpdate  → _mergeCompletions (append-only)
  ├── bookmarksSubscription     → _onBookmarksUpdate    → _mergeBookmarks (LWW)
  ├── settingsSubscription      → _onSettingsUpdate     → _mergeSettings (LWW)
  ├── streakSubscription        → _onStreakUpdate       → _mergeStreak (no-op)
  ├── goalsSubscription         → _onGoalsUpdate        → _mergeGoals (LWW)
  ├── rewardsSubscription       → _onRewardsUpdate      → _mergeRewards (LWW)
  ├── activeCurriculaSubscription → _onActiveCurriculaUpdate → _mergeActiveCurricula (additive)
  └── ledgerSubscription        → _onLedgerUpdate       → _mergeLedgerEntries (append-only)

App Background:
  SyncEngine.detachListeners()
  └── All 8 subscriptions cancelled, references nulled

Quota Degradation (3+ consecutive errors):
  _quotaDegraded = true → detachListeners()
  └── Fallback: pull-on-launch only until next reconnect resets
```

### Offline Queue Architecture

```
Push attempt while offline:
  pushCompletion() → !_isOnline → OfflineQueue.enqueueCompletion()
  pushBookmark()   → !_isOnline → OfflineQueue.enqueueBookmark()
  pushSettings()   → !_isOnline → OfflineQueue.enqueueSettings()
  ... (all 8 types)

On reconnect:
  _onReconnect()
  ├── Reset: _consecutiveListenerErrors = 0, _quotaDegraded = false
  ├── Flush queue: OfflineQueue.flush(batchSize: 5 if battery-saver, null otherwise)
  │   ├── FIFO order, exponential backoff on failure
  │   └── maxRetries = 5 per item, dead-lettered after that
  ├── Re-attach listeners
  └── Emit SyncStatus.synced
```

### Efficiency Requirements

1. **Foreground listeners only**: No background listeners — saves Firestore reads and battery
2. **Quota degradation**: Auto-disable listeners after 3 consecutive errors; reset on reconnect
3. **Battery-saver mode**: Queue flush in batches of 5 with delays between batches
4. **Push suppression**: After 3 consecutive PERMISSION_DENIED errors, pushes silently queue (no wasted network requests)
5. **Merge guards**: Single-flight merge per collection prevents redundant DB writes during listener bursts
6. **Paginated fetches**: `fetchCompletions()` etc. use `defaultPageSize = 500` to avoid OOM on large datasets
7. **Idempotent listeners**: `attachListeners()` checks `_listenersAttached` flag — calling twice is safe

### Key Files

| File | Action |
|------|--------|
| `lib/features/sync/data/sync_engine.dart` | Audit — verify all merge strategies, add missing edge-case handling |
| `lib/features/sync/data/firestore_data_source.dart` | Audit — verify listener streams, Firestore paths |
| `lib/features/sync/data/offline_queue.dart` | Audit — verify flush batching, retry logic, dead-letter handling |
| `lib/core/navigation/guards/restore_guard.dart` | Modify — add early-exit for unauthenticated users |
| `lib/features/sync/domain/services/device_restore_service.dart` | Audit — verify full restore flow, curriculum import metadata check |
| `lib/features/sync/presentation/screens/device_restore_screen.dart` | Audit — verify UX during restore |
| `lib/features/sync/presentation/providers/restore_providers.dart` | Audit — verify provider wiring |

### Critical Constraints

- **Completion immutability**: Completions are append-only. The merge MUST NOT update or delete existing completions. Dedup is by composite key only.
- **Ledger immutability**: Same as completions — append-only, composite key dedup.
- **LWW requires UTC timestamps**: All `updated_at` fields must be UTC. `FieldValue.serverTimestamp()` ensures Firestore-side UTC. Local timestamps must also be UTC.
- **No cross-profile sync**: All data is scoped under `profiles/{profileId}`. Device B must use the same `profileId` as Device A.
- **PINs are device-local**: PINs are never synced (FR99). Each device has its own PIN.
- **Streak is derived**: Streak doc in Firestore is a cache. Local truth comes from completions table. After merge, streak must be recomputed locally.

### Investigation Areas

- Does `upsertBookmark()` DAO correctly compare UTC `updated_at` timestamps, or could timezone issues cause incorrect LWW resolution?
- Does `_mergeActiveCurricula()` need to handle deactivation for the archive track feature (Story 18.3)?
- Is there a race between `DeviceRestoreService.restore()` calling `pullOnLaunch()` and the lifecycle observer also calling `pullOnLaunch()` on app resume?
- When completions listener fires with the FULL collection snapshot (not just delta), is the merge loop efficient enough for 10k+ completions? Consider adding a `synced_at` filter.

### References

- [Source: sync_engine.dart — D4 hybrid push/pull architecture]
- [Source: firestore_data_source.dart — Collection structure and merge semantics]
- [Source: restore_guard.dart — New device detection logic]
- [Source: device_restore_service.dart — Full restore orchestration]
- [Source: offline_queue.dart — Queue flush and retry mechanics]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
