import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart';

/// Abstract repository for managing stage definitions per curriculum.
///
/// AUD-tracks-12: addStage/updateStage/deleteStage/reorderStages were
/// removed — a repo-wide grep found zero UI callers; the live
/// stage-configuration path is the chazara wizard's
/// LearningProcessWizardService.applyWizardResult, not this repository's
/// mutation methods.
abstract class StageDefinitionRepository {
  /// Returns all stages for a curriculum, ordered by stageOrder.
  Future<List<StageDefinition>> getStagesForCurriculum(
    CurriculumId curriculumId,
  );

  /// Seeds default stages (Learn, Chazara 1, Chazara 2) if none exist.
  ///
  /// Idempotent — no-op if stages already exist for this track.
  Future<void> initializeDefaults(CurriculumId curriculumId);

  /// Overwrites a curriculum's full stage set with [stages] (already
  /// ordered 1..N by the caller). See
  /// FirestoreStageDefinitionRepository.replaceStagesForCurriculum's doc
  /// comment for why a REDUCTION in stage count can leave orphaned
  /// higher-order documents behind (Firestore denies delete on this
  /// collection) -- flagged there, not silently diverged from.
  Future<void> replaceStagesForCurriculum(
    CurriculumId curriculumId,
    List<StageDefinition> stages,
  );

  /// Removes all stages and restores the 3 defaults.
  Future<void> resetToDefaults(CurriculumId curriculumId);

  /// Returns true if any completions reference the given stage ID.
  Future<bool> hasCompletionsForStage(int stageId);

  /// Returns all stage definitions for a curriculum, ordered by stageOrder.
  ///
  /// `CurriculumId` is the sole track identity (AD-25); no Drift-local
  /// integer track id belongs in this contract.
  Future<List<StageDefinition>> getStagesByTrack(CurriculumId curriculumId);

  /// Tombstones all stage definitions for a curriculum.
  ///
  /// Used during track replacement / deletion workflows.
  /// Does NOT push settings — the caller is responsible for pushing after
  /// the replacement is complete.
  Future<void> deleteStagesForTrack(CurriculumId curriculumId);

  /// Returns every stage definition in the database (cross-curriculum).
  ///
  /// Intended for full-data export only.
  Future<List<StageDefinition>> getAllStageDefinitions();
}
