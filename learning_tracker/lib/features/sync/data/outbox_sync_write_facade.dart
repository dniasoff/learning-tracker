import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Outbox-backed implementation of [SyncWriteFacade].
///
/// Each push/delete call encodes the payload as a JSON outbox row, which
/// [OutboxProcessor] drains asynchronously via [PushPipeline].  The local
/// write and the outbox insert are not transactional at this layer (callers
/// that require atomicity should call [OutboxDao.insertOutboxRow] directly
/// inside their own `db.transaction()`); here we simply enqueue and return
/// so that the UI is never blocked on network.
///
/// **Gamification snapshot:** [pushGamificationSettingsSnapshot] needs to
/// read from [UserDatabase] and [RewardMilestoneService], which live in
/// `features/gamification/`.  This class therefore lives in
/// `features/sync/data/` rather than `core/sync/` so that the import is
/// permitted by the layering rules.
///
/// This replaces the [SyncEngine] as the canonical [SyncWriteFacade] for
/// all outbox-enrolled entity kinds (W2.31).
class OutboxSyncWriteFacade implements SyncWriteFacade {
  OutboxSyncWriteFacade({
    required OutboxDao outboxDao,
    required UserDatabase database,
    required int profileId,
    required LocalDayClock clock,
  }) : _dao = outboxDao,
       _database = database,
       _profileId = profileId,
       _clock = clock;

  final OutboxDao _dao;
  final UserDatabase _database;
  final int _profileId;
  final LocalDayClock _clock;

  static const _gamificationUpdatedAtMsKeyPrefix =
      'gamification_settings_updated_at_ms_p';

  // ── SyncWriteFacade implementation ─────────────────────────────────────────

  @override
  Future<void> pushBookmark(Map<String, dynamic> bookmark) =>
      _enqueue(OutboxEntityKind.bookmark, _key(bookmark), bookmark);

  @override
  Future<void> pushSettings(Map<String, dynamic> settings) =>
      _enqueue(OutboxEntityKind.settings, _key(settings), settings);

  @override
  Future<void> pushGoal(Map<String, dynamic> goal) =>
      _enqueue(OutboxEntityKind.goal, _goalKey(goal), goal);

  @override
  Future<void> deleteGoal(Map<String, dynamic> payload) => _enqueue(
    OutboxEntityKind.goalDelete,
    payload['firestore_id']?.toString() ?? 'unknown',
    payload,
  );

  @override
  Future<void> pushCurriculumTrack(Map<String, dynamic> trackData) =>
      _enqueue(OutboxEntityKind.track, _key(trackData), trackData);

  @override
  Future<void> pushLearningOrder({
    required int profileId,
    required String curriculumId,
    required List<Map<String, dynamic>> items,
    required DateTime updatedAt,
  }) async {
    // Enqueue each item as a separate outbox row — mirrors the SyncEngine
    // behaviour and allows [OutboxProcessor] to retry individual rows.
    for (final item in items) {
      final payload = {
        ...item,
        'curriculum_id': curriculumId,
        'updated_at': updatedAt.toIso8601String(),
      };
      final entityKey =
          '${curriculumId}_${item['sefaria_ref'] ?? item['ref'] ?? ''}';
      await _enqueue(OutboxEntityKind.learningOrder, entityKey, payload);
    }
  }

  @override
  Future<void> pushLearnerProfile(Map<String, dynamic> profile) => _enqueue(
    OutboxEntityKind.learnerProfile,
    profile['profile_id']?.toString() ?? _profileId.toString(),
    profile,
  );

  @override
  Future<void> deleteLearnerProfile(int profileId) => _enqueue(
    OutboxEntityKind.learnerProfileDelete,
    profileId.toString(),
    {'profile_id': profileId},
  );

  /// Build the gamification snapshot from local DB + [RewardMilestoneService]
  /// and enqueue it for push.
  ///
  /// Sets the local `gamification_settings_updated_at_ms_p$profileId`
  /// SharedPreferences timestamp before enqueuing (matches [SyncEngine]
  /// behaviour so LWW checks stay consistent).
  @override
  Future<void> pushGamificationSettingsSnapshot() async {
    final now = _clock.nowUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_gamificationUpdatedAtMsKeyPrefix$_profileId',
      now.millisecondsSinceEpoch,
    );

    final pointRows = await (_database.select(
      _database.pointConfigs,
    )..where((t) => t.profileId.equals(_profileId))).get();

    final rewardService = RewardMilestoneService(
      _database,
      profileId: _profileId,
    );
    final rewardPayload = await rewardService.exportCloudPayload();

    final totalPointsExpr = _database.completionEvents.points.sum();
    final totalPointsRow =
        await (_database.selectOnly(_database.completionEvents)
              ..addColumns([totalPointsExpr])
              ..where(
                _database.completionEvents.profileId.equals(_profileId) &
                    _database.completionEvents.purgedAt.isNull(),
              ))
            .getSingle();
    final totalPointsSum = totalPointsRow.read(totalPointsExpr) ?? 0;

