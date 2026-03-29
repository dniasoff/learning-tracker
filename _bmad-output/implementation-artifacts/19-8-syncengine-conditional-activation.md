# Story 19.8: SyncEngine Conditional Activation

Status: ready-for-dev

## Story

As a local-only learner,
I want the sync engine to remain completely dormant when I have no cloud account,
so that the app never makes unnecessary network calls, never shows sync errors, and works fully offline without any Firebase dependency at runtime.

## Acceptance Criteria

**AC-1: Three-tier activation**
**Given** the app launches
**When** the user has no cloud account (local-only)
**Then** the SyncEngine is never instantiated (provider returns null)
**And** no Firestore calls, no listeners, no queue operations occur

**Given** the app launches
**When** the user has a cloud account but the device is offline
**Then** the SyncEngine is instantiated but stays in offline mode
**And** writes are queued in the offline queue for later flush
**And** no Firestore listeners are attached

**Given** the app launches
**When** the user has a cloud account and the device is online
**Then** the SyncEngine is fully active with pull-on-launch, push-on-write, and foreground listeners

**AC-2: SyncEngine? nullable provider**
**Given** the syncEngineProvider is accessed
**When** no cloud account exists
**Then** the provider returns `null` (typed as `SyncEngine?`)
**And** all consumers handle the null case gracefully without errors

**AC-3: SyncStatus.localOnly for local-only users**
**Given** a local-only user (no cloud account)
**When** the sync status is queried
**Then** the status is `SyncStatus.localOnly` (a new variant)
**And** sync status UI shows nothing or a subtle "local only" indicator

**AC-4: Offline queue disabled for local-only users**
**Given** a local-only user writes data (completions, bookmarks, etc.)
**When** the write is persisted to SQLite
**Then** no offline queue entry is created
**And** the sync queue table remains empty

**AC-5: pushAllLocalData on first account link**
**Given** a local-only user who has been using the app without an account
**When** they create a cloud account (via Settings > Create Account)
**Then** the SyncEngine activates for the first time
**And** `pushAllLocalData()` pushes all existing local data to Firestore
**And** from that point on, normal sync behavior resumes

**AC-6: Clean activation on account creation**
**Given** the user creates a cloud account mid-session
**When** the auth state changes to cloud-authenticated
**Then** the syncEngineProvider rebuilds and returns a non-null SyncEngine
**And** the SyncLifecycleObserver attaches listeners on the next frame
**And** no app restart is required

## Tasks / Subtasks

### T1: Add SyncStatus.localOnly Variant (AC: 3)

- [ ] Add `localOnly` factory constructor to `SyncStatus` freezed class
- [ ] Regenerate freezed code with `build_runner`
- [ ] Update all `SyncStatus` pattern matches in the codebase to handle `localOnly`

**File:** `lib/features/sync/domain/models/sync_status.dart`

```dart
@freezed
sealed class SyncStatus with _$SyncStatus {
  /// Sync operation is currently in progress.
  const factory SyncStatus.syncing({required DateTime startedAt}) =
      SyncStatusSyncing;

  /// All data is successfully synchronized with Firestore.
  const factory SyncStatus.synced({required DateTime lastSyncedAt}) =
      SyncStatusSynced;

  /// Online but local changes are queued and awaiting push.
  const factory SyncStatus.pending({required int pendingChanges}) =
      SyncStatusPending;

  /// Device is offline. Local changes are queued for sync when online.
  const factory SyncStatus.offline({required int pendingChanges}) =
      SyncStatusOffline;

  /// Sync operation failed with an error.
  const factory SyncStatus.error({
    required String message,
    required DateTime failedAt,
  }) = SyncStatusError;

  /// Local-only mode — no cloud account, sync is dormant.
  const factory SyncStatus.localOnly() = SyncStatusLocalOnly;
}
```

Update every `switch` on `SyncStatus` in the codebase. Search for all pattern matches:

```dart
// Example: wherever SyncStatus is matched exhaustively, add the new case:
case SyncStatusLocalOnly():
  // No-op or display "Local only" indicator
  break;
```

### T2: Make syncEngineProvider Nullable (AC: 1, 2)

- [ ] Change return type from `Provider<SyncEngine>` to `Provider<SyncEngine?>`
- [ ] Gate creation on auth state: return `null` when no cloud account
- [ ] Watch `authStateProvider` so the provider rebuilds on account creation/deletion

