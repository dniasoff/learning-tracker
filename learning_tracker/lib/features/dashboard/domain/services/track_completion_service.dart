import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;

/// Pure computation service for track and curriculum completion percentages.
///
/// Accepts pre-loaded data (completion rows, stage definitions, total item
/// counts) and performs no IO itself — fully unit-testable.
///
/// ## Formula (track)
/// An item (sefariaRef) is "done" when ALL non-superseded stages for the
/// track have a completion record (matched by stageOrder). Percentage =
/// `(done items) / totalItems`.
///
/// ## Formula (curriculum)
/// An item is "done" when it is fully done in ANY of its tracks.
/// Percentage = `(distinct fully-done sefariaRefs) / totalItems`.
class TrackCompletionService {
  const TrackCompletionService();

  /// Computes item-based completion percentage for a single track.
  ///
  /// [stages] — stage definitions for the track (requiredStageIds = stageOrders).
  /// [completions] — all completion rows for the track + profile.
  /// [totalItems] — total leaf items in scope (denominator).
  ///
  /// Returns 0.0 when [stages] or [totalItems] is zero.
  double computeTrackPercentage({
    required List<domain_stage.StageDefinition> stages,
    required List<CompletionEntity> completions,
    required int totalItems,
  }) {
    if (stages.isEmpty || totalItems == 0) return 0.0;
    // Use stageOrder (1 = learn, 2 = chazara 1, …) — the value stored in
    // completion_events.stageId — NOT the stage definition's database primary key.
    final requiredStageIds = stages.map((s) => s.stageOrder).toSet();

    // Build a map of sefariaRef → set of completed stageIds for this track.
    final completedStagesByRef = <String, Set<int>>{};
    for (final c in completions) {
      completedStagesByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
    }

    // Count items where every required stage has a completion record.
    final doneItems = completedStagesByRef.values
        .where((doneStages) => requiredStageIds.every(doneStages.contains))
        .length;

    return (doneItems / totalItems).clamp(0.0, 1.0);
  }

  /// Computes item-based completion percentage for a curriculum across all tracks.
  ///
  /// [byTrack] — map of `trackId → (stageDefinitions, completionRows)` for each
  ///   track that has completions in this curriculum. Track 0 (bulk-mark sentinel)
  ///   is silently skipped.
  /// [totalItems] — total leaf items in scope (denominator).
  ///
  /// Returns 0.0 when [totalItems] is zero.
  double computeCurriculumPercentage({
    required Map<int, TrackEntry> byTrack,
    required int totalItems,
  }) {
    if (totalItems == 0) return 0.0;

    final doneRefs = <String>{};
    for (final entry in byTrack.entries) {
      final trackId = entry.key;
      if (trackId == 0) continue; // bulk-mark sentinel — skip

      final stages = entry.value.stages;
      final completions = entry.value.completions;
      if (stages.isEmpty) continue;

      // Use stageOrder (1 = learn, 2 = chazara 1, …) as in computeTrackPercentage.
      final requiredStageIds = stages.map((s) => s.stageOrder).toSet();

      // Group completions by sefariaRef → set of stageIds for this track.
      final stagesByRef = <String, Set<int>>{};
      for (final c in completions) {
        stagesByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
      }

      for (final refEntry in stagesByRef.entries) {
        if (requiredStageIds.every(refEntry.value.contains)) {
          doneRefs.add(refEntry.key);
        }
      }
    }

    return (doneRefs.length / totalItems).clamp(0.0, 1.0);
  }
}

/// Bundle of stage definitions + completion rows for a single track,
/// used as input to [TrackCompletionService.computeCurriculumPercentage].
class TrackEntry {
  const TrackEntry({required this.stages, required this.completions});

  final List<domain_stage.StageDefinition> stages;
  final List<CompletionEntity> completions;
}
