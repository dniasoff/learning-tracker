import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Scheduler-local learning order item representation.
class SchedulerOrderItem {
  const SchedulerOrderItem({
    required this.sefariaRef,
    required this.userSortOrder,
  });

  final String sefariaRef;
  final int userSortOrder;
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
