import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';

/// Adapts [StageDao] for scheduler consumption.
class SchedulerStageRepositoryImpl implements SchedulerStageRepository {
  SchedulerStageRepositoryImpl({required StageDao stageDao})
    : _stageDao = stageDao;

  final StageDao _stageDao;

  @override
  Future<List<SchedulerStage>> getStages(CurriculumId curriculumId) async {
    final rows = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );
    return rows
        .map(
          (r) => SchedulerStage(
            id: r.id,
            stageOrder: r.stageOrder,
            stageName: r.stageName,
            delayDays: r.delayDays,
          ),
        )
        .toList();
  }
}
