import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// Adapts [StageDefinitionRepository] for scheduler consumption.
///
/// [SchedulerStage] and [StageDefinition] carry the identical schedule
/// quartet (delayDays/scheduleType/daysOfWeek/rollingWindowSize) — this is a
/// pure field-mapping adapter, no new read/write surface. Replaces the
/// Drift-backed `StageDao` implementation the Drift user DB deletion removed
/// (archived under `docs/_archive/drift-user-db/`).
class SchedulerStageRepositoryImpl implements SchedulerStageRepository {
  SchedulerStageRepositoryImpl({required StageDefinitionRepository stageRepository})
    : _stageRepository = stageRepository;

  final StageDefinitionRepository _stageRepository;

  @override
  Future<List<SchedulerStage>> getStages(CurriculumId curriculumId) async {
    final stages = await _stageRepository.getStagesForCurriculum(curriculumId);
    return stages.map(_toSchedulerStage).toList();
  }

  static SchedulerStage _toSchedulerStage(StageDefinition s) {
    return SchedulerStage(
      stageOrder: s.stageOrder,
      stageName: s.stageName,
      delayDays: s.delayDays,
      scheduleType: s.scheduleType,
      daysOfWeek: s.daysOfWeek,
      rollingWindowSize: s.rollingWindowSize,
    );
  }
}
