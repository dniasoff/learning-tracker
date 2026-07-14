/// LWW merger for study-day config rows.
///
/// Natural key: `(curriculumId, dayOfWeek, trackId)` — the Drift PK minus
/// `profileId` (which is implicit in the per-profile Firestore subcollection
/// scope). `trackId` here is the REMOTE id (from the decoded row), not the
/// locally-resolved one, so the natural key stays stable across pulls even
/// when a tutored mirror rebinds the row to a different local track (Bug 3).
///
/// Phase 3: like every other LWW merger, the ordering decision goes through
/// [MergeStore.remoteIsNewer] (±5 s clock-skew window, Firestore
/// `synced_at` tie-break — see AUD-core-sync-03) instead of the plain
/// `remote.isAfter(local)` comparison, and a successful apply persists the
/// remote `updated_at`/`synced_at` via [MergeStore.persistUpdatedAt] so
/// subsequent pulls arbitrate symmetrically.
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/study_day_config_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/local_track_id_resolver.dart';

class StudyDayConfigMerger implements EntityMerger {
  StudyDayConfigMerger(
    UserDatabase db, {
    required MergeStore store,
    AppLogger? logger,
  }) : _db = db,
       _store = store,
       _logger = logger;

  final UserDatabase _db;
  final MergeStore _store;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;
  static const _codec = StudyDayConfigCodec();

  @override
  String get kind => EntityKind.studyDayConfig;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — a single malformed/throwing
      // row must never abort the whole page.
      try {
        final decoded = _codec.decode(row);
        if (decoded == null) continue;

        // Use the profile_id from the document only if it matches the active
        // profile scope — defensive: the subcollection path already binds the
        // document to this profile, so a payload claiming a different profile
        // is treated as malformed.
        final docProfileId = decoded.profileId == 0
            ? profileId
            : decoded.profileId;
        if (docProfileId != profileId) continue;

        // AUD-t-cross-43: study_day_configs.trackId is a FK into
        // curriculum_tracks. The stored track_id is the REMOTE id; under a
        // tutored mirror the track was re-inserted with a different local
        // autoincrement id, so the remote id never matches. Resolve the
        // LOCAL track by (profile, curriculum) via the shared helper and
        // bind the config to it (Bug 3). No-op for own-data sync.
        //
        // If the referenced track is not present locally yet (e.g. this listener
        // snapshot merged before the curriculum_tracks snapshot), inserting would
        // throw a FK-constraint violation that fails the ENTIRE study_day_configs
        // channel merge — which in turn triggers a dashboard rebuild storm. Skip
        // the row; the next full pull re-merges it (LWW, idempotent) once the
        // track exists.
        final trackId = await resolveLocalTrackId(
          _db,
          profileId: profileId,
          curriculumId: decoded.curriculumId,
        );
        if (trackId == null) continue;

        // Natural key is scoped by the REMOTE track id (decoded.trackId), not
        // the locally-resolved [trackId] above — matches the codec's own
        // doc-id derivation and keeps the SyncKv shadow key stable regardless
        // of how the local track was remapped (mirrors GoalMerger's pattern).
        final naturalKey =
            '${decoded.curriculumId}|${decoded.dayOfWeek}|${decoded.trackId}';
        final localUpdatedAt = await _store.currentUpdatedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
        );
        final localSyncedAt = await _store.currentSyncedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
        );

        if (!_store.remoteIsNewer(
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: decoded.updatedAt,
          localSyncedAt: localSyncedAt,
          remoteSyncedAt: decoded.syncedAt,
        )) {
          continue;
        }

        // AUD-core-sync-22 (DB-1): the actual SQLite write now lives in
        // StudyDayConfigDao, not here.
        await _db.studyDayConfigDao.upsertDayConfigFromSync(
          profileId: profileId,
          curriculumId: decoded.curriculumId,
          trackId: trackId,
          dayOfWeek: decoded.dayOfWeek,
          dayType: decoded.dayType,
          updatedAt: decoded.updatedAt,
        );

        await _store.persistUpdatedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
          updatedAt: decoded.updatedAt,
          syncedAt: decoded.syncedAt,
        );
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_study_day_config_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
