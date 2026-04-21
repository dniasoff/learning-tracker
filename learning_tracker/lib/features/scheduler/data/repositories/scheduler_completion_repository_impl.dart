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
    final knownStageOrders = {for (final s in stages) s.stageOrder};

    int? resolveStageOrder(int rawStageId) {
      // Newer writes may store stageOrder directly; older writes may store
      // stage definition id. Accept both for backward compatibility.
      if (knownStageOrders.contains(rawStageId)) return rawStageId;
      return stageOrderMap[rawStageId];
    }

    return completions
        .map((c) {
          final stageOrder = resolveStageOrder(c.stageId);
          if (stageOrder == null) return null;
          return SchedulerCompletion(
            sefariaRef: c.sefariaRef,
            stageOrder: stageOrder,
            trackType: c.trackType,
            completedAt: c.completedAt,
          );
        })
        .whereType<SchedulerCompletion>()
        .toList();
  }
}
