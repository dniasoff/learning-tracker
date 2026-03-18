import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';

part 'stage_definition.freezed.dart';

/// Domain model for a stage definition.
///
/// Represents a learning stage (e.g., Learn, Chazara 1) within a curriculum,
/// with ordering and scheduling configuration per D3.
///
/// Three schedule types are supported:
/// - [ScheduleType.delay]: item due X days after previous stage completion
/// - [ScheduleType.weekly]: review on specific days of the week
/// - [ScheduleType.rolling]: always review the last N items
@freezed
abstract class StageDefinition with _$StageDefinition {
  const factory StageDefinition({
    required int id,
    required CurriculumId curriculumId,
    required int stageOrder,
    required String stageName,
    required int delayDays,
    required bool isDefault,
    @Default(ScheduleType.delay) ScheduleType scheduleType,
    List<int>? daysOfWeek,
    int? rollingWindowSize,
  }) = _StageDefinition;
}
