import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';

/// Firestore-backed [SchedulerLearningOrderRepository]: the scheduler's
/// main-track order is the AD-33 `orderedLeaves` of the curriculum's
/// ContentIndex corpus and its live `track_learning_order` docs (Story
/// 1.14, DNI-476 — the retired `learning_order` collection is no longer
/// read, R13).
///
/// [getOrder] returns every leaf of the curriculum in that order, with
/// `userSortOrder` = its position, so `SchedulerEngine`'s order build is
/// exactly `orderedLeaves`. It returns `[]` (the engine's natural-order
/// fallback) when the curriculum has no live order doc, and while the
/// repository is not ready (no active account or profile yet); the next
/// read after it resolves sees the saved order, since nothing is cached.
///
/// The curriculum's full content tree (containers included) comes from
/// [_content], fetched only when a live order doc exists.
class SchedulerTrackOrderRepositoryAdapter
    implements SchedulerLearningOrderRepository {
  SchedulerTrackOrderRepositoryAdapter({
    required Ref ref,
    required Future<List<ContentItem>> Function(CurriculumId curriculumId)
    content,
  }) : _ref = ref,
       _content = content;

  final Ref _ref;
  final Future<List<ContentItem>> Function(CurriculumId curriculumId) _content;

  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId curriculumId) async {
    final repo = await _ref.read(
      firestoreTrackLearningOrderRepositoryProvider.future,
    );
    if (repo == null) return const [];
    final refs = await repo.orderedLeafRefs(
      curriculumId,
      content: () => _content(curriculumId),
    );
    return [
      for (var i = 0; i < refs.length; i++)
        SchedulerOrderItem(sefariaRef: refs[i], userSortOrder: i),
    ];
  }
}
