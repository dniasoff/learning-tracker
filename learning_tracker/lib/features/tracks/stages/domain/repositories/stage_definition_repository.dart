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
  Future<void> initializeDefaults(
    CurriculumId curriculumId, {
    required int profileId,
    required int trackId,
  });

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

  /// Pushes the stage definitions of a single [trackId] to the cloud.
  ///
  /// Stage seeding (via the chazara wizard / noReview fallback) writes only to
  /// the local DB. Without an explicit push the `stage_definitions` Firestore
  /// subcollection stays empty, so a tutor mirror (and any second device) pulls
  /// zero stages and the scheduler shows "No projection" for the track. Track
  /// creation calls this after committing the local seed.
  Future<void> pushStagesForTrack({
    required int trackId,
    required CurriculumId curriculumId,
  });

  /// Returns every stage definition in the database (cross-curriculum).
  ///
  /// Intended for full-data export only.
  Future<List<StageDefinition>> getAllStageDefinitions();
}
