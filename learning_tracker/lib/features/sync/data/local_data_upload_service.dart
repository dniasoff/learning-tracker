import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/streak/streak_state_provider.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outbox-backed replacement for [SyncEngine.pushAllLocalData] and
/// [SyncEngine.backfillGoalsForCloudCutover].
///
/// Routes every local entity kind through the outbox table so that
/// [OutboxProcessor] can drain them asynchronously — matching the
/// [OutboxSyncWriteFacade] contract. This lets [SyncEngine] be deleted once
/// all push paths are migrated (W2.35).
///
/// Thread safety: [pushAllLocalData] is not re-entrant. The caller
/// ([SyncOrchestrator]) must serialize calls.
class LocalDataUploadService {
  LocalDataUploadService({
    required OutboxSyncWriteFacade facade,
    required UserDatabase database,
    required int profileId,
    AppLogger? logger,
  }) : _facade = facade,
       _database = database,
       _profileId = profileId,
       _logger = logger,
       _streakStateProvider = StreakStateProvider(
         db: database,
         clock: const SystemLocalDayClock(),
       );

  final OutboxSyncWriteFacade _facade;
  final UserDatabase _database;
  final int _profileId;
  final AppLogger? _logger;
  final StreakStateProvider _streakStateProvider;

  static const _goalsBackfilledKey = 'sync_goals_backfilled_v1';

  // Notification-settings SharedPreferences keys — must match
  // [SyncEngine] and [NotificationSettingsMerger].
  static const _notificationSettingsUpdatedAtMsKey =
      'notification_settings_updated_at_ms';
  static const _reminderEnabledKey = 'daily_reminder_enabled';
  static const _reminderHourKey = 'daily_reminder_hour';
  static const _reminderMinuteKey = 'daily_reminder_minute';
  static const _streakAlertEnabledKey = 'streak_alert_enabled';
  static const _streakAlertHourKey = 'streak_alert_hour';
  static const _streakAlertMinuteKey = 'streak_alert_minute';
  static const _rewardNotificationEnabledKey = 'reward_notification_enabled';

