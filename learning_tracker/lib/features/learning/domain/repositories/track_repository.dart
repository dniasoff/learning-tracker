import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

/// Repository interface for track management operations.
///
/// V1 uses one track per curriculum (`personal`). The API is kept as a list
/// for parity with legacy data and for forward compatibility.
abstract class TrackRepository {
  /// Get all active tracks for a curriculum.
  ///
  /// In v1 this always returns `[TrackType.personal]` for an activated
  /// curriculum.
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
  Future<void> initializeDefaultTracks(
    CurriculumId curriculumId, {
    int profileId = 0,
  });
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
