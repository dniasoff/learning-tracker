import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

part 'scheduler_learning_order_repository.freezed.dart';

/// Scheduler-local learning order item representation.
@freezed
abstract class SchedulerOrderItem with _$SchedulerOrderItem {
  const factory SchedulerOrderItem({
    required String sefariaRef,
    required int userSortOrder,
  }) = _SchedulerOrderItem;
}

/// The main-track order the scheduler builds its order from (P6 seam).
abstract class SchedulerLearningOrderRepository {
  /// The curriculum's leaves in the learner's main-track order — the AD-33
  /// `orderedLeaves` of its corpus and its live `track_learning_order` docs
  /// (DNI-476) — with `userSortOrder` = position.
  ///
  /// Returns an empty list when no custom order is set (the engine then
  /// uses natural content `sortOrder`, which is also what `orderedLeaves`
  /// yields with no live order doc).
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId curriculumId);
}