    final payload = <String, dynamic>{
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

    await _enqueue(
      OutboxEntityKind.gamificationSettings,
      'gamification_settings_$_profileId',
      payload,
    );
  }

  /// Build the UI-preferences payload from [SharedPreferences] and enqueue it.
  ///
  /// Mirrors [SyncEngine._readLocalUiPreferencesPayload] and updates the
  /// `ui_preferences_updated_at_ms_p$profileId` timestamp before enqueuing.
  @override
  Future<void> pushUiPreferencesSnapshot() async {
    final now = _clock.nowUtc();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(_profileId),
      now.millisecondsSinceEpoch,
    );

    final payload = <String, dynamic>{
      'schema_version': 2,
      'profile_id': _profileId,
      'updated_at': now.toIso8601String(),
      'app_locale': ProfileScopedPreferenceKeys.readAppLocale(prefs, _profileId),
      'use_hebrew_calendar':
          ProfileScopedPreferenceKeys.readUseHebrewCalendar(prefs, _profileId),
      'text_display': {
        'font_size_index':
            ProfileScopedPreferenceKeys.readFontSizeIndex(prefs, _profileId),
        'show_nikud':
            ProfileScopedPreferenceKeys.readShowNikud(prefs, _profileId),
      },
      'learning_order_parent_controls':
          ProfileScopedPreferenceKeys.readLearningOrderParentControls(
            prefs,
            _profileId,
          ),
      'hebrew_terms_script':
          ProfileScopedPreferenceKeys.readHebrewTermsScript(prefs, _profileId),
    };

    if (_profileId == 0) {
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
      sacredTime['in_israel'] =
          prefs.getBool('sacred_time_in_israel') ?? false;
      payload['sacred_time'] = sacredTime;
    }

    await _enqueue(
      OutboxEntityKind.uiPreferences,
      'ui_preferences_$_profileId',
      payload,
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  Future<void> _enqueue(
    String kind,
    String entityKey,
    Map<String, dynamic> payload,
  ) => _dao.insertOutboxRow(
    OutboxCompanion(
      profileId: Value(_profileId),
      entityKind: Value(kind),
      entityKey: Value(entityKey),
      payload: Value(jsonEncode(payload)),
      createdAt: Value(_clock.nowUtc()),
    ),
  );

  /// Derive a stable entity key from a payload by concatenating a few
  /// discriminating fields.  Falls back to a timestamp suffix when neither
  /// `id`, `curriculum_id`, nor `track_id` is present so that the outbox
  /// never silently drops rows.
  String _key(Map<String, dynamic> payload) {
    final parts = <String>[];
    if (payload['curriculum_id'] != null) {
      parts.add(payload['curriculum_id'].toString());
    }
    if (payload['track_id'] != null) {
      parts.add(payload['track_id'].toString());
    }
    if (parts.isEmpty) {
      parts.add(DateTimeFactory.nowUtc().millisecondsSinceEpoch.toString());
    }
    return parts.join('_');
  }

  /// Goal entity key: mirrors the deterministic Firestore doc-id so the
  /// outbox de-duplicates multiple enqueues of the same goal.
  String _goalKey(Map<String, dynamic> goal) {
    final id = goal['id']?.toString() ?? goal['goal_id']?.toString();
    if (id != null) return id;
    final curriculum = goal['curriculumId']?.toString() ??
        goal['curriculum_id']?.toString() ??
        '';
    final pct = (goal['targetPercent'] ?? goal['target_percent'] ?? 0)
        .toString();
    final ts =
        goal['createdAt']?.toString() ?? goal['created_at']?.toString() ?? '';
    return '${curriculum}_${pct}_$ts';
  }

  // ── W2.32 package-visible enqueue helpers for LocalDataUploadService ────────
  //
  // These are NOT part of SyncWriteFacade — they are helpers used by
  // [LocalDataUploadService] for entity kinds that are not yet on the facade
  // interface.

  Future<void> enqueueNotificationSettings(
    Map<String, dynamic> payload,
  ) => _enqueue(
    OutboxEntityKind.notificationSettings,
    'notification_settings_$_profileId',
    payload,
  );

  Future<void> enqueueProfileProgram(Map<String, dynamic> payload) => _enqueue(
    OutboxEntityKind.profileProgram,
    '${payload['curriculum_id'] ?? ''}_${payload['program_id'] ?? ''}',
    payload,
  );

  Future<void> enqueueStreakPayload(Map<String, dynamic> payload) => _enqueue(
    OutboxEntityKind.streak,
    'streak_$_profileId',
    payload,
  );

  Future<void> enqueueLedgerEntry(Map<String, dynamic> payload) => _enqueue(
    OutboxEntityKind.learningLedgerEntry,
    payload['unitIdentifier']?.toString() ??
        DateTimeFactory.nowUtc().millisecondsSinceEpoch.toString(),
    payload,
  );
}
