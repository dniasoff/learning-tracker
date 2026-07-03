import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';

/// Adapts [LearningOrderDao] for scheduler consumption.
///
/// Scoped to a single profile so a sibling profile's custom learning order
/// cannot leak into this profile's daily plan (AUD-core-database-02).
class SchedulerLearningOrderRepositoryImpl
    implements SchedulerLearningOrderRepository {
  SchedulerLearningOrderRepositoryImpl({
    required LearningOrderDao learningOrderDao,
    int profileId = 0,
  }) : _learningOrderDao = learningOrderDao,
       _profileId = profileId;

  final LearningOrderDao _learningOrderDao;
  final int _profileId;

  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId curriculumId) async {
    final rows = await _learningOrderDao.getLearningOrderByCurriculum(
      curriculumId.storageKey,
      profileId: _profileId,
    );
    return rows
        .map(
          (r) => SchedulerOrderItem(
            sefariaRef: r.sefariaRef,
            userSortOrder: r.userSortOrder,
          ),
        )
        .toList();
  }
}
