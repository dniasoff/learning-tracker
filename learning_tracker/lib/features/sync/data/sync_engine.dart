import 'dart:async';
import 'package:drift/drift.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/learning/completion_command.dart';
import 'package:learning_tracker/core/learning/completion_writer.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/connectivity_service.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:learning_tracker/features/sync/data/firestore_data_source.dart';
import 'package:learning_tracker/features/sync/data/offline_queue.dart';
import 'package:learning_tracker/features/sync/domain/merge_rules.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/domain/profile_scoped_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Orchestrates sync between local SQLite and Firestore.
///
/// Implements D4 hybrid push/pull architecture:
/// - **Push-on-write**: Local writes enqueue to `sync_queue`, then a background
///   flush pushes to Firestore (never blocking the UI on network). Only used when
///   [SyncEngine] is wired—cloud-born / upgraded accounts (`sync_providers`).
/// - **Pull-on-launch**: App startup pulls latest data and merges locally
/// - **Foreground listeners**: Real-time sync while app is in foreground
/// - **Offline queue**: When offline or push-suppressed, writes stay queued until flush
///
/// @deprecated — DNI-333 Phase 6: External code should depend on [SyncWriteFacade]
/// (for push operations) or [SyncOrchestrator] (for pull/status). This class is
/// scheduled for deletion once all entity mergers have migrated to [MergeRouter].
class SyncEngine implements SyncWriteFacade {
  SyncEngine({
    required UserDatabase database,
    required FirestoreDataSource firestoreDataSource,
    required OfflineQueue offlineQueue,
    required AppLogger logger,
    required ConnectivityService connectivityService,
    AnalyticsService? analytics,
    OutboxProcessor? outboxProcessor,
  }) : _database = database,
       _firestoreDataSource = firestoreDataSource,
       _offlineQueue = offlineQueue,
       _logger = logger,
       _connectivityService = connectivityService,
       _analytics = analytics ?? const NullAnalyticsService(),
       _outboxProcessor = outboxProcessor;

  final UserDatabase _database;
  final FirestoreDataSource _firestoreDataSource;
  final OfflineQueue _offlineQueue;
  final AppLogger _logger;
  final ConnectivityService _connectivityService;
  final AnalyticsService _analytics;

  /// Optional new-pipeline outbox processor. When non-null, each background
  /// flush also drains the [Outbox] table via [OutboxProcessor.drain].
  /// This is Phase 1 of the SyncEngine decomposition (DNI-333): both paths
  /// run in parallel so no existing behaviour is removed.
  final OutboxProcessor? _outboxProcessor;

  final _statusController = StreamController<SyncStatus>.broadcast();
  Stream<SyncStatus> get statusStream => _statusController.stream;

  SyncStatus _currentStatus = SyncStatus.synced(
    lastSyncedAt: DateTimeFactory.nowUtc(),
  );
  SyncStatus get currentStatus => _currentStatus;

  StreamSubscription<List<Map<String, dynamic>>>? _completionsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _bookmarksSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _settingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _streakSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _goalsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _profileProgramsSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _ledgerSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _curriculumTracksSubscription;
  StreamSubscription<Map<String, dynamic>?>? _notificationSettingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _gamificationSettingsSubscription;
  StreamSubscription<Map<String, dynamic>?>? _uiPreferencesSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _learningOrderSubscription;

  bool _isOnline = true;
  bool _listenersAttached = false;

  /// Single-flight guard for [_runBackgroundFlush].
  /// When true, a drain is already in progress; new calls set [_rerunRequested]
  /// and return immediately to avoid concurrent drains.
  bool _flushInProgress = false;
  bool _rerunRequested = false;

  /// Guard ensuring [pullOnLaunch] runs at most once per app launch.
  /// Re-entrant calls (e.g. from both SyncEngine and SyncOrchestrator) are
  /// no-ops once the first call has started. [triggeredFromResume] throttle
  /// still applies on top of this for resume-driven calls.
  bool _pullOnLaunchExecuted = false;

  /// Debounce timer for [_onCompletionsUpdate] — batches rapid Firestore
  /// snapshots into a single merge pass (300 ms window).
  Timer? _completionsDebounceTimer;
  List<Map<String, dynamic>>? _pendingCompletionsSnapshot;

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
  bool _mergingLedgerEntries = false;
  bool _mergingCurriculumTracks = false;
  bool _mergingNotificationSettings = false;
  bool _mergingGamificationSettings = false;
  bool _mergingUiPreferences = false;
  bool _mergingLearningOrder = false;

  /// SharedPreferences key for persisted last-sync timestamp.
  static const _lastSyncKey = 'sync_engine_last_synced_at';

  /// SharedPreferences key for tombstoned learner profile IDs.
  /// Profiles in this set were deleted locally and must never be
  /// re-inserted by [_mergeLearnerProfiles], even if Firestore still
  /// has the document (e.g. network delete in flight).
  static const _deletedProfileIdsKey = 'sync_deleted_learner_profile_ids';

  /// Minimum time between full [pullOnLaunch] runs when triggered from
  /// [AppLifecycleState.resumed] only. Cold start / [initialize] always pulls.
  static const Duration pullOnResumeMinInterval = Duration(minutes: 5);

  // Notification settings keys (must match notification providers).
  static const _notificationSettingsUpdatedAtMsKey =
      'notification_settings_updated_at_ms';
  static const _gamificationSettingsUpdatedAtMsKey =
      'gamification_settings_updated_at_ms';

  String _curriculumSettingsTimestampKey(int profileId, String curriculumId) =>
      'settings_ts_p${profileId}_$curriculumId';

  String _gamificationLocalUpdatedAtKey(int profileId) =>
      '${_gamificationSettingsUpdatedAtMsKey}_p$profileId';

  static const _reminderEnabledKey = 'daily_reminder_enabled';
  static const _reminderHourKey = 'daily_reminder_hour';
  static const _reminderMinuteKey = 'daily_reminder_minute';
  static const _streakAlertEnabledKey = 'streak_alert_enabled';
  static const _streakAlertHourKey = 'streak_alert_hour';
  static const _streakAlertMinuteKey = 'streak_alert_minute';
  static const _rewardNotificationEnabledKey = 'reward_notification_enabled';

  // ========== Lifecycle Methods ==========

  /// Initialize sync engine and pull data on launch.
  Future<void> initialize() async {
    _logger.info(event: 'sync_engine_initializing');

    // One-time cleanup: drop stale `completion` rows left in the legacy
    // sync_queue by pre-rework builds. The outbox is now the canonical
    // completion queue, so these rows are unreachable dead data.
    await _purgeLegacyCompletionQueueRows();

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
    _logger.info(event: 'sync_engine_disposing');
    // detachListeners() cancels the completions debounce timer; cancel it here
    // too so disposal stays correct even if detachListeners() short-circuits or
    // is reordered by a future refactor (I2).
    _completionsDebounceTimer?.cancel();
    _completionsDebounceTimer = null;
    _pendingCompletionsSnapshot = null;
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
    _logger.info(
      event: 'sync_engine_network_state_changed',
      fields: {'online': isOnline},
    );

    if (isOnline) {
      _onReconnect();
    } else {
      _onDisconnect();
    }
  }

  /// Attach foreground listeners for real-time sync.
  Future<void> attachListeners() async {
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.debug(event: 'sync_listeners_attach_skipped_unauthenticated');
      return;
    }

    if (_listenersAttached) {
      _logger.debug(event: 'sync_listeners_already_attached');
      return;
    }

    if (!_isOnline) {
      _logger.debug(event: 'sync_listeners_attach_skipped_offline');
      return;
    }

    if (_quotaDegraded) {
      _logger.debug(event: 'sync_listeners_attach_skipped_quota_degraded');
      return;
    }

    _logger.info(event: 'sync_listeners_attaching');
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

    _uiPreferencesSubscription = _firestoreDataSource
        .listenToUiPreferences()
        .listen(_onUiPreferencesUpdate, onError: _handleListenerError);

