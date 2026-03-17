import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:talker/talker.dart';

/// Orchestrates sync between local SQLite and Firestore.
///
/// Implements D4 hybrid push/pull architecture:
/// - **Push-on-write**: Local writes trigger Firestore push (queued if offline)
/// - **Pull-on-launch**: App startup pulls latest data and merges locally
/// - **Foreground listeners**: Real-time sync while app is in foreground
/// - **Offline queue**: Writes are queued when offline, flushed on reconnect
class SyncEngine {
  SyncEngine({
    required AppDatabase database,
    required FirestoreDataSource firestoreDataSource,
    required OfflineQueue offlineQueue,
    required Talker logger,
    required ConnectivityService connectivityService,
  }) : _database = database,
       _firestoreDataSource = firestoreDataSource,
       _offlineQueue = offlineQueue,
       _logger = logger,
       _connectivityService = connectivityService;

  final AppDatabase _database;
  final FirestoreDataSource _firestoreDataSource;
  final OfflineQueue _offlineQueue;
  final Talker _logger;
  final ConnectivityService _connectivityService;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _currentStatus = SyncStatus.synced(
    lastSyncedAt: DateTime.now().toUtc(),
  );
  SyncStatus get currentStatus => _currentStatus;

  StreamSubscription<List<Map<String, dynamic>>>? _completionsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _bookmarksSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _settingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _streakSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _goalsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _rewardsSubscription;

  bool _isOnline = true;
  bool _listenersAttached = false;

  /// Tracks consecutive listener errors for quota monitoring (NFR21).
  int _consecutiveListenerErrors = 0;

  /// Threshold of consecutive errors before disabling listeners.
  static const int quotaErrorThreshold = 3;

  /// Whether listeners have been disabled due to quota exhaustion.
  bool _quotaDegraded = false;

  /// Whether listeners are degraded due to Firebase quota issues.
  bool get isQuotaDegraded => _quotaDegraded;

  // Merge guards to prevent concurrent merges on the same collection (issue #2)
  bool _mergingCompletions = false;
  bool _mergingBookmarks = false;
  bool _mergingSettings = false;

  /// SharedPreferences key for persisted last-sync timestamp.
  static const _lastSyncKey = 'sync_engine_last_synced_at';

  // ========== Lifecycle Methods ==========

  /// Initialize sync engine and pull data on launch.
  Future<void> initialize() async {
    _logger.info('Initializing sync engine');

    // Restore persisted last-sync timestamp (issue #5)
    await _restoreLastSyncTimestamp();

    // Check connectivity before pulling (issue #7)
    final online = await _connectivityService.isOnline;
    setOnlineState(online);

    await pullOnLaunch();
  }

  /// Dispose resources and detach listeners.
  Future<void> dispose() async {
    _logger.info('Disposing sync engine');
    await detachListeners();
    await _statusController.close();
  }

  /// Set online/offline state.
  ///
  /// Called automatically during [initialize] via [ConnectivityService].
  /// When `connectivity_plus` is added to pubspec.yaml, replace the DNS
  /// probe with its stream for instant network-change events.
  void setOnlineState(bool isOnline) {
    if (_isOnline == isOnline) return;

    _isOnline = isOnline;
    _logger.info('Network state changed: ${isOnline ? "online" : "offline"}');

    if (isOnline) {
      _onReconnect();
    } else {
      _onDisconnect();
    }
  }

