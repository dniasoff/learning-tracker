import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';

/// Adapts [CompletionDao] for scheduler consumption.
///
/// Scoped to a single profile so daily task generation reflects only the
/// active profile's completion history.
class SchedulerCompletionRepositoryImpl
    implements SchedulerCompletionRepository {
  SchedulerCompletionRepositoryImpl({
    required CompletionDao completionDao,
    required StageDao stageDao,
    int profileId = 0,
  }) : _completionDao = completionDao,
       _stageDao = stageDao,
       _profileId = profileId;

  final CompletionDao _completionDao;
  final StageDao _stageDao;
  final int _profileId;

  @override
  Future<List<SchedulerCompletion>> getCompletions(
    CurriculumId curriculumId,
  ) async {
    final completions = await _completionDao.getCompletionsByCurriculumAndProfile(
      curriculumId.storageKey,
      _profileId,
    );
    final stages = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );

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
