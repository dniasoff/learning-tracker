import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

/// Repository interface for track management operations.
///
/// Handles activation/deactivation of optional tracks (school, tutor) per
/// curriculum. Personal track is always present and cannot be removed.
abstract class TrackRepository {
  /// Get all active tracks for a curriculum.
  ///
  /// A freshly activated curriculum returns only [TrackType.personal].
  /// After activating school/tutor tracks, they appear in this list.
  Future<List<TrackType>> getActiveTracks(CurriculumId curriculumId);

  /// Activate a track for a curriculum.
  ///
  /// Makes the track available for completion tracking. If the track was
  /// previously deactivated, reactivates it with a new activation timestamp.
  ///
  /// Does nothing if the track is already active.
  Future<void> activateTrack(CurriculumId curriculumId, TrackType trackType);

  /// Deactivate a track for a curriculum.
  ///
  /// Hides the track from the UI but preserves all completion data
  /// associated with it. The track can be reactivated later.
  ///
  /// Throws [InvalidTrackOperationException] if attempting to deactivate
  /// [TrackType.personal] as it cannot be removed.
  Future<void> deactivateTrack(CurriculumId curriculumId, TrackType trackType);

  /// Check if a specific track is active for a curriculum.
  Future<bool> isTrackActive(CurriculumId curriculumId, TrackType trackType);

  /// Initialize default tracks for a newly activated curriculum.
  ///
  /// Creates the personal track (active by default). Should be called
  /// when a curriculum is first activated by the user.
  Future<void> initializeDefaultTracks(CurriculumId curriculumId);
}

/// Exception thrown when attempting an invalid track operation.
///
/// For example: attempting to deactivate the personal track.
class InvalidTrackOperationException implements Exception {
  const InvalidTrackOperationException(this.message);
  final String message;

  @override
  String toString() => 'InvalidTrackOperationException: $message';
}
