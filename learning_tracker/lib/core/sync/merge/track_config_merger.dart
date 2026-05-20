/// LWW merger for curriculum-track configuration rows.
///
/// Natural key: `curriculum_id` (W3.22: trackType removed from schema).
/// Remote wins iff its `state_changed_at` is strictly newer than the local row.
///
/// W3.22/W3.28: natural key simplified from `(curriculum_id|track_type)`
/// to just `curriculum_id`; `deactivatedAt` replaced by `stateChangedAt`.
library;

import 'package:learning_tracker/core/sync/codec/track_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

class TrackConfigMerger implements EntityMerger {
  TrackConfigMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = TrackCodec();

  @override
  String get kind => EntityKind.trackConfig;

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue; // Missing required fields — skip.

      // W3.22: natural key is just curriculumId (one track per curriculum).
      final naturalKey = decoded.curriculumId;
      final localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      // The LWW timestamp for a track is stateChangedAt.
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: decoded.stateChangedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }
}
