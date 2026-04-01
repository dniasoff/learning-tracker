import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

/// Repository interface for progress data operations.
///
/// Provides methods to query completion progress broken down by track
/// or aggregated across all tracks.
abstract class ProgressRepository {
  /// Get completion count breakdown by track type for a curriculum.
  ///
  /// Returns a map of TrackType to completion counts.
  /// Includes counts from deactivated tracks (historical data preserved).
  /// Returns zero counts for inactive tracks that have no completions.
  Future<Map<TrackType, int>> getTrackBreakdown(String curriculumId);

  /// Get total completion count for a curriculum across all tracks.
  ///
  /// Returns the sum of all completions regardless of track type.
  /// Should match the sum of individual track counts from getTrackBreakdown.
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
