import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
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
///
/// ### ScheduleSpec
/// Use `.schedule` (via the [StageDefinitionScheduleSpec] extension) to get
/// the strongly-typed sealed [ScheduleSpec] that encapsulates the quartet
/// fields. The raw fields exist only for Drift-column mapping (W3.27 will
/// collapse them into a single JSON column).
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

/// Extension that surfaces [ScheduleSpec] on [StageDefinition] without
/// requiring Freezed code-gen to be re-run (W4.10).
///
/// Until W3.27 collapses the quartet into a single JSON column, consumers
/// should use [schedule] instead of accessing the raw fields directly.
extension StageDefinitionScheduleSpec on StageDefinition {
  /// Returns the strongly-typed [ScheduleSpec] encapsulating the schedule
  /// quartet fields ([scheduleType], [delayDays], [daysOfWeek], [rollingWindowSize]).
  ScheduleSpec get schedule => ScheduleSpec.fromParts(
    scheduleTypeKey: scheduleType.storageKey,
    delayDays: delayDays,
    daysOfWeek: daysOfWeek,
    rollingWindowSize: rollingWindowSize,
  );
}
