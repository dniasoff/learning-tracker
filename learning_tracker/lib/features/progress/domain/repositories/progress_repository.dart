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
}