  /// Attach foreground listeners for real-time sync.
  Future<void> attachListeners() async {
    if (_listenersAttached) {
      _logger.debug('Listeners already attached');
      return;
    }

    if (!_isOnline) {
      _logger.debug('Cannot attach listeners while offline');
      return;
    }

    if (_quotaDegraded) {
      _logger.debug('Listeners disabled due to quota degradation');
      return;
    }

    _logger.info('Attaching foreground listeners');
    _listenersAttached = true;

    _completionsSubscription = _firestoreDataSource
        .listenToCompletions()
        .listen(_onCompletionsUpdate, onError: _handleListenerError);

    _bookmarksSubscription = _firestoreDataSource.listenToBookmarks().listen(
      _onBookmarksUpdate,
      onError: _handleListenerError,
    );

    _settingsSubscription = _firestoreDataSource.listenToSettings().listen(
      _onSettingsUpdate,
      onError: _handleListenerError,
    );

    _streakSubscription = _firestoreDataSource.listenToStreak().listen(
      _onStreakUpdate,
      onError: _handleListenerError,
    );

    _goalsSubscription = _firestoreDataSource.listenToGoals().listen(
      _onGoalsUpdate,
      onError: _handleListenerError,
    );

    _rewardsSubscription = _firestoreDataSource.listenToRewards().listen(
      _onRewardsUpdate,
      onError: _handleListenerError,
    );
  }

  /// Detach foreground listeners (on app background).
  Future<void> detachListeners() async {
    if (!_listenersAttached) {
      _logger.debug('Listeners already detached');
      return;
    }

    _logger.info('Detaching foreground listeners');
    _listenersAttached = false;

    await _completionsSubscription?.cancel();
    await _bookmarksSubscription?.cancel();
    await _settingsSubscription?.cancel();
    await _streakSubscription?.cancel();
    await _goalsSubscription?.cancel();
    await _rewardsSubscription?.cancel();

    _completionsSubscription = null;
    _bookmarksSubscription = null;
    _settingsSubscription = null;
    _streakSubscription = null;
    _goalsSubscription = null;
    _rewardsSubscription = null;
  }

  // ========== Pull-on-Launch ==========

