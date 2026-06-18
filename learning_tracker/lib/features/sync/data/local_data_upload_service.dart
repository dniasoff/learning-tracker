import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/bookmark_codec.dart';
import 'package:learning_tracker/core/sync/codec/goal_codec.dart';
import 'package:learning_tracker/core/sync/codec/profile_program_codec.dart';
import 'package:learning_tracker/core/sync/codec/streak_event_codec.dart';
import 'package:learning_tracker/core/sync/codec/track_codec.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/learning/data/completion_writer.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart';
import 'package:learning_tracker/features/notifications/domain/repositories/notification_preferences_repository.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outbox-backed replacement for [SyncEngine.pushAllLocalData].
///
/// Routes every local entity kind through the outbox table so that
/// [OutboxProcessor] can drain them asynchronously — matching the
/// [OutboxSyncWriteFacade] contract. This lets [SyncEngine] be deleted once
/// all push paths are migrated (W2.35).
///
/// Thread safety: [pushAllLocalData] is not re-entrant. The caller
/// ([SyncOrchestrator]) must serialize calls.
///
/// The legacy `backfillGoalsForCloudCutover` (DNI-334 cutover bridge) was
/// removed at Plan §F Phase 5 deliverable 9. See the deletion comment in
/// the body for the rationale.
class LocalDataUploadService {
  LocalDataUploadService({
    required OutboxSyncWriteFacade facade,
    required UserDatabase database,
    required int profileId,
    AppLogger? logger,
  }) : _facade = facade,
       _database = database,
       _profileId = profileId,
       _logger = logger;

  final OutboxSyncWriteFacade _facade;
  final UserDatabase _database;
  final int _profileId;
  final AppLogger? _logger;

  // Notification-settings SharedPreferences keys are now per-profile
  // (WS5.key-prefs). Keys are resolved at call-time via
  // [NotificationPreferencesRepository.keyForProfile].

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
    // Phase B: route through BookmarkCodec.encode() so the bulk-upload shape
    // is identical to the per-save shape in BookmarkEntity.toFirestore().
    const bookmarkCodec = BookmarkCodec();
    final bookmarks = await _database.bookmarkDao.getAllBookmarks();
    for (final b in bookmarks) {
      final track = await (_database.select(
        _database.curriculumTracks,
      )..where((t) => t.id.equals(b.trackId))).getSingleOrNull();
      if (track == null) continue;
      await _facade.pushBookmark(
        bookmarkCodec.encode(
          BookmarkRow(
            curriculumId: b.curriculumId,
            sefariaRef: b.sefariaRef,
            updatedAt: b.updatedAt,
          ),
        ),
      );
    }
    _logger?.debug(
      event: 'local_data_upload_bookmarks_queued',
      fields: {'count': bookmarks.length},
    );

    // ── Goals ─────────────────────────────────────────────────────────────
    // Phase B: route through the canonical GoalCodec.encode() serializer so
    // the bulk-upload shape is identical to the per-save shape in
    // goal_repository_impl._syncGoal. `id` is injected post-encode (matches
    // FirestoreGateway.pushGoal's doc-id convention).
    const goalCodec = GoalCodec();
    final goals = await _database.goalDao.getAllGoals();
    for (final g in goals) {
      final firestoreId =
          '${g.curriculumId}_${g.targetPercent.toStringAsFixed(1)}_'
          '${g.createdAt.millisecondsSinceEpoch}';
      final payload = goalCodec.encode(
        GoalRow(
          firestoreId: firestoreId,
          profileId: g.profileId,
          curriculumId: g.curriculumId,
          trackId: g.trackId,
          targetPercent: g.targetPercent,
          description: g.description,
          dateType: g.dateType,
          goalType: g.goalType,
          paceValue: g.paceValue,
          pacePeriod: g.pacePeriod,
          paceGranularity: g.paceGranularity,
          targetDate: g.targetDate,
          createdAt: g.createdAt,
          updatedAt: g.updatedAt,
        ),
      );
      payload['id'] = firestoreId;
      await _facade.pushGoal(payload);
    }
    _logger?.debug(
      event: 'local_data_upload_goals_queued',
      fields: {'count': goals.length},
    );

