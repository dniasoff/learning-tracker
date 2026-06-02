import 'package:learning_tracker/core/enums/curriculum_id.dart';

export 'package:learning_tracker/core/exceptions/invalid_track_operation_exception.dart'
    show InvalidTrackOperationException;

/// Repository interface for track management operations.
///
/// One track per curriculum per profile.
abstract class TrackRepository {
  /// Initialize the default track for a newly activated curriculum.
  ///
  /// Creates the track (active by default). Should be called when a curriculum
  /// is first activated by the user.
  Future<void> initializeDefaultTracks(
    CurriculumId curriculumId, {
    int profileId = 0,
  });
}

// InvalidTrackOperationException is now defined in core/exceptions/ (W7.4).
// Re-exported above so existing importers of this file don't need updating.
