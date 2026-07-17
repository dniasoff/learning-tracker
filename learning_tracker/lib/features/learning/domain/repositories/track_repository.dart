import 'package:learning_tracker/core/enums/curriculum_id.dart';

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
