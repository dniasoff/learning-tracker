import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/log_events.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

/// Concrete [MergeStore] implementation backed by Drift DAOs.
///
/// Dispatches each [MergeStore] operation to the appropriate DAO for the
/// given [EntityKind]. The DAO is responsible for the final SQLite write
/// so no Firestore types leak into this layer.
///
/// Kind → DAO mapping:
///   completion      → [CompletionEventDao]      (insertOrIgnore on natural key)
///   learner_profile → [ProfileDao]               (upsert by id)
///   track_config    → [TrackDao]                 (upsert by curriculum_id + track_type)
///   bookmark        → [BookmarkDao]              (upsert by curriculum_id + track_id)
///   settings        → [StageDao]                 (replace stages for curriculum)
///   stage_definition → [StageDao]               (upsert by curriculum_id + track_id + stage_order)
///   streak          → not routed here — [StreakEventMerger] uses [StreakEventLog] directly
///
/// Phase 3 of the sync architecture plan adds LWW symmetry: every merger
/// calls [persistUpdatedAt] after a successful apply, and [currentUpdatedAt]
/// reads back from the [SyncKv] table so [remoteIsNewer] is symmetric.
/// Within a ±5 s clock-skew window, [remoteIsNewer] falls back to the
/// Firestore server timestamp (`synced_at`) to break ties.
class DriftMergeStore implements MergeStore {
  /// Clock-skew window for the [remoteIsNewer] tie-breaker. When two
  /// devices' clocks differ by less than this, the server timestamp
  /// (`synced_at`) decides instead of the strict `remote > local`
  /// comparison on the client `updated_at`.
  static const Duration clockSkewTieBreakWindow = Duration(seconds: 5);
  DriftMergeStore(UserDatabase db, {AnalyticsService? analytics})
    : _db = db,
      _analytics = analytics;

  final UserDatabase _db;
  // W7.5: optional analytics — fires merge_row_skipped at every silent-skip site.
  final AnalyticsService? _analytics;

  // ── W7.5 telemetry helper ───────────────────────────────────────────────────

  /// Fire [LogEvents.sync.mergeRowSkipped] on the injected analytics service.
  ///
  /// Silent skips occur when a Firestore row arrives malformed (missing
  /// required fields) or when a dependency is missing (e.g. bookmark arrives
  /// before its track). Each skip call closes the L2 gap — these were
  /// previously invisible in dashboards.
  void _fireSkipped({required String kind, required String reason}) {
    final future = _analytics?.logEvent(
      LogEvents.sync.mergeRowSkipped,
      parameters: {'entity_kind': kind, 'reason': reason},
    );
    if (future != null) unawaited(future);
  }

  // ── currentUpdatedAt ────────────────────────────────────────────────────────

