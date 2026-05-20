/// LWW merger for stage definitions.
///
/// Closes T1.9: every configurable field on a stage is merged, not just
/// delay configuration. The full set is:
///   `stage_name`, `stage_order`, `schedule` (JSON), `is_default`.
///
/// W3.27: schedule quartet replaced by JSON `schedule` column.
/// Natural key: `(curriculum_id, track_id, stage_order)`. Remote wins iff
/// its `updated_at` is strictly newer than the local row.
library;

import 'package:learning_tracker/core/sync/codec/stage_definition_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/core/sync/merge/merge_rules.dart';

class StageDefinitionMerger implements EntityMerger {
  StageDefinitionMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;
  static const _codec = StageDefinitionCodec();

  @override
  String get kind => EntityKind.stageDefinition;

  /// All fields preserved through a merge. See T1.9 in the rebuild plan.
  /// W3.27: schedule quartet collapsed to single JSON `schedule` field.
  static const List<String> mergedFields = [
    'stage_name',
    'stage_order',
    'schedule',
    'is_default',
  ];

  @override
  Future<void> merge({
    required int profileId,
    required List<Map<String, dynamic>> rows,
  }) async {
    for (final row in rows) {
      final decoded = _codec.decode(row);
      if (decoded == null) continue; // Missing required fields — skip.

      final naturalKey =
          '${decoded.curriculumId}|${decoded.trackId}|${decoded.stageOrder}';
      final localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: decoded.updatedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }
}
