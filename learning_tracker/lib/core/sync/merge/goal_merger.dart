/// LWW merger for per-track goal rows (W2.27 / closes M1).
///
/// Natural key: `track_id`. Remote wins iff its `updated_at` is strictly
/// newer than the local row; within ±5 s clock skew the Firestore server
/// timestamp (`synced_at`) decides.
///
/// Phase 3: the merger consults [MergeStore.remoteIsNewer] (which knows
/// about clock-skew arbitration) before applying, and persists the remote
/// `updated_at` via [MergeStore.persistUpdatedAt] after a successful apply
/// so subsequent pulls arbitrate symmetrically against the persisted
/// timestamp. The underlying [GoalDao.upsertGoalByTrack] also applies its
/// own LWW guard against the local row's `updated_at` column — the two
/// guards agree on remote-newer cases and the merger's check is the
/// authoritative one for clock-skew ties.
library;

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class GoalMerger implements EntityMerger {
  GoalMerger(UserDatabase db, {required MergeStore store})
    : _db = db,
      _store = store;

  final UserDatabase _db;
  final MergeStore _store;

  @override
  String get kind => EntityKind.goal;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final curriculumId = row['curriculum_id'] as String?;
      final remoteTrackId = FirestoreCodec.parseInt(row['track_id']);
      final createdAt = FirestoreCodec.parseDateTime(row['created_at']);
      final updatedAt = FirestoreCodec.parseDateTime(row['updated_at']);
      final syncedAt = FirestoreCodec.parseDateTime(row['synced_at']);

      if (curriculumId == null ||
          remoteTrackId == null ||
          remoteTrackId == 0 ||
          createdAt == null ||
          updatedAt == null) {
        continue;
      }

      // Bug 3: resolve the LOCAL track id from (profile, curriculum). The
      // stored track_id is the remote id; under a tutored mirror the track was
      // re-inserted with a different local autoincrement id, so binding the
      // goal to the remote id leaves getGoalByTrack(localTrackId) empty and the
      // scheduler projection skips the track. No-op for own-data sync.
      final localTrack = await _db.trackDao.getTrackByProfileAndCurriculum(
        profileId,
        curriculumId,
      );
      final trackId = localTrack?.id ?? remoteTrackId;

      // AUD-core-sync-07: guard against this goal referencing a
      // curriculum_tracks row that hasn't synced locally yet — inserting
      // would violate the goals → curriculum_tracks FK (SqliteException 787)
      // and abort merging the whole page. Skip; the next pull re-merges
      // idempotently once the track exists (mirrors the guard already
      // applied to bookmark/gamification_settings/study_day_config).
      if (localTrack == null && await _db.trackDao.getById(trackId) == null) {
        continue;
      }

      // Keep the LWW natural key tied to the remote track id so the per-row
      // timestamp arbitration stays stable across pulls regardless of how the
      // local id was minted.
      final naturalKey = remoteTrackId.toString();
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
        remoteUpdatedAt: updatedAt,
        localSyncedAt: localSyncedAt,
        remoteSyncedAt: syncedAt,
      )) {
        continue;
      }

      // AUD-core-sync-08: apply + persist the LWW shadow atomically — see
      // BookmarkMerger for the crash-mid-sequence rationale. GoalMerger
      // writes via GoalDao directly (not MergeStore.upsert) but both this
      // write and persistUpdatedAt below hit the same underlying database
      // instance as _store, so they still participate in _store's
      // transaction.
      await _store.runInTransaction(() async {
        await _db.goalDao.upsertGoalByTrack(
          profileId: profileId,
          trackId: trackId,
          curriculumId: curriculumId,
          description: row['description'] as String? ?? '',
          targetPercent: (row['target_percent'] as num?)?.toDouble() ?? 100.0,
          targetDate: FirestoreCodec.parseDateTime(row['target_date']),
          dateType: row['date_type'] as String? ?? 'gregorian',
          goalType: row['goal_type'] as String? ?? 'deadline',
          paceValue: FirestoreCodec.parseInt(row['pace_value']),
          pacePeriod: row['pace_unit'] as String?,
          paceGranularity: row['pace_granularity'] as String?,
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

        await _store.persistUpdatedAt(
          kind: kind,
          profileId: profileId,
          naturalKey: naturalKey,
          updatedAt: updatedAt,
          syncedAt: syncedAt,
        );
      });
    }
  }
}
