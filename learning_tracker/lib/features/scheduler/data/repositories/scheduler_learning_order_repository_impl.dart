import 'package:learning_tracker/core/database/daos/learning_order_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';

/// Adapts [LearningOrderDao] for scheduler consumption.
class SchedulerLearningOrderRepositoryImpl
    implements SchedulerLearningOrderRepository {
  SchedulerLearningOrderRepositoryImpl({
    required LearningOrderDao learningOrderDao,
  }) : _learningOrderDao = learningOrderDao;

  final LearningOrderDao _learningOrderDao;

  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId curriculumId) async {
    final rows = await _learningOrderDao.getLearningOrderByCurriculum(
      curriculumId.storageKey,
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
