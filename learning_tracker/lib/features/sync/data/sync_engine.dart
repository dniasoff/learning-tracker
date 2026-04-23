import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart'
    show FirebaseException, Timestamp;
import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/domain/merge_rules.dart';
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
    required UserDatabase database,
    required FirestoreDataSource firestoreDataSource,
    required OfflineQueue offlineQueue,
    required Talker logger,
    required ConnectivityService connectivityService,
  }) : _database = database,
       _firestoreDataSource = firestoreDataSource,
       _offlineQueue = offlineQueue,
       _logger = logger,
       _connectivityService = connectivityService;

  final UserDatabase _database;
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
  StreamSubscription<List<Map<String, dynamic>>>? _profileProgramsSubscription;
  StreamSubscription<List<String>>? _activeCurriculaSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _ledgerSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _curriculumTracksSubscription;
  StreamSubscription<Map<String, dynamic>?>? _notificationSettingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _gamificationSettingsSubscription;

  bool _isOnline = true;
  bool _listenersAttached = false;

  /// Tracks consecutive listener errors for quota monitoring (NFR21).
  int _consecutiveListenerErrors = 0;

  /// Threshold of consecutive errors before disabling listeners.
  static const int quotaErrorThreshold = 3;

  /// Whether listeners have been disabled due to quota exhaustion.
  bool _quotaDegraded = false;

  /// Consecutive PERMISSION_DENIED errors on push. After threshold,
  /// pushes are silently queued to avoid log spam and wasted requests.
  int _consecutivePushPermissionErrors = 0;
  static const int _pushPermissionErrorThreshold = 3;

  /// Whether listeners are degraded due to Firebase quota issues.
  bool get isQuotaDegraded => _quotaDegraded;

  // Merge guards to prevent concurrent merges on the same collection (issue #2)
  bool _mergingCompletions = false;
  bool _mergingBookmarks = false;
  bool _mergingSettings = false;
  bool _mergingStreak = false;
  bool _mergingGoals = false;
  bool _mergingProfilePrograms = false;
  bool _mergingActiveCurricula = false;
  bool _mergingLedgerEntries = false;
  bool _mergingCurriculumTracks = false;
  bool _mergingNotificationSettings = false;
  bool _mergingGamificationSettings = false;

  /// SharedPreferences key for persisted last-sync timestamp.
  static const _lastSyncKey = 'sync_engine_last_synced_at';

  // Notification settings keys (must match notification providers).
  static const _notificationSettingsUpdatedAtMsKey =
      'notification_settings_updated_at_ms';
  static const _gamificationSettingsUpdatedAtMsKey =
      'gamification_settings_updated_at_ms';
  static const _reminderEnabledKey = 'daily_reminder_enabled';
  static const _reminderHourKey = 'daily_reminder_hour';
  static const _reminderMinuteKey = 'daily_reminder_minute';
  static const _streakAlertEnabledKey = 'streak_alert_enabled';
  static const _streakAlertHourKey = 'streak_alert_hour';
  static const _streakAlertMinuteKey = 'streak_alert_minute';
  static const _rewardNotificationEnabledKey = 'reward_notification_enabled';
  static const _shabbosModeEnabledKey = 'shabbos_mode_enabled';
  static const _shabbosModeUseLocationKey = 'shabbos_mode_use_location';
  static const _shabbosModeLatitudeKey = 'shabbos_mode_latitude';
  static const _shabbosModeLongitudeKey = 'shabbos_mode_longitude';
  static const _shabbosModeFixedStartHourKey = 'shabbos_mode_fixed_start_hour';
  static const _shabbosModeFixedStartMinuteKey =
      'shabbos_mode_fixed_start_minute';
  static const _shabbosModeFixedEndHourKey = 'shabbos_mode_fixed_end_hour';
  static const _shabbosModeFixedEndMinuteKey = 'shabbos_mode_fixed_end_minute';

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
    await _backfillLearnerProfilesIfNeeded();
    await _backfillCurriculumTracksIfNeeded();
    await _repairLegacyCompletionTrackIds();
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
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.debug('Cannot attach listeners: user not authenticated');
      return;
    }

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

    _profileProgramsSubscription = _firestoreDataSource
        .listenToProfilePrograms()
        .listen(_onProfileProgramsUpdate, onError: _handleListenerError);

    _activeCurriculaSubscription = _firestoreDataSource
        .listenToActiveCurricula()
        .listen(_onActiveCurriculaUpdate, onError: _handleListenerError);

    _ledgerSubscription = _firestoreDataSource.listenToLedgerEntries().listen(
      _onLedgerUpdate,
      onError: _handleListenerError,
    );

    _curriculumTracksSubscription = _firestoreDataSource
        .listenToCurriculumTracks()
        .listen(_onCurriculumTracksUpdate, onError: _handleListenerError);

    _notificationSettingsSubscription = _firestoreDataSource
        .listenToNotificationSettings()
        .listen(_onNotificationSettingsUpdate, onError: _handleListenerError);

    _gamificationSettingsSubscription = _firestoreDataSource
        .listenToGamificationSettings()
        .listen(_onGamificationSettingsUpdate, onError: _handleListenerError);
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
    await _profileProgramsSubscription?.cancel();
    await _activeCurriculaSubscription?.cancel();
    await _ledgerSubscription?.cancel();
    await _curriculumTracksSubscription?.cancel();
    await _notificationSettingsSubscription?.cancel();
    await _gamificationSettingsSubscription?.cancel();

    _completionsSubscription = null;
    _bookmarksSubscription = null;
    _settingsSubscription = null;
    _streakSubscription = null;
    _goalsSubscription = null;
    _profileProgramsSubscription = null;
    _activeCurriculaSubscription = null;
    _ledgerSubscription = null;
    _curriculumTracksSubscription = null;
    _notificationSettingsSubscription = null;
    _gamificationSettingsSubscription = null;
  }

  // ========== Pull-on-Launch ==========

  /// Pull latest data from Firestore on app launch.
  Future<void> pullOnLaunch() async {
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.info('Pull-on-launch skipped: user not authenticated');
      return;
    }

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
        _firestoreDataSource.fetchProfilePrograms(),
        _firestoreDataSource.fetchStreak(),
        _firestoreDataSource.fetchProfile(),
        _firestoreDataSource.fetchLedgerEntries(),
        _firestoreDataSource.fetchActiveCurricula(),
        _firestoreDataSource.fetchCurriculumTracks(),
        _firestoreDataSource.fetchLearnerProfiles(),
        _firestoreDataSource.fetchNotificationSettings(),
        _firestoreDataSource.fetchGamificationSettings(),
      ]);
      final completions = results[0] as List<Map<String, dynamic>>;
      final bookmarks = results[1] as List<Map<String, dynamic>>;
      final settings = results[2] as List<Map<String, dynamic>>;
      final goals = results[3] as List<Map<String, dynamic>>;
      final profilePrograms = results[4] as List<Map<String, dynamic>>;
      final streak = results[5] as Map<String, dynamic>?;
      final profile = results[6] as Map<String, dynamic>?;
      final ledgerEntries = results[7] as List<Map<String, dynamic>>;
      final activeCurricula = results[8] as List<String>;
      final curriculumTracks = results[9] as List<Map<String, dynamic>>;
      final learnerProfiles = results[10] as List<Map<String, dynamic>>;
      final notificationSettings = results[11] as Map<String, dynamic>?;
      final gamificationSettings = results[12] as Map<String, dynamic>?;

      // Merge learner profiles FIRST — other rows (completions, bookmarks,
      // goals, streaks, etc.) reference profile_id, so they need the
      // target rows to exist before foreign-key-style lookups run.
      await _mergeLearnerProfiles(learnerProfiles);

      // Merge with local database
      await _mergeCompletions(completions);
      await _mergeBookmarks(bookmarks);
      await _mergeSettings(settings);
      await _mergeGoals(goals);
      await _mergeProfilePrograms(profilePrograms);
      if (streak != null) await _mergeStreak(streak);
      if (profile != null) await _mergeProfile(profile);
      await _mergeLedgerEntries(ledgerEntries);
      await _mergeActiveCurricula(activeCurricula);
      await _mergeCurriculumTracks(curriculumTracks);
      await _mergeNotificationSettings(notificationSettings);
      await _mergeGamificationSettings(gamificationSettings);

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

  /// Whether pushes are suppressed due to repeated PERMISSION_DENIED errors.
  bool get _pushSuppressed =>
      _consecutivePushPermissionErrors >= _pushPermissionErrorThreshold;

  /// Check if an error is a Firestore PERMISSION_DENIED and track it.
  /// Returns true if the error is permission-denied.
  bool _trackPushError(Object e) {
    if (e is FirebaseException && e.code == 'permission-denied') {
      _consecutivePushPermissionErrors++;
      if (_pushSuppressed) {
        _logger.warning(
          'Push suppressed after $_consecutivePushPermissionErrors '
          'consecutive permission-denied errors — queuing silently',
        );
      }
      return true;
    }
    // Non-permission error resets the counter
    _consecutivePushPermissionErrors = 0;
    return false;
  }

  bool get _isQueueOnlyMode =>
      !_isOnline || _pushSuppressed || !_firestoreDataSource.isAuthenticated;

  Future<void> _updateQueueOnlyStatus() async {
    final pending = await _offlineQueue.getPendingCount();
    if (!_isOnline) {
      _updateStatus(SyncStatus.offline(pendingChanges: pending));
      return;
    }
    if (pending > 0) {
      _updateStatus(SyncStatus.pending(pendingChanges: pending));
    }
  }

  Map<String, dynamic> _withQueueTargetProfile(Map<String, dynamic> payload) {
    if (payload.containsKey('profile_id') ||
        payload.containsKey('_target_profile_id')) {
      return payload;
    }
    return {...payload, '_target_profile_id': _firestoreDataSource.profileId};
  }

  int? _asInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  Future<Map<String, dynamic>> _withTrackProgressSchema(
    Map<String, dynamic> trackData,
  ) async {
    final enriched = Map<String, dynamic>.from(trackData);
    final profileId =
        _asInt(enriched['profile_id']) ?? _firestoreDataSource.profileId;
    final trackId = _asInt(enriched['track_id']);
    final curriculumId = (enriched['curriculum_id'] ?? '').toString();
    final trackType =
        (enriched['track_type'] ?? TrackType.personal.storageKey).toString();

    if (curriculumId.isEmpty) {
      return enriched;
    }

    final nowUtc = DateTime.now().toUtc();
    final enrollment = await _database.profileProgramDao
        .getProgramForProfileAndCurriculum(profileId, curriculumId);
    final isProgramTrack = enrollment != null;

    enriched['progress_schema_version'] = 1;
    enriched['progress_computed_at'] = nowUtc.toIso8601String();
    enriched['progress_model'] = isProgramTrack
        ? 'program_adherence'
        : 'self_paced_completion';

    if (isProgramTrack) {
      final planDate = DateUtils.extractLocalDate(nowUtc);
      final rows = await _database.dailyPlanDao.getPlanForDay(
        profileId: profileId,
        planDate: planDate,
      );
      final relevantRows = trackId == null
          ? rows
                .where(
                  (r) => r.curriculumId == curriculumId,
                )
                .toList()
          : rows.where((r) => r.trackId == trackId).toList();

      final overdueCount = relevantRows
          .where((r) => r.priority == 'overdueProgram')
          .length;
      final todayDueCount = relevantRows
          .where((r) => r.priority == 'todayProgram')
          .length;
      final status = overdueCount > 0
          ? 'behind'
          : (todayDueCount > 0 ? 'on_time' : 'caught_up');

      enriched['program_progress'] = {
        'overdue_count': overdueCount,
        'today_due_count': todayDueCount,
        'status': status,
        'snapshot_plan_date': planDate.toIso8601String(),
      };
      enriched['self_paced_progress'] = null;
    } else {
      final completedStageEvents = trackId == null
          ? (await _database.completionDao.getCompletionsByCurriculumAndProfile(
              curriculumId,
              profileId,
            ))
                .where((c) => c.trackType == trackType)
                .length
          : await _database.completionDao.getAggregateCountByTrack(
              trackId,
              profileId,
            );

      enriched['self_paced_progress'] = {
        'completed_stage_events': completedStageEvents,
      };
      enriched['program_progress'] = null;
    }

    return enriched;
  }

  /// Push a completion to Firestore after local write.
  Future<void> pushCompletion(Map<String, dynamic> completion) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueCompletion(
        _withQueueTargetProfile(completion),
      );
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushCompletion(completion);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed completion to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push completion, queuing for later', e);
      await _offlineQueue.enqueueCompletion(
        _withQueueTargetProfile(completion),
      );
      await _emitPendingStatus();
    }
  }

  /// Push a ledger entry to Firestore after local write.
  Future<void> pushLedgerEntry(Map<String, dynamic> entry) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueLedgerEntry(_withQueueTargetProfile(entry));
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushLedgerEntry(entry);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed ledger entry to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push ledger entry, queuing for later', e);
      await _offlineQueue.enqueueLedgerEntry(_withQueueTargetProfile(entry));
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
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueBookmark(_withQueueTargetProfile(bookmark));
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushBookmark(bookmark);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed bookmark to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push bookmark, queuing for later', e);
      await _offlineQueue.enqueueBookmark(_withQueueTargetProfile(bookmark));
      await _emitPendingStatus();
    }
  }

  /// Push settings to Firestore after local write.
  Future<void> pushSettings(Map<String, dynamic> settings) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueSettings(_withQueueTargetProfile(settings));
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushSettings(settings);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed settings to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push settings, queuing for later', e);
      await _offlineQueue.enqueueSettings(_withQueueTargetProfile(settings));
      await _emitPendingStatus();
    }
  }

  /// Push notification settings to Firestore after local write.
  Future<void> pushNotificationSettings(
    Map<String, dynamic> notificationSettings,
  ) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueNotificationSettings(
        _withQueueTargetProfile(notificationSettings),
      );
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushNotificationSettings(notificationSettings);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed notification settings to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning(
        'Failed to push notification settings, queuing for later',
        e,
      );
      await _offlineQueue.enqueueNotificationSettings(
        _withQueueTargetProfile(notificationSettings),
      );
      await _emitPendingStatus();
    }
  }

  /// Push gamification settings to Firestore after local write.
  Future<void> pushGamificationSettings(
    Map<String, dynamic> gamificationSettings,
  ) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueGamificationSettings(
        _withQueueTargetProfile(gamificationSettings),
      );
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushGamificationSettings(gamificationSettings);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed gamification settings to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning(
        'Failed to push gamification settings, queuing for later',
        e,
      );
      await _offlineQueue.enqueueGamificationSettings(
        _withQueueTargetProfile(gamificationSettings),
      );
      await _emitPendingStatus();
    }
  }

  /// Build and push the current gamification snapshot from local storage.
  Future<void> pushGamificationSettingsSnapshot() async {
    final payload = await _buildGamificationSettingsPayload();
    await pushGamificationSettings(payload);
  }

  /// Push study day config to Firestore as part of settings document.
  Future<void> pushStudyDayConfig({
    required String curriculumId,
    required Map<String, String> dayConfig,
  }) async {
    final payload = <String, dynamic>{
      'curriculum_id': curriculumId,
      'study_day_config': dayConfig,
      'study_day_config_updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await pushSettings(payload);
  }

  /// Push streak data to Firestore after local write.
  Future<void> pushStreak(Map<String, dynamic> streak) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueStreak(_withQueueTargetProfile(streak));
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushStreak(streak);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed streak to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push streak, queuing for later', e);
      await _offlineQueue.enqueueStreak(_withQueueTargetProfile(streak));
      await _emitPendingStatus();
    }
  }

  /// Push profile to Firestore after local write.
  Future<void> pushProfile(Map<String, dynamic> profile) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueProfile(_withQueueTargetProfile(profile));
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushProfile(profile);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed profile to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push profile, queuing for later', e);
      await _offlineQueue.enqueueProfile(_withQueueTargetProfile(profile));
      await _emitPendingStatus();
    }
  }

  /// Push a learner profile (profiles table) to Firestore.
  /// Local row remains authoritative; cloud push is background/queued.
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {
    final payload = await _enrichLearnerProfilePayload(profile);

    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueLearnerProfile(payload);
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushLearnerProfile(payload);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed learner profile to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push learner profile, queuing for later', e);
      await _offlineQueue.enqueueLearnerProfile(payload);
      await _emitPendingStatus();
    }
  }

  /// Delete a learner profile from Firestore.
  Future<void> deleteLearnerProfile(int profileId) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueLearnerProfileDelete(profileId);
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.deleteLearnerProfile(profileId);
      _consecutivePushPermissionErrors = 0;
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to delete learner profile, queuing for later', e);
      await _offlineQueue.enqueueLearnerProfileDelete(profileId);
      await _emitPendingStatus();
    }
  }

  /// Push a goal to Firestore after local write.
  Future<void> pushGoal(Map<String, dynamic> goal) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueGoal(_withQueueTargetProfile(goal));
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushGoal(goal);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed goal to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push goal, queuing for later', e);
      await _offlineQueue.enqueueGoal(_withQueueTargetProfile(goal));
      await _emitPendingStatus();
    }
  }

  /// Push a profile-program assignment to Firestore after local write.
  Future<void> pushProfileProgram(Map<String, dynamic> profileProgram) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueProfileProgram(
        _withQueueTargetProfile(profileProgram),
      );
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushProfileProgram(profileProgram);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed profile program to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push profile program, queuing for later', e);
      await _offlineQueue.enqueueProfileProgram(
        _withQueueTargetProfile(profileProgram),
      );
      await _emitPendingStatus();
    }
  }

  /// Push active curricula list to Firestore after local write.
  Future<void> pushActiveCurricula(List<String> activeCurricula) async {
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueActiveCurricula(
        activeCurricula,
        targetProfileId: _firestoreDataSource.profileId,
      );
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushActiveCurricula(activeCurricula);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed active curricula to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push active curricula, queuing for later', e);
      await _offlineQueue.enqueueActiveCurricula(
        activeCurricula,
        targetProfileId: _firestoreDataSource.profileId,
      );
      await _emitPendingStatus();
    }
  }

  /// Push curriculum-track state to Firestore after local write.
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {
    final payload = await _withTrackProgressSchema(trackData);
    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueCurriculumTrack(
        _withQueueTargetProfile(payload),
      );
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushCurriculumTrack(payload);
      _consecutivePushPermissionErrors = 0;
      _logger.debug('Pushed curriculum track to Firestore');
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning('Failed to push curriculum track, queuing for later', e);
      await _offlineQueue.enqueueCurriculumTrack(
        _withQueueTargetProfile(payload),
      );
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
    final trackIdCache = <String, int>{};
    for (final remote in remoteCompletions) {
      try {
        final curriculumId =
            (remote['curriculum_id'] ?? remote['curriculumId']) as String?;
        final sefariaRef =
            (remote['content_item_id'] ??
                    remote['sefaria_ref'] ??
                    remote['sefariaRef'])
                as String?;

        final rawStageId =
            remote['stage_id'] ?? remote['stageOrder'] ?? remote['stage_order'];
        final stageId = rawStageId is int
            ? rawStageId
            : rawStageId is num
            ? rawStageId.toInt()
            : int.tryParse(rawStageId?.toString() ?? '');

        final trackType =
            (remote['track_type'] ?? remote['trackType']) as String?;
        final completedAt = _parseTimestamp(
          remote['completed_at'] ?? remote['completedAt'],
        );

        if (curriculumId == null ||
            sefariaRef == null ||
            stageId == null ||
            trackType == null ||
            completedAt == null) {
          _logger.warning('Skipping invalid remote completion: $remote');
          continue;
        }

        final rawProfileId = remote['profile_id'] ?? remote['profileId'];
        final profileId = rawProfileId is int
            ? rawProfileId
            : rawProfileId is num
            ? rawProfileId.toInt()
            : int.tryParse(rawProfileId?.toString() ?? '') ??
                  _firestoreDataSource.profileId;

        final exists = await _database.completionDao.completionExistsByProfile(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          completedAt: completedAt,
          profileId: profileId,
        );

        if (!exists) {
          final rawTrackId = remote['track_id'] ?? remote['trackId'];
          final remoteTrackId = rawTrackId is int
              ? rawTrackId
              : rawTrackId is num
              ? rawTrackId.toInt()
              : int.tryParse(rawTrackId?.toString() ?? '');
          final resolvedTrackId =
              remoteTrackId ??
              await (() async {
                final key = '$profileId|$curriculumId|$trackType';
                final cached = trackIdCache[key];
                if (cached != null) return cached;

                final track =
                    await (_database.select(_database.curriculumTracks)
                          ..where(
                            (t) =>
                                t.profileId.equals(profileId) &
                                t.curriculumId.equals(curriculumId) &
                                t.trackType.equals(trackType),
                          )
                          ..limit(1))
                        .getSingleOrNull();
                final value = track?.id ?? 0;
                trackIdCache[key] = value;
                return value;
              })();

          await _database.completionDao.insertCompletion(
            CompletionsCompanion.insert(
              profileId: Value(profileId),
              curriculumId: curriculumId,
              sefariaRef: sefariaRef,
              stageId: stageId,
              trackType: trackType,
              trackId: resolvedTrackId,
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

  /// Merge ledger entries from Firestore (append-only).
  ///
  /// Ledger entries are append-only. For each remote entry, check if it
  /// already exists locally by composite key. If not, insert it.
  Future<void> _mergeLedgerEntries(
    List<Map<String, dynamic>> remoteLedgerEntries,
  ) async {
    _logger.debug(
      'Merging ${remoteLedgerEntries.length} ledger entries from Firestore',
    );

    var insertedCount = 0;
    for (final remote in remoteLedgerEntries) {
      try {
        final curriculumId = remote['curriculumId'] as String?;
        final unitIdentifier = remote['unitIdentifier'] as String?;
        final trackType = remote['trackType'] as String?;
        final completedAt = _parseTimestamp(remote['completedAt']);
        final profileId = remote['profileId'] as int? ?? 0;

        if (curriculumId == null ||
            unitIdentifier == null ||
            trackType == null ||
            completedAt == null) {
          _logger.warning('Skipping invalid remote ledger entry: $remote');
          continue;
        }

        final exists = await _database.learningLedgerDao.entryExists(
          profileId: profileId,
          curriculumId: curriculumId,
          unitIdentifier: unitIdentifier,
          trackType: trackType,
          completedAt: completedAt,
        );

        if (!exists) {
          await _database.learningLedgerDao.insertEntry(
            LearningLedgerCompanion.insert(
              profileId: Value(profileId),
              curriculumId: curriculumId,
              unitType: remote['unitType'] as String? ?? 'masechta',
              unitIdentifier: unitIdentifier,
              unitDisplayNameHe: remote['unitDisplayNameHe'] as String? ?? '',
              unitDisplayNameEn: remote['unitDisplayNameEn'] as String? ?? '',
              trackType: trackType,
              trackId: Value(remote['trackId'] as int?),
              completedAt: completedAt,
              completionNumber: remote['completionNumber'] as int? ?? 1,
              markedBy: remote['markedBy'] as int? ?? 0,
              isManual: Value(remote['isManual'] as bool? ?? false),
            ),
          );
          insertedCount++;
        }
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge ledger entry: $e');
      }
    }

    _logger.debug('Inserted $insertedCount new ledger entries from Firestore');
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

        // v2 §4.1 LWW: delegate the "is remote strictly newer?"
        // predicate to merge_rules.remoteIsNewer so every pull path
        // uses the same rule.
        if (remoteUpdatedAt != null) {
          final localTs = await _getSettingsTimestamp(curriculumId);
          if (!remoteIsNewer(
            localUpdatedAt: localTs,
            remoteUpdatedAt: remoteUpdatedAt,
          )) {
            _logger.debug(
              'Skipping settings for $curriculumId: local is newer or equal',
            );
            continue;
          }
        }

        final trackId = remote['track_id'] as int? ?? 0;
        final companions = stages
            .cast<Map<String, dynamic>>()
            .map(
              (s) => StageDefinitionsCompanion.insert(
                curriculumId: curriculumId,
                trackId: s['track_id'] as int? ?? trackId,
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

        // Merge study day config if present
        await _mergeStudyDayConfig(remote, curriculumId);
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge settings: $e');
      }
    }
  }

  /// Merge study day config from a remote settings document.
  Future<void> _mergeStudyDayConfig(
    Map<String, dynamic> remote,
    String curriculumId,
  ) async {
    final studyDayConfig = remote['study_day_config'] as Map<String, dynamic>?;
    if (studyDayConfig == null) return;

    final remoteTs = _parseTimestamp(remote['study_day_config_updated_at']);
    final profileId = _firestoreDataSource.profileId;

    // v2 §4.1 LWW via merge_rules.remoteIsNewer.
    if (remoteTs != null) {
      final localTs = await _database.studyDayConfigDao.getLatestUpdatedAt(
        profileId: profileId,
        curriculumId: curriculumId,
      );
      if (!remoteIsNewer(localUpdatedAt: localTs, remoteUpdatedAt: remoteTs)) {
        _logger.debug(
          'Skipping study day config for $curriculumId: local is newer',
        );
        return;
      }
    }

    for (final entry in studyDayConfig.entries) {
      final dayOfWeek = int.tryParse(entry.key);
      final dayType = entry.value as String?;
      if (dayOfWeek != null &&
          dayType != null &&
          (dayType == 'study' || dayType == 'review')) {
        await _database.studyDayConfigDao.upsertDayConfig(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: remote['track_id'] as int? ?? 0,
          dayOfWeek: dayOfWeek,
          dayType: dayType,
        );
      }
    }
  }

  /// Merge notification settings from Firestore (last-write-wins per profile).
  ///
  /// Source of truth for runtime notification settings is SharedPreferences.
  /// This merge hydrates local prefs for cloud-born accounts so notification
  /// behavior round-trips across devices.
  Future<void> _mergeNotificationSettings(
    Map<String, dynamic>? remoteSettings,
  ) async {
    if (remoteSettings == null || remoteSettings.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final remoteUpdatedAt = _parseTimestamp(remoteSettings['updated_at']);
      final localUpdatedAtMs = prefs.getInt(
        _notificationSettingsUpdatedAtMsKey,
      );
      final localUpdatedAt = localUpdatedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(localUpdatedAtMs, isUtc: true);

      if (remoteUpdatedAt != null &&
          !remoteIsNewer(
            localUpdatedAt: localUpdatedAt,
            remoteUpdatedAt: remoteUpdatedAt,
          )) {
        _logger.debug(
          'Skipping notification settings merge: local is newer or equal',
        );
        return;
      }

      final dailyReminder =
          remoteSettings['daily_reminder'] as Map<String, dynamic>? ?? const {};
      final streakAlert =
          remoteSettings['streak_alert'] as Map<String, dynamic>? ?? const {};
      final rewardNotifications =
          remoteSettings['reward_notifications'] as Map<String, dynamic>? ??
          const {};
      final shabbosQuietMode =
          remoteSettings['shabbos_quiet_mode'] as Map<String, dynamic>? ??
          const {};

      await prefs.setBool(
        _reminderEnabledKey,
        dailyReminder['enabled'] as bool? ?? true,
      );
      await prefs.setInt(_reminderHourKey, dailyReminder['hour'] as int? ?? 19);
      await prefs.setInt(
        _reminderMinuteKey,
        dailyReminder['minute'] as int? ?? 0,
      );

      await prefs.setBool(
        _streakAlertEnabledKey,
        streakAlert['enabled'] as bool? ?? true,
      );
      await prefs.setInt(
        _streakAlertHourKey,
        streakAlert['hour'] as int? ?? 21,
      );
      await prefs.setInt(
        _streakAlertMinuteKey,
        streakAlert['minute'] as int? ?? 0,
      );

      await prefs.setBool(
        _rewardNotificationEnabledKey,
        rewardNotifications['enabled'] as bool? ?? true,
      );

      await prefs.setBool(
        _shabbosModeEnabledKey,
        shabbosQuietMode['enabled'] as bool? ?? false,
      );
      await prefs.setBool(
        _shabbosModeUseLocationKey,
        shabbosQuietMode['use_location'] as bool? ?? false,
      );
      await prefs.setDouble(
        _shabbosModeLatitudeKey,
        (shabbosQuietMode['latitude'] as num?)?.toDouble() ?? 0.0,
      );
      await prefs.setDouble(
        _shabbosModeLongitudeKey,
        (shabbosQuietMode['longitude'] as num?)?.toDouble() ?? 0.0,
      );
      await prefs.setInt(
        _shabbosModeFixedStartHourKey,
        shabbosQuietMode['fixed_start_hour'] as int? ?? 18,
      );
      await prefs.setInt(
        _shabbosModeFixedStartMinuteKey,
        shabbosQuietMode['fixed_start_minute'] as int? ?? 0,
      );
      await prefs.setInt(
        _shabbosModeFixedEndHourKey,
        shabbosQuietMode['fixed_end_hour'] as int? ?? 20,
      );
      await prefs.setInt(
        _shabbosModeFixedEndMinuteKey,
        shabbosQuietMode['fixed_end_minute'] as int? ?? 0,
      );

      final stamp =
          remoteUpdatedAt?.millisecondsSinceEpoch ??
          DateTime.now().toUtc().millisecondsSinceEpoch;
      await prefs.setInt(_notificationSettingsUpdatedAtMsKey, stamp);
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
      _logger.warning('Failed to merge notification settings: $e');
    }
  }

  Future<Map<String, dynamic>> _buildGamificationSettingsPayload() async {
    final profileId = _firestoreDataSource.profileId;
    final pointRows = await (_database.select(
      _database.pointConfigs,
    )..where((t) => t.profileId.equals(profileId))).get();

    final rewardService = RewardMilestoneService(
      _database,
      profileId: profileId,
    );
    final rewardPayload = await rewardService.exportCloudPayload();
    final now = DateTime.now().toUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _gamificationSettingsUpdatedAtMsKey,
      now.millisecondsSinceEpoch,
    );

    return {
      'updated_at': now.toIso8601String(),
      'points_config': pointRows
          .map(
            (row) => {
              'profile_id': row.profileId,
              'track_id': row.trackId,
              'curriculum_id': row.curriculumId,
              'stage_order': row.stageOrder,
              'points': row.points,
            },
          )
          .toList(),
      'reward_settings': rewardPayload,
    };
  }

  Future<void> _mergeGamificationSettings(
    Map<String, dynamic>? remoteSettings,
  ) async {
    if (remoteSettings == null || remoteSettings.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final remoteUpdatedAt = _parseTimestamp(remoteSettings['updated_at']);
      final localUpdatedAtMs = prefs.getInt(
        _gamificationSettingsUpdatedAtMsKey,
      );
      final localUpdatedAt = localUpdatedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(localUpdatedAtMs, isUtc: true);

      if (remoteUpdatedAt != null &&
          !remoteIsNewer(
            localUpdatedAt: localUpdatedAt,
            remoteUpdatedAt: remoteUpdatedAt,
          )) {
        _logger.debug('Skipping gamification settings merge: local is newer');
        return;
      }

      final remoteRows = remoteSettings['points_config'];
      if (remoteRows is List) {
        for (final raw in remoteRows) {
          if (raw is! Map) continue;
          final map = raw.map((key, value) => MapEntry(key.toString(), value));
          final curriculumId = map['curriculum_id'] as String?;
          final stageOrder = (map['stage_order'] as num?)?.toInt();
          final points = (map['points'] as num?)?.toInt();
          final trackId = (map['track_id'] as num?)?.toInt();
          if (curriculumId == null ||
              stageOrder == null ||
              points == null ||
              trackId == null) {
            continue;
          }

          await _database.pointConfigDao.upsertConfig(
            PointConfigsCompanion.insert(
              profileId: Value(_firestoreDataSource.profileId),
              curriculumId: curriculumId,
              trackId: trackId,
              stageOrder: stageOrder,
              points: points,
            ),
          );
        }
      }

      final rewardService = RewardMilestoneService(
        _database,
        profileId: _firestoreDataSource.profileId,
      );
      final rewardSettingsRaw = remoteSettings['reward_settings'];
      await rewardService.mergeCloudPayload(
        rewardSettingsRaw is Map
            ? rewardSettingsRaw.map(
                (key, value) => MapEntry(key.toString(), value),
              )
            : null,
      );

      final stamp =
          remoteUpdatedAt?.millisecondsSinceEpoch ??
          DateTime.now().toUtc().millisecondsSinceEpoch;
      await prefs.setInt(_gamificationSettingsUpdatedAtMsKey, stamp);
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
      _logger.warning('Failed to merge gamification settings: $e');
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
        final dateType = remote['date_type'] as String? ?? 'gregorian';
        final createdAt = _parseTimestamp(remote['created_at']);
        final updatedAt = _parseTimestamp(remote['updated_at']);

        if (curriculumId == null || createdAt == null || updatedAt == null) {
          _logger.warning('Skipping invalid remote goal: $remote');
          continue;
        }

        await _database.goalDao.upsertGoal(
          curriculumId: curriculumId,
          trackId: remote['track_id'] as int? ?? 0,
          description: description,
          targetPercent: targetPercent,
          targetDate: targetDate,
          dateType: dateType,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge goal: $e');
      }
    }
  }

  /// Merge profile-program assignments from Firestore.
  Future<void> _mergeProfilePrograms(
    List<Map<String, dynamic>> remoteProfilePrograms,
  ) async {
    _logger.debug(
      'Merging ${remoteProfilePrograms.length} profile programs from Firestore',
    );

    final defaultProfileId = _firestoreDataSource.profileId;
    for (final remote in remoteProfilePrograms) {
      try {
        final curriculumId = remote['curriculum_id'] as String?;
        final rawProgramId = remote['program_id'];
        final programId = rawProgramId is int
            ? rawProgramId
            : int.tryParse(rawProgramId?.toString() ?? '');
        final rawProfileId = remote['profile_id'];
        final profileId = rawProfileId is int
            ? rawProfileId
            : int.tryParse(rawProfileId?.toString() ?? '') ?? defaultProfileId;
        final trackingStartDate = _parseTimestamp(
          remote['tracking_start_date'],
        );
        final trackingStartRef = remote['tracking_start_ref'] as String?;

        if (curriculumId == null || programId == null) {
          _logger.warning(
            'Skipping invalid remote profile program assignment: $remote',
          );
          continue;
        }

        await _database.profileProgramDao.setProfileProgram(
          profileId: profileId,
          curriculumType: curriculumId,
          programId: programId,
          trackingStartDate: trackingStartDate,
          trackingStartRef: trackingStartRef,
        );
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge profile program assignment: $e');
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

  /// Merge active curricula from Firestore.
  ///
  /// Activates any remote curriculum not yet present locally, scoped to the
  /// syncing profile. Does not deactivate — deactivation flows through the
  /// repository so user intent is preserved.
  Future<void> _mergeActiveCurricula(List<String> remoteCurricula) async {
    _logger.debug(
      'Merging ${remoteCurricula.length} active curricula from Firestore',
    );
    if (remoteCurricula.isEmpty) return;

    try {
      final profileId = _firestoreDataSource.profileId;
      final localCurricula = await _database.activeCurriculumDao
          .getActiveCurriculaByProfile(profileId);

      for (final curriculumKey in remoteCurricula) {
        if (!localCurricula.contains(curriculumKey)) {
          final curriculumId = CurriculumId.values
              .cast<CurriculumId?>()
              .firstWhere(
                (c) => c!.storageKey == curriculumKey,
                orElse: () => null,
              );
          if (curriculumId != null) {
            await _database.activeCurriculumDao.activateByProfile(
              curriculumId,
              profileId,
            );
          }
        }
      }
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional merge error boundary
      _logger.warning('Failed to merge active curricula: $e');
    }
  }

  /// Merge curriculum tracks from Firestore.
  ///
  /// Upserts each remote track row keyed by (profileId, curriculumId,
  /// trackType) so track activation, deactivation, and archival state all
  /// round-trip across devices. Unknown curriculum/track keys are skipped.
  Future<void> _mergeCurriculumTracks(
    List<Map<String, dynamic>> remoteTracks,
  ) async {
    _logger.debug(
      'Merging ${remoteTracks.length} curriculum tracks from Firestore',
    );
    if (remoteTracks.isEmpty) return;

    final profileId = _firestoreDataSource.profileId;

    for (final remote in remoteTracks) {
      try {
        final curriculumKey = remote['curriculum_id'] as String?;
        final trackTypeKey = remote['track_type'] as String?;
        final isActive = remote['is_active'] as bool? ?? true;
        final activatedAt = _parseTimestamp(remote['activated_at']);
        final deactivatedAt = _parseTimestamp(remote['deactivated_at']);
        final archivedAt = _parseTimestamp(remote['archived_at']);
        final paceResetDate = _parseTimestamp(remote['pace_reset_date']);

        if (curriculumKey == null ||
            trackTypeKey == null ||
            activatedAt == null) {
          _logger.warning('Skipping invalid remote curriculum track: $remote');
          continue;
        }

        final curriculumId = CurriculumId.values
            .cast<CurriculumId?>()
            .firstWhere(
              (c) => c!.storageKey == curriculumKey,
              orElse: () => null,
            );
        final trackType = TrackType.values.cast<TrackType?>().firstWhere(
          (t) => t!.storageKey == trackTypeKey,
          orElse: () => null,
        );
        if (curriculumId == null || trackType == null) {
          _logger.warning(
            'Skipping curriculum track with unknown key: $remote',
          );
          continue;
        }

        final existing =
            await (_database.select(_database.curriculumTracks)..where(
                  (t) =>
                      t.profileId.equals(profileId) &
                      t.curriculumId.equals(curriculumKey) &
                      t.trackType.equals(trackTypeKey),
                ))
                .getSingleOrNull();

        if (existing == null) {
          await _database
              .into(_database.curriculumTracks)
              .insert(
                CurriculumTracksCompanion.insert(
                  profileId: Value(profileId),
                  curriculumId: curriculumKey,
                  trackType: trackTypeKey,
                  isActive: Value(isActive),
                  activatedAt: activatedAt,
                  deactivatedAt: Value(deactivatedAt),
                  archivedAt: Value(archivedAt),
                  paceResetDate: Value(paceResetDate),
                ),
              );
        } else {
          await (_database.update(
            _database.curriculumTracks,
          )..where((t) => t.id.equals(existing.id))).write(
            CurriculumTracksCompanion(
              isActive: Value(isActive),
              activatedAt: Value(activatedAt),
              deactivatedAt: Value(deactivatedAt),
              archivedAt: Value(archivedAt),
              paceResetDate: Value(paceResetDate),
            ),
          );
        }

        // Keep active_curricula table consistent even when the dedicated
        // active_curricula document is missing in Firestore.
        if (isActive && archivedAt == null) {
          await _database.activeCurriculumDao.activateByProfile(
            curriculumId,
            profileId,
          );
        }
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge curriculum track: $e');
      }
    }
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

  /// Merge learner profiles (profiles table) from Firestore.
  /// Upserts each remote row into the local profiles table preserving its
  /// remote id so profile-scoped data (completions, bookmarks, …) keyed by
  /// profile_id resolves consistently across devices.
  Future<void> _mergeLearnerProfiles(
    List<Map<String, dynamic>> remoteProfiles,
  ) async {
    _logger.debug('Merging ${remoteProfiles.length} learner profiles');

    for (final remote in remoteProfiles) {
      try {
        final rawId = remote['id'];
        final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (id == null) {
          _logger.warning('Skipping invalid remote learner profile: $remote');
          continue;
        }

        final rawAccountId = remote['account_id'];
        final accountId = rawAccountId is int
            ? rawAccountId
            : int.tryParse(rawAccountId?.toString() ?? '') ?? 1;

        final rawDisplayName = remote['display_name']?.toString().trim();
        final legacyName = remote['name']?.toString().trim();
        final displayName = rawDisplayName != null && rawDisplayName.isNotEmpty
            ? rawDisplayName
            : (legacyName != null && legacyName.isNotEmpty
                  ? legacyName
                  : 'Profile $id');

        final rawMode = remote['mode']?.toString().toLowerCase().trim();
        final mode = rawMode == 'child' ? 'child' : 'adult';

        final rawAvatarIndex = remote['avatar_index'];
        final avatarIndex = rawAvatarIndex is int
            ? rawAvatarIndex
            : int.tryParse(rawAvatarIndex?.toString() ?? '') ?? 0;

        final nowUtc = DateTime.now().toUtc();
        final createdAt =
            _parseTimestamp(remote['created_at']) ??
            _parseTimestamp(remote['updated_at']) ??
            nowUtc;
        final remoteUpdatedAt = _parseTimestamp(remote['updated_at']);
        final updatedAt =
            remoteUpdatedAt ??
            _parseTimestamp(remote['created_at']) ??
            createdAt;

        final existing = await _database.profileDao.getProfileById(id);
        if (existing == null) {
          await _database
              .into(_database.profiles)
              .insertOnConflictUpdate(
                ProfilesCompanion.insert(
                  id: Value(id),
                  accountId: accountId,
                  displayName: displayName,
                  mode: mode,
                  avatarIndex: Value(avatarIndex),
                  createdAt: createdAt,
                  updatedAt: updatedAt,
                ),
              );
        } else if (remoteUpdatedAt != null &&
            remoteUpdatedAt.isAfter(existing.updatedAt)) {
          await (_database.update(
            _database.profiles,
          )..where((t) => t.id.equals(id))).write(
            ProfilesCompanion(
              displayName: Value(displayName),
              mode: Value(mode),
              avatarIndex: Value(avatarIndex),
              updatedAt: Value(updatedAt),
            ),
          );
        }
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning('Failed to merge learner profile: $e');
      }
    }
  }

  /// Backfill learner profiles to Firestore when local rows exist but
  /// the account-level `learner_profiles` collection is missing entries.
  ///
  /// This heals accounts created before learner-profile Firestore rules
  /// were deployed, so signing in on a second device can recover profiles.
  Future<void> _backfillLearnerProfilesIfNeeded() async {
    if (!_isOnline || !_firestoreDataSource.isAuthenticated) return;

    try {
      final remoteProfiles = await _firestoreDataSource.fetchLearnerProfiles();
      final remoteById = <int, Map<String, dynamic>>{};
      for (final remote in remoteProfiles) {
        final rawId = remote['id'];
        final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (id != null) {
          remoteById[id] = remote;
        }
      }

      final localProfiles = await _database.select(_database.profiles).get();
      if (localProfiles.isEmpty) return;

      var pushed = 0;
      for (final profile in localProfiles) {
        final remote = remoteById[profile.id];
        final needsCreate = remote == null;
        final missingStreakSummary =
            remote != null && remote['streak_summary'] == null;
        final missingRewardConfiguration =
            remote != null && remote['reward_configuration'] == null;
        if (!needsCreate &&
            !missingStreakSummary &&
            !missingRewardConfiguration) {
          continue;
        }

        await pushLearnerProfile({
          'id': profile.id,
          'account_id': profile.accountId,
          'display_name': profile.displayName,
          'mode': profile.mode,
          'avatar_index': profile.avatarIndex,
          'created_at': profile.createdAt.toIso8601String(),
          'updated_at': profile.updatedAt.toIso8601String(),
        });
        pushed++;
      }

      if (pushed > 0) {
        _logger.info('Backfilled $pushed learner profile(s) to Firestore');
      }
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — best-effort backfill path
      _logger.warning('Learner profile backfill skipped: $e');
    }
  }

  /// Backfill profile-scoped curriculum tracks to Firestore when missing.
  ///
  /// This ensures newly added track-state syncing is populated for existing
  /// cloud users who already had local track rows before the sync payload
  /// included `track_id` / activation fields.
  Future<void> _backfillCurriculumTracksIfNeeded() async {
    if (!_isOnline || !_firestoreDataSource.isAuthenticated) return;

    try {
      final remoteTracks = await _firestoreDataSource.fetchCurriculumTracks();
      final remoteKeys = remoteTracks
          .map((t) => '${t['curriculum_id']}_${t['track_type']}')
          .whereType<String>()
          .toSet();

      final localTracks = await _database.trackDao.getAllForProfile(
        _firestoreDataSource.profileId,
      );
      if (localTracks.isEmpty) return;

      var pushed = 0;
      for (final track in localTracks) {
        final key = '${track.curriculumId}_${track.trackType}';
        if (remoteKeys.contains(key)) continue;

        await pushCurriculumTrack({
          'profile_id': track.profileId,
          'track_id': track.id,
          'curriculum_id': track.curriculumId,
          'track_type': track.trackType,
          'is_active': track.isActive,
          'activated_at': track.activatedAt.toIso8601String(),
          'deactivated_at': track.deactivatedAt?.toIso8601String(),
          'archived_at': track.archivedAt?.toIso8601String(),
          'pace_reset_date': track.paceResetDate?.toIso8601String(),
        });
        pushed++;
      }

      if (pushed > 0) {
        _logger.info('Backfilled $pushed curriculum track(s) to Firestore');
      }
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — best-effort backfill path
      _logger.warning('Curriculum track backfill skipped: $e');
    }
  }

  /// Repair legacy completion rows that were synced without `track_id`.
  ///
  /// Older cloud payloads omitted track_id, causing restored rows to land
  /// with trackId=0. This breaks track-scoped progress percentages on the
  /// dashboard/progress views. We repair by mapping (profile,curriculum,
  /// trackType) -> trackId when possible.
  Future<void> _repairLegacyCompletionTrackIds() async {
    final profileId = _firestoreDataSource.profileId;

    try {
      final legacyRows =
          await (_database.select(_database.completions)..where(
                (t) => t.profileId.equals(profileId) & t.trackId.equals(0),
              ))
              .get();
      if (legacyRows.isEmpty) return;

      final trackIdCache = <String, int>{};
      var updated = 0;

      for (final row in legacyRows) {
        final key = '${row.curriculumId}|${row.trackType}';
        var trackId = trackIdCache[key];
        if (trackId == null) {
          final track =
              await (_database.select(_database.curriculumTracks)
                    ..where(
                      (t) =>
                          t.profileId.equals(profileId) &
                          t.curriculumId.equals(row.curriculumId) &
                          t.trackType.equals(row.trackType),
                    )
                    ..limit(1))
                  .getSingleOrNull();
          trackId = track?.id ?? 0;
          trackIdCache[key] = trackId;
        }

        if (trackId == 0) continue;

        await (_database.update(_database.completions)
              ..where((t) => t.id.equals(row.id)))
            .write(CompletionsCompanion(trackId: Value(trackId)));
        updated++;
      }

      if (updated > 0) {
        _logger.info('Repaired $updated legacy completion track ids');
      }
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — best-effort repair path
      _logger.warning('Legacy completion track-id repair skipped: $e');
    }
  }

  /// Enrich learner profile payload with user-visible snapshot data so
  /// account-level `learner_profiles` docs contain profile settings and
  /// progress metadata for quick inspection and restore UX.
  Future<Map<String, dynamic>> _enrichLearnerProfilePayload(
    Map<String, dynamic> profile,
  ) async {
    final profileId = profile['id'] as int?;
    if (profileId == null) return profile;
    final mode = (profile['mode'] as String?)?.toLowerCase();
    final isChildProfile = mode == 'child';

    final activeCurricula = await _database.activeCurriculumDao
        .getActiveCurriculaByProfile(profileId);

    final stageRows = await (_database.select(
      _database.stageDefinitions,
    )..where((t) => t.profileId.equals(profileId))).get();
    final pointRows = await (_database.select(
      _database.pointConfigs,
    )..where((t) => t.profileId.equals(profileId))).get();
    final studyDayRows = await (_database.select(
      _database.studyDayConfigs,
    )..where((t) => t.profileId.equals(profileId))).get();

    final curriculumSettings = <String, Map<String, dynamic>>{};
    for (final row in stageRows) {
      final cfg = curriculumSettings.putIfAbsent(
        row.curriculumId,
        () => <String, dynamic>{
          'stages': <Map<String, dynamic>>[],
          'points_by_stage': <String, int>{},
          'points_by_stage_by_track': <String, Map<String, int>>{},
          'study_day_config': <String, String>{},
        },
      );
      (cfg['stages'] as List<Map<String, dynamic>>).add({
        'track_id': row.trackId,
        'stage_order': row.stageOrder,
        'stage_name': row.stageName,
        'delay_days': row.delayDays,
        'schedule_type': row.scheduleType,
        'days_of_week': row.daysOfWeek,
        'rolling_window_size': row.rollingWindowSize,
      });
    }
    for (final row in pointRows) {
      final cfg = curriculumSettings.putIfAbsent(
        row.curriculumId,
        () => <String, dynamic>{
          'stages': <Map<String, dynamic>>[],
          'points_by_stage': <String, int>{},
          'points_by_stage_by_track': <String, Map<String, int>>{},
          'study_day_config': <String, String>{},
        },
      );
      (cfg['points_by_stage'] as Map<String, int>)[row.stageOrder.toString()] =
          row.points;
      final byTrack =
          cfg['points_by_stage_by_track'] as Map<String, Map<String, int>>;
      final trackMap = byTrack.putIfAbsent(row.trackId.toString(), () => {});
      trackMap[row.stageOrder.toString()] = row.points;
    }
    for (final row in studyDayRows) {
      final cfg = curriculumSettings.putIfAbsent(
        row.curriculumId,
        () => <String, dynamic>{
          'stages': <Map<String, dynamic>>[],
          'points_by_stage': <String, int>{},
          'points_by_stage_by_track': <String, Map<String, int>>{},
          'study_day_config': <String, String>{},
        },
      );
      (cfg['study_day_config'] as Map<String, String>)[row.dayOfWeek
              .toString()] =
          row.dayType;
    }

    final totalCompletionsExpr = _database.completions.id.count();
    final completionStats =
        await (_database.selectOnly(_database.completions)
              ..addColumns([totalCompletionsExpr])
              ..where(_database.completions.profileId.equals(profileId)))
            .getSingle();
    final lastCompletion =
        await (_database.select(_database.completions)
              ..where((t) => t.profileId.equals(profileId))
              ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
              ..limit(1))
            .getSingleOrNull();
    final streak = await _database.streakDao.getStreakByProfile(profileId);
    final rewardService = RewardMilestoneService(
      _database,
      profileId: profileId,
    );
    final rewardPayload = await rewardService.exportCloudPayload();

    final enriched = <String, dynamic>{
      ...profile,
      'active_curricula': activeCurricula,
      'progress_summary': {
        'total_completions': completionStats.read(totalCompletionsExpr) ?? 0,
        'last_completion_at': lastCompletion?.completedAt.toIso8601String(),
      },
      'streak_summary': {
        'current_streak': streak?.currentStreak ?? 0,
        'max_streak': streak?.maxStreak ?? 0,
        'last_completion_date': streak?.lastCompletionDate?.toIso8601String(),
      },
      'reward_configuration':
          rewardPayload['milestones'] ?? const <Map<String, dynamic>>[],
      'reward_progress': {
        'unlocks': rewardPayload['unlocks'] ?? const <Map<String, dynamic>>[],
      },
      'settings_snapshot': curriculumSettings,
    };

    // Handbook alignment: gamification payload is child-mode only.
    if (isChildProfile) {
      final totalPointsExpr = _database.completions.points.sum();
      final totalPointsRow =
          await (_database.selectOnly(_database.completions)
                ..addColumns([totalPointsExpr])
                ..where(_database.completions.profileId.equals(profileId)))
              .getSingle();
      final totalPoints = totalPointsRow.read(totalPointsExpr) ?? 0;

      enriched['gamification_summary'] = {
        'total_points': totalPoints,
        'current_streak': streak?.currentStreak ?? 0,
        'max_streak': streak?.maxStreak ?? 0,
        'last_completion_date': streak?.lastCompletionDate?.toIso8601String(),
      };
    }

    return enriched;
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

  Future<void> _onBookmarksUpdate(List<Map<String, dynamic>> bookmarks) async {
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

  Future<void> _onSettingsUpdate(List<Map<String, dynamic>> settings) async {
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

  Future<void> _onStreakUpdate(Map<String, dynamic>? streak) async {
    if (streak == null) return;
    if (_mergingStreak) return;
    _mergingStreak = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug('Received streak update from listener');
      await _mergeStreak(streak);
    } finally {
      _mergingStreak = false;
    }
  }

  Future<void> _onGoalsUpdate(List<Map<String, dynamic>> goals) async {
    if (_mergingGoals) return;
    _mergingGoals = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug('Received ${goals.length} goals from listener');
      await _mergeGoals(goals);
    } finally {
      _mergingGoals = false;
    }
  }

  Future<void> _onProfileProgramsUpdate(
    List<Map<String, dynamic>> profilePrograms,
  ) async {
    if (_mergingProfilePrograms) return;
    _mergingProfilePrograms = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(
        'Received ${profilePrograms.length} profile programs from listener',
      );
      await _mergeProfilePrograms(profilePrograms);
    } finally {
      _mergingProfilePrograms = false;
    }
  }

  Future<void> _onActiveCurriculaUpdate(List<String> curricula) async {
    if (_mergingActiveCurricula) return;
    _mergingActiveCurricula = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(
        'Received ${curricula.length} active curricula from listener',
      );
      await _mergeActiveCurricula(curricula);
    } finally {
      _mergingActiveCurricula = false;
    }
  }

  Future<void> _onLedgerUpdate(List<Map<String, dynamic>> ledgerEntries) async {
    if (_mergingLedgerEntries) return;
    _mergingLedgerEntries = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(
        'Received ${ledgerEntries.length} ledger entries from listener',
      );
      await _mergeLedgerEntries(ledgerEntries);
    } finally {
      _mergingLedgerEntries = false;
    }
  }

  Future<void> _onCurriculumTracksUpdate(
    List<Map<String, dynamic>> tracks,
  ) async {
    if (_mergingCurriculumTracks) return;
    _mergingCurriculumTracks = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(
        'Received ${tracks.length} curriculum tracks from listener',
      );
      await _mergeCurriculumTracks(tracks);
    } finally {
      _mergingCurriculumTracks = false;
    }
  }

  Future<void> _onNotificationSettingsUpdate(
    Map<String, dynamic>? notificationSettings,
  ) async {
    if (notificationSettings == null) return;
    if (_mergingNotificationSettings) return;
    _mergingNotificationSettings = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug('Received notification settings update from listener');
      await _mergeNotificationSettings(notificationSettings);
    } finally {
      _mergingNotificationSettings = false;
    }
  }

  Future<void> _onGamificationSettingsUpdate(
    Map<String, dynamic>? gamificationSettings,
  ) async {
    if (gamificationSettings == null) return;
    if (_mergingGamificationSettings) return;
    _mergingGamificationSettings = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug('Received gamification settings update from listener');
      await _mergeGamificationSettings(gamificationSettings);
    } finally {
      _mergingGamificationSettings = false;
    }
  }

  /// Handle listener errors with quota monitoring (NFR21).
  ///
  /// After [quotaErrorThreshold] consecutive errors, disables all listeners
  /// to prevent further quota consumption. The app falls back to
  /// pull-on-launch sync only.
  void _handleListenerError(Object error, StackTrace stackTrace) {
    _logger.error('Listener error', error, stackTrace);

    // Distinguish PERMISSION_DENIED (auth issue) from other errors (quota).
    // Permission errors should detach immediately — retrying just wastes
    // requests and the 3-strike counter would misattribute them as quota.
    if (error is FirebaseException && error.code == 'permission-denied') {
      _logger.warning(
        'Listener received PERMISSION_DENIED — detaching listeners. '
        'Likely a stale or missing auth session.',
      );
      detachListeners();
      _updateStatus(
        SyncStatus.error(
          message:
              'Authentication error — real-time sync paused. '
              'Sync will resume on next sign-in.',
          failedAt: DateTime.now().toUtc(),
        ),
      );
      return;
    }

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
    _consecutivePushPermissionErrors = 0;

    if (!_firestoreDataSource.isAuthenticated) {
      _logger.info(
        'Reconnect flush deferred: user not authenticated '
        '(keeping queued writes local)',
      );
      await _updateQueueOnlyStatus();
      return;
    }

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

    if (_isQueueOnlyMode) {
      await _offlineQueue.enqueueCurriculumImportMetadata(
        _withQueueTargetProfile(metadata),
      );
      await _updateQueueOnlyStatus();
      return;
    }

    try {
      await _firestoreDataSource.pushCurriculumImportMetadata(metadata);
      _consecutivePushPermissionErrors = 0;
      _logger.debug(
        'Pushed curriculum import metadata to Firestore: $curriculumId',
      );
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning(
        'Failed to push curriculum import metadata, queuing for later',
        e,
      );
      await _offlineQueue.enqueueCurriculumImportMetadata(
        _withQueueTargetProfile(metadata),
      );
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

  /// Read notification preferences from local SharedPreferences and convert
  /// them into the profile-scoped Firestore notification_settings payload.
  Future<Map<String, dynamic>> _readLocalNotificationSettingsPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final updatedAtMs = prefs.getInt(_notificationSettingsUpdatedAtMsKey);
    final updatedAt = updatedAtMs == null
        ? DateTime.now().toUtc()
        : DateTime.fromMillisecondsSinceEpoch(updatedAtMs, isUtc: true);

    return {
      'schema_version': 1,
      'daily_reminder': {
        'enabled': prefs.getBool(_reminderEnabledKey) ?? true,
        'hour': prefs.getInt(_reminderHourKey) ?? 19,
        'minute': prefs.getInt(_reminderMinuteKey) ?? 0,
      },
      'streak_alert': {
        'enabled': prefs.getBool(_streakAlertEnabledKey) ?? true,
        'hour': prefs.getInt(_streakAlertHourKey) ?? 21,
        'minute': prefs.getInt(_streakAlertMinuteKey) ?? 0,
      },
      'reward_notifications': {
        'enabled': prefs.getBool(_rewardNotificationEnabledKey) ?? true,
      },
      'shabbos_quiet_mode': {
        'enabled': prefs.getBool(_shabbosModeEnabledKey) ?? false,
        'use_location': prefs.getBool(_shabbosModeUseLocationKey) ?? false,
        'latitude': prefs.getDouble(_shabbosModeLatitudeKey) ?? 0.0,
        'longitude': prefs.getDouble(_shabbosModeLongitudeKey) ?? 0.0,
        'fixed_start_hour': prefs.getInt(_shabbosModeFixedStartHourKey) ?? 18,
        'fixed_start_minute':
            prefs.getInt(_shabbosModeFixedStartMinuteKey) ?? 0,
        'fixed_end_hour': prefs.getInt(_shabbosModeFixedEndHourKey) ?? 20,
        'fixed_end_minute': prefs.getInt(_shabbosModeFixedEndMinuteKey) ?? 0,
      },
      // LWW merge compares this timestamp against local prefs timestamp.
      'updated_at': updatedAt.toIso8601String(),
    };
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

  // ========== Initial Cloud Push (DNI-190) ==========

  /// Push all local data to Firestore after account creation.
  ///
  /// Reads every user-data table and pushes each record using the existing
  /// push-on-write methods. Firestore uses `set(merge: true)` underneath,
  /// so this is idempotent and safe to retry.
  ///
  /// Called once after the user creates a cloud account (story 19.7).
  Future<void> pushAllLocalData() async {
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.warning('pushAllLocalData skipped: user not authenticated');
      return;
    }

    _logger.info('pushAllLocalData: starting initial cloud push');
    _updateStatus(SyncStatus.syncing(startedAt: DateTime.now().toUtc()));

    try {
      // --- Completions (append-only) ---
      final completions = await _database.completionDao.getAllCompletions();
      for (final c in completions) {
        await pushCompletion({
          'profile_id': c.profileId,
          'curriculum_id': c.curriculumId,
          'content_item_id': c.sefariaRef,
          'stage_id': c.stageId,
          'track_type': c.trackType,
          'track_id': c.trackId,
          'completed_at': c.completedAt.toIso8601String(),
          'points': c.points,
        });
      }
      _logger.debug('Pushed ${completions.length} completions');

      // --- Bookmarks ---
      final bookmarks = await _database.bookmarkDao.getAllBookmarks();
      for (final b in bookmarks) {
        await pushBookmark({
          'curriculum_id': b.curriculumId,
          'track_type': b.trackType,
          'content_item_id': b.sefariaRef,
          'updated_at': b.updatedAt.toIso8601String(),
        });
      }
      _logger.debug('Pushed ${bookmarks.length} bookmarks');

      // --- Goals ---
      final goals = await _database.goalDao.getAllGoals();
      for (final g in goals) {
        await pushGoal({
          'curriculum_id': g.curriculumId,
          'description': g.description,
          'target_percent': g.targetPercent,
          'target_date': g.targetDate?.toIso8601String(),
          'date_type': g.dateType,
          'goal_type': g.goalType,
          'pace_value': g.paceValue,
          'pace_unit': g.paceUnit,
          'created_at': g.createdAt.toIso8601String(),
          'updated_at': g.updatedAt.toIso8601String(),
        });
      }
      _logger.debug('Pushed ${goals.length} goals');

      // --- Program assignments / start anchors ---
      final profilePrograms = await _database.profileProgramDao
          .getProgramsForProfile(_firestoreDataSource.profileId);
      for (final p in profilePrograms) {
        await pushProfileProgram({
          'profile_id': p.profileId,
          'curriculum_id': p.curriculumType,
          'program_id': p.programId,
          'tracking_start_date': p.trackingStartDate?.toIso8601String(),
          'tracking_start_ref': p.trackingStartRef,
        });
      }
      _logger.debug('Pushed ${profilePrograms.length} profile programs');

      // --- Streak ---
      final streak = await _database.streakDao.getStreakByProfile(
        _firestoreDataSource.profileId,
      );
      if (streak != null) {
        await pushStreak({
          'current_count': streak.currentStreak,
          'max_count': streak.maxStreak,
          'last_completion_date': streak.lastCompletionDate?.toIso8601String(),
          'grace_used_date': streak.graceUsedDate?.toIso8601String(),
          'grace_period_days': streak.gracePeriodDays,
        });
        _logger.debug('Pushed streak');
      }

      // --- Ledger entries ---
      // LearningLedgerDao has no getAll, so query via the database
      // directly using select on the table.
      final ledgerEntries = await _database
          .select(_database.learningLedger)
          .get();
      for (final e in ledgerEntries) {
        await pushLedgerEntry({
          'curriculumId': e.curriculumId,
          'unitType': e.unitType,
          'unitIdentifier': e.unitIdentifier,
          'unitDisplayNameHe': e.unitDisplayNameHe,
          'unitDisplayNameEn': e.unitDisplayNameEn,
          'trackType': e.trackType,
          'trackId': e.trackId,
          'completedAt': e.completedAt.toIso8601String(),
          'completionNumber': e.completionNumber,
          'markedBy': e.markedBy,
          'isManual': e.isManual,
        });
      }
      _logger.debug('Pushed ${ledgerEntries.length} ledger entries');

      // --- Active curricula (scoped to the syncing profile) ---
      final activeCurricula = await _database.activeCurriculumDao
          .getActiveCurriculaByProfile(_firestoreDataSource.profileId);
      if (activeCurricula.isNotEmpty) {
        await _firestoreDataSource.pushActiveCurricula(activeCurricula);
        _logger.debug('Pushed ${activeCurricula.length} active curricula');
      }

      // --- Curriculum tracks (track activation/archival state) ---
      final tracks = await _database.trackDao.getAllForProfile(
        _firestoreDataSource.profileId,
      );
      for (final t in tracks) {
        await pushCurriculumTrack({
          'profile_id': t.profileId,
          'track_id': t.id,
          'curriculum_id': t.curriculumId,
          'track_type': t.trackType,
          'is_active': t.isActive,
          'activated_at': t.activatedAt.toIso8601String(),
          'deactivated_at': t.deactivatedAt?.toIso8601String(),
          'archived_at': t.archivedAt?.toIso8601String(),
          'pace_reset_date': t.paceResetDate?.toIso8601String(),
        });
      }
      _logger.debug('Pushed ${tracks.length} curriculum tracks');

      // --- Notification settings (profile-scoped preferences) ---
      final notificationSettings =
          await _readLocalNotificationSettingsPayload();
      await pushNotificationSettings(notificationSettings);
      _logger.debug('Pushed notification settings');

      // --- Gamification settings (points + reward milestones/unlocks) ---
      await pushGamificationSettingsSnapshot();
      _logger.debug('Pushed gamification settings');

      _logger.info('pushAllLocalData: completed successfully');
      final syncedAt = DateTime.now().toUtc();
      await _persistLastSyncTimestamp(syncedAt);
      _updateStatus(SyncStatus.synced(lastSyncedAt: syncedAt));
    } catch (e, stackTrace) {
      _logger.error('pushAllLocalData failed', e, stackTrace);
      _updateStatus(
        SyncStatus.error(
          message: e.toString(),
          failedAt: DateTime.now().toUtc(),
        ),
      );
    }
  }
}
