/// Codec for Firestore `stage_definitions/{id}` documents.
///
/// W3.27: schedule quartet (scheduleType/daysOfWeek/rollingWindowSize/delayDays)
/// replaced by a single JSON `schedule` column.
/// W3.23: updatedAt added for LWW sync.
library;

import 'dart:convert';

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
    required this.schedule,
    required this.isDefault,
    this.updatedAt,
  });

  final String curriculumId;
  final int trackId;
  final int stageOrder;
  final String stageName;

  /// JSON-encoded ScheduleSpec, e.g. `{"type":"delay","delay_days":7}`.
  final String schedule;

  final bool isDefault;
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

    // Prefer pre-encoded `schedule` field; fall back to legacy quartet.
    final String schedule;
    final rawSchedule = raw['schedule'];
    if (rawSchedule is String && rawSchedule.isNotEmpty) {
      schedule = rawSchedule;
    } else if (rawSchedule is Map) {
      schedule = jsonEncode(rawSchedule);
    } else {
      // Back-compat: build from legacy quartet fields.
      final scheduleType = raw['schedule_type'] as String? ?? 'delay';
      final delayDays = FirestoreCodec.parseInt(raw['delay_days']) ?? 0;
      final daysOfWeek = raw['days_of_week'];
      final rollingWindowSize = FirestoreCodec.parseInt(
        raw['rolling_window_size'],
      );

      switch (scheduleType) {
        case 'days_of_week':
          List<int> days;
          if (daysOfWeek is String) {
            try {
              days = (jsonDecode(daysOfWeek) as List).cast<int>();
            } catch (_) {
              days = const [];
            }
          } else if (daysOfWeek is List) {
            days = daysOfWeek.cast<int>();
          } else {
            days = const [];
          }
          schedule = jsonEncode({'type': 'days_of_week', 'days': days});
        case 'rolling_window':
          schedule = jsonEncode({
            'type': 'rolling_window',
            'window_size': rollingWindowSize ?? 7,
          });
        default:
          schedule = jsonEncode({'type': 'delay', 'delay_days': delayDays});
      }
    }

    return StageDefinitionRow(
      curriculumId: curriculumId,
      trackId: trackId,
      stageOrder: stageOrder,
      stageName: raw['stage_name'] as String? ?? '',
      schedule: schedule,
      isDefault: FirestoreCodec.parseBool(raw['is_default']) ?? false,
      updatedAt: FirestoreCodec.parseDateTime(raw['updated_at']),
    );
  }

  @override
  Map<String, dynamic> encode(StageDefinitionRow model) => {
    'curriculum_id': model.curriculumId,
    'track_id': model.trackId,
    'stage_order': model.stageOrder,
    'stage_name': model.stageName,
    'schedule': model.schedule,
    'is_default': model.isDefault,
    if (model.updatedAt != null)
      'updated_at': FirestoreCodec.encodeDateTime(model.updatedAt),
  };
}
