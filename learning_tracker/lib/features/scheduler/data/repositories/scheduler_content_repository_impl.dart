import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';

/// Adapts [ContentRepository] for scheduler consumption.
///
/// Uses a function type to avoid importing the content_browsing feature directly.
class SchedulerContentRepositoryImpl implements SchedulerContentRepository {
  SchedulerContentRepositoryImpl({
    required Future<List<ContentItem>> Function(CurriculumId) getContent,
  }) : _getContent = getContent;

  final Future<List<ContentItem>> Function(CurriculumId) _getContent;

  @override
  Future<List<SchedulerContentItem>> getLeafItems(
    CurriculumId curriculumId,
  ) async {
    final items = await _getContent(curriculumId);
    return items
        .where((i) => i.isLeaf)
        .map(
          (i) => SchedulerContentItem(
            sefariaRef: i.sefariaRef,
            sortOrder: i.sortOrder,
            level1: i.level1,
            level2: i.level2,
            level3: i.level3,
            level4: i.level4,
          ),
        )
        .toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }
}
