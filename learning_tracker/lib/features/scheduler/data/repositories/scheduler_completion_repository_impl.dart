import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';

/// Adapts [CompletionDao] for scheduler consumption.
///
/// Joins completions with stage definitions to resolve stageOrder from stageId.
class SchedulerCompletionRepositoryImpl
    implements SchedulerCompletionRepository {
  SchedulerCompletionRepositoryImpl({
    required CompletionDao completionDao,
    required StageDao stageDao,
  }) : _completionDao = completionDao,
       _stageDao = stageDao;

  final CompletionDao _completionDao;
  final StageDao _stageDao;

  @override
  Future<List<SchedulerCompletion>> getCompletions(
    CurriculumId curriculumId,
  ) async {
    final completions = await _completionDao.getCompletionsByCurriculum(
      curriculumId.storageKey,
    );
    final stages = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );

    // Build stageId -> stageOrder map
    final stageOrderMap = {for (final s in stages) s.id: s.stageOrder};

    return completions
        .where((c) => stageOrderMap.containsKey(c.stageId))
        .map(
          (c) => SchedulerCompletion(
            sefariaRef: c.sefariaRef,
            stageOrder: stageOrderMap[c.stageId]!,
            trackType: c.trackType,
            completedAt: c.completedAt,
          ),
        )
        .toList();
  }
}