**File:** `lib/features/sync/presentation/providers/sync_providers.dart`

Replace the current `syncEngineProvider`:

```dart
/// Provider for SyncEngine — nullable.
///
/// Returns `null` when the user has no cloud account (local-only mode).
/// Returns a fully initialized [SyncEngine] when a Firebase user is
/// authenticated. Rebuilds automatically when auth state changes.
final syncEngineProvider = Provider<SyncEngine?>((ref) {
  // Gate: no Firebase user → no sync engine
  final authStream = ref.watch(authStateProvider);
  final firebaseUser = authStream.valueOrNull;
  if (firebaseUser == null) return null;

  final database = ref.watch(appDatabaseProvider);
  final firestoreDataSource = ref.watch(firestoreDataSourceProvider);
  final offlineQueue = ref.watch(offlineQueueProvider);
  final logger = ref.watch(talkerProvider);
  final connectivityService = ref.watch(connectivityServiceProvider);

  final engine = SyncEngine(
    database: database,
    firestoreDataSource: firestoreDataSource,
    offlineQueue: offlineQueue,
    logger: logger,
    connectivityService: connectivityService,
  );

  // Initialize on creation; surface errors onto the status stream.
  engine.initialize().catchError((Object error, StackTrace stackTrace) {
    // initialize() updates the status stream with an error status on failure,
    // but catchError is needed here so an unhandled async error doesn't crash
    // the isolate when the Future is fire-and-forget.
  });

  // Dispose when provider is disposed (e.g., auth state changes)
  ref.onDispose(() {
    engine.dispose();
  });

  return engine;
});
```

Update the `syncStatusStreamProvider` and `syncStatusProvider` to handle null engine:

```dart
/// Provider for sync status stream.
///
/// Emits [SyncStatus.localOnly] immediately when there is no sync engine,
/// otherwise delegates to the engine's status stream.
final syncStatusStreamProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) {
    return Stream.value(const SyncStatus.localOnly());
  }
  return engine.statusStream;
});

/// Provider for current sync status (from stream).
final syncStatusProvider = Provider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  if (engine == null) {
    return const SyncStatus.localOnly();
  }
  final asyncStatus = ref.watch(syncStatusStreamProvider);
  return asyncStatus.when(
    data: (status) => status,
    loading: () => SyncStatus.syncing(startedAt: DateTime.now()),
    error: (error, _) =>
        SyncStatus.error(message: error.toString(), failedAt: DateTime.now()),
  );
});
```

### T3: Update All SyncEngine Consumers for Null Safety (AC: 2)

- [ ] Update every file that reads `syncEngineProvider` to handle `SyncEngine?`
- [ ] For repository constructors that take `SyncEngine`, change to `SyncEngine?`
- [ ] Guard all sync calls with null-check — local writes always succeed regardless

**Affected files (12 total):**

| File | Change |
|------|--------|
| `lib/features/learning/presentation/providers/completion_providers.dart` | `final syncEngine = ref.watch(syncEngineProvider);` — already typed, but pass `SyncEngine?` to repository |
| `lib/features/learning/presentation/providers/bookmark_providers.dart` | Same pattern |
| `lib/features/learning/presentation/providers/learning_ledger_providers.dart` | Same pattern |
| `lib/features/learning_order/presentation/providers/learning_order_providers.dart` | Same pattern |
| `lib/features/stages/presentation/providers/stage_providers.dart` | Same pattern |
| `lib/features/sync/presentation/providers/restore_providers.dart` | Same pattern |
| `lib/features/learning/data/repositories/completion_repository_impl.dart` | Change `final SyncEngine _syncEngine` to `final SyncEngine? _syncEngine` |
| `lib/features/learning/data/repositories/bookmark_repository_impl.dart` | Same pattern |
| `lib/features/learning/data/repositories/learning_ledger_repository_impl.dart` | Same pattern |
| `lib/features/learning_order/data/repositories/learning_order_repository_impl.dart` | Same pattern |
| `lib/features/scheduler/data/repositories/goal_repository_impl.dart` | Same pattern |
| `lib/features/sync/domain/services/device_restore_service.dart` | Same pattern |

**Pattern for repository changes:**

