/// LWW merger for stage definitions.
///
/// Closes T1.9: every configurable field on a stage is merged, not just
/// `delay_days`. The full set is:
///   `stage_name`, `stage_order`, `delay_days`, `schedule_type`,
///   `days_of_week`, `rolling_window_size`, `is_default`.
///
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

  /// All fields preserved through a merge — `delay_days` is just one of
  /// them. See T1.9 in the rebuild plan.
  static const List<String> mergedFields = [
    'stage_name',
    'stage_order',
    'delay_days',
    'schedule_type',
    'days_of_week',
    'rolling_window_size',
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
