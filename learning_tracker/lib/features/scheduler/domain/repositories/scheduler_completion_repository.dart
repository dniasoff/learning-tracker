import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'scheduler_completion_repository.freezed.dart';

/// Scheduler-local completion record representation.
@freezed
abstract class SchedulerCompletion with _$SchedulerCompletion {
  const factory SchedulerCompletion({
    required String sefariaRef,
    required int stageOrder,
    required String trackType,
    required DateTime completedAt,
  }) = _SchedulerCompletion;
}

/// Abstract repository for completions consumed by the scheduler.
///
/// Decouples the scheduler from the learning feature per P6.
abstract class SchedulerCompletionRepository {
  /// Get all completions for a curriculum.
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId curriculumId);
}
