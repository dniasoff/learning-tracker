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

import 'package:drift/drift.dart' as drift;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/study_day_config_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class StudyDayConfigMerger implements EntityMerger {
  StudyDayConfigMerger(UserDatabase db, {required MergeStore store})
    : _db = db,
      _store = store;

  final UserDatabase _db;
  final MergeStore _store;
  static const _codec = StudyDayConfigCodec();

  @override
  String get kind => EntityKind.studyDayConfig;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
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

      // study_day_configs.trackId is a FK into curriculum_tracks. The stored
      // track_id is the REMOTE id; under a tutored mirror the track was
      // re-inserted with a different local autoincrement id, so the remote id
      // never matches and the row would be dropped (the FK-existence guard
      // below fails) — leaving the scheduler with no study-day pattern and a
      // 0-due projection (Bug 3). Resolve the LOCAL track by (profile,
      // curriculum) and bind the config to it. No-op for own-data sync.
      //
      // If the referenced track is not present locally yet (e.g. this listener
      // snapshot merged before the curriculum_tracks snapshot), inserting would
      // throw a FK-constraint violation that fails the ENTIRE study_day_configs
      // channel merge — which in turn triggers a dashboard rebuild storm. Skip
      // the row; the next full pull re-merges it (LWW, idempotent) once the
      // track exists.
      final localTrack = await _db.trackDao.getTrackByProfileAndCurriculum(
        profileId,
        decoded.curriculumId,
      );
      final trackId = localTrack?.id ?? decoded.trackId;
      final trackExists =
          localTrack ??
          await (_db.select(
            _db.curriculumTracks,
          )..where((t) => t.id.equals(trackId))).getSingleOrNull();
      if (trackExists == null) continue;

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

      await _db
          .into(_db.studyDayConfigs)
          .insertOnConflictUpdate(
            StudyDayConfigsCompanion.insert(
              profileId: profileId,
              curriculumId: decoded.curriculumId,
              trackId: trackId,
              dayOfWeek: decoded.dayOfWeek,
              dayType: drift.Value(decoded.dayType),
              updatedAt: decoded.updatedAt,
            ),
          );

      await _store.persistUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
        updatedAt: decoded.updatedAt,
        syncedAt: decoded.syncedAt,
      );
    }
  }
}