  /// Returns the persisted last-applied `updated_at` for `(kind, naturalKey)`.
  ///
  /// Phase 3: every LWW kind reads from the [SyncKv] table. The persisted
  /// value is written by [persistUpdatedAt] inside every merger's
  /// successful-apply branch. When no value has been recorded yet, returns
  /// `null` (callers treat that as "remote wins on first sync").
  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) {
    return _db.syncKvDao.get(kind, _scopedKey(profileId, naturalKey));
  }

  /// Returns the persisted Firestore `synced_at` server timestamp for
  /// `(kind, naturalKey)`. Used as the tie-breaker by [remoteIsNewer]
  /// inside the ±5 s clock-skew window.
  @override
  Future<DateTime?> currentSyncedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) {
    return _db.syncKvDao.getSyncedAt(kind, _scopedKey(profileId, naturalKey));
  }

  /// Persist the remote `updated_at` (and optional Firestore `synced_at`)
  /// for `(kind, naturalKey)`. Called by every LWW merger after a
  /// successful [upsert].
  @override
  Future<void> persistUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
    required DateTime updatedAt,
    DateTime? syncedAt,
  }) {
    return _db.syncKvDao.upsert(
      kind,
      _scopedKey(profileId, naturalKey),
      updatedAt,
      syncedAt: syncedAt,
    );
  }

  /// Phase-3 LWW gate. See [MergeStore.remoteIsNewer] for the rule order.
  @override
  bool remoteIsNewer({
    required DateTime? localUpdatedAt,
    required DateTime? remoteUpdatedAt,
    DateTime? localSyncedAt,
    DateTime? remoteSyncedAt,
  }) {
    if (remoteUpdatedAt == null) return false;
    if (localUpdatedAt == null) return true;

    final localUtc = localUpdatedAt.toUtc();
    final remoteUtc = remoteUpdatedAt.toUtc();
    final diff = remoteUtc.difference(localUtc).abs();

    // Outside the clock-skew window: strict `remote > local` wins; ties go
    // to local (matches the long-standing flapping-free behaviour).
    if (diff > clockSkewTieBreakWindow) {
      return remoteUtc.isAfter(localUtc);
    }

    // Inside the window: fall back to the Firestore server timestamp.
    if (remoteSyncedAt != null && localSyncedAt != null) {
      if (remoteSyncedAt.isAfter(localSyncedAt)) return true;
      if (localSyncedAt.isAfter(remoteSyncedAt)) return false;
      // Equal synced_at — fall through to the "prefer remote" default.
    }

    // Tie within the window with no usable server timestamp on at least one
    // side → prefer remote (it has authoritatively reached the server;
    // preserves convergence).
    //
    // The one true tie (local == remote with no server-timestamp signal) is
    // resolved by preferring remote so two devices that wrote the same
    // value at the same instant converge instead of bouncing.
    return true;
  }

  /// Compose the per-profile [SyncKv] entity key from [profileId] and the
  /// merger's per-kind natural key.
  ///
  /// The `(kind, entityKey)` primary key in [SyncKv] is global to the DB,
  /// not scoped per profile. Prefixing the natural key with `profileId|`
  /// keeps profiles isolated without adding a third column.
  static String _scopedKey(int profileId, String naturalKey) =>
      '$profileId|$naturalKey';

  // ── upsert ──────────────────────────────────────────────────────────────────

  @override
  Future<void> upsert({
    required String kind,
    required int profileId,
    required Map<String, dynamic> fields,
  }) async {
    switch (kind) {
      case EntityKind.learnerProfile:
        await _upsertLearnerProfile(profileId, fields);

      case EntityKind.trackConfig:
        await _upsertTrack(profileId, fields);

      case EntityKind.bookmark:
        await _upsertBookmark(profileId, fields);

      case EntityKind.settings:
        // Settings upsert = replace all stage definitions for the curriculum.
        await _upsertSettings(profileId, fields);

      case EntityKind.stageDefinition:
        await _upsertStageDefinition(profileId, fields);

      case EntityKind.profileProgram:
        await _upsertProfileProgram(profileId, fields);

      case EntityKind.learningOrder:
        await _upsertLearningOrder(profileId, fields);

      default:
        // Unknown kind — no-op (the MergeRouter has already validated the kind).
        break;
    }
  }

  // ── insertIfAbsent ──────────────────────────────────────────────────────────

  @override
  Future<void> insertIfAbsent({
    required String kind,
    required int profileId,
    required String naturalKey,
    required Map<String, dynamic> fields,
  }) async {
    if (kind == EntityKind.completion) {
      await _insertCompletionIfAbsent(profileId, fields);
    }
    // Other kinds use upsert — insertIfAbsent is only meaningful for event logs.
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  Future<void> _insertCompletionIfAbsent(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final sefariaRef = fields['sefaria_ref'] as String?;
    final stageId =
        fields['stage_id'] as int? ??
        int.tryParse(fields['stage_id']?.toString() ?? '');
    final trackType = fields['track_type'] as String?;
    final eventTs = _parseDateTime(
      fields['completed_at'] ?? fields['event_timestamp'],
    );

    if (curriculumId == null ||
        sefariaRef == null ||
        stageId == null ||
        trackType == null ||
        eventTs == null) {
      // W7.5: fire telemetry for every silently-skipped completion row.
      _fireSkipped(kind: EntityKind.completion, reason: 'malformed_fields');
      return;
    }

    // H2: before inserting, check whether a tombstoned row already occupies
    // this natural key. If so, the remote is "more alive" than local — clear
    // the tombstone instead of inserting (INSERT OR IGNORE would silently
    // no-op and leave the tombstone in place).
    final tombstoned = await _db.completionEventDao
        .findTombstonedEventByNaturalKey(
          profileId: profileId,
          curriculumId: curriculumId,
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          eventTimestamp: eventTs,
        );
    if (tombstoned != null) {
      await _db.completionEventDao.clearTombstone(tombstoned.id);
      return;
    }

    await _db.completionEventDao.appendEvent(
      CompletionEventsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
        eventTimestamp: eventTs,
      ),
    );
  }

  Future<void> _upsertLearnerProfile(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final remoteId =
        fields['profile_id'] as int? ??
        int.tryParse(fields['profile_id']?.toString() ?? '') ??
        profileId;
    final accountId =
        fields['account_id'] as int? ??
        int.tryParse(fields['account_id']?.toString() ?? '') ??
        0;
    final displayName = fields['display_name'] as String? ?? '';
    final mode = fields['mode'] as String? ?? 'adult';
    final avatarIndex =
        fields['avatar_index'] as int? ??
        int.tryParse(fields['avatar_index']?.toString() ?? '') ??
        0;
    final updatedAt =
        _parseDateTime(fields['updated_at']) ?? DateTimeFactory.nowUtc();
    final createdAt = _parseDateTime(fields['created_at']) ?? updatedAt;

    final existing = await _db.profileDao.getProfileById(remoteId);
    if (existing == null) {
      await _db
          .into(_db.learnerProfiles)
          .insertOnConflictUpdate(
            LearnerProfilesCompanion.insert(
              id: Value(remoteId),
              accountId: accountId,
              displayName: displayName,
              mode: mode,
              avatarIndex: Value(avatarIndex),
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
          );
    } else {
      await (_db.update(
        _db.learnerProfiles,
      )..where((t) => t.id.equals(remoteId))).write(
        LearnerProfilesCompanion(
          displayName: Value(displayName),
          mode: Value(mode),
          avatarIndex: Value(avatarIndex),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }

  Future<void> _upsertTrack(int profileId, Map<String, dynamic> fields) async {
    final curriculumId = fields['curriculum_id'] as String?;
    if (curriculumId == null) {
      // W7.5
      _fireSkipped(
        kind: EntityKind.trackConfig,
        reason: 'missing_curriculum_id',
      );
      return;
    }

    // W3.22: trackType dropped. W3.28: use state enum.
    final state =
        fields['state'] as String? ??
        ((fields['is_active'] as bool? ?? true)
            ? 'active'
            : 'retired'); // back-compat shim
    final activatedAt = _parseDateTime(fields['activated_at']);
    if (activatedAt == null) {
      // W7.5
      _fireSkipped(
        kind: EntityKind.trackConfig,
        reason: 'missing_activated_at',
      );
      return;
    }
    final stateChangedAt =
        _parseDateTime(fields['state_changed_at']) ??
        _parseDateTime(fields['deactivated_at']) ??
        activatedAt;
    final paceResetDate = _parseDateTime(fields['pace_reset_date']);

    final existing =
        await (_db.select(_db.curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              state: Value(state),
              stateChangedAt: stateChangedAt,
              activatedAt: activatedAt,
              paceResetDate: Value(paceResetDate),
            ),
          );
    } else {
      await (_db.update(
        _db.curriculumTracks,
      )..where((t) => t.id.equals(existing.id))).write(
        CurriculumTracksCompanion(
          state: Value(state),
          stateChangedAt: Value(stateChangedAt),
          activatedAt: Value(activatedAt),
          paceResetDate: Value(paceResetDate),
        ),
      );
    }
  }

  Future<void> _upsertBookmark(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final trackType = fields['track_type'] as String?;
    final sefariaRef = fields['sefaria_ref'] as String?;
    final updatedAt = _parseDateTime(fields['updated_at']);

    if (curriculumId == null ||
        trackType == null ||
        sefariaRef == null ||
        updatedAt == null) {
      // W7.5
      _fireSkipped(kind: EntityKind.bookmark, reason: 'malformed_fields');
      return;
    }

    // Bookmarks in the DB are keyed by trackId (FK).
    // W3.22: trackType dropped; UNIQUE is {profileId, curriculumId}.
    // Find the active track row to get the trackId.
    final track =
        await (_db.select(_db.curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId),
            ))
            .getSingleOrNull();

    if (track == null) {
      // Track not yet synced — skip the bookmark; it will re-arrive when
      // the listener fires after the track is synced.
      // W7.5: this is a non-malformed skip (dependency ordering), fire telemetry.
      _fireSkipped(kind: EntityKind.bookmark, reason: 'track_not_yet_synced');
      return;
    }

    await _db.bookmarkDao.upsertBookmarkByProfile(
      curriculumId: curriculumId,
      trackId: track.id,
      sefariaRef: sefariaRef,
      updatedAt: updatedAt,
      profileId: profileId,
    );
  }

  Future<void> _upsertSettings(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    // Settings document shape: { curriculum_id, track_id, stages: [...], updated_at }
    final curriculumId = fields['curriculum_id'] as String?;
    if (curriculumId == null) {
      // W7.5
      _fireSkipped(kind: EntityKind.settings, reason: 'missing_curriculum_id');
      return;
    }

    final stagesList = fields['stages'] as List<dynamic>?;
    if (stagesList == null || stagesList.isEmpty) {
      // W7.5: no stages to merge — likely a partial settings doc.
      _fireSkipped(kind: EntityKind.settings, reason: 'empty_stages_list');
      return;
    }

    final defaultTrackId = fields['track_id'] as int? ?? 0;

    final companions = stagesList.cast<Map<String, dynamic>>().map((s) {
      final trackId = s['track_id'] as int? ?? defaultTrackId;
      final stageOrder = s['stage_order'] as int? ?? 0;
      final stageName = s['stage_name'] as String? ?? '';
      final isDefault = s['is_default'] as bool? ?? false;
      // W3.27: prefer pre-encoded JSON schedule; fall back to quartet fields.
      final schedule = _encodeSchedule(s);
      final updatedAt =
          _parseDateTime(s['updated_at']) ?? DateTimeFactory.nowUtc();

      return StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        stageOrder: stageOrder,
        stageName: stageName,
        isDefault: Value(isDefault),
        schedule: Value(schedule),
        updatedAt: Value(updatedAt),
      );
    }).toList();

    await _db.stageDao.replaceStagesForCurriculum(curriculumId, companions);
  }

  Future<void> _upsertStageDefinition(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final trackId =
        fields['track_id'] as int? ??
        int.tryParse(fields['track_id']?.toString() ?? '');
    final stageOrder =
        fields['stage_order'] as int? ??
        int.tryParse(fields['stage_order']?.toString() ?? '');
    final stageName = fields['stage_name'] as String? ?? '';

    if (curriculumId == null || trackId == null || stageOrder == null) {
      // W7.5
      _fireSkipped(
        kind: EntityKind.stageDefinition,
        reason: 'missing_key_fields',
      );
      return;
    }

    final isDefault = fields['is_default'] as bool? ?? false;
    // W3.27: prefer pre-encoded JSON schedule; fall back to quartet fields.
    final schedule = _encodeSchedule(fields);
    final updatedAt =
        _parseDateTime(fields['updated_at']) ?? DateTimeFactory.nowUtc();

    final existing =
        await (_db.select(_db.stageDefinitions)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId) &
                  t.trackId.equals(trackId) &
                  t.stageOrder.equals(stageOrder),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await _db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          trackId: trackId,
          stageOrder: stageOrder,
          stageName: stageName,
          isDefault: Value(isDefault),
          schedule: Value(schedule),
          updatedAt: Value(updatedAt),
        ),
      );
    } else {
      await (_db.update(
        _db.stageDefinitions,
      )..where((t) => t.id.equals(existing.id))).write(
        StageDefinitionsCompanion(
          stageName: Value(stageName),
          isDefault: Value(isDefault),
          schedule: Value(schedule),
          updatedAt: Value(updatedAt),
        ),
      );
    }
  }

  /// Encode schedule spec from raw Firestore fields into the JSON column format.
  ///
  /// Accepts either a pre-encoded `schedule` JSON string (new shape, W3.27)
  /// or the legacy quartet (schedule_type, delay_days, days_of_week,
  /// rolling_window_size). Returns a JSON string compatible with ScheduleSpec.
  static String _encodeSchedule(Map<String, dynamic> s) {
    // New shape: schedule is already a JSON string or map.
    final raw = s['schedule'];
    if (raw is String && raw.isNotEmpty) return raw;
    if (raw is Map) {
      return jsonEncode(raw);
    }
    // Legacy quartet → JSON.
    final scheduleType = s['schedule_type'] as String? ?? 'delay';
    final delayDays = (s['delay_days'] as num?)?.toInt() ?? 0;
    final daysOfWeek = s['days_of_week'];
    final rollingWindowSize = s['rolling_window_size'] as int?;

    switch (scheduleType) {
      case 'days_of_week':
        List<int> days;
        if (daysOfWeek is String) {
          try {
            final decoded = jsonDecode(daysOfWeek);
            days = (decoded as List).cast<int>();
          } catch (_) {
            days = const [];
          }
        } else if (daysOfWeek is List) {
          days = daysOfWeek.cast<int>();
        } else {
          days = const [];
        }
        return jsonEncode({'type': 'days_of_week', 'days': days});
      case 'rolling_window':
        return jsonEncode({
          'type': 'rolling_window',
          'window_size': rollingWindowSize ?? 7,
        });
      default:
        return jsonEncode({'type': 'delay', 'delay_days': delayDays});
    }
  }

  Future<void> _upsertProfileProgram(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final rawProgramId = fields['program_id'];
    final programId = rawProgramId is int
        ? rawProgramId
        : int.tryParse(rawProgramId?.toString() ?? '');
    if (curriculumId == null || programId == null) return;

    final rawProfileId = fields['profile_id'];
    final resolvedProfileId = rawProfileId is int
        ? rawProfileId
        : int.tryParse(rawProfileId?.toString() ?? '') ?? profileId;

    final trackingStartDate = _parseDateTime(fields['tracking_start_date']);
    final trackingStartRef = fields['tracking_start_ref'] as String?;

    await _db.profileProgramDao.setProfileProgram(
      profileId: resolvedProfileId,
      curriculumType: curriculumId,
      programId: programId,
      trackingStartDate: trackingStartDate,
      trackingStartRef: trackingStartRef,
    );
  }

  Future<void> _upsertLearningOrder(
    int profileId,
    Map<String, dynamic> fields,
  ) async {
    final curriculumId = fields['curriculum_id'] as String?;
    final sefariaRef = fields['sefaria_ref'] as String?;
    final userSortOrder =
        fields['user_sort_order'] as int? ??
        int.tryParse(fields['user_sort_order']?.toString() ?? '');
    final updatedAt = _parseDateTime(fields['updated_at']);

    if (curriculumId == null || sefariaRef == null || userSortOrder == null) {
      // W7.5
      _fireSkipped(
        kind: EntityKind.learningOrder,
        reason: 'missing_key_fields',
      );
      return;
    }
    final ts = updatedAt ?? DateTimeFactory.nowUtc();

    await _db.learningOrderDao.upsertLearningOrderIfNewer(
      LearningOrderCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        userSortOrder: userSortOrder,
        updatedAt: Value(ts),
      ),
      updatedAt: ts,
    );
  }

  // ── Shared parse helpers ────────────────────────────────────────────────────

  /// Delegate to [FirestoreCodec.parseDateTime] — centralised timestamp
  /// parsing handles DateTime, String (ISO-8601), int (Unix seconds), and
  /// Map `{'seconds': int}` (Timestamp JSON).
  static DateTime? _parseDateTime(Object? raw) =>
      FirestoreCodec.parseDateTime(raw);
}