```dart
class CompletionRepositoryImpl implements CompletionRepository {
  final AppDatabase _database;
  final SyncEngine? _syncEngine;  // <-- nullable
  // ...

  CompletionRepositoryImpl({
    required AppDatabase database,
    required SyncEngine? syncEngine,  // <-- nullable
    // ...
  }) : _database = database,
       _syncEngine = syncEngine,
       // ...

  // Every push call becomes null-safe:
  Future<void> _pushCompletion(Map<String, dynamic> data) async {
    await _syncEngine?.pushCompletion(data);
    // If null, write stays local-only — which is correct behavior
  }
}
```

**Pattern for bookmark repository (fetch also needs guarding):**

```dart
@override
Future<int> syncFromFirestore() async {
  if (_syncEngine == null) return 0; // Local-only, nothing to sync
  final remoteBookmarks = await _syncEngine!.fetchBookmarksFromFirestore();
  for (final remote in remoteBookmarks) {
    await mergeRemoteBookmark(remote);
  }
  return remoteBookmarks.length;
}
```

### T4: Update SyncLifecycleObserver (AC: 1, 6)

- [ ] Remove direct `FirebaseAuth.instance.currentUser` checks
- [ ] Use `syncEngineProvider` nullability as the single gating mechanism
- [ ] Handle mid-session activation when provider rebuilds

**File:** `lib/features/sync/presentation/widgets/sync_lifecycle_observer.dart`

```dart
class SyncLifecycleObserver extends ConsumerStatefulWidget {
  const SyncLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<SyncLifecycleObserver> createState() =>
      _SyncLifecycleObserverState();
}

class _SyncLifecycleObserverState extends ConsumerState<SyncLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Attach listeners if sync engine exists (user has cloud account).
    // No more FirebaseAuth.instance.currentUser check — the engine's
    // existence is the single gating mechanism.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = ref.read(syncEngineProvider);
      engine?.attachListeners();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final engine = ref.read(syncEngineProvider);
    if (engine == null) return; // Local-only user, nothing to manage

    switch (state) {
      case AppLifecycleState.resumed:
        engine.attachListeners();
        break;

      case AppLifecycleState.inactive:
        // On iOS, inactive fires for transient states (notification shade,
        // alerts). Do not detach listeners here.
        break;

      case AppLifecycleState.paused:
        engine.detachListeners();
        break;

      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        engine.detachListeners();
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the provider so the widget rebuilds when sync engine
    // activates (account creation) or deactivates (account deletion).
    // This ensures attachListeners() is called on the new engine.
    final engine = ref.watch(syncEngineProvider);

    // If engine just became available (account was created mid-session),
    // attach listeners immediately.
    if (engine != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        engine.attachListeners();
      });
    }

    return widget.child;
  }
}
```

### T5: Add pushAllLocalData() Method to SyncEngine (AC: 5)

- [ ] Implement `pushAllLocalData()` — reads all local data from SQLite and pushes to Firestore
- [ ] Called once on first account link (after UID migration completes)
- [ ] Reports progress via the status stream
- [ ] Handles large datasets gracefully (batched pushes)

**File:** `lib/features/sync/data/sync_engine.dart`

