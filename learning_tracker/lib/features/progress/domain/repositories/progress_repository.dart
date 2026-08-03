import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';

/// Repository interface for progress data operations.
///
/// Provides methods to query completion progress.
abstract class ProgressRepository {
  /// Get completion counts for a curriculum, keyed by the internal track
  /// storage key. One track per curriculum, so this is a single-entry map.
  Future<Map<String, int>> getTrackBreakdown(String curriculumId);

  /// Get total completion count for a curriculum.
  ///
  /// Should match the sum of the counts from getTrackBreakdown.
  Future<int> getAggregateCount(String curriculumId);

  /// Get all completion records for a specific curriculum.
  ///
  /// Owner decision 3 (`docs/firestore-rewrite-map.md`): returns
  /// [CompletionEntity] — the Firestore-shaped record — rather than the
  /// Drift-era `Completion` (which carried an autoincrement `id`, an `int
  /// profileId`, and the AD-25-retired `trackId`; none of the three have a
  /// Firestore equivalent). Order is not guaranteed. Used by history screen.
  Future<List<CompletionEntity>> getCompletionsByCurriculum(
    String curriculumId,
  );

  /// Get all completion records across all curricula.
  ///
  /// See [getCompletionsByCurriculum]'s doc comment for the [CompletionEntity]
  /// return type. Used by history screen when no curriculum filter is
  /// applied.
  Future<List<CompletionEntity>> getAllCompletions();
}
