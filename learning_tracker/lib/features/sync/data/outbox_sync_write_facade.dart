import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/daos/outbox_dao.dart';
import 'package:learning_tracker/core/database/daos/points_balance_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/logging/logger.dart';
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
///
/// **AUD-core-sync-10:** [resolveProfileId] is a resolver, not a captured
/// value, so every method reads the CURRENT active profile at call time
/// instead of the profile that was active when this facade was constructed.
/// A long-lived caller (e.g. `syncOrchestratorProvider`'s keepAlive
/// singleton, which wires one facade instance for the whole session and
/// survives profile switches without rebuilding — see that file's R1
/// comment) would otherwise stamp every outbox row for a NEWLY-active
/// profile with the STALE boot-time profile id, silently orphaning that
/// data (the drain only sweeps the active profile + account-level 0).
class OutboxSyncWriteFacade implements SyncWriteFacade, PointsSyncSink {
  OutboxSyncWriteFacade({
    required OutboxDao outboxDao,
    required UserDatabase database,
    required int Function() resolveProfileId,
    required LocalDayClock clock,
    Future<void> Function()? onEnqueueDrain,
    // AUD-sync-03 (EH-3): optional so tests can build the facade without
    // wiring a logger, mirroring LocalDataUploadService's `logger:` param.
    // Production providers pass AppLogger.instance so a swallowed drain-tee
    // failure (permission-denied, UnmountedRefException, network error) is
    // no longer discarded with zero trace.
    AppLogger? logger,
    // AUD-sync-05 (SM-7): optional so tests can substitute a fake
    // [RewardMilestoneService] without also faking the whole Drift database
    // it reads, mirroring the `logger:` seam above. The factory takes just
    // the profile id (not the whole service) because — per AUD-core-sync-10
    // — the profile id is resolved live per call, not captured at
    // construction time; a fixed service instance would go stale across a
    // profile switch on this long-lived facade.
    RewardMilestoneService Function(int profileId)?
    rewardMilestoneServiceFactory,
  }) : _dao = outboxDao,
       _database = database,
       _resolveProfileId = resolveProfileId,
       _clock = clock,
       _onEnqueueDrain = onEnqueueDrain,
       _logger = logger,
       _rewardMilestoneServiceFactory =
           rewardMilestoneServiceFactory ??
           ((profileId) =>
               RewardMilestoneService(database, profileId: profileId));

  final OutboxDao _dao;
  final UserDatabase _database;

  /// AUD-core-sync-10: resolved live at each call site — never cached — so a
  /// profile switch on a long-lived facade instance is picked up immediately.
  final int Function() _resolveProfileId;
  final LocalDayClock _clock;
  final AppLogger? _logger;
  final RewardMilestoneService Function(int profileId)
  _rewardMilestoneServiceFactory;

