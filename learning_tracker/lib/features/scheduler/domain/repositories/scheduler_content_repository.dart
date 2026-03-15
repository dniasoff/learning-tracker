import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Scheduler-local content item representation.
class SchedulerContentItem {
  const SchedulerContentItem({
    required this.sefariaRef,
    required this.sortOrder,
  });

  final String sefariaRef;
  final int sortOrder;
}

/// Abstract repository for content items consumed by the scheduler.
///
/// Decouples the scheduler from the content_browsing feature per P6.
abstract class SchedulerContentRepository {
  /// Get all leaf content items for a curriculum, ordered by sortOrder.
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId curriculumId);
}