  /// Pull latest data from Firestore on app launch.
  Future<void> pullOnLaunch() async {
    if (!_isOnline) {
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    _updateStatus(SyncStatus.syncing(startedAt: DateTime.now().toUtc()));

    try {
      _logger.info('Pull-on-launch: Fetching data from Firestore');

      // Fetch all data from Firestore in parallel
      final results = await Future.wait([
        _firestoreDataSource.fetchCompletions(),
        _firestoreDataSource.fetchBookmarks(),
        _firestoreDataSource.fetchSettings(),
        _firestoreDataSource.fetchGoals(),
        _firestoreDataSource.fetchRewards(),
        _firestoreDataSource.fetchStreak(),
        _firestoreDataSource.fetchProfile(),
      ]);
      final completions = results[0] as List<Map<String, dynamic>>;
      final bookmarks = results[1] as List<Map<String, dynamic>>;
      final settings = results[2] as List<Map<String, dynamic>>;
      final goals = results[3] as List<Map<String, dynamic>>;
      final rewards = results[4] as List<Map<String, dynamic>>;
      final streak = results[5] as Map<String, dynamic>?;
      final profile = results[6] as Map<String, dynamic>?;

      // Merge with local database
      await _mergeCompletions(completions);
      await _mergeBookmarks(bookmarks);
      await _mergeSettings(settings);
      await _mergeGoals(goals);
      await _mergeRewards(rewards);
      if (streak != null) await _mergeStreak(streak);
      if (profile != null) await _mergeProfile(profile);

      _logger.info('Pull-on-launch completed successfully');
      final syncedAt = DateTime.now().toUtc();
      await _persistLastSyncTimestamp(syncedAt);
      _updateStatus(SyncStatus.synced(lastSyncedAt: syncedAt));
    } catch (e, stackTrace) {
      _logger.error('Pull-on-launch failed', e, stackTrace);
      _updateStatus(
        SyncStatus.error(
          message: e.toString(),
          failedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  // ========== Push-on-Write ==========

  /// Push a completion to Firestore after local write.
  Future<void> pushCompletion(Map<String, dynamic> completion) async {
    if (!_isOnline) {
      await _offlineQueue.enqueueCompletion(completion);
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    try {
      await _firestoreDataSource.pushCompletion(completion);
      _logger.debug('Pushed completion to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning('Failed to push completion, queuing for later', e);
      await _offlineQueue.enqueueCompletion(completion);
      await _emitPendingStatus();
    }
  }

  /// Fetch all bookmarks for the current user from Firestore.
  ///
  /// Used by [BookmarkRepositoryImpl.syncFromFirestore] for pull-on-demand sync.
  Future<List<Map<String, dynamic>>> fetchBookmarksFromFirestore() =>
      _firestoreDataSource.fetchBookmarks();

  /// Push a bookmark to Firestore after local write.
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {
    if (!_isOnline) {
      await _offlineQueue.enqueueBookmark(bookmark);
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    try {
      await _firestoreDataSource.pushBookmark(bookmark);
      _logger.debug('Pushed bookmark to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning('Failed to push bookmark, queuing for later', e);
      await _offlineQueue.enqueueBookmark(bookmark);
      await _emitPendingStatus();
    }
  }

  /// Push settings to Firestore after local write.
  Future<void> pushSettings(Map<String, dynamic> settings) async {
    if (!_isOnline) {
      await _offlineQueue.enqueueSettings(settings);
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    try {
      await _firestoreDataSource.pushSettings(settings);
      _logger.debug('Pushed settings to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning('Failed to push settings, queuing for later', e);
      await _offlineQueue.enqueueSettings(settings);
      await _emitPendingStatus();
    }
  }

  /// Push streak data to Firestore after local write.
  Future<void> pushStreak(Map<String, dynamic> streak) async {
    if (!_isOnline) {
      await _offlineQueue.enqueueStreak(streak);
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    try {
      await _firestoreDataSource.pushStreak(streak);
      _logger.debug('Pushed streak to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning('Failed to push streak, queuing for later', e);
      await _offlineQueue.enqueueStreak(streak);
      await _emitPendingStatus();
    }
  }

  /// Push profile to Firestore after local write.
  Future<void> pushProfile(Map<String, dynamic> profile) async {
    if (!_isOnline) {
      await _offlineQueue.enqueueProfile(profile);
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    try {
      await _firestoreDataSource.pushProfile(profile);
      _logger.debug('Pushed profile to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning('Failed to push profile, queuing for later', e);
      await _offlineQueue.enqueueProfile(profile);
      await _emitPendingStatus();
    }
  }

  /// Push a goal to Firestore after local write.
  Future<void> pushGoal(Map<String, dynamic> goal) async {
    if (!_isOnline) {
      await _offlineQueue.enqueueGoal(goal);
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    try {
      await _firestoreDataSource.pushGoal(goal);
      _logger.debug('Pushed goal to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning('Failed to push goal, queuing for later', e);
      await _offlineQueue.enqueueGoal(goal);
      await _emitPendingStatus();
    }
  }

  /// Push a reward to Firestore after local write.
  Future<void> pushReward(Map<String, dynamic> reward) async {
    if (!_isOnline) {
      await _offlineQueue.enqueueReward(reward);
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    try {
      await _firestoreDataSource.pushReward(reward);
      _logger.debug('Pushed reward to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning('Failed to push reward, queuing for later', e);
      await _offlineQueue.enqueueReward(reward);
      await _emitPendingStatus();
    }
  }

  // ========== Conflict Resolution & Merge ==========

  /// Convert a Firestore Timestamp or ISO string to DateTime.
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  /// Merge completions from Firestore (additive merge per D4).
  ///
  /// Completions are append-only. For each remote completion, check if it
  /// already exists locally by composite key. If not, insert it.
  Future<void> _mergeCompletions(
    List<Map<String, dynamic>> remoteCompletions,
  ) async {
    _logger.debug(
      'Merging ${remoteCompletions.length} completions from Firestore',
    );

    var insertedCount = 0;
    for (final remote in remoteCompletions) {
      try {
        final curriculumId = remote['curriculum_id'] as String?;
        final sefariaRef = remote['content_item_id'] as String?;
        final stageId = remote['stage_id'] as int?;
        final trackType = remote['track_type'] as String?;
        final completedAt = _parseTimestamp(remote['completed_at']);

        if (curriculumId == null ||
            sefariaRef == null ||
            stageId == null ||
            trackType == null ||
            completedAt == null) {
          _logger.warning('Skipping invalid remote completion: $remote');
          continue;
        }

        final exists = await _database.completionDao.completionExists(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          completedAt: completedAt,
        );

        if (!exists) {
          await _database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              curriculumId: curriculumId,
              sefariaRef: sefariaRef,
              stageId: stageId,
              trackType: trackType,
              completedAt: completedAt,
              points: Value(remote['points'] as int? ?? 0),
            ),
          );
          insertedCount++;
        }
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge completion: $e');
      }
    }

    _logger.debug('Inserted $insertedCount new completions from Firestore');
  }

  /// Merge bookmarks from Firestore (last-write-wins per D4).
  ///
  /// For each remote bookmark, upsert into local DB. If local bookmark
  /// is older, update it; otherwise keep the local version.
  Future<void> _mergeBookmarks(
    List<Map<String, dynamic>> remoteBookmarks,
  ) async {
    _logger.debug('Merging ${remoteBookmarks.length} bookmarks from Firestore');

    for (final remote in remoteBookmarks) {
      try {
        final curriculumId = remote['curriculum_id'] as String?;
        final trackType = remote['track_type'] as String?;
        final sefariaRef = remote['content_item_id'] as String?;
        final updatedAt = _parseTimestamp(remote['updated_at']);

        if (curriculumId == null ||
            trackType == null ||
            sefariaRef == null ||
            updatedAt == null) {
          _logger.warning('Skipping invalid remote bookmark: $remote');
          continue;
        }

        await _database.bookmarkDao.upsertBookmark(
          curriculumId: curriculumId,
          trackType: trackType,
          sefariaRef: sefariaRef,
          updatedAt: updatedAt,
        );
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge bookmark: $e');
      }
    }
  }

  /// Merge settings from Firestore (last-write-wins per D4).
  ///
  /// Settings contain stage definitions per curriculum. Only replaces local
  /// stages when the remote `updated_at` is newer than the locally persisted
  /// settings timestamp for that curriculum.
  Future<void> _mergeSettings(List<Map<String, dynamic>> remoteSettings) async {
    _logger.debug('Merging ${remoteSettings.length} settings from Firestore');

    for (final remote in remoteSettings) {
      try {
        final curriculumId = remote['curriculum_id'] as String?;
        final stages = remote['stages'] as List<dynamic>?;
        final remoteUpdatedAt = _parseTimestamp(remote['updated_at']);
        if (curriculumId == null || stages == null) {
          _logger.warning('Skipping invalid remote settings: $remote');
          continue;
        }

        // LWW: compare remote updated_at against local settings timestamp
        if (remoteUpdatedAt != null) {
          final localTs = await _getSettingsTimestamp(curriculumId);
          if (localTs != null && !remoteUpdatedAt.isAfter(localTs)) {
            _logger.debug(
              'Skipping settings for $curriculumId: local is newer or equal',
            );
            continue;
          }
        }

        final companions = stages
            .cast<Map<String, dynamic>>()
            .map(
              (s) => StageDefinitionsCompanion.insert(
                curriculumId: curriculumId,
                stageOrder: s['stage_order'] as int,
                stageName: s['stage_name'] as String,
                delayDays: s['delay_days'] as int,
                isDefault: Value(s['is_default'] as bool? ?? false),
              ),
            )
            .toList();

        await _database.stageDao.replaceStagesForCurriculum(
          curriculumId,
          companions,
        );

        // Persist the remote timestamp as the new local settings timestamp
        if (remoteUpdatedAt != null) {
          await _setSettingsTimestamp(curriculumId, remoteUpdatedAt);
        }
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge settings: $e');
      }
    }
  }

  /// Merge goals from Firestore (last-write-wins per D4).
  ///
  /// For each remote goal, upsert into local DB. If local goal
  /// is older, update it; otherwise keep the local version.
  Future<void> _mergeGoals(List<Map<String, dynamic>> remoteGoals) async {
    _logger.debug('Merging ${remoteGoals.length} goals from Firestore');

    for (final remote in remoteGoals) {
      try {
        final curriculumId = remote['curriculum_id'] as String?;
        final description = remote['description'] as String? ?? '';
        final targetPercent =
            (remote['target_percent'] as num?)?.toDouble() ?? 100.0;
        final targetDate = _parseTimestamp(remote['target_date']);
        final createdAt = _parseTimestamp(remote['created_at']);
        final updatedAt = _parseTimestamp(remote['updated_at']);

        if (curriculumId == null || createdAt == null || updatedAt == null) {
          _logger.warning('Skipping invalid remote goal: $remote');
          continue;
        }

        await _database.goalDao.upsertGoal(
          curriculumId: curriculumId,
          description: description,
          targetPercent: targetPercent,
          targetDate: targetDate,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge goal: $e');
      }
    }
  }

  /// Merge rewards from Firestore (last-write-wins per D4).
  ///
  /// For each remote reward, upsert into local DB. Rewards that are
  /// earned remotely but not locally get updated.
  Future<void> _mergeRewards(List<Map<String, dynamic>> remoteRewards) async {
    _logger.debug('Merging ${remoteRewards.length} rewards from Firestore');

    for (final remote in remoteRewards) {
      try {
        final title = remote['title'] as String?;
        final description = remote['description'] as String? ?? '';
        final pointsThreshold = remote['points_threshold'] as int?;
        final isRevealed = remote['is_revealed'] as bool? ?? false;
        final isEarned = remote['is_earned'] as bool? ?? false;
        final earnedAt = _parseTimestamp(remote['earned_at']);
        final createdAt = _parseTimestamp(remote['created_at']);
        final updatedAt = _parseTimestamp(remote['updated_at']);
        final curriculumId = remote['curriculum_id'] as String?;

        if (title == null || pointsThreshold == null || createdAt == null) {
          _logger.warning('Skipping invalid remote reward: $remote');
          continue;
        }

        await _database.rewardDao.upsertReward(
          title: title,
          description: description,
          pointsThreshold: pointsThreshold,
          isRevealed: isRevealed,
          isEarned: isEarned,
          earnedAt: earnedAt,
          createdAt: createdAt,
          updatedAt: updatedAt,
          curriculumId: curriculumId,
        );
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge reward: $e');
      }
    }
  }

  /// Merge streak from Firestore (last-write-wins per D4).
  ///
  /// Streak is a precomputed cache in Firestore. Locally, streak can be
  /// derived from completions. This merge is a no-op for now — streak
  /// accuracy is ensured by completions merge.
  Future<void> _mergeStreak(Map<String, dynamic> remoteStreak) async {
    _logger.debug(
      'Streak from Firestore: current=${remoteStreak['current_count']}, '
      'max=${remoteStreak['max_count']}',
    );
    // Streak is computed from completions locally. The Firestore streak
    // document serves as a cross-device cache but local truth comes from
    // the completions table. No local write needed.
  }

  /// Merge profile from Firestore (last-write-wins per D4).
  Future<void> _mergeProfile(Map<String, dynamic> remoteProfile) async {
    _logger.debug('Merging profile from Firestore');

    try {
      final firebaseUid = remoteProfile['firebase_uid'] as String?;
      final displayName = remoteProfile['display_name'] as String?;
      final userMode = remoteProfile['user_mode'] as String?;
      final updatedAt = _parseTimestamp(remoteProfile['updated_at']);

      if (firebaseUid == null ||
          displayName == null ||
          userMode == null ||
          updatedAt == null) {
        _logger.warning('Skipping invalid remote profile: $remoteProfile');
        return;
      }

      await _database.userProfileDao.upsertProfile(
        firebaseUid: firebaseUid,
        displayName: displayName,
        userMode: userMode,
        updatedAt: updatedAt,
      );
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning('Failed to merge profile: $e');
    }
  }

  // ========== Listener Callbacks ==========

  Future<void> _onCompletionsUpdate(
    List<Map<String, dynamic>> completions,
  ) async {
    if (_mergingCompletions) return;
    _mergingCompletions = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug('Received ${completions.length} completions from listener');
      await _mergeCompletions(completions);
    } finally {
      _mergingCompletions = false;
    }
  }

  Future<void> _onBookmarksUpdate(
    List<Map<String, dynamic>> bookmarks,
  ) async {
    if (_mergingBookmarks) return;
    _mergingBookmarks = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug('Received ${bookmarks.length} bookmarks from listener');
      await _mergeBookmarks(bookmarks);
    } finally {
      _mergingBookmarks = false;
    }
  }

  Future<void> _onSettingsUpdate(
    List<Map<String, dynamic>> settings,
  ) async {
    if (_mergingSettings) return;
    _mergingSettings = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug('Received ${settings.length} settings from listener');
      await _mergeSettings(settings);
    } finally {
      _mergingSettings = false;
    }
  }

  void _onStreakUpdate(Map<String, dynamic>? streak) {
    if (streak != null) {
      _logger.debug('Received streak update from listener');
      _mergeStreak(streak);
    }
  }

  void _onGoalsUpdate(List<Map<String, dynamic>> goals) {
    _logger.debug('Received ${goals.length} goals from listener');
    _consecutiveListenerErrors = 0;
    _mergeGoals(goals);
  }

  void _onRewardsUpdate(List<Map<String, dynamic>> rewards) {
    _logger.debug('Received ${rewards.length} rewards from listener');
    _consecutiveListenerErrors = 0;
    _mergeRewards(rewards);
  }

  /// Handle listener errors with quota monitoring (NFR21).
  ///
  /// After [quotaErrorThreshold] consecutive errors, disables all listeners
  /// to prevent further quota consumption. The app falls back to
  /// pull-on-launch sync only.
  void _handleListenerError(Object error, StackTrace stackTrace) {
    _logger.error('Listener error', error, stackTrace);
    _consecutiveListenerErrors++;

    if (_consecutiveListenerErrors >= quotaErrorThreshold && !_quotaDegraded) {
      _logger.warning(
        'Firebase quota threshold reached ($_consecutiveListenerErrors '
        'consecutive errors). Disabling real-time listeners.',
      );
      _quotaDegraded = true;
      detachListeners();
      _updateStatus(
        SyncStatus.error(
          message:
              'Firebase quota exceeded — real-time sync disabled. '
              'Data will sync on next app launch.',
          failedAt: DateTime.now().toUtc(),
        ),
      );
      return;
    }

    _updateStatus(
      SyncStatus.error(
        message: error.toString(),
        failedAt: DateTime.now().toUtc(),
      ),
    );
  }

  // ========== Network Events ==========

  Future<void> _onReconnect() async {
    _logger.info('Device reconnected, flushing offline queue');

    // Reset quota degradation on reconnect — give listeners another chance
    _consecutiveListenerErrors = 0;
    _quotaDegraded = false;

    _updateStatus(SyncStatus.syncing(startedAt: DateTime.now().toUtc()));

    try {
      // In battery saver mode, process in smaller batches with delays
      final batchSize = _isBatterySaverMode ? 5 : null;
      final syncedCount = await _offlineQueue.flush(batchSize: batchSize);
      _logger.info('Flushed $syncedCount operations from offline queue');

      _updateStatus(SyncStatus.synced(lastSyncedAt: DateTime.now().toUtc()));

      // Reattach listeners — detachListeners() cleared the flag on disconnect,
      // so always attempt to attach them now that we are back online.
      _listenersAttached = false;
      await attachListeners();
    } catch (e, stackTrace) {
      _logger.error('Failed to flush offline queue', e, stackTrace);
      _updateStatus(
        SyncStatus.error(
          message: e.toString(),
          failedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }

  Future<void> _onDisconnect() async {
    final pendingCount = await _offlineQueue.getPendingCount();
    _updateStatus(SyncStatus.offline(pendingChanges: pendingCount));

    // Detach listeners to save battery
    await detachListeners();
  }

  /// Push curriculum import metadata to Firestore.
  ///
  /// This allows other devices to detect that a curriculum has already been
  /// imported and skip re-import from Sefaria.
  Future<void> pushCurriculumImportMetadata({
    required String curriculumId,
    required int itemCount,
    required DateTime importedAt,
  }) async {
    final metadata = {
      'curriculum_id': curriculumId,
      'item_count': itemCount,
      'imported_at': importedAt.toIso8601String(),
    };

    if (!_isOnline) {
      await _offlineQueue.enqueueCurriculumImportMetadata(metadata);
      _updateStatus(
        SyncStatus.offline(
          pendingChanges: await _offlineQueue.getPendingCount(),
        ),
      );
      return;
    }

    try {
      await _firestoreDataSource.pushCurriculumImportMetadata(metadata);
      _logger.debug(
        'Pushed curriculum import metadata to Firestore: $curriculumId',
      );
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _logger.warning(
        'Failed to push curriculum import metadata, queuing for later',
        e,
      );
      await _offlineQueue.enqueueCurriculumImportMetadata(metadata);
      await _emitPendingStatus();
    }
  }

  // ========== Timestamp Persistence ==========

  /// Get the locally persisted settings timestamp for a curriculum.
  Future<DateTime?> _getSettingsTimestamp(String curriculumId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt('settings_ts_$curriculumId');
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — SharedPreferences may be unavailable in tests
      _logger.warning('Failed to read settings timestamp: $e');
      return null;
    }
  }

  /// Set the locally persisted settings timestamp for a curriculum.
  Future<void> _setSettingsTimestamp(
    String curriculumId,
    DateTime updatedAt,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        'settings_ts_$curriculumId',
        updatedAt.toUtc().millisecondsSinceEpoch,
      );
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — SharedPreferences may be unavailable in tests
      _logger.warning('Failed to persist settings timestamp: $e');
    }
  }

  /// Persist the last successful sync timestamp.
  Future<void> _persistLastSyncTimestamp(DateTime syncedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, syncedAt.millisecondsSinceEpoch);
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — SharedPreferences may be unavailable in tests
      _logger.warning('Failed to persist last sync timestamp: $e');
    }
  }

  /// Restore persisted last-sync timestamp into current status.
  Future<void> _restoreLastSyncTimestamp() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ms = prefs.getInt(_lastSyncKey);
      if (ms != null) {
        _currentStatus = SyncStatus.synced(
          lastSyncedAt: DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true),
        );
      }
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — SharedPreferences may be unavailable in tests
      _logger.warning('Failed to restore last sync timestamp: $e');
    }
  }

  // ========== Status Management ==========

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Emit pending status when online but queue has items.
  Future<void> _emitPendingStatus() async {
    if (_isOnline) {
      final count = await _offlineQueue.getPendingCount();
      if (count > 0) {
        _updateStatus(SyncStatus.pending(pendingChanges: count));
      }
    }
  }

  // ========== Battery-Aware Queue Processing ==========

  bool _isBatterySaverMode = false;

  /// Set battery saver mode. When enabled, queue flush uses larger batch
  /// intervals to reduce network activity (NFR27).
  void setBatterySaverMode(bool enabled) {
    _isBatterySaverMode = enabled;
    _logger.info('Battery saver mode: ${enabled ? "on" : "off"}');
  }

  /// Whether battery saver mode is currently active.
  bool get isBatterySaverMode => _isBatterySaverMode;
}
