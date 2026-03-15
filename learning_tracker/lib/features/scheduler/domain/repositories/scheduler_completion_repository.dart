import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Scheduler-local completion record representation.
class SchedulerCompletion {
  const SchedulerCompletion({
    required this.sefariaRef,
    required this.stageOrder,
    required this.trackType,
    required this.completedAt,
  });

  final String sefariaRef;
  final int stageOrder;
  final String trackType;
  final DateTime completedAt;
}

/// Abstract repository for completions consumed by the scheduler.
///
/// Decouples the scheduler from the learning feature per P6.
abstract class SchedulerCompletionRepository {
  /// Get all completions for a curriculum.
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId curriculumId);
}
