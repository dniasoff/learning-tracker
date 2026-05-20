/// LWW merger for curriculum-track configuration rows.
///
/// Natural key: `(curriculum_id, track_type)`. Remote wins iff its
/// `activated_at` / `deactivated_at` (whichever is later) is strictly
/// newer than the local row — matches [DriftMergeStore.currentUpdatedAt]
/// for [EntityKind.trackConfig].
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

      final naturalKey = '${decoded.curriculumId}|${decoded.trackType}';
      final localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      // The "updatedAt" for a track is the later of activatedAt and
      // deactivatedAt (mirrors DriftMergeStore.currentUpdatedAt logic).
      final remoteUpdatedAt = _effectiveTimestamp(decoded);
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }

  static DateTime _effectiveTimestamp(TrackRow track) {
    final deactivated = track.deactivatedAt;
    if (deactivated != null && deactivated.isAfter(track.activatedAt)) {
      return deactivated;
    }
    return track.activatedAt;
  }
}