```dart
/// Push all local data to Firestore for the first time.
///
/// Called after account creation when a local-only user links a cloud
/// account. Reads all existing data from SQLite and pushes each
/// collection to Firestore. Uses batched operations for large datasets.
///
/// This is a one-time operation — subsequent syncs use the normal
/// push-on-write path.
Future<void> pushAllLocalData() async {
  _logger.info('pushAllLocalData: Starting first-time sync to Firestore');
  _updateStatus(SyncStatus.syncing(startedAt: DateTime.now().toUtc()));

  try {
    // 1. Push all completions
    final completions = await _database.completionDao.getAllCompletions();
    _logger.info(
      'pushAllLocalData: Pushing ${completions.length} completions',
    );
    for (final completion in completions) {
      final data = <String, dynamic>{
        'curriculum_id': completion.curriculumId,
        'content_item_id': completion.sefariaRef,
        'stage_id': completion.stageId,
        'track_type': completion.trackType,
        'completed_at': completion.completedAt.toUtc().toIso8601String(),
        'profile_id': completion.profileId,
      };
      await _firestoreDataSource.pushCompletion(data);
    }

    // 2. Push all bookmarks
    final bookmarks = await _database.bookmarkDao.getAllBookmarks();
    _logger.info(
      'pushAllLocalData: Pushing ${bookmarks.length} bookmarks',
    );
    for (final bookmark in bookmarks) {
      await _firestoreDataSource.pushBookmark(bookmark.toFirestoreMap());
    }

    // 3. Push streak data
    final streak = await _database.streakDao.getStreak();
    if (streak != null) {
      _logger.info('pushAllLocalData: Pushing streak data');
      await _firestoreDataSource.pushStreak(streak.toFirestoreMap());
    }

    // 4. Push all goals
    final goals = await _database.goalDao.getAllGoals();
    _logger.info(
      'pushAllLocalData: Pushing ${goals.length} goals',
    );
    for (final goal in goals) {
      await _firestoreDataSource.pushGoal(goal.toFirestoreMap());
    }

    // 5. Push all rewards
    final rewards = await _database.rewardDao.getAllRewards();
    _logger.info(
      'pushAllLocalData: Pushing ${rewards.length} rewards',
    );
    for (final reward in rewards) {
      await _firestoreDataSource.pushReward(reward.toFirestoreMap());
    }

    // 6. Push all settings (per curriculum)
    final settings = await _database.settingsDao.getAllSettings();
    _logger.info(
      'pushAllLocalData: Pushing ${settings.length} settings documents',
    );
    for (final setting in settings) {
      await _firestoreDataSource.pushSettings(setting.toFirestoreMap());
    }

    // 7. Push all ledger entries
    final ledgerEntries = await _database.learningLedgerDao.getAllEntries();
    _logger.info(
      'pushAllLocalData: Pushing ${ledgerEntries.length} ledger entries',
    );
    for (final entry in ledgerEntries) {
      await _firestoreDataSource.pushLedgerEntry(entry.toFirestoreMap());
    }

    // 8. Push active curricula
    final activeCurricula =
        await _database.activeCurriculaDao.getActiveCurricula();
    if (activeCurricula.isNotEmpty) {
      _logger.info(
        'pushAllLocalData: Pushing ${activeCurricula.length} active curricula',
      );
      await _firestoreDataSource.pushActiveCurricula(
        activeCurricula.map((c) => c.curriculumId).toList(),
      );
    }

    final syncedAt = DateTime.now().toUtc();
    await _persistLastSyncTimestamp(syncedAt);
    _updateStatus(SyncStatus.synced(lastSyncedAt: syncedAt));

    _logger.info('pushAllLocalData: First-time sync completed successfully');
  } catch (e, stackTrace) {
    _logger.error('pushAllLocalData: Failed', e, stackTrace);
    _updateStatus(
      SyncStatus.error(
        message: 'First-time sync failed: $e',
        failedAt: DateTime.now().toUtc(),
      ),
    );
    rethrow;
  }
}
```

### T6: Wire pushAllLocalData into Account Creation Flow (AC: 5, 6)

- [ ] After successful `promoteToCloud()` (or equivalent account creation), call `pushAllLocalData()`
- [ ] Show progress indicator during first-time sync
- [ ] Handle failure gracefully — retry option, or queue remaining data

**Integration point** (exact location depends on Epic 19 auth refactor stories):

```dart
/// Called when a local-only user creates a cloud account.
Future<void> onAccountCreated() async {
  // 1. Auth state changes → syncEngineProvider rebuilds → returns non-null
  // 2. Wait for provider to settle
  await Future<void>.delayed(const Duration(milliseconds: 100));

  // 3. Push all existing local data to Firestore
  final engine = ref.read(syncEngineProvider);
  if (engine != null) {
    await engine.pushAllLocalData();
  }
}
```

### T7: Ensure Offline Queue Is Disabled for Local-Only Users (AC: 4)

- [ ] Verify that when `SyncEngine` is null, no code path calls enqueue methods
- [ ] Since repositories receive `SyncEngine?` and use `?.push*()`, the queue is never touched
- [ ] Confirm with a test that no sync queue entries are created during local-only usage

The offline queue disablement is a natural consequence of T3: when `_syncEngine` is null, `_syncEngine?.pushCompletion(data)` evaluates to `null` (no-op). The push method on SyncEngine is the only code path that calls `_offlineQueue.enqueue*()`, so the queue stays empty.

No changes to `OfflineQueue` itself are needed.

