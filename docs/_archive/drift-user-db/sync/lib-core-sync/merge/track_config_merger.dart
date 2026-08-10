/// LWW merger for curriculum-track configuration rows.
///
/// Natural key: `curriculum_id` (W3.22: trackType removed from schema).
/// Remote wins iff its `state_changed_at` is strictly newer than the local
/// row; within ±5 s clock skew the Firestore server timestamp (`synced_at`)
/// decides.
///
/// W3.22/W3.28: natural key simplified from `(curriculum_id|track_type)`
/// to just `curriculum_id`; `deactivatedAt` replaced by `stateChangedAt`.
///
/// Phase 3: after a successful apply the merger persists the remote
/// `state_changed_at` via [MergeStore.persistUpdatedAt].
library;

import 'package:learning_tracker/core/ids/natural_key.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/sync/codec/track_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

class TrackConfigMerger implements EntityMerger {
  TrackConfigMerger({required MergeStore store, AppLogger? logger})
    : _store = store,
      _logger = logger;

  final MergeStore _store;
  // AUD-core-sync-15: optional logger so a per-row merge failure is
  // observable instead of silently swallowed.
  final AppLogger? _logger;
  static const _codec = TrackCodec();

  @override
  String get kind => EntityKind.trackConfig;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      // AUD-core-sync-15: isolate each row — mirrors LearnerProfileMerger.
      try {
        final decoded = _codec.decode(row);
        if (decoded == null) continue; // Missing required fields — skip.

        // W3.22: natural key is just curriculumId (one track per curriculum).
        // AUD-core-ids-01: route through NaturalKey.forTrackConfig instead
        // of using the raw curriculumId.
        final naturalKey = NaturalKey.forTrackConfig(
          curriculumId: decoded.curriculumId,
        ).value;
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
        // The LWW timestamp for a track is stateChangedAt.
        if (!_store.remoteIsNewer(
          localUpdatedAt: localUpdatedAt,
          remoteUpdatedAt: decoded.stateChangedAt,
          localSyncedAt: localSyncedAt,
          remoteSyncedAt: decoded.syncedAt,
        )) {
          continue;
        }
        // AUD-core-sync-08: apply + persist the LWW shadow atomically — see
        // BookmarkMerger for the crash-mid-sequence rationale.
        await _store.runInTransaction(() async {
          await _store.upsert(kind: kind, profileId: profileId, fields: row);
          await _store.persistUpdatedAt(
            kind: kind,
            profileId: profileId,
            naturalKey: naturalKey,
            updatedAt: decoded.stateChangedAt,
            syncedAt: decoded.syncedAt,
          );
        });
      } on Exception catch (e, stackTrace) {
        _logger?.warning(
          event: 'sync_track_config_merge_row_failed',
          fields: {'profile_id': profileId},
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }
  }
}
