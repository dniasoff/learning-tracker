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
    final completions = await _completionDao
        .getCompletionsByCurriculumAndProfile(
          curriculumId.storageKey,
          _profileId,
        );
    final stages = await _stageDao.getStageDefinitionsByCurriculum(
      curriculumId.storageKey,
    );

    final stageOrderMap = {for (final s in stages) s.id: s.stageOrder};
    final knownStageOrders = {for (final s in stages) s.stageOrder};

    // AUD-scheduler-15: `stage_definitions.id` (a global autoincrement) and
    // `stageOrder` (a small 1..10 per-curriculum ordinal) are both small
    // positive integers that can coincide — especially once
    // StageDefinitionRepository.reorderStages moves a stage's order away
    // from its id. Guessing the format from value coincidence (does
    // rawStageId happen to match a CURRENT stageOrder?) can silently
    // resolve to the WRONG stage when it does. `stageIdFormat` (v37)
    // removes the guess: it is an explicit marker stamped at write time
    // (CompletionWriter always writes 'stageOrder'; the v37 migration
    // backfilled pre-existing rows it could classify with certainty).
    // Only a row with no marker at all (a pre-v37 row the migration could
    // not classify, or a row inserted by a path that predates this column)
    // falls back to the historical best-effort guess.
    int? resolveStageOrder(int rawStageId, String? stageIdFormat) {
      switch (stageIdFormat) {
        case 'stageOrder':
          return knownStageOrders.contains(rawStageId) ? rawStageId : null;
        case 'legacyId':
          return stageOrderMap[rawStageId];
        default:
          // Unmarked row — no explicit signal available. Preserve the
          // pre-v37 behaviour exactly (no regression for already-synced or
          // not-yet-migrated data).
          if (knownStageOrders.contains(rawStageId)) return rawStageId;
          return stageOrderMap[rawStageId];
      }
    }

    return completions
        .map((c) {
          final stageOrder = resolveStageOrder(c.stageId, c.stageIdFormat);
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