    _learningOrderSubscription = _firestoreDataSource
        .listenToLearningOrder()
        .listen(_onLearningOrderUpdate, onError: _handleListenerError);
  }

  /// Detach foreground listeners (on app background).
  Future<void> detachListeners() async {
    // Cancel the completions debounce timer unconditionally — a pending timer
    // outlives the listener subscriptions and would otherwise fire ~300 ms
    // later, merging into a detached (or, after dispose, closed) engine (I2).
    _completionsDebounceTimer?.cancel();
    _completionsDebounceTimer = null;
    _pendingCompletionsSnapshot = null;

    if (!_listenersAttached) {
      _logger.debug(event: 'sync_listeners_already_detached');
      return;
    }

    _logger.info(event: 'sync_listeners_detaching');
    _listenersAttached = false;

    await _completionsSubscription?.cancel();
    await _bookmarksSubscription?.cancel();
    await _settingsSubscription?.cancel();
    await _streakSubscription?.cancel();
    await _goalsSubscription?.cancel();
    await _profileProgramsSubscription?.cancel();
    await _ledgerSubscription?.cancel();
    await _curriculumTracksSubscription?.cancel();
    await _notificationSettingsSubscription?.cancel();
    await _gamificationSettingsSubscription?.cancel();
    await _uiPreferencesSubscription?.cancel();
    await _learningOrderSubscription?.cancel();

    _completionsSubscription = null;
    _bookmarksSubscription = null;
    _settingsSubscription = null;
    _streakSubscription = null;
    _goalsSubscription = null;
    _profileProgramsSubscription = null;
    _ledgerSubscription = null;
    _curriculumTracksSubscription = null;
    _notificationSettingsSubscription = null;
    _gamificationSettingsSubscription = null;
    _uiPreferencesSubscription = null;
    _learningOrderSubscription = null;
  }

  // ========== Pull-on-Launch ==========

  /// Pull latest data from Firestore on app launch.
  ///
  /// When [triggeredFromResume] is true, a full pull is skipped if the last
  /// successful pull was within [pullOnResumeMinInterval] (foreground listeners
  /// still deliver realtime updates).
  Future<void> pullOnLaunch({bool triggeredFromResume = false}) async {
    // Re-entrancy guard: if a cold-start pull has already been kicked off
    // (or completed), additional non-resume calls are no-ops. Resume-triggered
    // calls still proceed through the timestamp throttle below.
    if (!triggeredFromResume && _pullOnLaunchExecuted) {
      _logger.debug(event: 'sync_pull_on_launch_skipped_already_executed');
      return;
    }
    if (!triggeredFromResume) {
      _pullOnLaunchExecuted = true;
    }

    if (!_firestoreDataSource.isAuthenticated) {
      _logger.info(event: 'sync_pull_on_launch_skipped_unauthenticated');
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

    if (triggeredFromResume) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final ms = prefs.getInt(_lastSyncKey);
        if (ms != null) {
          final last = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
          final elapsed = DateTimeFactory.nowUtc().difference(last);
          if (elapsed < pullOnResumeMinInterval) {
            _logger.info(
              event: 'sync_pull_on_launch_skipped_resume_throttle',
              fields: {'elapsedSeconds': elapsed.inSeconds},
            );
            return;
          }
        }
      } catch (e) {
        _logger.warning(
          event: 'sync_resume_throttle_prefs_read_failed',
          exception: e,
        );
      }
    }

    _updateStatus(SyncStatus.syncing(startedAt: DateTimeFactory.nowUtc()));

    try {
      _logger.info(event: 'sync_pull_on_launch_fetching');

      final learnerProfiles = await _firestoreDataSource.fetchLearnerProfiles();
      _logger.info(
        event: 'sync_pull_on_launch_fetched_learner_profiles',
        fields: {'count': learnerProfiles.length},
      );
      await _mergeLearnerProfiles(learnerProfiles);

      final accountProfile = await _firestoreDataSource.fetchProfile();
      if (accountProfile != null) {
        await _mergeProfile(accountProfile);
      }

      // Resolve every learner profile id we should pull subtrees for:
      // - IDs returned from Firestore `learner_profiles` (authoritative paths)
      // - Plus any row already in local `profiles` (covers offline-created
      //   rows and accounts other than the active one). Do not rely solely
      //   on `getProfilesByAccount(currentAccountId)`.
      final idsFromRemote = _learnerProfileIdsFromRemotePayload(
        learnerProfiles,
      );
      final allLocalProfiles = await _database
          .select(_database.learnerProfiles)
          .get();
      final idsFromLocal = allLocalProfiles.map((p) => p.id).toSet();
      final mergedProfileIds = {...idsFromRemote, ...idsFromLocal}.toList()
        ..sort();

      if (mergedProfileIds.isEmpty) {
        await _pullAndMergeProfileSubtree(
          profileId: _firestoreDataSource.profileId,
          mergeNotificationSettings: true,
        );
      } else {
        final notifSourceId = mergedProfileIds.first;
        for (final id in mergedProfileIds) {
          await _pullAndMergeProfileSubtree(
            profileId: id,
            mergeNotificationSettings: id == notifSourceId,
          );
        }
      }

      _logger.info(event: 'sync_pull_on_launch_completed');
      final syncedAt = DateTimeFactory.nowUtc();
      await _persistLastSyncTimestamp(syncedAt);
      _updateStatus(SyncStatus.synced(lastSyncedAt: syncedAt));
    } catch (e, stackTrace) {
      // Reset the guard so DeviceRestoreService.retry() (or any external
      // retry) can call pullOnLaunch again after a failed attempt.
      if (!triggeredFromResume) _pullOnLaunchExecuted = false;
      _logger.error(
        event: 'sync_pull_on_launch_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      // Story 27.14 (DNI-390): fire sync_failed analytics event.
      unawaited(_analytics.logSyncFailed(reason: e.toString()));
      _updateStatus(
        SyncStatus.error(
          message: e.toString(),
          failedAt: DateTimeFactory.nowUtc(),
        ),
      );
    }
  }

  /// Fetches and merges everything under
  /// `users/{uid}/learner_profiles/{profileId}/` for one learner.
  ///
  /// Pull-on-launch merges subtrees for every id returned from Firestore plus
  /// every local `profiles` row so paths match cloud data even when
  /// `account_id` filtering would hide rows.
  Future<void> _pullAndMergeProfileSubtree({
    required int profileId,
    required bool mergeNotificationSettings,
  }) async {
    final ds = _firestoreDataSource.forProfile(profileId);
    final results = await Future.wait([
      ds.fetchCompletions(),
      ds.fetchBookmarks(),
      ds.fetchSettings(),
      ds.fetchGoals(),
      ds.fetchProfilePrograms(),
      ds.fetchStreak(),
      ds.fetchLedgerEntries(),
      ds.fetchCurriculumTracks(),
      ds.fetchNotificationSettings(),
      ds.fetchGamificationSettings(),
      ds.fetchUiPreferences(),
      ds.fetchLearningOrder(),
    ]);

    await _mergeCompletions(
      results[0] as List<Map<String, dynamic>>,
      fallbackProfileId: profileId,
    );
    await _mergeBookmarks(
      results[1] as List<Map<String, dynamic>>,
      profileId: profileId,
    );
    await _mergeSettings(
      results[2] as List<Map<String, dynamic>>,
      profileId: profileId,
    );
    await _mergeGoals(
      results[3] as List<Map<String, dynamic>>,
      profileId: profileId,
    );
    await _mergeProfilePrograms(
      results[4] as List<Map<String, dynamic>>,
      defaultProfileId: profileId,
    );
    final streak = results[5] as Map<String, dynamic>?;
    if (streak != null) await _mergeStreak(streak);
    await _mergeLedgerEntries(
      results[6] as List<Map<String, dynamic>>,
      fallbackProfileId: profileId,
    );
    await _mergeCurriculumTracks(
      results[7] as List<Map<String, dynamic>>,
      profileId: profileId,
    );

    if (mergeNotificationSettings) {
      await _mergeNotificationSettings(results[8] as Map<String, dynamic>?);
    }
    await _mergeGamificationSettings(
      results[9] as Map<String, dynamic>?,
      profileId: profileId,
    );
    await _mergeUiPreferences(
      results[10] as Map<String, dynamic>?,
      profileId: profileId,
    );
    await _mergeLearningOrder(
      results[11] as List<Map<String, dynamic>>,
      profileId: profileId,
    );
  }

  // ========== Push-on-Write ==========

  /// Whether pushes are suppressed due to repeated PERMISSION_DENIED errors.
  bool get _pushSuppressed =>
      _consecutivePushPermissionErrors >= _pushPermissionErrorThreshold;

  /// Check if an error is a Firestore PERMISSION_DENIED and track it.
  /// Returns true if the error is permission-denied.
  bool _trackPushError(Object e) {
    // FirebaseException is no longer imported directly — detect by message
    // content. The gateway wraps cloud_firestore exceptions; PERMISSION_DENIED
    // surfaces as an Exception whose toString contains 'permission-denied'.
    final isPermissionDenied = e.toString().contains('permission-denied');
    if (isPermissionDenied) {
      _consecutivePushPermissionErrors++;
      if (_pushSuppressed) {
        _logger.warning(
          event: 'sync_push_suppressed_permission_denied',
          fields: {'consecutiveErrors': _consecutivePushPermissionErrors},
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
    if (_pushSuppressed) {
      // Online but the server keeps rejecting writes — surface this loudly.
      // The previous behaviour silently emitted `pending` here, so users
      // believed their changes were queued for an imminent flush even though
      // every retry was failing with permission-denied.
      _updateStatus(
        SyncStatus.degraded(
          pendingChanges: pending,
          reason:
              'Sync paused — your account is temporarily unable to push '
              'changes. They are kept on this device and will retry '
              'automatically.',
        ),
      );
      return;
    }
    if (pending > 0) {
      _updateStatus(SyncStatus.pending(pendingChanges: pending));
    }
  }

  /// After a local enqueue, update status and flush in the background when
  /// online and allowed to push. The caller never awaits Firestore.
  ///
  /// Used for all cloud sync writes: [SyncEngine] is only constructed for
  /// cloud-born (or upgraded) accounts. Queue rows live in the active
  /// [UserDatabase] and payloads include `profile_id` / `_target_profile_id`
  /// so work is not mixed across device accounts or learner profiles.
  Future<void> _afterEnqueueForBackgroundFlush({
    String context = 'queue',
  }) async {
    await _emitPendingStatus();
    if (_isQueueOnlyMode) {
      await _updateQueueOnlyStatus();
      return;
    }
    unawaited(_runBackgroundFlush(context: context));
  }

  Future<void> _runBackgroundFlush({required String context}) async {
    // Single-flight guard: if a drain is already in progress, set the re-run
    // flag so the in-flight drain picks it up when done.
    if (_flushInProgress) {
      _rerunRequested = true;
      return;
    }
    _flushInProgress = true;
    try {
      final batchSize = _isBatterySaverMode ? 5 : null;

      // Track whether any work was done across both drain loops so a single
      // `synced` status is emitted once at the end — emitting per iteration
      // makes the status flap while a multi-batch drain is still running (I9).
      var didSyncWork = false;

      // Drain the legacy OfflineQueue to completion (loop until 0 rows remain).
      int synced;
      do {
        synced = await _offlineQueue.flush(batchSize: batchSize);
        if (synced > 0) {
          _consecutivePushPermissionErrors = 0;
          didSyncWork = true;
        }
      } while (synced > 0);

      // Phase 1 (DNI-333): also drain the new Outbox table to completion.
      final processor = _outboxProcessor;
      if (processor != null) {
        int drained;
        do {
          drained = await processor.drain(_firestoreDataSource.profileId);
          if (drained > 0) didSyncWork = true;
        } while (drained > 0);
      }

      // Emit a single `synced` status once both drain loops have fully
      // completed, only if any rows were actually flushed.
      if (didSyncWork) {
        _updateStatus(
          SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowUtc()),
        );
      }
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional Firestore error boundary
      _trackPushError(e);
      _logger.warning(
        event: 'sync_background_flush_failed',
        fields: {'context': context},
        exception: e,
      );
    } finally {
      _flushInProgress = false;
      // If a concurrent caller requested a re-run, honour it now.
      if (_rerunRequested) {
        _rerunRequested = false;
        unawaited(_runBackgroundFlush(context: 'rerun'));
      }
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

  /// Document ids under Firestore `learner_profiles` — must align with paths
  /// `users/{uid}/learner_profiles/{profileId}/…` when pulling subtrees.
  Set<int> _learnerProfileIdsFromRemotePayload(
    List<Map<String, dynamic>> remoteProfiles,
  ) {
    final ids = <int>{};
    for (final remote in remoteProfiles) {
      final id = _asInt(remote['id']);
      if (id != null) {
        ids.add(id);
      }
    }
    return ids;
  }

  int? _parseOffsetDaysFromRef(String? trackingStartRef) {
    if (trackingStartRef == null || trackingStartRef.isEmpty) return null;
    final firstToken = trackingStartRef.split('|').first;
    if (!firstToken.startsWith('offset:')) return null;
    return int.tryParse(firstToken.substring('offset:'.length));
  }

  Future<Map<String, dynamic>> _withTrackProgressSchema(
    Map<String, dynamic> trackData,
  ) async {
    final enriched = Map<String, dynamic>.from(trackData);
    final profileId =
        _asInt(enriched['profile_id']) ?? _firestoreDataSource.profileId;
    final trackId = _asInt(enriched['track_id']);
    final curriculumId = (enriched['curriculum_id'] ?? '').toString();
    final trackType = (enriched['track_type'] ?? TrackType.personal.storageKey)
        .toString();

    if (curriculumId.isEmpty) {
      return enriched;
    }

    final nowUtc = DateTimeFactory.nowUtc();
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
      final offsetDays =
          _parseOffsetDaysFromRef(enrollment.trackingStartRef) ?? 0;
      final deferredUntil = enrollment.trackingStartDate;
      final relevantRows = trackId == null
          ? rows.where((r) => r.curriculumId == curriculumId).toList()
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
        'precredit': {
          'mode': 'deferred_baseline',
          'offset_days': offsetDays,
          'deferred_until': deferredUntil?.toIso8601String(),
          'counts_as_completion': false,
          'affects_streak_points_awards': false,
        },
      };
      enriched['self_paced_progress'] = null;
    } else {
      final completedStageEvents = trackId == null
          ? (await _database.completionDao.getCompletionsByCurriculumAndProfile(
              curriculumId,
              profileId,
            )).where((c) => c.trackType == trackType).length
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

  /// Push a ledger entry to Firestore after local write.
  Future<void> pushLedgerEntry(Map<String, dynamic> entry) async {
    // Local-born / unauthenticated sessions should stay local-only.
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.debug(event: 'sync_ledger_skipped_unauthenticated');
      return;
    }

    // Always queue first so UI never blocks on network for lifetime marking.
    await _offlineQueue.enqueueLedgerEntry(_withQueueTargetProfile(entry));
    await _afterEnqueueForBackgroundFlush(context: 'ledger entry');
  }

  /// After many ledger inserts (e.g. lifetime marking batch), enqueue once.
  Future<void> pushLedgerEntriesBatch(
    List<Map<String, dynamic>> entries,
  ) async {
    if (entries.isEmpty) return;
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.debug(event: 'sync_ledger_batch_skipped_unauthenticated');
      return;
    }
    for (final e in entries) {
      await _offlineQueue.enqueueLedgerEntry(_withQueueTargetProfile(e));
    }
    await _afterEnqueueForBackgroundFlush(context: 'ledger batch');
  }

  /// Fetch all bookmarks for the current user from Firestore.
  ///
  /// Used by [BookmarkRepositoryImpl.syncFromFirestore] for pull-on-demand sync.
  Future<List<Map<String, dynamic>>> fetchBookmarksFromFirestore() =>
      _firestoreDataSource.fetchBookmarks();

  /// Push a bookmark to Firestore after local write.
  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) async {
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.debug(event: 'sync_bookmark_skipped_unauthenticated');
      return;
    }

    // Always queue first so UI never blocks on network during track creation.
    await _offlineQueue.enqueueBookmark(_withQueueTargetProfile(bookmark));
    await _afterEnqueueForBackgroundFlush(context: 'bookmark');
  }

  /// Push settings to Firestore after local write.
  @override
  Future<void> pushSettings(Map<String, dynamic> settings) async {
    await _offlineQueue.enqueueSettings(_withQueueTargetProfile(settings));
    await _afterEnqueueForBackgroundFlush(context: 'settings');
  }

  /// Push notification settings to Firestore after local write.
  Future<void> pushNotificationSettings(
    Map<String, dynamic> notificationSettings,
  ) async {
    await _offlineQueue.enqueueNotificationSettings(
      _withQueueTargetProfile(notificationSettings),
    );
    await _afterEnqueueForBackgroundFlush(context: 'notification settings');
  }

  /// Push gamification settings to Firestore after local write.
  Future<void> pushGamificationSettings(
    Map<String, dynamic> gamificationSettings,
  ) async {
    await _offlineQueue.enqueueGamificationSettings(
      _withQueueTargetProfile(gamificationSettings),
    );
    await _afterEnqueueForBackgroundFlush(context: 'gamification settings');
  }

  /// Build and push the current gamification snapshot from local storage.
  @override
  Future<void> pushGamificationSettingsSnapshot() async {
    final payload = await _buildGamificationSettingsPayload();
    await pushGamificationSettings(payload);
  }

  /// Push locale / calendar / text / learning-order prefs for the active profile.
  Future<void> pushUiPreferencesSnapshot() async {
    final profileId = _firestoreDataSource.profileId;
    final prefs = await SharedPreferences.getInstance();
    final now = DateTimeFactory.nowUtc();
    await prefs.setInt(
      ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileId),
      now.millisecondsSinceEpoch,
    );
    final payload = await _readLocalUiPreferencesPayload();
    await _offlineQueue.enqueueUiPreferences(_withQueueTargetProfile(payload));
    await _afterEnqueueForBackgroundFlush(context: 'ui preferences');
  }

  /// Push study day config to Firestore as part of settings document.
  Future<void> pushStudyDayConfig({
    required String curriculumId,
    required Map<String, String> dayConfig,
  }) async {
    final payload = <String, dynamic>{
      'curriculum_id': curriculumId,
      'study_day_config': dayConfig,
      'study_day_config_updated_at': DateTimeFactory.nowUtc().toIso8601String(),
    };

    await pushSettings(payload);
  }

  /// Push streak data to Firestore after local write.
  Future<void> pushStreak(Map<String, dynamic> streak) async {
    await _offlineQueue.enqueueStreak(_withQueueTargetProfile(streak));
    await _afterEnqueueForBackgroundFlush(context: 'streak');
  }

  /// Push profile to Firestore after local write.
  Future<void> pushProfile(Map<String, dynamic> profile) async {
    await _offlineQueue.enqueueProfile(_withQueueTargetProfile(profile));
    await _afterEnqueueForBackgroundFlush(context: 'profile');
  }

  /// Push a learner profile (profiles table) to Firestore.
  /// Local row remains authoritative; cloud push is background/queued.
  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) async {
    final payload = await _enrichLearnerProfilePayload(profile);

    await _offlineQueue.enqueueLearnerProfile(payload);
    await _afterEnqueueForBackgroundFlush(context: 'learner profile');
  }

  /// Delete a learner profile from Firestore.
  ///
  /// Step 1 (synchronous): persists a tombstone in SharedPreferences so
  /// [_mergeLearnerProfiles] will never re-create this profile, even if the
  /// network delete hasn't propagated yet.
  ///
  /// Step 2 (fire-and-forget): kicks off the actual Firestore delete in the
  /// background so the UI can respond immediately after the local DB write.
  @override
  Future<void> deleteLearnerProfile(int profileId) async {
    _logger.info(
      event: 'sync_delete_learner_profile_start',
      fields: {
        'profileId': profileId,
        'authenticated': _firestoreDataSource.isAuthenticated,
      },
    );

    // 1. Persist tombstone so pullOnLaunch never re-creates this profile.
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_deletedProfileIdsKey) ?? [];
      if (!existing.contains(profileId.toString())) {
        existing.add(profileId.toString());
        await prefs.setStringList(_deletedProfileIdsKey, existing);
        _logger.info(
          event: 'sync_delete_learner_profile_tombstone_stored',
          fields: {'totalTombstoned': existing.length},
        );
      }
    } catch (e) {
      _logger.warning(
        event: 'sync_delete_learner_profile_tombstone_failed',
        exception: e,
      );
    }

    // 2. Fire-and-forget Firestore delete — UI does not wait for network.
    unawaited(() async {
      if (_firestoreDataSource.isAuthenticated) {
        try {
          _logger.info(
            event: 'sync_delete_learner_profile_firestore_start',
            fields: {'profileId': profileId},
          );
          await _firestoreDataSource.deleteLearnerProfile(profileId);
          _logger.info(
            event: 'sync_delete_learner_profile_firestore_complete',
            fields: {'profileId': profileId},
          );
        } catch (e) {
          _logger.warning(
            event: 'sync_delete_learner_profile_firestore_failed_queuing',
            exception: e,
          );
          await _offlineQueue.enqueueLearnerProfileDelete(profileId);
          await _afterEnqueueForBackgroundFlush(
            context: 'learner profile delete',
          );
        }
      } else {
        _logger.info(
          event: 'sync_delete_learner_profile_offline_queuing',
          fields: {'profileId': profileId},
        );
        await _offlineQueue.enqueueLearnerProfileDelete(profileId);
        await _afterEnqueueForBackgroundFlush(
          context: 'learner profile delete',
        );
      }
    }());
  }

  /// Push a goal to Firestore after local write.
  Future<void> pushGoal(Map<String, dynamic> goal) async {
    await _offlineQueue.enqueueGoal(_withQueueTargetProfile(goal));
    await _afterEnqueueForBackgroundFlush(context: 'goal');
  }

  /// Push a profile-program assignment to Firestore after local write.
  Future<void> pushProfileProgram(Map<String, dynamic> profileProgram) async {
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.debug(event: 'sync_profile_program_skipped_unauthenticated');
      return;
    }

    // Always queue first so UI never blocks on network during track creation.
    await _offlineQueue.enqueueProfileProgram(
      _withQueueTargetProfile(profileProgram),
    );
    await _afterEnqueueForBackgroundFlush(context: 'profile program');
  }

  /// Remove profile-program enrollment on Firestore (self-paced re-add).
  Future<void> removeProfileProgramAssignment(
    String curriculumStorageKey,
  ) async {
    if (!_firestoreDataSource.isAuthenticated) {
      _logger.debug(
        event: 'sync_profile_program_delete_skipped_unauthenticated',
      );
      return;
    }
    await _offlineQueue.enqueueProfileProgramDelete(
      _withQueueTargetProfile({'curriculum_id': curriculumStorageKey}),
    );
    await _afterEnqueueForBackgroundFlush(context: 'profile program delete');
  }

  /// Push curriculum-track state to Firestore after local write.
  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) async {
    final payload = await _withTrackProgressSchema(trackData);
    await _offlineQueue.enqueueCurriculumTrack(
      _withQueueTargetProfile(payload),
    );
    await _afterEnqueueForBackgroundFlush(context: 'curriculum track');
  }

  /// Push all learning-order items for a curriculum after a drag-and-drop
  /// reorder (DNI-311).
  ///
  /// Each item is enqueued as a separate `learning_order_item` operation so
  /// that the offline queue can retry individual rows independently.
  /// [profileId] must match the active learner profile at the time of the
  /// write so the queue flushes to the correct Firestore sub-collection.
  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {
    for (final item in items) {
      final payload = {
        ...item,
        'curriculum_id': curriculumId,
        'updated_at': updatedAt.toIso8601String(),
        '_target_profile_id': profileId,
      };
      await _offlineQueue.enqueueLearningOrderItem(payload);
    }
    if (items.isNotEmpty) {
      await _afterEnqueueForBackgroundFlush(context: 'learning order');
    }
  }

  // ========== Conflict Resolution & Merge ==========

  /// Convert a Firestore Timestamp (as Map), ISO string, or DateTime to
  /// [DateTime]. Firestore Timestamps arrive as `{seconds: int, nanoseconds:
  /// int}` maps after passing through [FirestoreGateway].
  DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is Map) {
      final s = value['seconds'];
      if (s is int) {
        return DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
      }
    }
    return null;
  }

  /// Merge completions from Firestore (additive merge per D4).
  ///
  /// Completions are append-only. For each remote completion, check if it
  /// already exists locally by composite key. If not, insert it.
  Future<void> _mergeCompletions(
    List<Map<String, dynamic>> remoteCompletions, {
    required int fallbackProfileId,
  }) async {
    _logger.debug(
      event: 'sync_merge_completions_start',
      fields: {'count': remoteCompletions.length},
    );

    var insertedCount = 0;
    var skippedOrphanProfile = 0;
    final trackIdCache = <String, int?>{};
    // completion_events.profileId is an FK to learner_profiles. A remote
    // completion whose profile was deleted/tombstoned locally must be skipped —
    // inserting it would fail the FK (SqliteException 787). Gather the live
    // profile ids once so the per-row check is a cheap set lookup.
    final existingProfileIds =
        (await _database.select(_database.learnerProfiles).get())
            .map((p) => p.id)
            .toSet();
    for (final remote in remoteCompletions) {
      try {
        final curriculumId =
            (remote['curriculum_id'] ?? remote['curriculumId']) as String?;
        final sefariaRef =
            (remote['content_item_id'] ??
                    remote['sefaria_ref'] ??
                    remote['sefariaRef'])
                as String?;

        // `stage_id` is the canonical snake_case key the outbox payload now
        // emits; `stageId` / `stageOrder` / `stage_order` are accepted so any
        // lingering camelCase or legacy Firestore docs still merge (I6).
        final rawStageId =
            remote['stage_id'] ??
            remote['stageId'] ??
            remote['stageOrder'] ??
            remote['stage_order'];
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
          _logger.warning(event: 'sync_merge_completion_invalid_skipped');
          continue;
        }

        final rawProfileId = remote['profile_id'] ?? remote['profileId'];
        final profileId = rawProfileId is int
            ? rawProfileId
            : rawProfileId is num
            ? rawProfileId.toInt()
            : int.tryParse(rawProfileId?.toString() ?? '') ?? fallbackProfileId;

        if (!existingProfileIds.contains(profileId)) {
          // Profile deleted/tombstoned locally — skip rather than orphan-insert.
          skippedOrphanProfile++;
          continue;
        }

        final exists = await _database.completionDao.completionExistsByProfile(
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          completedAt: completedAt,
          profileId: profileId,
        );

        if (exists) {
          // H2: the row exists locally — but it may be tombstoned (purgedAt IS
          // NOT NULL) while Firestore says it is alive. In that case the remote
          // is "more alive" than local: resurrect the row by clearing purgedAt.
          final tombstoned =
              await _database.completionEventDao.findTombstonedEventByNaturalKey(
            profileId: profileId,
            curriculumId: curriculumId,
            sefariaRef: sefariaRef,
            stageId: stageId,
            trackType: trackType,
            eventTimestamp: completedAt,
          );
          if (tombstoned != null) {
            await _database.completionEventDao.clearTombstone(tombstoned.id);
            _logger.debug(
              event: 'sync_merge_completion_tombstone_resurrected',
              fields: {'id': tombstoned.id},
            );
            insertedCount++;
          }
        } else {
          // The remote `track_id` is the SOURCE device's row id and is
          // meaningless on this device — always resolve the local track by its
          // natural key. Falls back to null (track_id is nullable) when this
          // device has no matching track, never a bogus/foreign id.
          final trackKey = '$profileId|$curriculumId|$trackType';
          final int? resolvedTrackId;
          if (trackIdCache.containsKey(trackKey)) {
            resolvedTrackId = trackIdCache[trackKey];
          } else {
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
            resolvedTrackId = track?.id;
            trackIdCache[trackKey] = resolvedTrackId;
          }

          // C1: write to the canonical event log instead of the completions
          // projection table. INSERT OR IGNORE — idempotent on natural key.
          await _database.completionEventDao.appendEvent(
            CompletionEventsCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              sefariaRef: sefariaRef,
              stageId: stageId,
              trackType: trackType,
              trackId: Value<int?>(resolvedTrackId),
              eventTimestamp: completedAt,
            ),
          );
          insertedCount++;
        }
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning(event: 'sync_merge_completion_failed', exception: e);
      }
    }

    if (skippedOrphanProfile > 0) {
      _logger.warning(
        event: 'sync_merge_completions_skipped_orphan_profile',
        fields: {'count': skippedOrphanProfile},
      );
    }
    _logger.debug(
      event: 'sync_merge_completions_done',
      fields: {'insertedCount': insertedCount},
    );
  }

  /// Merge ledger entries from Firestore (append-only).
  ///
  /// Ledger entries are append-only. For each remote entry, check if it
  /// already exists locally by composite key. If not, insert it.
  Future<void> _mergeLedgerEntries(
    List<Map<String, dynamic>> remoteLedgerEntries, {
    required int fallbackProfileId,
  }) async {
    _logger.debug(
      event: 'sync_merge_ledger_entries_start',
      fields: {'count': remoteLedgerEntries.length},
    );

    var insertedCount = 0;
    var skippedOrphanProfile = 0;
    // learning_ledger.profileId is an FK to learner_profiles. A remote entry
    // whose profile was deleted/tombstoned locally must be skipped — inserting
    // it would fail the FK (SqliteException 787).
    final existingProfileIds =
        (await _database.select(_database.learnerProfiles).get())
            .map((p) => p.id)
            .toSet();
    for (final remote in remoteLedgerEntries) {
      try {
        final curriculumId = remote['curriculumId'] as String?;
        final unitIdentifier = remote['unitIdentifier'] as String?;
        final trackType = remote['trackType'] as String?;
        final completedAt = _parseTimestamp(remote['completedAt']);
        final rawPid = remote['profileId'] ?? remote['profile_id'];
        var profileId = rawPid is int
            ? rawPid
            : rawPid is num
            ? rawPid.toInt()
            : int.tryParse(rawPid?.toString() ?? '') ?? 0;
        if (profileId == 0) {
          profileId = fallbackProfileId;
        }

        if (!existingProfileIds.contains(profileId)) {
          // Profile deleted/tombstoned locally — skip rather than orphan-insert.
          skippedOrphanProfile++;
          continue;
        }

        if (curriculumId == null ||
            unitIdentifier == null ||
            trackType == null ||
            completedAt == null) {
          _logger.warning(event: 'sync_merge_ledger_entry_invalid_skipped');
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
          final remoteUlid = remote['ulid'] as String?;
          await _database.learningLedgerDao.insertEntry(
            LearningLedgerCompanion.insert(
              profileId: profileId,
              ulid: Value(
                remoteUlid != null && remoteUlid.isNotEmpty
                    ? remoteUlid
                    : newUlid(completedAt),
              ),
              curriculumId: curriculumId,
              entryScope: remote['entryScope'] as String? ?? 'masechta',
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
        _logger.warning(event: 'sync_merge_ledger_entry_failed', exception: e);
      }
    }

    if (skippedOrphanProfile > 0) {
      _logger.warning(
        event: 'sync_merge_ledger_entries_skipped_orphan_profile',
        fields: {'count': skippedOrphanProfile},
      );
    }
    _logger.debug(
      event: 'sync_merge_ledger_entries_done',
      fields: {'insertedCount': insertedCount},
    );
  }

  /// Merge bookmarks from Firestore (last-write-wins per D4).
  ///
  /// For each remote bookmark, upsert into local DB. If local bookmark
  /// is older, update it; otherwise keep the local version.
  Future<void> _mergeBookmarks(
    List<Map<String, dynamic>> remoteBookmarks, {
    required int profileId,
  }) async {
    _logger.debug(
      event: 'sync_merge_bookmarks_start',
      fields: {'count': remoteBookmarks.length},
    );

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
          _logger.warning(event: 'sync_merge_bookmark_invalid_skipped');
          continue;
        }

        // Resolve trackType string → trackId FK (CurriculumTracks.id)
        final track =
            await (_database.select(_database.curriculumTracks)..where(
                  (t) =>
                      t.profileId.equals(profileId) &
                      t.curriculumId.equals(curriculumId) &
                      t.trackType.equals(trackType),
                ))
                .getSingleOrNull();
        if (track == null) {
          _logger.warning(event: 'sync_merge_bookmark_track_not_found_skipped');
          continue;
        }

        await _database.bookmarkDao.upsertBookmarkByProfile(
          curriculumId: curriculumId,
          trackId: track.id,
          sefariaRef: sefariaRef,
          updatedAt: updatedAt,
          profileId: profileId,
        );
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning(event: 'sync_merge_bookmark_failed', exception: e);
      }
    }
  }

  /// Merge settings from Firestore (last-write-wins per D4).
  ///
  /// Settings contain stage definitions per curriculum. Only replaces local
  /// stages when the remote `updated_at` is newer than the locally persisted
  /// settings timestamp for that curriculum.
  Future<void> _mergeSettings(
    List<Map<String, dynamic>> remoteSettings, {
    required int profileId,
  }) async {
    _logger.debug(
      event: 'sync_merge_settings_start',
      fields: {'count': remoteSettings.length},
    );

    for (final remote in remoteSettings) {
      try {
        final curriculumId = remote['curriculum_id'] as String?;
        final stages = remote['stages'] as List<dynamic>?;
        final remoteUpdatedAt = _parseTimestamp(remote['updated_at']);
        if (curriculumId == null || stages == null) {
          _logger.warning(event: 'sync_merge_settings_invalid_skipped');
          continue;
        }

        // v2 §4.1 LWW: delegate the "is remote strictly newer?"
        // predicate to merge_rules.remoteIsNewer so every pull path
        // uses the same rule.
        if (remoteUpdatedAt != null) {
          final localTs = await _getSettingsTimestamp(curriculumId, profileId);
          if (!remoteIsNewer(
            localUpdatedAt: localTs,
            remoteUpdatedAt: remoteUpdatedAt,
          )) {
            _logger.debug(
              event: 'sync_merge_settings_skipped_local_newer',
              fields: {'curriculumId': curriculumId},
            );
            continue;
          }
        }

        final trackId = remote['track_id'] as int? ?? 0;
        final companions = stages
            .cast<Map<String, dynamic>>()
            .map(
              (s) => StageDefinitionsCompanion.insert(
                profileId: profileId, // profile from enclosing merge context
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
          await _setSettingsTimestamp(curriculumId, remoteUpdatedAt, profileId);
        }

        // Merge study day config if present
        await _mergeStudyDayConfig(remote, curriculumId, profileId);
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning(event: 'sync_merge_settings_failed', exception: e);
      }
    }
  }

  /// Merge study day config from a remote settings document.
  Future<void> _mergeStudyDayConfig(
    Map<String, dynamic> remote,
    String curriculumId,
    int profileId,
  ) async {
    final studyDayConfig = remote['study_day_config'] as Map<String, dynamic>?;
    if (studyDayConfig == null) return;

    final remoteTs = _parseTimestamp(remote['study_day_config_updated_at']);

    // v2 §4.1 LWW via merge_rules.remoteIsNewer.
    if (remoteTs != null) {
      final localTs = await _database.studyDayConfigDao.getLatestUpdatedAt(
        profileId: profileId,
        curriculumId: curriculumId,
      );
      if (!remoteIsNewer(localUpdatedAt: localTs, remoteUpdatedAt: remoteTs)) {
        _logger.debug(
          event: 'sync_merge_study_day_config_skipped_local_newer',
          fields: {'curriculumId': curriculumId},
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
          event: 'sync_merge_notification_settings_skipped_local_newer',
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

      final stamp =
          remoteUpdatedAt?.millisecondsSinceEpoch ??
          DateTimeFactory.nowUtc().millisecondsSinceEpoch;
      await prefs.setInt(_notificationSettingsUpdatedAtMsKey, stamp);
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
      _logger.warning(
        event: 'sync_merge_notification_settings_failed',
        exception: e,
      );
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
    final now = DateTimeFactory.nowUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      _gamificationLocalUpdatedAtKey(profileId),
      now.millisecondsSinceEpoch,
    );

    final totalPointsExpr = _database.completionEvents.points.sum();
    final totalPointsRow =
        await (_database.selectOnly(_database.completionEvents)
              ..addColumns([totalPointsExpr])
              ..where(
                _database.completionEvents.profileId.equals(profileId) &
                    _database.completionEvents.purgedAt.isNull(),
              ))
            .getSingle();
    final totalPointsSum = totalPointsRow.read(totalPointsExpr) ?? 0;

    // `schema_version` 3: same shape as v2; `reward_settings.milestones[].track_id`
    // may be `0` (RewardMilestone.kGlobalTrackSentinel) for total-points rewards;
    // optional `icon_index` (0–2) selects the parent-configured reward avatar tile.
    // Per-track milestones use positive curriculum track ids as before.
    return {
      'schema_version': 3,
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
      'lifetime_stats': {'total_points_from_completions': totalPointsSum},
    };
  }

  Future<void> _mergeGamificationSettings(
    Map<String, dynamic>? remoteSettings, {
    required int profileId,
  }) async {
    if (remoteSettings == null || remoteSettings.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final remoteUpdatedAt = _parseTimestamp(remoteSettings['updated_at']);
      final localUpdatedAtMs = prefs.getInt(
        _gamificationLocalUpdatedAtKey(profileId),
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
          event: 'sync_merge_gamification_settings_skipped_local_newer',
        );
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
              profileId: profileId,
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
        profileId: profileId,
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
          DateTimeFactory.nowUtc().millisecondsSinceEpoch;
      await prefs.setInt(_gamificationLocalUpdatedAtKey(profileId), stamp);
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
      _logger.warning(
        event: 'sync_merge_gamification_settings_failed',
        exception: e,
      );
    }
  }

  Future<void> _mergeUiPreferences(
    Map<String, dynamic>? remote, {
    required int profileId,
  }) async {
    if (remote == null || remote.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final remoteUpdatedAt = _parseTimestamp(remote['updated_at']);
      final localUpdatedAtMs = prefs.getInt(
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileId),
      );
      final localUpdatedAt = localUpdatedAtMs == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(localUpdatedAtMs, isUtc: true);

      if (remoteUpdatedAt != null &&
          !remoteIsNewer(
            localUpdatedAt: localUpdatedAt,
            remoteUpdatedAt: remoteUpdatedAt,
          )) {
        _logger.debug(event: 'sync_merge_ui_preferences_skipped_local_newer');
        return;
      }

      final locale = remote['app_locale'] as String?;
      if (locale != null && (locale == 'en' || locale == 'he')) {
        await prefs.setString(
          ProfileScopedPreferenceKeys.appLocale(profileId),
          locale,
        );
      }

      final hebrew = remote['use_hebrew_calendar'];
      if (hebrew is bool) {
        await prefs.setBool(
          ProfileScopedPreferenceKeys.useHebrewCalendar(profileId),
          hebrew,
        );
      }

      final textDisplay = remote['text_display'] as Map<String, dynamic>?;
      if (textDisplay != null) {
        final idx = textDisplay['font_size_index'];
        if (idx is int && idx >= 0 && idx <= 2) {
          await prefs.setInt(
            ProfileScopedPreferenceKeys.textFontSize(profileId),
            idx,
          );
        }
        final nikud = textDisplay['show_nikud'];
        if (nikud is bool) {
          await prefs.setBool(
            ProfileScopedPreferenceKeys.textShowNikud(profileId),
            nikud,
          );
        }
      }

      final learningOrder = remote['learning_order_parent_controls'];
      if (learningOrder is bool) {
        await prefs.setBool(
          ProfileScopedPreferenceKeys.learningOrderParentControls(profileId),
          learningOrder,
        );
      }

      final hebrewTermsScript = remote['hebrew_terms_script'];
      if (hebrewTermsScript is bool) {
        await prefs.setBool(
          ProfileScopedPreferenceKeys.hebrewTermsScript(profileId),
          hebrewTermsScript,
        );
      }

      // Sacred Time settings are device-global; only profile 0 carries them
      // in its UI-preferences doc. Other profile docs leave them alone.
      if (profileId == 0) {
        final sacredTime = remote['sacred_time'];
        if (sacredTime is Map<String, dynamic>) {
          final lat = sacredTime['latitude'];
          final lon = sacredTime['longitude'];
          if (lat is num && lon is num) {
            await prefs.setDouble('sacred_time_latitude', lat.toDouble());
            await prefs.setDouble('sacred_time_longitude', lon.toDouble());
          }
          final country = sacredTime['country_code'];
          if (country is String && country.isNotEmpty) {
            await prefs.setString('sacred_time_country_code', country);
          }
          final city = sacredTime['city_label'];
          if (city is String && city.isNotEmpty) {
            await prefs.setString('sacred_time_city_label', city);
          }
          final source = sacredTime['source'];
          if (source is String && source.isNotEmpty) {
            await prefs.setString('sacred_time_source', source);
          }
          final fixedAt = sacredTime['fixed_at_ms'];
          if (fixedAt is int) {
            await prefs.setInt('sacred_time_fixed_at_ms', fixedAt);
          }
          final inIsrael = sacredTime['in_israel'];
          if (inIsrael is bool) {
            await prefs.setBool('sacred_time_in_israel', inIsrael);
          }
        }
      }

      final stamp =
          remoteUpdatedAt?.millisecondsSinceEpoch ??
          DateTimeFactory.nowUtc().millisecondsSinceEpoch;
      await prefs.setInt(
        ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileId),
        stamp,
      );
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
      _logger.warning(event: 'sync_merge_ui_preferences_failed', exception: e);
    }
  }

  /// Merge goals from Firestore (last-write-wins per D4).
  ///
  /// For each remote goal, upsert into local DB. If local goal
  /// is older, update it; otherwise keep the local version.
  Future<void> _mergeGoals(
    List<Map<String, dynamic>> remoteGoals, {
    required int profileId,
  }) async {
    _logger.debug(
      event: 'sync_merge_goals_start',
      fields: {'count': remoteGoals.length},
    );

    for (final remote in remoteGoals) {
      try {
        final curriculumId = remote['curriculum_id'] as String?;
        final rawTid = remote['track_id'];
        final trackId = rawTid is int
            ? rawTid
            : rawTid is num
            ? rawTid.toInt()
            : int.tryParse(rawTid?.toString() ?? '');
        final description = remote['description'] as String? ?? '';
        final targetPercent =
            (remote['target_percent'] as num?)?.toDouble() ?? 100.0;
        final targetDate = _parseTimestamp(remote['target_date']);
        final dateType = remote['date_type'] as String? ?? 'gregorian';
        final goalType = remote['goal_type'] as String? ?? 'deadline';
        final paceValue = (remote['pace_value'] as num?)?.toInt();
        final pacePeriod = remote['pace_unit'] as String?;
        final createdAt = _parseTimestamp(remote['created_at']);
        final updatedAt = _parseTimestamp(remote['updated_at']);

        if (curriculumId == null ||
            trackId == null ||
            trackId == 0 ||
            createdAt == null ||
            updatedAt == null) {
          _logger.warning(event: 'sync_merge_goal_invalid_skipped');
          continue;
        }

        await _database.goalDao.upsertGoalByTrack(
          profileId: profileId,
          trackId: trackId,
          curriculumId: curriculumId,
          description: description,
          targetPercent: targetPercent,
          targetDate: targetDate,
          dateType: dateType,
          goalType: goalType,
          paceValue: paceValue,
          pacePeriod: pacePeriod,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning(event: 'sync_merge_goal_failed', exception: e);
      }
    }
  }

  /// Merge profile-program assignments from Firestore.
  Future<void> _mergeProfilePrograms(
    List<Map<String, dynamic>> remoteProfilePrograms, {
    required int defaultProfileId,
  }) async {
    _logger.debug(
      event: 'sync_merge_profile_programs_start',
      fields: {'count': remoteProfilePrograms.length},
    );

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
          _logger.warning(event: 'sync_merge_profile_program_invalid_skipped');
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
        _logger.warning(
          event: 'sync_merge_profile_program_failed',
          exception: e,
        );
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
      event: 'sync_merge_streak_received',
      fields: {
        'current': remoteStreak['current_count'],
        'max': remoteStreak['max_count'],
      },
    );
    // Streak is computed from completions locally. The Firestore streak
    // document serves as a cross-device cache but local truth comes from
    // the completions table. No local write needed.
  }

  /// Merge curriculum tracks from Firestore.
  ///
  /// Upserts each remote track row keyed by (profileId, curriculumId,
  /// trackType) so track activation, deactivation, and archival state all
  /// round-trip across devices. Unknown curriculum/track keys are skipped.
  Future<void> _mergeCurriculumTracks(
    List<Map<String, dynamic>> remoteTracks, {
    required int profileId,
  }) async {
    _logger.debug(
      event: 'sync_merge_curriculum_tracks_start',
      fields: {'count': remoteTracks.length},
    );
    if (remoteTracks.isEmpty) return;

    for (final remote in remoteTracks) {
      try {
        final curriculumKey = remote['curriculum_id'] as String?;
        final trackTypeKey = remote['track_type'] as String?;
        final isActive = remote['is_active'] as bool? ?? true;
        final activatedAt = _parseTimestamp(remote['activated_at']);
        final deactivatedAt = _parseTimestamp(remote['deactivated_at']);
        final paceResetDate = _parseTimestamp(remote['pace_reset_date']);

        if (curriculumKey == null ||
            trackTypeKey == null ||
            activatedAt == null) {
          _logger.warning(event: 'sync_merge_curriculum_track_invalid_skipped');
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
            event: 'sync_merge_curriculum_track_unknown_key_skipped',
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
                  profileId: profileId,
                  curriculumId: curriculumKey,
                  trackType: trackTypeKey,
                  isActive: Value(isActive),
                  activatedAt: activatedAt,
                  deactivatedAt: Value(deactivatedAt),
                  paceResetDate: Value(paceResetDate),
                ),
              );
        } else {
          // v2 §4.1 LWW: the "last write" is the most recent state-change
          // timestamp — max(activatedAt, deactivatedAt).  Ties go to local.
          final remoteUpdatedAt =
              deactivatedAt != null && deactivatedAt.isAfter(activatedAt)
              ? deactivatedAt
              : activatedAt;
          final localUpdatedAt =
              existing.deactivatedAt != null &&
                  existing.deactivatedAt!.isAfter(existing.activatedAt)
              ? existing.deactivatedAt!
              : existing.activatedAt;

          if (remoteIsNewer(
            localUpdatedAt: localUpdatedAt,
            remoteUpdatedAt: remoteUpdatedAt,
          )) {
            await (_database.update(
              _database.curriculumTracks,
            )..where((t) => t.id.equals(existing.id))).write(
              CurriculumTracksCompanion(
                isActive: Value(isActive),
                activatedAt: Value(activatedAt),
                deactivatedAt: Value(deactivatedAt),
                paceResetDate: Value(paceResetDate),
              ),
            );
            _logger.debug(
              event:
                  'LWW: remote curriculum track wins '
                  '(curriculum=$curriculumKey, trackType=$trackTypeKey)',
            );
          } else {
            _logger.debug(
              event:
                  'LWW: local curriculum track kept '
                  '(curriculum=$curriculumKey, trackType=$trackTypeKey)',
            );
          }
        }
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning(
          event: 'sync_merge_curriculum_track_failed',
          exception: e,
        );
      }
    }
  }

  /// Merge profile from Firestore (last-write-wins per D4).
  Future<void> _mergeProfile(Map<String, dynamic> remoteProfile) async {
    _logger.debug(event: 'sync_merge_profile_start');

    try {
      final firebaseUid = remoteProfile['firebase_uid'] as String?;
      final displayName = remoteProfile['display_name'] as String?;
      final userMode = remoteProfile['user_mode'] as String?;
      final updatedAt = _parseTimestamp(remoteProfile['updated_at']);

      if (firebaseUid == null ||
          displayName == null ||
          userMode == null ||
          updatedAt == null) {
        _logger.warning(event: 'sync_merge_profile_invalid_skipped');
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
      _logger.warning(event: 'sync_merge_profile_failed', exception: e);
    }
  }

  /// Merge learner profiles (profiles table) from Firestore.
  /// Upserts each remote row into the local profiles table preserving its
  /// remote id so profile-scoped data (completions, bookmarks, …) keyed by
  /// profile_id resolves consistently across devices.
  Future<void> _mergeLearnerProfiles(
    List<Map<String, dynamic>> remoteProfiles,
  ) async {
    _logger.info(
      event: 'sync_merge_learner_profiles_start',
      fields: {'count': remoteProfiles.length},
    );

    // Load tombstone set once — profiles deleted locally are never re-created.
    var tombstoned = <int>{};
    try {
      final prefs = await SharedPreferences.getInstance();
      tombstoned = (prefs.getStringList(_deletedProfileIdsKey) ?? [])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      if (tombstoned.isNotEmpty) {
        _logger.info(
          event: 'sync_merge_learner_profiles_tombstone_set_loaded',
          fields: {'tombstonedCount': tombstoned.length},
        );
      }
    } catch (e) {
      _logger.warning(
        event: 'sync_merge_learner_profiles_tombstone_load_failed',
        exception: e,
      );
    }

    for (final remote in remoteProfiles) {
      try {
        final rawId = remote['id'];
        final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '');
        if (id == null) {
          _logger.warning(event: 'sync_merge_learner_profile_invalid_skipped');
          continue;
        }

        // Skip tombstoned profiles — user explicitly deleted them locally.
        if (tombstoned.contains(id)) {
          _logger.info(
            event: 'sync_merge_learner_profile_tombstoned_skipped',
            fields: {'profileId': id},
          );
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

        final nowUtc = DateTimeFactory.nowUtc();
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
          _logger.info(
            event: 'sync_merge_learner_profile_insert',
            fields: {'profileId': id, 'mode': mode},
          );
          await _database
              .into(_database.learnerProfiles)
              .insertOnConflictUpdate(
                LearnerProfilesCompanion.insert(
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
          _logger.info(
            event: 'sync_merge_learner_profile_update',
            fields: {'profileId': id},
          );
          await (_database.update(
            _database.learnerProfiles,
          )..where((t) => t.id.equals(id))).write(
            LearnerProfilesCompanion(
              displayName: Value(displayName),
              mode: Value(mode),
              avatarIndex: Value(avatarIndex),
              updatedAt: Value(updatedAt),
            ),
          );
        } else {
          _logger.debug(
            event: 'sync_merge_learner_profile_skip_local_current',
            fields: {'profileId': id},
          );
        }
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning(
          event: 'sync_merge_learner_profile_failed',
          exception: e,
        );
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

      final localProfiles = await _database
          .select(_database.learnerProfiles)
          .get();
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
        _logger.info(
          event: 'sync_backfill_learner_profiles_done',
          fields: {'pushedCount': pushed},
        );
      }
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — best-effort backfill path
      _logger.warning(
        event: 'sync_backfill_learner_profiles_skipped',
        exception: e,
      );
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
          'pace_reset_date': track.paceResetDate?.toIso8601String(),
        });
        pushed++;
      }

      if (pushed > 0) {
        _logger.info(
          event: 'sync_backfill_curriculum_tracks_done',
          fields: {'pushedCount': pushed},
        );
      }
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — best-effort backfill path
      _logger.warning(
        event: 'sync_backfill_curriculum_tracks_skipped',
        exception: e,
      );
    }
  }

  /// Repair legacy completion rows that were synced without `track_id`.
  ///
  /// Older cloud payloads omitted track_id, causing restored rows to land
  /// with trackId=0. This breaks track-scoped progress percentages on the
  /// dashboard/progress views. We repair by mapping (profile,curriculum,
  /// trackType) -> trackId when possible.
  Future<void> _repairLegacyCompletionTrackIds() async {
    // C1 (v20): completion_events is the canonical table; the physical
    // completions table is empty post-migration. This repair path is obsolete.
  }

  /// One-time purge of stale `completion` rows in the legacy sync_queue.
  ///
  /// Pre-rework builds double-wrote completions into both the outbox table
  /// and the legacy sync_queue. The outbox is now the canonical completion
  /// queue and the OfflineQueue no longer enqueues or flushes `completion`
  /// operations, so any leftover rows are unreachable dead data. This runs
  /// once per launch from [initialize] and is a cheap no-op once drained.
  Future<void> _purgeLegacyCompletionQueueRows() async {
    final removed = await _database.syncQueueDao.purgeCompletionRows();
    if (removed > 0) {
      _logger.info(
        event: 'sync_legacy_completion_queue_purged',
        fields: {'rowsRemoved': removed},
      );
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

    // RC7 fix: progress_summary, streak_summary, and gamification_summary were
    // write-only fields (no readers confirmed in repo-wide search). Removed to
    // eliminate 6 unnecessary DB queries per learner profile push.

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

    return <String, dynamic>{
      ...profile,
      'settings_snapshot': curriculumSettings,
    };
  }

  // ========== Listener Callbacks ==========

  Future<void> _onCompletionsUpdate(
    List<Map<String, dynamic>> completions,
  ) async {
    _consecutiveListenerErrors = 0;
    // Debounce: batch rapid successive snapshots into a single merge pass.
    // The Firestore listener stream feeding this callback
    // (FirestoreDataSource.listenToCompletions) only emits server-confirmed
    // snapshots — local-echo (hasPendingWrites==true) snapshots are filtered
    // upstream — so every snapshot reaching here is authoritative.
    _pendingCompletionsSnapshot = completions;
    _completionsDebounceTimer?.cancel();
    _completionsDebounceTimer = Timer(
      const Duration(milliseconds: 300),
      _drainPendingCompletionsSnapshot,
    );
  }

  /// Debounce-timer callback: merge the most recent completions snapshot.
  ///
  /// If a prior merge is still running, the pending snapshot is left intact
  /// and the debounce timer is re-armed so the snapshot is merged once the
  /// merge lock frees — a snapshot is never silently dropped (I1).
  void _drainPendingCompletionsSnapshot() {
    final pending = _pendingCompletionsSnapshot;
    if (pending == null) return;

    // A merge is in flight: do NOT consume the pending snapshot. Re-arm the
    // debounce timer so this snapshot is picked up after the lock frees.
    if (_mergingCompletions) {
      _completionsDebounceTimer?.cancel();
      _completionsDebounceTimer = Timer(
        const Duration(milliseconds: 300),
        _drainPendingCompletionsSnapshot,
      );
      return;
    }

    _pendingCompletionsSnapshot = null;
    _mergingCompletions = true;
    _logger.debug(
      event: 'sync_listener_completions_received',
      fields: {'count': pending.length},
    );
    _mergeCompletions(
      pending,
      fallbackProfileId: _firestoreDataSource.profileId,
    ).whenComplete(() => _mergingCompletions = false);
  }

  Future<void> _onBookmarksUpdate(List<Map<String, dynamic>> bookmarks) async {
    if (_mergingBookmarks) return;
    _mergingBookmarks = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(
        event: 'sync_listener_bookmarks_received',
        fields: {'count': bookmarks.length},
      );
      await _mergeBookmarks(
        bookmarks,
        profileId: _firestoreDataSource.profileId,
      );
    } finally {
      _mergingBookmarks = false;
    }
  }

  Future<void> _onSettingsUpdate(List<Map<String, dynamic>> settings) async {
    if (_mergingSettings) return;
    _mergingSettings = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(
        event: 'sync_listener_settings_received',
        fields: {'count': settings.length},
      );
      await _mergeSettings(settings, profileId: _firestoreDataSource.profileId);
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
      _logger.debug(event: 'sync_listener_streak_received');
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
      _logger.debug(
        event: 'sync_listener_goals_received',
        fields: {'count': goals.length},
      );
      await _mergeGoals(goals, profileId: _firestoreDataSource.profileId);
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
        event: 'sync_listener_profile_programs_received',
        fields: {'count': profilePrograms.length},
      );
      await _mergeProfilePrograms(
        profilePrograms,
        defaultProfileId: _firestoreDataSource.profileId,
      );
    } finally {
      _mergingProfilePrograms = false;
    }
  }

  Future<void> _onLedgerUpdate(List<Map<String, dynamic>> ledgerEntries) async {
    if (_mergingLedgerEntries) return;
    _mergingLedgerEntries = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(
        event: 'sync_listener_ledger_entries_received',
        fields: {'count': ledgerEntries.length},
      );
      await _mergeLedgerEntries(
        ledgerEntries,
        fallbackProfileId: _firestoreDataSource.profileId,
      );
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
        event: 'sync_listener_curriculum_tracks_received',
        fields: {'count': tracks.length},
      );
      await _mergeCurriculumTracks(
        tracks,
        profileId: _firestoreDataSource.profileId,
      );
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
      _logger.debug(event: 'sync_listener_notification_settings_received');
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
      _logger.debug(event: 'sync_listener_gamification_settings_received');
      await _mergeGamificationSettings(
        gamificationSettings,
        profileId: _firestoreDataSource.profileId,
      );
    } finally {
      _mergingGamificationSettings = false;
    }
  }

  Future<void> _onUiPreferencesUpdate(Map<String, dynamic>? remote) async {
    if (remote == null || remote.isEmpty) return;
    if (_mergingUiPreferences) return;
    _mergingUiPreferences = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(event: 'sync_listener_ui_preferences_received');
      await _mergeUiPreferences(
        remote,
        profileId: _firestoreDataSource.profileId,
      );
    } finally {
      _mergingUiPreferences = false;
    }
  }

  /// Merge learning-order items from Firestore (LWW per row — DNI-311).
  ///
  /// Each item is merged independently: the row is only written locally if
  /// [updatedAt] from Firestore is strictly newer than the local row's
  /// [updatedAt]. This prevents a stale cloud push from clobbering a fresh
  /// local drag-and-drop reorder that hasn't reached Firestore yet.
  Future<void> _mergeLearningOrder(
    List<Map<String, dynamic>> remoteItems, {
    required int profileId,
  }) async {
    _logger.debug(
      event:
          'Merging ${remoteItems.length} learning-order items from Firestore',
    );

    for (final remote in remoteItems) {
      try {
        final curriculumId = remote['curriculum_id'] as String?;
        final sefariaRef =
            (remote['sefaria_ref'] ?? remote['sefariaRef']) as String?;
        final rawSortOrder =
            remote['user_sort_order'] ?? remote['userSortOrder'];
        final sortOrder = rawSortOrder is int
            ? rawSortOrder
            : rawSortOrder is num
            ? rawSortOrder.toInt()
            : int.tryParse(rawSortOrder?.toString() ?? '');
        final updatedAt = _parseTimestamp(remote['updated_at']);

        if (curriculumId == null ||
            sefariaRef == null ||
            sortOrder == null ||
            updatedAt == null) {
          _logger.warning(
            event: 'Skipping invalid remote learning-order item',
            fields: {'item': remote.toString()},
          );
          continue;
        }

        final entry = LearningOrderCompanion(
          profileId: Value(profileId),
          curriculumId: Value(curriculumId),
          sefariaRef: Value(sefariaRef),
          userSortOrder: Value(sortOrder),
        );
        await _database.learningOrderDao.upsertLearningOrderIfNewer(
          entry,
          updatedAt: updatedAt,
        );
      } catch (e) {
        // ignore: avoid_catches_without_on_clauses — intentional merge-loop error boundary
        _logger.warning(
          event: 'Failed to merge learning-order item',
          fields: {'error': e.toString()},
        );
      }
    }
  }

  Future<void> _onLearningOrderUpdate(List<Map<String, dynamic>> items) async {
    if (_mergingLearningOrder) return;
    _mergingLearningOrder = true;
    _consecutiveListenerErrors = 0;
    try {
      _logger.debug(
        event: 'Received ${items.length} learning-order items from listener',
      );
      await _mergeLearningOrder(
        items,
        profileId: _firestoreDataSource.profileId,
      );
    } finally {
      _mergingLearningOrder = false;
    }
  }

  /// Handle listener errors with quota monitoring (NFR21).
  ///
  /// After [quotaErrorThreshold] consecutive errors, disables all listeners
  /// to prevent further quota consumption. The app falls back to
  /// pull-on-launch sync only.
  void _handleListenerError(Object error, StackTrace stackTrace) {
    _logger.error(
      event: 'sync_listener_error',
      exception: error,
      stackTrace: stackTrace,
    );

    // Distinguish PERMISSION_DENIED (auth issue) from other errors (quota).
    // Permission errors should detach immediately — retrying just wastes
    // requests and the 3-strike counter would misattribute them as quota.
    if (error.toString().contains('permission-denied')) {
      _logger.warning(event: 'sync_listener_permission_denied_detaching');
      detachListeners();
      _updateStatus(
        SyncStatus.error(
          message:
              'Authentication error — real-time sync paused. '
              'Sync will resume on next sign-in.',
          failedAt: DateTimeFactory.nowUtc(),
        ),
      );
      return;
    }

    _consecutiveListenerErrors++;

    if (_consecutiveListenerErrors >= quotaErrorThreshold && !_quotaDegraded) {
      _logger.warning(
        event: 'sync_listener_quota_threshold_reached_disabling',
        fields: {'consecutiveErrors': _consecutiveListenerErrors},
      );
      _quotaDegraded = true;
      detachListeners();
      _updateStatus(
        SyncStatus.error(
          message:
              'Firebase quota exceeded — real-time sync disabled. '
              'Data will sync on next app launch.',
          failedAt: DateTimeFactory.nowUtc(),
        ),
      );
      return;
    }

    _updateStatus(
      SyncStatus.error(
        message: error.toString(),
        failedAt: DateTimeFactory.nowUtc(),
      ),
    );
  }

  // ========== Network Events ==========

  Future<void> _onReconnect() async {
    _logger.info(event: 'sync_device_reconnected_flushing_queue');

    // Reset quota degradation on reconnect — give listeners another chance
    _consecutiveListenerErrors = 0;
    _quotaDegraded = false;
    _consecutivePushPermissionErrors = 0;

    if (!_firestoreDataSource.isAuthenticated) {
      _logger.info(event: 'sync_reconnect_flush_deferred_unauthenticated');
      await _updateQueueOnlyStatus();
      return;
    }

    _updateStatus(SyncStatus.syncing(startedAt: DateTimeFactory.nowUtc()));

    try {
      // In battery saver mode, process in smaller batches with delays
      final batchSize = _isBatterySaverMode ? 5 : null;
      final syncedCount = await _offlineQueue.flush(batchSize: batchSize);
      _logger.info(
        event: 'sync_reconnect_flush_done',
        fields: {'syncedCount': syncedCount},
      );

      _updateStatus(SyncStatus.synced(lastSyncedAt: DateTimeFactory.nowUtc()));

      // Reattach listeners — detachListeners() cleared the flag on disconnect,
      // so always attempt to attach them now that we are back online.
      _listenersAttached = false;
      await attachListeners();
    } catch (e, stackTrace) {
      _logger.error(
        event: 'sync_reconnect_flush_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      _updateStatus(
        SyncStatus.error(
          message: e.toString(),
          failedAt: DateTimeFactory.nowUtc(),
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

    await _offlineQueue.enqueueCurriculumImportMetadata(
      _withQueueTargetProfile(metadata),
    );
    await _afterEnqueueForBackgroundFlush(
      context: 'curriculum import metadata',
    );
  }

  // ========== Timestamp Persistence ==========

  /// Get the locally persisted settings timestamp for a curriculum.
  Future<DateTime?> _getSettingsTimestamp(
    String curriculumId,
    int profileId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newKey = _curriculumSettingsTimestampKey(profileId, curriculumId);
      var ms = prefs.getInt(newKey);
      if (ms == null) {
        // Legacy key (pre–per-profile LWW) — treat as this profile’s stamp so
        // first per-profile pull after upgrade still compares sanely.
        ms = prefs.getInt('settings_ts_$curriculumId');
      }
      if (ms == null) return null;
      return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — SharedPreferences may be unavailable in tests
      _logger.warning(
        event: 'sync_settings_timestamp_read_failed',
        exception: e,
      );
      return null;
    }
  }

  /// Set the locally persisted settings timestamp for a curriculum.
  Future<void> _setSettingsTimestamp(
    String curriculumId,
    DateTime updatedAt,
    int profileId,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
        _curriculumSettingsTimestampKey(profileId, curriculumId),
        updatedAt.toUtc().millisecondsSinceEpoch,
      );
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — SharedPreferences may be unavailable in tests
      _logger.warning(
        event: 'sync_settings_timestamp_persist_failed',
        exception: e,
      );
    }
  }

  /// Persist the last successful sync timestamp.
  Future<void> _persistLastSyncTimestamp(DateTime syncedAt) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSyncKey, syncedAt.millisecondsSinceEpoch);
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses — SharedPreferences may be unavailable in tests
      _logger.warning(
        event: 'sync_last_sync_timestamp_persist_failed',
        exception: e,
      );
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
      _logger.warning(
        event: 'sync_last_sync_timestamp_restore_failed',
        exception: e,
      );
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

  /// Read UI preferences for the active learner profile (locale, calendar,
  /// text display, learning-order flag) for Firestore `ui_preferences/data`.
  Future<Map<String, dynamic>> _readLocalUiPreferencesPayload() async {
    final profileId = _firestoreDataSource.profileId;
    final prefs = await SharedPreferences.getInstance();
    final locale = ProfileScopedPreferenceKeys.readAppLocale(prefs, profileId);
    final hebrew = ProfileScopedPreferenceKeys.readUseHebrewCalendar(
      prefs,
      profileId,
    );
    final fontIdx = ProfileScopedPreferenceKeys.readFontSizeIndex(
      prefs,
      profileId,
    );
    final nikud = ProfileScopedPreferenceKeys.readShowNikud(prefs, profileId);
    final learningOrder =
        ProfileScopedPreferenceKeys.readLearningOrderParentControls(
          prefs,
          profileId,
        );
    final hebrewTermsScript = ProfileScopedPreferenceKeys.readHebrewTermsScript(
      prefs,
      profileId,
    );
    final updatedAtMs = prefs.getInt(
      ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileId),
    );
    final updatedAt = updatedAtMs == null
        ? DateTimeFactory.nowUtc()
        : DateTime.fromMillisecondsSinceEpoch(updatedAtMs, isUtc: true);

    final payload = <String, dynamic>{
      'schema_version': 2,
      'profile_id': profileId,
      'updated_at': updatedAt.toIso8601String(),
      'app_locale': locale,
      'use_hebrew_calendar': hebrew,
      'text_display': {'font_size_index': fontIdx, 'show_nikud': nikud},
      'learning_order_parent_controls': learningOrder,
      'hebrew_terms_script': hebrewTermsScript,
    };

    // Sacred Time settings are device-global (not per-profile). Stash them
    // on profile 0's UI-preferences doc so they restore after a wipe + login;
    // other profile docs don't carry them.
    if (profileId == 0) {
      final sacredTime = <String, dynamic>{};
      final lat = prefs.getDouble('sacred_time_latitude');
      final lon = prefs.getDouble('sacred_time_longitude');
      if (lat != null) sacredTime['latitude'] = lat;
      if (lon != null) sacredTime['longitude'] = lon;
      final country = prefs.getString('sacred_time_country_code');
      if (country != null) sacredTime['country_code'] = country;
      final city = prefs.getString('sacred_time_city_label');
      if (city != null) sacredTime['city_label'] = city;
      final source = prefs.getString('sacred_time_source');
      if (source != null) sacredTime['source'] = source;
      final fixedAt = prefs.getInt('sacred_time_fixed_at_ms');
      if (fixedAt != null) sacredTime['fixed_at_ms'] = fixedAt;
      sacredTime['in_israel'] = prefs.getBool('sacred_time_in_israel') ?? false;
      payload['sacred_time'] = sacredTime;
    }

    return payload;
  }

  /// Read notification preferences from local SharedPreferences and convert
  /// them into the profile-scoped Firestore notification_settings payload.
  Future<Map<String, dynamic>> _readLocalNotificationSettingsPayload() async {
    final prefs = await SharedPreferences.getInstance();
    final updatedAtMs = prefs.getInt(_notificationSettingsUpdatedAtMsKey);
    final updatedAt = updatedAtMs == null
        ? DateTimeFactory.nowUtc()
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
    _logger.info(
      event: 'sync_battery_saver_mode_changed',
      fields: {'enabled': enabled},
    );
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
      _logger.warning(
        event: 'sync_push_all_local_data_skipped_unauthenticated',
      );
      return;
    }

    _logger.info(event: 'sync_push_all_local_data_start');
    _updateStatus(SyncStatus.syncing(startedAt: DateTimeFactory.nowUtc()));

    try {
      // --- Completions (append-only) ---
      // Route local completions through the canonical outbox path. Building a
      // CompletionCommand list and calling CompletionWriter.commitBatch is an
      // idempotent safety pass: commitBatch enqueues an outbox row ONLY for a
      // completion whose natural key is NOT yet in completion_events — it does
      // NOT regenerate an outbox row for a completion whose event already
      // exists (a present event is treated as already-queued). For a
      // local-born account upgrading to cloud, every completion already
      // received its outbox row at creation time and the outbox is never
      // drained pre-upgrade, so in practice this call inserts nothing for
      // existing completions and only covers any genuinely-new one recorded
      // between account creation and this push. The background-flush
      // machinery then drains the outbox — no manual push loop here.
      final analytics = ParentAnalyticsRepositoryImpl(_database);
      final completions = await analytics.getAllCompletions(
        scope: CrossProfileScope.syncRestore,
      );
      final completionCommands = completions
          .map(
            (c) => CompletionCommand(
              profileId: c.profileId,
              curriculumId: c.curriculumId,
              sefariaRef: c.sefariaRef,
              stageId: c.stageId,
              trackType: c.trackType,
              trackId: c.trackId,
              completedAt: c.completedAt,
              points: c.points,
            ),
          )
          .toList();
      await CompletionWriter(_database).commitBatch(completionCommands);
      _logger.debug(
        event: 'sync_push_all_completions_queued',
        fields: {'count': completionCommands.length},
      );

      // --- Bookmarks ---
      final bookmarks = await _database.bookmarkDao.getAllBookmarks();
      for (final b in bookmarks) {
        // Resolve trackId → trackType string for Firestore payload
        final track = await (_database.select(
          _database.curriculumTracks,
        )..where((t) => t.id.equals(b.trackId))).getSingleOrNull();
        if (track == null) continue;
        await pushBookmark({
          'curriculum_id': b.curriculumId,
          'track_type': track.trackType,
          'content_item_id': b.sefariaRef,
          'updated_at': b.updatedAt.toIso8601String(),
        });
      }
      _logger.debug(
        event: 'sync_push_all_bookmarks_queued',
        fields: {'count': bookmarks.length},
      );

      // --- Goals ---
      final goals = await _database.goalDao.getAllGoals();
      for (final g in goals) {
        await pushGoal({
          'profile_id': g.profileId,
          'track_id': g.trackId,
          'curriculum_id': g.curriculumId,
          'description': g.description,
          'target_percent': g.targetPercent,
          'target_date': g.targetDate?.toIso8601String(),
          'date_type': g.dateType,
          'goal_type': g.goalType,
          'pace_value': g.paceValue,
          'pace_unit': g.pacePeriod,
          'created_at': g.createdAt.toIso8601String(),
          'updated_at': g.updatedAt.toIso8601String(),
        });
      }
      _logger.debug(
        event: 'sync_push_all_goals_queued',
        fields: {'count': goals.length},
      );

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
      _logger.debug(
        event: 'sync_push_all_profile_programs_queued',
        fields: {'count': profilePrograms.length},
      );

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
        _logger.debug(event: 'sync_push_all_streak_queued');
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
          'entryScope': e.entryScope,
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
      _logger.debug(
        event: 'sync_push_all_ledger_entries_queued',
        fields: {'count': ledgerEntries.length},
      );

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
          'pace_reset_date': t.paceResetDate?.toIso8601String(),
        });
      }
      _logger.debug(
        event: 'sync_push_all_curriculum_tracks_queued',
        fields: {'count': tracks.length},
      );

      // --- Notification settings (profile-scoped preferences) ---
      final notificationSettings =
          await _readLocalNotificationSettingsPayload();
      await pushNotificationSettings(notificationSettings);
      _logger.debug(event: 'sync_push_all_notification_settings_queued');

      // --- Gamification settings (points + reward milestones/unlocks) ---
      await pushGamificationSettingsSnapshot();
      _logger.debug(event: 'sync_push_all_gamification_settings_queued');

      // --- UI preferences (locale, Hebrew calendar, text display, learning order) ---
      await pushUiPreferencesSnapshot();
      _logger.debug(event: 'sync_push_all_ui_preferences_queued');

      _logger.info(event: 'sync_push_all_local_data_completed');
      final syncedAt = DateTimeFactory.nowUtc();
      await _persistLastSyncTimestamp(syncedAt);
      _updateStatus(SyncStatus.synced(lastSyncedAt: syncedAt));
    } catch (e, stackTrace) {
      _logger.error(
        event: 'sync_push_all_local_data_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      _updateStatus(
        SyncStatus.error(
          message: e.toString(),
          failedAt: DateTimeFactory.nowUtc(),
        ),
      );
    }
  }
}