### T8: Tests (AC: 1-6)

- [ ] **Unit test: SyncEngine is null when no Firebase user**
  - Mock `authStateProvider` to emit `null`
  - Assert `syncEngineProvider` returns `null`

- [ ] **Unit test: SyncEngine is created when Firebase user exists**
  - Mock `authStateProvider` to emit a `User`
  - Assert `syncEngineProvider` returns a non-null `SyncEngine`

- [ ] **Unit test: SyncStatus.localOnly when engine is null**
  - Assert `syncStatusProvider` returns `SyncStatus.localOnly()` when no engine

- [ ] **Unit test: Repositories work with null SyncEngine**
  - Create `CompletionRepositoryImpl` with `syncEngine: null`
  - Call `markComplete()` — assert it succeeds (local write only)
  - Assert no sync queue entries created

- [ ] **Unit test: Repositories work with non-null SyncEngine**
  - Create `CompletionRepositoryImpl` with a mock `SyncEngine`
  - Call `markComplete()` — assert `pushCompletion` is called

- [ ] **Unit test: pushAllLocalData pushes all collections**
  - Seed local DB with test data (completions, bookmarks, streak, goals, etc.)
  - Call `pushAllLocalData()`
  - Verify each Firestore push method was called with correct data
  - Verify status transitions: syncing → synced

- [ ] **Unit test: pushAllLocalData handles errors gracefully**
  - Mock Firestore to throw on one push
  - Assert status becomes `SyncStatus.error`
  - Assert error is rethrown for caller to handle

- [ ] **Unit test: SyncLifecycleObserver no-ops when engine is null**
  - Simulate lifecycle events with null engine
  - Assert no crashes, no Firestore calls

- [ ] **Unit test: SyncLifecycleObserver attaches listeners when engine becomes non-null**
  - Start with null engine (local-only)
  - Simulate auth state change → engine becomes non-null
  - Assert `attachListeners()` is called on next frame

- [ ] **Unit test: SyncStatus exhaustive matching**
  - Write a switch that covers all 6 variants including `localOnly`
  - Ensure no analyzer warnings about non-exhaustive switches

- [ ] **Integration test: Full local-only lifecycle**
  - Launch app with no account
  - Complete items, set bookmarks, earn rewards
  - Assert sync queue is empty throughout
  - Assert sync status stays `localOnly`

- [ ] **Integration test: Local-only → account creation → first sync**
  - Use app locally, accumulate data
  - Create account
  - Assert `pushAllLocalData()` runs
  - Assert all local data appears in Firestore mock
  - Assert normal sync resumes after first push

## Dev Notes

### Architecture

- **Dependencies:** Requires auth abstraction layer from Epic 19 stories (auth state notifier that distinguishes local vs cloud accounts). If `authStateProvider` already emits `null` for local users, this story can proceed as-is. Otherwise, coordinate with the auth refactor story.
- **Core principle:** The sync engine's existence (non-null) is the SINGLE gating mechanism. No more scattered `FirebaseAuth.instance.currentUser` checks in widgets or repositories.
- **Backwards compatible:** Existing cloud users see zero behavior change — the provider returns non-null for them just as it effectively did before.

### Three-Tier Activation Model

```
Tier 1: No Account (local-only)
  syncEngineProvider → null
  syncStatusProvider → SyncStatus.localOnly()
  All writes → SQLite only, no queue
  SyncLifecycleObserver → no-op on all lifecycle events
  Firestore → never touched

Tier 2: Account + Offline
  syncEngineProvider → SyncEngine (initialized, offline mode)
  syncStatusProvider → SyncStatus.offline(pendingChanges: N)
  Writes → SQLite + offline queue
  SyncLifecycleObserver → does not attach listeners (engine guards this)
  Firestore → queued for later

Tier 3: Account + Online
  syncEngineProvider → SyncEngine (fully active)
  syncStatusProvider → SyncStatus.synced / syncing / pending
  Writes → SQLite + immediate Firestore push
  SyncLifecycleObserver → attaches/detaches listeners on lifecycle
  Firestore → real-time listeners + push-on-write + pull-on-launch
```

### Key Invariant: Local Writes Never Fail Due to Sync