  /// Push all locally-stored data to the outbox.
  ///
  /// Called once after a local-born account is upgraded to cloud (story 19.7)
  /// so that the user's offline learning history is immediately available in
  /// the cloud. Each entity kind is enqueued via [OutboxSyncWriteFacade] /
  /// [OutboxProcessor] rather than the legacy [SyncEngine.pushAllLocalData]
  /// path.
  Future<void> pushAllLocalData() async {
    _logger?.info(event: 'local_data_upload_start');

    // ── Completions (append-only via CompletionWriter) ────────────────────
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
    _logger?.debug(
      event: 'local_data_upload_completions_queued',
      fields: {'count': completionCommands.length},
    );

    // ── Bookmarks ─────────────────────────────────────────────────────────
    final bookmarks = await _database.bookmarkDao.getAllBookmarks();
    for (final b in bookmarks) {
      final track = await (_database.select(
        _database.curriculumTracks,
      )..where((t) => t.id.equals(b.trackId))).getSingleOrNull();
      if (track == null) continue;
      await _facade.pushBookmark({
        'curriculum_id': b.curriculumId,
        'content_item_id': b.sefariaRef,
        'updated_at': b.updatedAt.toIso8601String(),
      });
    }
    _logger?.debug(
      event: 'local_data_upload_bookmarks_queued',
      fields: {'count': bookmarks.length},
    );

    // ── Goals ─────────────────────────────────────────────────────────────
    final goals = await _database.goalDao.getAllGoals();
    for (final g in goals) {
      final firestoreId =
          '${g.curriculumId}_${g.targetPercent.toStringAsFixed(1)}_'
          '${g.createdAt.millisecondsSinceEpoch}';
      await _facade.pushGoal({
        'id': firestoreId,
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
    _logger?.debug(
      event: 'local_data_upload_goals_queued',
      fields: {'count': goals.length},
    );

    // ── Profile programs ──────────────────────────────────────────────────
    final profilePrograms = await _database.profileProgramDao
        .getProgramsForProfile(_profileId);
    for (final p in profilePrograms) {
      await _facade.enqueueProfileProgram({
        'profile_id': p.profileId,
        'curriculum_id': p.curriculumType,
        'program_id': p.programId,
        'tracking_start_date': p.trackingStartDate?.toIso8601String(),
        'tracking_start_ref': p.trackingStartRef,
      });
    }
    _logger?.debug(
      event: 'local_data_upload_profile_programs_queued',
      fields: {'count': profilePrograms.length},
    );

    // ── Streak ────────────────────────────────────────────────────────────
    // W3.20: streaks table dropped; derive from streak_events via
    // StreakStateProvider rather than reading the cached snapshot row.
    final streakState = await _streakStateProvider.read(profileId: _profileId);
    if (streakState.currentStreak > 0 ||
        streakState.lastCompletionDayUtc != null) {
      await _facade.enqueueStreakPayload({
        'current_count': streakState.currentStreak,
        'max_count': streakState.maxStreak,
        'last_completion_date': streakState.lastCompletionDayUtc
            ?.toIso8601String(),
      });
      _logger?.debug(event: 'local_data_upload_streak_queued');
    }

    // ── Learning-ledger entries ───────────────────────────────────────────
    final ledgerEntries = await _database
        .select(_database.learningLedger)
        .get();
    for (final e in ledgerEntries) {
      await _facade.enqueueLedgerEntry({
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
    _logger?.debug(
      event: 'local_data_upload_ledger_entries_queued',
      fields: {'count': ledgerEntries.length},
    );

    // ── Curriculum tracks ─────────────────────────────────────────────────
    final tracks = await _database.trackDao.getAllForProfile(_profileId);
    for (final t in tracks) {
      await _facade.pushCurriculumTrack({
        'profile_id': t.profileId,
        'track_id': t.id,
        'curriculum_id': t.curriculumId,
        'state': t.state,
        'state_changed_at': t.stateChangedAt.toIso8601String(),
        'activated_at': t.activatedAt.toIso8601String(),
        'pace_reset_date': t.paceResetDate?.toIso8601String(),
      });
    }
    _logger?.debug(
      event: 'local_data_upload_curriculum_tracks_queued',
      fields: {'count': tracks.length},
    );

    // ── Notification settings ─────────────────────────────────────────────
    final notifPayload = await _buildNotificationSettingsPayload();
    await _facade.enqueueNotificationSettings(notifPayload);
    _logger?.debug(event: 'local_data_upload_notification_settings_queued');

    // ── Gamification settings ─────────────────────────────────────────────
    await _facade.pushGamificationSettingsSnapshot();
    _logger?.debug(event: 'local_data_upload_gamification_settings_queued');

    // ── UI preferences ────────────────────────────────────────────────────
    await _facade.pushUiPreferencesSnapshot();
    _logger?.debug(event: 'local_data_upload_ui_preferences_queued');

    _logger?.info(event: 'local_data_upload_complete');
  }

  /// One-time backfill of locally-known goals to Firestore.
  ///
  /// Idempotent: guarded by [_goalsBackfilledKey] in SharedPreferences.
  /// Returns the number of goals enqueued (zero on subsequent launches).
  Future<int> backfillGoalsForCloudCutover() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_goalsBackfilledKey) ?? false) return 0;

    final goals = await _database.goalDao.getAllGoals();
    for (final g in goals) {
      final firestoreId =
          '${g.curriculumId}_${g.targetPercent.toStringAsFixed(1)}_'
          '${g.createdAt.millisecondsSinceEpoch}';
      await _facade.pushGoal({
        'id': firestoreId,
        'profile_id': g.profileId,
        'track_id': g.trackId,
        'curriculumId': g.curriculumId,
        'targetPercent': g.targetPercent,
        'targetDate': g.targetDate?.toIso8601String(),
        'description': g.description,
        'dateType': g.dateType,
        'goalType': g.goalType,
        'paceValue': g.paceValue,
        'pacePeriod': g.pacePeriod,
        'paceGranularity': g.paceGranularity,
        'createdAt': g.createdAt.toIso8601String(),
        'updatedAt': g.updatedAt.toIso8601String(),
      });
    }
    await prefs.setBool(_goalsBackfilledKey, true);
    _logger?.info(
      event: 'local_data_upload_goals_backfilled',
      fields: {'count': goals.length},
    );
    return goals.length;
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildNotificationSettingsPayload() async {
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
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
