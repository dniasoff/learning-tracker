import 'dart:async';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
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
  }) : _database = database,
       _firestoreDataSource = firestoreDataSource,
       _offlineQueue = offlineQueue,
       _logger = logger;

  final AppDatabase _database;
  final FirestoreDataSource _firestoreDataSource;
  final OfflineQueue _offlineQueue;
  final Talker _logger;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _currentStatus = SyncStatus.synced(lastSyncedAt: DateTime.now());
  SyncStatus get currentStatus => _currentStatus;

  StreamSubscription? _completionsSubscription;
  StreamSubscription? _bookmarksSubscription;
  StreamSubscription? _settingsSubscription;
  StreamSubscription? _streakSubscription;

  bool _isOnline = true;
  bool _listenersAttached = false;

  // ========== Lifecycle Methods ==========

  /// Initialize sync engine and pull data on launch.
  Future<void> initialize() async {
    _logger.info('Initializing sync engine');
    await pullOnLaunch();
  }

  /// Dispose resources and detach listeners.
  Future<void> dispose() async {
    _logger.info('Disposing sync engine');
    await detachListeners();
    await _statusController.close();
  }

  /// Set online/offline state.
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

    _completionsSubscription = null;
    _bookmarksSubscription = null;
    _settingsSubscription = null;
    _streakSubscription = null;
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

    _updateStatus(SyncStatus.syncing(startedAt: DateTime.now()));

    try {
      _logger.info('Pull-on-launch: Fetching data from Firestore');

      // Fetch all data from Firestore
      final completions = await _firestoreDataSource.fetchCompletions();
      final bookmarks = await _firestoreDataSource.fetchBookmarks();
      final settings = await _firestoreDataSource.fetchSettings();
      final streak = await _firestoreDataSource.fetchStreak();
      final profile = await _firestoreDataSource.fetchProfile();

      // Merge with local database
      await _mergeCompletions(completions);
      await _mergeBookmarks(bookmarks);
      await _mergeSettings(settings);
      if (streak != null) await _mergeStreak(streak);
      if (profile != null) await _mergeProfile(profile);

      _logger.info('Pull-on-launch completed successfully');
      _updateStatus(SyncStatus.synced(lastSyncedAt: DateTime.now()));
    } catch (e, stackTrace) {
      _logger.error('Pull-on-launch failed', e, stackTrace);
      _updateStatus(
        SyncStatus.error(message: e.toString(), failedAt: DateTime.now()),
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
    } catch (e, stackTrace) {
      _logger.warning('Failed to push completion, queuing for later', e);
      await _offlineQueue.enqueueCompletion(completion);
    }
  }

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
    } catch (e, stackTrace) {
      _logger.warning('Failed to push bookmark, queuing for later', e);
      await _offlineQueue.enqueueBookmark(bookmark);
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
    } catch (e, stackTrace) {
      _logger.warning('Failed to push settings, queuing for later', e);
      await _offlineQueue.enqueueSettings(settings);
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
    } catch (e, stackTrace) {
      _logger.warning('Failed to push streak, queuing for later', e);
      await _offlineQueue.enqueueStreak(streak);
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
    } catch (e, stackTrace) {
      _logger.warning('Failed to push profile, queuing for later', e);
      await _offlineQueue.enqueueProfile(profile);
    }
  }

  // ========== Conflict Resolution & Merge ==========

  /// Merge completions from Firestore (additive merge).
  Future<void> _mergeCompletions(
    List<Map<String, dynamic>> remoteCompletions,
  ) async {
    // Completions are append-only, so we just insert new ones
    // that don't exist locally (based on Firestore ID or composite key)
    _logger.debug(
      'Merging ${remoteCompletions.length} completions from Firestore',
    );

    for (final remote in remoteCompletions) {
      // TODO: Check if completion already exists locally
      // For now, we'll just log
      _logger.debug('Would merge completion: $remote');
    }
  }

  /// Merge bookmarks from Firestore (last-write-wins).
  Future<void> _mergeBookmarks(
    List<Map<String, dynamic>> remoteBookmarks,
  ) async {
    _logger.debug('Merging ${remoteBookmarks.length} bookmarks from Firestore');

    for (final remote in remoteBookmarks) {
      // Compare timestamps: if remote is newer, update local
      _logger.debug('Would merge bookmark: $remote');
    }
  }

  /// Merge settings from Firestore (last-write-wins).
  Future<void> _mergeSettings(List<Map<String, dynamic>> remoteSettings) async {
    _logger.debug('Merging ${remoteSettings.length} settings from Firestore');

    for (final remote in remoteSettings) {
      // Compare timestamps: if remote is newer, update local
      _logger.debug('Would merge settings: $remote');
    }
  }

  /// Merge streak from Firestore (last-write-wins).
  Future<void> _mergeStreak(Map<String, dynamic> remoteStreak) async {
    _logger.debug('Merging streak from Firestore: $remoteStreak');
    // Compare timestamps and update local if remote is newer
  }

  /// Merge profile from Firestore (last-write-wins).
  Future<void> _mergeProfile(Map<String, dynamic> remoteProfile) async {
    _logger.debug('Merging profile from Firestore: $remoteProfile');
    // Compare timestamps and update local if remote is newer
  }

  // ========== Listener Callbacks ==========

  void _onCompletionsUpdate(List<Map<String, dynamic>> completions) {
    _logger.debug('Received ${completions.length} completions from listener');
    _mergeCompletions(completions);
  }

  void _onBookmarksUpdate(List<Map<String, dynamic>> bookmarks) {
    _logger.debug('Received ${bookmarks.length} bookmarks from listener');
    _mergeBookmarks(bookmarks);
  }

  void _onSettingsUpdate(List<Map<String, dynamic>> settings) {
    _logger.debug('Received ${settings.length} settings from listener');
    _mergeSettings(settings);
  }

  void _onStreakUpdate(Map<String, dynamic>? streak) {
    if (streak != null) {
      _logger.debug('Received streak update from listener');
      _mergeStreak(streak);
    }
  }

  void _handleListenerError(Object error, StackTrace stackTrace) {
    _logger.error('Listener error', error, stackTrace);
    _updateStatus(
      SyncStatus.error(message: error.toString(), failedAt: DateTime.now()),
    );
  }

  // ========== Network Events ==========

  void _onReconnect() async {
    _logger.info('Device reconnected, flushing offline queue');

    _updateStatus(SyncStatus.syncing(startedAt: DateTime.now()));

    try {
      final syncedCount = await _offlineQueue.flush();
      _logger.info('Flushed $syncedCount operations from offline queue');

      _updateStatus(SyncStatus.synced(lastSyncedAt: DateTime.now()));

      // Reattach listeners if app is in foreground
      if (_listenersAttached) {
        await attachListeners();
      }
    } catch (e, stackTrace) {
      _logger.error('Failed to flush offline queue', e, stackTrace);
      _updateStatus(
        SyncStatus.error(message: e.toString(), failedAt: DateTime.now()),
      );
    }
  }

  void _onDisconnect() async {
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
    } catch (e, stackTrace) {
      _logger.warning(
        'Failed to push curriculum import metadata, queuing for later',
        e,
      );
      await _offlineQueue.enqueueCurriculumImportMetadata(metadata);
    }
  }

  // ========== Status Management ==========

  void _updateStatus(SyncStatus status) {
    _currentStatus = status;
    _statusController.add(status);
  }
}
