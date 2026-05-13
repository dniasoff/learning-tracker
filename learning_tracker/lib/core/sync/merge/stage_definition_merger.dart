import 'package:learning_tracker/core/sync/merge/entity_merger.dart';
import 'package:learning_tracker/features/sync/domain/merge_rules.dart';

/// LWW merger for stage definitions.
///
/// Closes T1.9: every configurable field on a stage is merged, not just
/// `delay_days`. The full set is:
///   `stage_name`, `stage_order`, `delay_days`, `schedule_type`,
///   `days_of_week`, `rolling_window_size`, `is_default`.
///
/// Natural key: `(curriculum_id, track_id, stage_order)`. Remote wins iff
/// its `updated_at` is strictly newer than the local row.
class StageDefinitionMerger implements EntityMerger {
  StageDefinitionMerger({required MergeStore store}) : _store = store;

  final MergeStore _store;

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
      final naturalKey =
          '${row['curriculum_id']}|${row['track_id']}|${row['stage_order']}';
      final localUpdatedAt = await _store.currentUpdatedAt(
        kind: kind,
        profileId: profileId,
        naturalKey: naturalKey,
      );
      final remoteUpdatedAt = _parseUpdatedAt(row['updated_at']);
      if (!remoteIsNewer(
        localUpdatedAt: localUpdatedAt,
        remoteUpdatedAt: remoteUpdatedAt,
      )) {
        continue;
      }
      await _store.upsert(kind: kind, profileId: profileId, fields: row);
    }
  }

  DateTime? _parseUpdatedAt(Object? raw) {
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    return null;
  }
}
