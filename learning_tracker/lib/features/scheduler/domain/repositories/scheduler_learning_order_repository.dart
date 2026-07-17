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

/// Abstract repository for learning order consumed by the scheduler.
///
/// Decouples the scheduler from the learning_order feature per P6.
abstract class SchedulerLearningOrderRepository {
  /// Get the custom learning order for a curriculum.
  ///
  /// Returns empty list if no custom order is set (use content sortOrder).
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId curriculumId);
}
