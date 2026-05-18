import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';

/// Abstract repository for managing stage definitions per curriculum.
abstract class StageDefinitionRepository {
  /// Returns all stages for a curriculum, ordered by stageOrder.
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  );

  /// Adds a new custom stage. Assigns stageOrder = max + 1.
  ///
  /// Throws [StageLimitExceededException] if curriculum already has 10 stages.
  /// Throws [ArgumentError] if [StageValidator] rejects the new stage.
  Future<StageDefinition> addStage(
    CurriculumId curriculumId,
    String name,
    int delayDays, {
    required int profileId,
    required int trackId,
    ScheduleType scheduleType = ScheduleType.delay,
    List<int>? daysOfWeek,
    int? rollingWindowSize,
  });

  /// Updates the name and/or delayDays of an existing stage.
  Future<void> updateStage(int id, {String? name, int? delayDays});

  /// Deletes a stage by ID.
  ///
  /// Throws [ProtectedStageException] if the stage has stageOrder == 1.
  /// Does NOT delete associated completions.
  Future<void> deleteStage(int id);

  /// Reorders stages by updating stageOrder for each ID in [orderedIds].
  ///
  /// Runs in a single transaction — a mid-loop failure leaves stages unchanged.
  /// Throws [ProtectedStageException] if the Learn stage (stageOrder == 1) would
  /// be displaced from position 1 (i.e., its ID is not first in [orderedIds]).
  Future<void> reorderStages(CurriculumId curriculumId, List<int> orderedIds);

  /// Seeds default stages (Learn, Chazara 1, Chazara 2) if none exist.
  ///
  /// Idempotent — no-op if stages already exist for this track.
  Future<void> initializeDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  });

  /// Removes all stages and restores the 3 defaults.
  Future<void> resetToDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  });

  /// Returns true if any completions reference the given stage ID.
  Future<bool> hasCompletionsForStage(int stageId);

  /// Returns all stage definitions for a track, ordered by stageOrder.
  ///
  /// Track-scoped variant used by callers that have a [trackId] but not a
  /// [CurriculumId] (e.g. scheduler, point-config screen).
  Future<List<StageDefinition>> getStagesByTrack(int trackId);

  /// Deletes all stage definitions for a track.
  ///
  /// Used during track replacement / deletion workflows.
  /// Does NOT push settings — the caller is responsible for pushing after
  /// the replacement is complete.
  Future<void> deleteStagesForTrack(int trackId);

  /// Returns every stage definition in the database (cross-curriculum).
  ///
  /// Intended for full-data export only.
  Future<List<StageDefinition>> getAllStageDefinitions();
}
