import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
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
class DriftMergeStore implements MergeStore {
  DriftMergeStore(UserDatabase db) : _db = db;

  final UserDatabase _db;

  // ── currentUpdatedAt ────────────────────────────────────────────────────────

  @override
  Future<DateTime?> currentUpdatedAt({
    required String kind,
    required int profileId,
    required String naturalKey,
  }) async {
    switch (kind) {
      case EntityKind.learnerProfile:
        final id = int.tryParse(naturalKey);
        if (id == null) return null;
        final row = await _db.profileDao.getProfileById(id);
        return row?.updatedAt;

      case EntityKind.trackConfig:
        final parts = naturalKey.split('|');
        if (parts.length != 2) return null;
        final curriculumId = parts[0];
        final trackType = parts[1];
        final row =
            await (_db.select(_db.curriculumTracks)..where(
                  (t) =>
                      t.profileId.equals(profileId) &
                      t.curriculumId.equals(curriculumId) &
                      t.trackType.equals(trackType),
                ))
                .getSingleOrNull();
        // Track uses activatedAt as its LWW timestamp (most recent state change).
        if (row == null) return null;
        final deactivated = row.deactivatedAt;
        return (deactivated != null && deactivated.isAfter(row.activatedAt))
            ? deactivated
            : row.activatedAt;

      case EntityKind.bookmark:
        // Natural key for bookmarks: "curriculum_id|track_type"
        // Bookmarks are keyed by trackId in the DB but track_type in Firestore.
        // Since we cannot look up by track_type without a full trackDao scan,
        // return null here to let the remote win on first sync (safe: LWW).
        // A future migration can persist track_type on the bookmarks table.
        return null;

      case EntityKind.settings:
        // Settings updatedAt is stored in SharedPreferences by SyncEngine
        // (_settingsTimestampKey). DriftMergeStore cannot read SharedPreferences.
        // Return null — the SettingsMerger handles LWW at the merger level.
        return null;

      case EntityKind.stageDefinition:
        // Natural key: "curriculum_id|track_id|stage_order"
        final parts = naturalKey.split('|');
        if (parts.length != 3) return null;
        final curriculumId = parts[0];
        final trackId = int.tryParse(parts[1]);
        final stageOrder = int.tryParse(parts[2]);
        if (trackId == null || stageOrder == null) return null;
        final row =
            await (_db.select(_db.stageDefinitions)..where(
                  (t) =>
                      t.profileId.equals(profileId) &
                      t.curriculumId.equals(curriculumId) &
                      t.trackId.equals(trackId) &
                      t.stageOrder.equals(stageOrder),
                ))
                .getSingleOrNull();
        // StageDefinitions don't have an updatedAt column — return null to let
        // the merger-level LWW (from updated_at in the enclosing settings doc)
        // make the decision. The StageDefinitionMerger checks the row's
        // updated_at field which comes from the enclosing settings document.
        if (row != null) return null;
        return null;

      default:
        return null;
    }
  }

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
      return; // Skip malformed rows.
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
    final trackType = fields['track_type'] as String?;
    if (curriculumId == null || trackType == null) return;

    final isActive = fields['is_active'] as bool? ?? true;
    final activatedAt = _parseDateTime(fields['activated_at']);
    if (activatedAt == null) return;
    final deactivatedAt = _parseDateTime(fields['deactivated_at']);
    final paceResetDate = _parseDateTime(fields['pace_reset_date']);

    final existing =
        await (_db.select(_db.curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId) &
                  t.trackType.equals(trackType),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await _db
          .into(_db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              trackType: trackType,
              isActive: Value(isActive),
              activatedAt: activatedAt,
              deactivatedAt: Value(deactivatedAt),
              paceResetDate: Value(paceResetDate),
            ),
          );
    } else {
      await (_db.update(
        _db.curriculumTracks,
      )..where((t) => t.id.equals(existing.id))).write(
        CurriculumTracksCompanion(
          isActive: Value(isActive),
          activatedAt: Value(activatedAt),
          deactivatedAt: Value(deactivatedAt),
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
      return;
    }

    // Bookmarks in the DB are keyed by trackId (FK), not track_type string.
    // Find the track row to get the trackId.
    final track =
        await (_db.select(_db.curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId) &
                  t.trackType.equals(trackType),
            ))
            .getSingleOrNull();

    if (track == null) {
      // Track not yet synced — skip the bookmark; it will re-arrive when
      // the listener fires after the track is synced.
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
    if (curriculumId == null) return;

    final stagesList = fields['stages'] as List<dynamic>?;
    if (stagesList == null || stagesList.isEmpty) return;

    final defaultTrackId = fields['track_id'] as int? ?? 0;

    final companions = stagesList.cast<Map<String, dynamic>>().map((s) {
      final trackId = s['track_id'] as int? ?? defaultTrackId;
      final stageOrder = s['stage_order'] as int? ?? 0;
      final stageName = s['stage_name'] as String? ?? '';
      final delayDays = s['delay_days'] as int? ?? 0;
      final isDefault = s['is_default'] as bool? ?? false;
      final scheduleType = s['schedule_type'] as String? ?? 'delay';
      final daysOfWeek = s['days_of_week'] as String?;
      final rollingWindowSize = s['rolling_window_size'] as int?;

      return StageDefinitionsCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId,
        trackId: trackId,
        stageOrder: stageOrder,
        stageName: stageName,
        delayDays: delayDays,
        isDefault: Value(isDefault),
        scheduleType: Value(scheduleType),
        daysOfWeek: Value(daysOfWeek),
        rollingWindowSize: Value(rollingWindowSize),
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
    final delayDays =
        fields['delay_days'] as int? ??
        int.tryParse(fields['delay_days']?.toString() ?? '') ??
        0;

    if (curriculumId == null || trackId == null || stageOrder == null) return;

    final isDefault = fields['is_default'] as bool? ?? false;
    final scheduleType = fields['schedule_type'] as String? ?? 'delay';
    final daysOfWeek = fields['days_of_week'] as String?;
    final rollingWindowSize =
        fields['rolling_window_size'] as int? ??
        int.tryParse(fields['rolling_window_size']?.toString() ?? '');

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
          delayDays: delayDays,
          isDefault: Value(isDefault),
          scheduleType: Value(scheduleType),
          daysOfWeek: Value(daysOfWeek),
          rollingWindowSize: Value(rollingWindowSize),
        ),
      );
    } else {
      await (_db.update(
        _db.stageDefinitions,
      )..where((t) => t.id.equals(existing.id))).write(
        StageDefinitionsCompanion(
          stageName: Value(stageName),
          delayDays: Value(delayDays),
          isDefault: Value(isDefault),
          scheduleType: Value(scheduleType),
          daysOfWeek: Value(daysOfWeek),
          rollingWindowSize: Value(rollingWindowSize),
        ),
      );
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

  // ── Shared parse helpers ────────────────────────────────────────────────────

  static DateTime? _parseDateTime(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) {
      return DateTime.fromMillisecondsSinceEpoch(raw * 1000, isUtc: true);
    }
    if (raw is Map) {
      final s = raw['seconds'];
      if (s is int) {
        return DateTime.fromMillisecondsSinceEpoch(s * 1000, isUtc: true);
      }
    }
    return null;
  }
}