The null-safe `_syncEngine?.push*()` pattern ensures that local SQLite writes ALWAYS succeed regardless of sync engine state. If sync is null (no account), the push is silently skipped. If sync is present but offline, the push queues. If sync is present and online, the push fires immediately. The local write path is never blocked.

### pushAllLocalData Design Decisions

1. **Why not use the offline queue?** Queuing all local data into `sync_queue` then flushing would work but is wasteful — the queue would grow unboundedly for users with weeks of local data, payloads become stale, and the 5-retry dead-letter mechanism could permanently lose data. Direct push is simpler and more reliable.

2. **Batching:** For users with thousands of completions, individual Firestore writes could be slow. Future optimization: use Firestore `writeBatch` to push up to 500 docs per batch. For this story, sequential pushes are acceptable (first-time sync is expected to take a few seconds).

3. **Idempotency:** The push methods use `set()` with merge semantics or append-only collections, so calling `pushAllLocalData()` twice is safe — duplicates are handled by the existing merge logic.

4. **Progress:** The status stream emits `syncing` during the push. A future enhancement could add a progress variant (`SyncStatus.syncing(progress: 0.5)`) but that is out of scope for this story.

### What NOT to Change

- `OfflineQueue` class itself — no changes needed. It is only reached via `SyncEngine.push*()` methods, which are not called when engine is null.
- `FirestoreDataSource` — no changes needed. It is only used by `SyncEngine`.
- `ConnectivityService` — no changes needed. Only used by `SyncEngine` internally.
- `SyncEngine` internals (merge logic, listener management, reconnect behavior) — unchanged. This story only affects engine CREATION and the null-safety wrapper around it.

### Key Files

| File | Action |
|------|--------|
| `lib/features/sync/domain/models/sync_status.dart` | Modify — add `localOnly` variant |
| `lib/features/sync/presentation/providers/sync_providers.dart` | Modify — nullable provider, status providers |
| `lib/features/sync/presentation/widgets/sync_lifecycle_observer.dart` | Modify — remove FirebaseAuth check, null-safe engine |
| `lib/features/sync/data/sync_engine.dart` | Modify — add `pushAllLocalData()` method |
| `lib/features/learning/data/repositories/completion_repository_impl.dart` | Modify — `SyncEngine?` nullable field |
| `lib/features/learning/data/repositories/bookmark_repository_impl.dart` | Modify — `SyncEngine?` nullable field |
| `lib/features/learning/data/repositories/learning_ledger_repository_impl.dart` | Modify — `SyncEngine?` nullable field |
| `lib/features/learning_order/data/repositories/learning_order_repository_impl.dart` | Modify — `SyncEngine?` nullable field |
| `lib/features/scheduler/data/repositories/goal_repository_impl.dart` | Modify — `SyncEngine?` nullable field |
| `lib/features/sync/domain/services/device_restore_service.dart` | Modify — `SyncEngine?` nullable field |
| `lib/features/learning/presentation/providers/completion_providers.dart` | Modify — pass nullable engine |
| `lib/features/learning/presentation/providers/bookmark_providers.dart` | Modify — pass nullable engine |
| `lib/features/learning/presentation/providers/learning_ledger_providers.dart` | Modify — pass nullable engine |
| `lib/features/learning_order/presentation/providers/learning_order_providers.dart` | Modify — pass nullable engine |
| `lib/features/stages/presentation/providers/stage_providers.dart` | Modify — pass nullable engine |
| `lib/features/sync/presentation/providers/restore_providers.dart` | Modify — pass nullable engine |

### Risk: Exhaustive Switch Breakage

Adding `SyncStatus.localOnly` to the freezed union will cause compile errors everywhere `SyncStatus` is pattern-matched without a `localOnly` case. This is intentional — the compiler enforces that every consumer handles the new state. Search for all `switch` statements on `SyncStatus` and add the new case before running tests.

### References

- [Source: _bmad-output/planning-artifacts/offline-first-analysis-2026-03-27.md — Section 3: Target Architecture]
- [Source: _bmad-output/planning-artifacts/local-first-auth-abstraction-layer.md — Section 6: SyncEngine Conditional Activation]
- [Source: _bmad-output/planning-artifacts/offline-first-analysis-2026-03-27.md — Section 3.3: Optional Sync User Journey]

## Dev Agent Record

### Agent Model Used

_To be filled during implementation_

### Debug Log References

### Completion Notes List

### File List