    // ── Profile programs ──────────────────────────────────────────────────
    const profileProgramCodec = ProfileProgramCodec();
    final profilePrograms = await _database.profileProgramDao
        .getProgramsForProfile(_profileId);
    for (final p in profilePrograms) {
      final payload = profileProgramCodec.encode(
        ProfileProgramRow(
          profileId: p.profileId,
          curriculumId: p.curriculumType,
          programId: p.programId,
          trackingStartDate: p.trackingStartDate,
          trackingStartRef: p.trackingStartRef,
          // The local DB has no stored updated_at — use now() so the
          // remote document carries a valid LWW timestamp. The merger
          // falls back to trackingStartDate for pre-codec rows, so this
          // is strictly additive and safe to back-fill.
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
      await _facade.enqueueProfileProgram(payload);
    }
    _logger?.debug(
      event: 'local_data_upload_profile_programs_queued',
      fields: {'count': profilePrograms.length},
    );

    // ── Streak ────────────────────────────────────────────────────────────
    // H7 fix (V3-W1 / W3.37): streak_events is a per-event collection.
    // Enqueue each local streak event as a separate outbox row with the
    // correct per-event fields (event_type, study_date, created_at, profile_id,
    // ulid). Payload is built via StreakEventCodec.encode() so this path
    // and the per-completion _appendStreakEvent path share the same canonical
    // write shape (Phase B serialization-unify).
    const streakCodec = StreakEventCodec();
    final streakEvents = await _database.streakEventDao.getEventsByProfile(
      _profileId,
    );
    for (final e in streakEvents) {
      final payload = streakCodec.encode(
        StreakEventRow(
          profileId: _profileId,
          eventType: e.eventType,
          studyDate: DateTime.utc(
            e.eventTimestamp.year,
            e.eventTimestamp.month,
            e.eventTimestamp.day,
          ),
          createdAt: e.createdAt,
          ulid: newUlid(e.eventTimestamp),
        ),
      );
      await _facade.enqueueStreakPayload(payload);
    }
    _logger?.debug(
      event: 'local_data_upload_streak_queued',
      fields: {'count': streakEvents.length},
    );

    // ── Learning-ledger entries ───────────────────────────────────────────
    // W3.18/W3.19: push with snake_case field names so the pull-side
    // LearningLedgerMerger can decode them correctly.
    final ledgerEntries = await _database
        .select(_database.learningLedger)
        .get();
    for (final e in ledgerEntries) {
      await _facade.enqueueLedgerEntry({
        'ulid': e.ulid,
        'profile_id': e.profileId,
        'curriculum_id': e.curriculumId,
        'entry_scope': e.entryScope,
        'unit_identifier': e.unitIdentifier,
        'unit_display_name_he': e.unitDisplayNameHe,
        'unit_display_name_en': e.unitDisplayNameEn,
        'track_type': e.trackType,
        'track_id': e.trackId,
        'completed_at': e.completedAt.toIso8601String(),
        'completion_number': e.completionNumber,
        'marked_by': e.markedBy,
        'is_manual': e.isManual,
      });
    }
    _logger?.debug(
      event: 'local_data_upload_ledger_entries_queued',
      fields: {'count': ledgerEntries.length},
    );

    // ── Curriculum tracks ─────────────────────────────────────────────────
    const trackCodec = TrackCodec();
    final tracks = await _database.trackDao.getAllForProfile(_profileId);
    for (final t in tracks) {
      await _facade.pushCurriculumTrack(
        trackCodec.encode(
          TrackRow(
            profileId: t.profileId,
            trackId: t.id,
            curriculumId: t.curriculumId,
            state: t.state,
            stateChangedAt: t.stateChangedAt,
            activatedAt: t.activatedAt,
            paceResetDate: t.paceResetDate,
          ),
        ),
      );
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

  // Plan §F Phase 5 deliverable 9 — `backfillGoalsForCloudCutover` is gone.
  // It existed for the one-time DNI-334 cutover where goals had been routed
  // through `pushSettings` and never reached Firestore. The cutover landed
  // pre-launch (per the `project_pre_launch_status` memory there are no
  // live users), so the SharedPrefs flag (`sync_goals_backfilled_v1`) has
  // never fired in production and there is no goal-data left over to
  // resurrect. Anything new uses the outbox-backed [pushGoal] path from
  // first commit forward.

  // ── helpers ─────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> _buildNotificationSettingsPayload() async {
    final prefs = await SharedPreferences.getInstance();
    // WS5.key-prefs: keys are per-profile namespaced.
    final updatedAtMs = prefs.getInt(
      NotificationPreferencesRepository.notificationSettingsUpdatedAtMsKey(
        _profileId,
      ),
    );
    final updatedAt = updatedAtMs == null
        ? DateTimeFactory.nowUtc()
        : DateTime.fromMillisecondsSinceEpoch(updatedAtMs, isUtc: true);

    return {
      'schema_version': 1,
      'daily_reminder': {
        'enabled':
            prefs.getBool(
              NotificationPreferencesRepository.reminderEnabledKey(_profileId),
            ) ??
            true,
        'hour':
            prefs.getInt(
              NotificationPreferencesRepository.reminderHourKey(_profileId),
            ) ??
            19,
        'minute':
            prefs.getInt(
              NotificationPreferencesRepository.reminderMinuteKey(_profileId),
            ) ??
            0,
      },
      'streak_alert': {
        'enabled':
            prefs.getBool(
              NotificationPreferencesRepository.streakAlertEnabledKey(
                _profileId,
              ),
            ) ??
            true,
        'hour':
            prefs.getInt(
              NotificationPreferencesRepository.streakAlertHourKey(_profileId),
            ) ??
            21,
        'minute':
            prefs.getInt(
              NotificationPreferencesRepository.streakAlertMinuteKey(
                _profileId,
              ),
            ) ??
            0,
      },
      'reward_notifications': {
        'enabled':
            prefs.getBool(
              NotificationPreferencesRepository.rewardNotificationEnabledKey(
                _profileId,
              ),
            ) ??
            true,
      },
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
