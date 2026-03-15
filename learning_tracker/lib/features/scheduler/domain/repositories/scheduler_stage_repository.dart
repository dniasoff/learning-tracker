import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Scheduler-local stage definition representation.
class SchedulerStage {
  const SchedulerStage({
    required this.id,
    required this.stageOrder,
    required this.stageName,
    required this.delayDays,
  });

  final int id;
  final int stageOrder;
  final String stageName;
  final int delayDays;
}

/// Abstract repository for stage definitions consumed by the scheduler.
///
/// Decouples the scheduler from the stages feature per P6.
abstract class SchedulerStageRepository {
  /// Get all stage definitions for a curriculum, ordered by stageOrder.
  Future<List<SchedulerStage>> getStages(CurriculumId curriculumId);
}