  /// Phase 1 — write-tee callback. The facade fires this fire-and-forget at
  /// the end of every [_enqueue] so a write reaches Firestore in the same
  /// network round as the local commit (best-case 1-RTT). Optional so tests
  /// can build the facade without a processor; the production provider passes
  /// a closure that calls `outboxProcessor.drain(profileId)`.
  final Future<void> Function()? _onEnqueueDrain;

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
    profile['profile_id']?.toString() ?? _resolveProfileId().toString(),
    profile,
  );

  @override
  Future<void> deleteLearnerProfile(String profileUlid) => _enqueue(
    OutboxEntityKind.learnerProfileDelete,
    profileUlid,
    {'profile_id': profileUlid},
    // Account-level op: enqueue under profile 0 (the account-level sweep that
    // _doDrain always runs alongside the active profile), NOT under the
    // profile being deleted. Stamping it with the target profile id orphans
    // the row — the drain only sweeps the ACTIVE profile + 0, so a delete
    // enqueued while that profile is active is never drained once the user
    // switches away (it never will be, since it's being deleted). The CF
    // still targets payload['profile_id'], so the correct profile is deleted.
    outboxProfileId: 0,
  );

  /// Build the gamification snapshot map from local DB + [RewardMilestoneService].
  ///
  /// Extracted so [TutoredWriteRouter] can call this to get the payload before
  /// forwarding it to the matching tutorUpdateGamificationSettings CF without
  /// re-enqueuing to the outbox (which the tutored-profile guard would drop).
  Future<Map<String, dynamic>> buildGamificationSnapshot() async {
    final now = _clock.nowUtc();
    // AUD-core-sync-10: resolve once per call so the queried data and the
    // outbox row this snapshot is later enqueued under (via _enqueue's own
    // live resolve) agree on the same profile.
    final profileId = _resolveProfileId();

    final pointRows = await (_database.select(
      _database.pointConfigs,
    )..where((t) => t.profileId.equals(profileId))).get();

    final rewardService = _rewardMilestoneServiceFactory(profileId);
    final rewardPayload = await rewardService.exportCloudPayload();

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

    return <String, dynamic>{
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

  /// Build the gamification snapshot from local DB + [RewardMilestoneService]
  /// and enqueue it for push.
  ///
  /// Sets the local `gamification_settings_updated_at_ms_p$profileId`
  /// SharedPreferences timestamp before enqueuing (matches [SyncEngine]
  /// behaviour so LWW checks stay consistent).
  @override
  Future<void> pushGamificationSettingsSnapshot() async {
    final now = _clock.nowUtc();
    final profileId = _resolveProfileId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      '$_gamificationUpdatedAtMsKeyPrefix$profileId',
      now.millisecondsSinceEpoch,
    );

    final payload = await buildGamificationSnapshot();

    await _enqueue(
      OutboxEntityKind.gamificationSettings,
      'gamification_settings_$profileId',
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
    final profileId = _resolveProfileId();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      ProfileScopedPreferenceKeys.uiPreferencesUpdatedAtMs(profileId),
      now.millisecondsSinceEpoch,
    );

    final payload = <String, dynamic>{
      'schema_version': 2,
      'profile_id': profileId,
      'updated_at': now.toIso8601String(),
      'app_locale': ProfileScopedPreferenceKeys.readAppLocale(prefs, profileId),
      'use_hebrew_calendar': ProfileScopedPreferenceKeys.readUseHebrewCalendar(
        prefs,
        profileId,
      ),
      'text_display': {
        'font_size_index': ProfileScopedPreferenceKeys.readFontSizeIndex(
          prefs,
          profileId,
        ),
        'show_nikud': ProfileScopedPreferenceKeys.readShowNikud(
          prefs,
          profileId,
        ),
      },
      'learning_order_parent_controls':
          ProfileScopedPreferenceKeys.readLearningOrderParentControls(
            prefs,
            profileId,
          ),
      'hebrew_terms_script': ProfileScopedPreferenceKeys.readHebrewTermsScript(
        prefs,
        profileId,
      ),
    };

    // DEC-26 (WS6) — location is Device-scoped. Sacred-time prefs
    // (lat/lon/country/city/in-israel) are stored locally in device-global
    // SharedPreferences keys and are NOT embedded in the per-profile
    // ui_preferences document. Syncing them per-profile caused LWW clobber
    // across profiles on the same device: whichever profile pushed last would
    // overwrite the shared device location on every other profile's merge.
    // The local read path (SacredTimePreferences) is already device-global
    // and remains unchanged. Location has no cloud sync path — it is
    // re-detected or manually set on each device.
    await _enqueue(
      OutboxEntityKind.uiPreferences,
      'ui_preferences_$profileId',
      payload,
    );
  }

  // ── helpers ─────────────────────────────────────────────────────────────────

  Future<void> _enqueue(
    String kind,
    String entityKey,
    Map<String, dynamic> payload, {
    // Outbox row's profile_id. Defaults to the active profile; pass 0 for
    // account-level operations that must drain regardless of which profile is
    // active (the processor's _doDrain sweeps the active profile AND 0).
    int? outboxProfileId,
  }) async {
    // AUD-core-sync-10: resolved live, at enqueue time, not captured at
    // facade-construction time — see the class doc.
    await _dao.insertOutboxRow(
      OutboxCompanion(
        profileId: Value(outboxProfileId ?? _resolveProfileId()),
        entityKind: Value(kind),
        entityKey: Value(entityKey),
        payload: Value(jsonEncode(payload)),
        createdAt: Value(_clock.nowUtc()),
      ),
    );
    // Phase 1 (trigger 1) — write-tee: kick the outbox processor after every
    // enqueue. Fire-and-forget so the caller's local commit returns straight
    // away; the OutboxProcessor owns the single-flight guard so concurrent
    // tees collapse to one push round. A throw in the drain must not bubble
    // back to the enqueue caller — the row is already durable in Drift so a
    // subsequent trigger (periodic, pull-complete) will retry it.
    _kickDrainTee(kind);
  }

  /// DB-3 (AUD-sync-02): batch-insert several outbox rows of the SAME entity
  /// [kind] via one Drift `batch()`/`insertAll` call instead of a loop of
  /// individually-awaited [_enqueue] calls, and fire at most ONE drain-kick
  /// for the whole batch (not one per row). Used by bulk callers (e.g.
  /// [LocalDataUploadService.pushAllLocalData]) whose per-row loop would
  /// otherwise re-prepare the same INSERT statement N times and fire N
  /// concurrent drain-kick Futures for a single logical operation.
  ///
  /// A no-op when [items] is empty (matches [_enqueue]'s callers, which
  /// never call it for an empty payload either).
  Future<void> _enqueueBatch(
    String kind,
    List<({String entityKey, Map<String, dynamic> payload})> items, {
    // See [_enqueue]'s matching parameter.
    int? outboxProfileId,
  }) async {
    if (items.isEmpty) return;
    // AUD-core-sync-10: resolved live, once for this whole batch — every row
    // in a single batch call is for the same logical bulk operation, so
    // resolving once (rather than per-item) is correct and avoids N redundant
    // resolver calls.
    final profileId = outboxProfileId ?? _resolveProfileId();
    final now = _clock.nowUtc();
    final companions = items
        .map(
          (item) => OutboxCompanion(
            profileId: Value(profileId),
            entityKind: Value(kind),
            entityKey: Value(item.entityKey),
            payload: Value(jsonEncode(item.payload)),
            createdAt: Value(now),
          ),
        )
        .toList(growable: false);
    await _database.batch((batch) {
      _dao.batchInsertOutboxRows(batch, companions);
    });
    _kickDrainTee(kind);
  }

  /// Fire-and-forget write-tee drain-kick shared by [_enqueue] and
  /// [_enqueueBatch]. See the call sites for the fire-and-forget rationale.
  ///
  /// AUD-sync-03 (EH-3): the failure must still be observable — this used
  /// to be a log-less `catchError((Object _) {})` that discarded every
  /// drain-tee exception (permission-denied, UnmountedRefException,
  /// network error) with zero trace, and this class had no AppLogger field
  /// to log through even if it wanted to.
  void _kickDrainTee(String kind) {
    final tee = _onEnqueueDrain;
    if (tee == null) return;
    unawaited(
      tee().catchError((Object e, StackTrace st) {
        _logger?.warning(
          event: LogEvents.sync.outboxEnqueueDrainTeeFailed,
          fields: {'entity_kind': kind},
          exception: e,
          stackTrace: st,
        );
      }),
    );
  }

  /// Derive a stable entity key from a payload by concatenating a few
  /// discriminating fields.  Falls back to a timestamp suffix when neither
  /// `id`, `curriculum_id`, nor `track_id` is present so that the outbox
  /// never silently drops rows.
  ///
  /// **Bookmark payloads** carry neither `track_id` nor a track type — one
  /// track per curriculum means `curriculum_id` alone is the natural key,
  /// mirroring the gateway's deterministic bookmark doc-id.
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
    final curriculum =
        goal['curriculumId']?.toString() ??
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

  Future<void> enqueueNotificationSettings(Map<String, dynamic> payload) =>
      _enqueue(
        OutboxEntityKind.notificationSettings,
        'notification_settings_${_resolveProfileId()}',
        payload,
      );

  Future<void> enqueueProfileProgram(Map<String, dynamic> payload) => _enqueue(
    OutboxEntityKind.profileProgram,
    '${payload['curriculum_id'] ?? ''}_${payload['program_id'] ?? ''}',
    payload,
  );

  Future<void> enqueueStreakPayload(Map<String, dynamic> payload) => _enqueue(
    OutboxEntityKind.streak,
    'streak_${_resolveProfileId()}',
    payload,
  );

  Future<void> enqueueLedgerEntry(Map<String, dynamic> payload) => _enqueue(
    OutboxEntityKind.learningLedgerEntry,
    // W3.18/W3.19: entity key uses snake_case field; accept camelCase as
    // a fallback for any legacy calls that have not yet been updated.
    payload['unit_identifier']?.toString() ??
        payload['unitIdentifier']?.toString() ??
        DateTimeFactory.nowUtc().millisecondsSinceEpoch.toString(),
    payload,
  );

  // ── DB-3 (AUD-sync-02) batch variants for LocalDataUploadService ───────────
  //
  // pushAllLocalData is a one-time bulk reconciler that can enqueue hundreds
  // of rows per entity kind. Each batch* method below enqueues its whole list
  // via ONE Drift batch()/insertAll call (through _enqueueBatch) instead of a
  // loop of individually-awaited enqueue calls, and fires at most one
  // drain-kick per kind instead of one per row. Each mirrors the entityKey
  // derivation of its singular sibling exactly, so behaviour (Firestore doc
  // id / outbox dedup semantics) is unchanged — only the write shape is.

  /// Batch variant of [pushLearnerProfile].
  Future<void> enqueueLearnerProfilesBatch(
    List<Map<String, dynamic>> profiles,
  ) => _enqueueBatch(
    OutboxEntityKind.learnerProfile,
    profiles
        .map(
          (p) => (
            entityKey:
                p['profile_id']?.toString() ?? _resolveProfileId().toString(),
            payload: p,
          ),
        )
        .toList(growable: false),
  );

  /// Batch variant of [pushBookmark].
  Future<void> enqueueBookmarksBatch(List<Map<String, dynamic>> bookmarks) =>
      _enqueueBatch(
        OutboxEntityKind.bookmark,
        bookmarks
            .map((b) => (entityKey: _key(b), payload: b))
            .toList(growable: false),
      );

  /// Batch variant of [pushGoal].
  Future<void> enqueueGoalsBatch(List<Map<String, dynamic>> goals) =>
      _enqueueBatch(
        OutboxEntityKind.goal,
        goals
            .map((g) => (entityKey: _goalKey(g), payload: g))
            .toList(growable: false),
      );

  /// Batch variant of [enqueueProfileProgram].
  Future<void> enqueueProfileProgramsBatch(
    List<Map<String, dynamic>> payloads,
  ) => _enqueueBatch(
    OutboxEntityKind.profileProgram,
    payloads
        .map(
          (p) => (
            entityKey: '${p['curriculum_id'] ?? ''}_${p['program_id'] ?? ''}',
            payload: p,
          ),
        )
        .toList(growable: false),
  );

  /// Batch variant of [enqueueStreakPayload].
  Future<void> enqueueStreakPayloadsBatch(
    List<Map<String, dynamic>> payloads,
  ) => _enqueueBatch(
    OutboxEntityKind.streak,
    payloads
        .map((p) => (entityKey: 'streak_${_resolveProfileId()}', payload: p))
        .toList(growable: false),
  );

  /// Batch variant of [enqueueLedgerEntry].
  Future<void> enqueueLedgerEntriesBatch(List<Map<String, dynamic>> payloads) =>
      _enqueueBatch(
        OutboxEntityKind.learningLedgerEntry,
        payloads
            .map(
              (p) => (
                entityKey:
                    p['unit_identifier']?.toString() ??
                    p['unitIdentifier']?.toString() ??
                    DateTimeFactory.nowUtc().millisecondsSinceEpoch.toString(),
                payload: p,
              ),
            )
            .toList(growable: false),
      );

  /// Batch variant of [pushCurriculumTrack].
  Future<void> pushCurriculumTracksBatch(List<Map<String, dynamic>> tracks) =>
      _enqueueBatch(
        OutboxEntityKind.track,
        tracks
            .map((t) => (entityKey: _key(t), payload: t))
            .toList(growable: false),
      );

  /// Plan §F Phase 5 deliverable 6 — push a stage-definition snapshot via the
  /// dedicated `stage_definition` outbox kind.
  ///
  /// Replaces the historical `pushSettings`-piggyback route (kind=`settings`)
  /// for stage-definition payloads. Each call enqueues one row per stage —
  /// the OutboxProcessor dispatches via `PushPipeline.pushStageDefinition`,
  /// which writes a deterministic doc id of `{trackId}_{stageOrder}`.
  ///
  /// [trackId] and [stages] are passed explicitly so this helper does not
  /// need to crack open `pushSettings`'s aggregate-snapshot payload — each
  /// stage row carries its own `track_id` + `stage_order` for the gateway.
  @override
  Future<void> pushStageDefinitions({
    required int trackId,
    required String curriculumId,
    required List<Map<String, dynamic>> stages,
    required DateTime updatedAt,
  }) async {
    final updatedAtIso = updatedAt.toIso8601String();
    for (final stage in stages) {
      final stageOrder = stage['stage_order']?.toString() ?? '';
      final payload = <String, dynamic>{
        ...stage,
        'track_id': trackId,
        'curriculum_id': curriculumId,
        'updated_at': updatedAtIso,
      };
      await _enqueue(
        OutboxEntityKind.stageDefinition,
        '${trackId}_$stageOrder',
        payload,
      );
    }
  }

  /// Plan §F Phase 1 — study-day config enrolment.
  ///
  /// Entity key is `${curriculum_id}_${day_of_week}_${track_id}` so repeated
  /// enqueues of the same (curriculum, day, track) collapse to one Firestore
  /// document — matching the per-row PK on `study_day_configs`.
  Future<void> enqueueStudyDayConfig(Map<String, dynamic> payload) {
    final curriculumId = payload['curriculum_id']?.toString() ?? '';
    final dayOfWeek = payload['day_of_week']?.toString() ?? '';
    final trackId = payload['track_id']?.toString() ?? '';
    final entityKey = '${curriculumId}_${dayOfWeek}_$trackId';
    return _enqueue(OutboxEntityKind.studyDayConfig, entityKey, payload);
  }

  @override
  Future<void> pushStudyDayConfig(Map<String, dynamic> payload) =>
      enqueueStudyDayConfig(payload);

  /// Own-profile code never deletes individual completions — this method exists
  /// only so TutoredWriteRouter can call it on the delegate in non-tutored mode.
  /// In practice the router intercepts the call before delegation.
  @override
  Future<void> deleteCompletion(String completionId) async {}

  @override
  Future<void> pushProfileProgram(Map<String, dynamic> payload) =>
      enqueueProfileProgram(payload);

  // ── WS9 Wave-B (C#2) — points spend economy (PointsSyncSink) ────────────────

  /// D14: kick the outbox processor so points-ledger rows the DAO enqueued
  /// inside its own transaction are pushed promptly. Reuses the same drain tee
  /// every [_enqueue] fires; best-effort (the facade swallows drain failures).
  @override
  Future<void> requestSyncDrain() async {
    final tee = _onEnqueueDrain;
    if (tee != null) await tee();
  }

  @override
  Future<void> enqueueRewardRedemption(Map<String, dynamic> payload) =>
      _enqueue(
        OutboxEntityKind.rewardRedemption,
        payload['ulid']?.toString() ??
            DateTimeFactory.nowUtc().millisecondsSinceEpoch.toString(),
        payload,
      );
}
