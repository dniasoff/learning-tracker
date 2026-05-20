/// Codec for Firestore `stage_definitions/{id}` documents.
library;

import 'package:learning_tracker/core/sync/codec/entity_codec.dart';
import 'package:learning_tracker/core/sync/codec/firestore_codec.dart';
import 'package:learning_tracker/core/sync/merge/entity_merger.dart';

/// Decoded shape for a stage definition row.
class StageDefinitionRow {
  const StageDefinitionRow({
    required this.curriculumId,
    required this.trackId,
    required this.stageOrder,
    required this.stageName,
    required this.delayDays,
    required this.isDefault,
    required this.scheduleType,
    this.daysOfWeek,
    this.rollingWindowSize,
    this.updatedAt,
  });

  final String curriculumId;
  final int trackId;
  final int stageOrder;
  final String stageName;
  final int delayDays;
  final bool isDefault;
  final String scheduleType;
  final String? daysOfWeek;
  final int? rollingWindowSize;
  final DateTime? updatedAt;
}

/// Codec for the `stage_definitions` Firestore collection.
///
/// Natural key: `(curriculumId, trackId, stageOrder)`.
/// LWW: remote wins when `updated_at` is strictly newer.
class StageDefinitionCodec extends EntityCodec<StageDefinitionRow> {
  const StageDefinitionCodec();

  @override
  String get kind => EntityKind.stageDefinition;

  @override
  StageDefinitionRow? decode(Map<String, dynamic> raw) {
    final curriculumId = raw['curriculum_id'] as String?;
    final trackId = FirestoreCodec.parseInt(raw['track_id']);
    final stageOrder = FirestoreCodec.parseInt(raw['stage_order']);

    if (curriculumId == null || trackId == null || stageOrder == null) {
      return null;
    }

    return StageDefinitionRow(
      curriculumId: curriculumId,
      trackId: trackId,
      stageOrder: stageOrder,
      stageName: raw['stage_name'] as String? ?? '',
      delayDays: FirestoreCodec.parseInt(raw['delay_days']) ?? 0,
      isDefault: FirestoreCodec.parseBool(raw['is_default']) ?? false,
      scheduleType: raw['schedule_type'] as String? ?? 'delay',
      daysOfWeek: raw['days_of_week'] as String?,
      rollingWindowSize: FirestoreCodec.parseInt(raw['rolling_window_size']),
      updatedAt: FirestoreCodec.parseDateTime(raw['updated_at']),
    );
  }

  @override
  Map<String, dynamic> encode(StageDefinitionRow model) => {
        'curriculum_id': model.curriculumId,
        'track_id': model.trackId,
        'stage_order': model.stageOrder,
        'stage_name': model.stageName,
        'delay_days': model.delayDays,
        'is_default': model.isDefault,
        'schedule_type': model.scheduleType,
        if (model.daysOfWeek != null) 'days_of_week': model.daysOfWeek,
        if (model.rollingWindowSize != null)
          'rolling_window_size': model.rollingWindowSize,
        if (model.updatedAt != null)
          'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
      };
}
