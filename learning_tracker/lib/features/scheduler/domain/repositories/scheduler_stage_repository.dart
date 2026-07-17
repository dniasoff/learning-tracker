import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';

part 'scheduler_stage_repository.freezed.dart';

/// Scheduler-local stage definition representation.
@freezed
abstract class SchedulerStage with _$SchedulerStage {
  const factory SchedulerStage({
    required int id,
    required int stageOrder,
    required String stageName,
    required int delayDays,
    @Default(ScheduleType.delay) ScheduleType scheduleType,
    List<int>? daysOfWeek,
    int? rollingWindowSize,
  }) = _SchedulerStage;
}

/// Abstract repository for stage definitions consumed by the scheduler.
///
/// Decouples the scheduler from the stages feature per P6.
abstract class SchedulerStageRepository {
  /// Get all stage definitions for a curriculum, ordered by stageOrder.
  Future<List<SchedulerStage>> getStages(CurriculumId curriculumId);
}
