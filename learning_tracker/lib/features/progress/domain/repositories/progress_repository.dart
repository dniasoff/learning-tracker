import 'package:learning_tracker/core/database/daos/completion_dao.dart';

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
  /// Returns completions in insertion order. Used by history screen.
  Future<List<Completion>> getCompletionsByCurriculum(String curriculumId);

  /// Get all completion records across all curricula.
  ///
  /// Used by history screen when no curriculum filter is applied.
  Future<List<Completion>> getAllCompletions();
}
