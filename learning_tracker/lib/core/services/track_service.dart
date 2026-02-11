import 'package:learning_tracker/core/enums/track_type.dart';

/// Service for managing active tracks per curriculum.
///
/// This is a simplified implementation that will be replaced by the full
/// TrackRepository from DNI-38 when it's merged. For now, it provides
/// the interface needed for track assignment and duplicate prevention.
class TrackService {
  // In-memory storage of active tracks per curriculum
  // This will be replaced with database storage from DNI-38
  final Map<String, List<TrackType>> _activeTracks = {};

  /// Gets the list of active tracks for a curriculum.
  ///
  /// Returns [TrackType.personal] by default if no tracks are configured.
  Future<List<TrackType>> getActiveTracks(String curriculumId) async {
    return _activeTracks[curriculumId] ?? [TrackType.personal];
  }

  /// Activates a track for a curriculum.
  Future<void> activateTrack(String curriculumId, TrackType track) async {
    final tracks = _activeTracks[curriculumId] ?? [TrackType.personal];
    if (!tracks.contains(track)) {
      tracks.add(track);
      _activeTracks[curriculumId] = tracks;
    }
  }

  /// Deactivates a track for a curriculum.
  ///
  /// Personal track cannot be deactivated.
  Future<void> deactivateTrack(String curriculumId, TrackType track) async {
    if (track == TrackType.personal) {
      throw InvalidOperationException('Personal track cannot be deactivated');
    }

    final tracks = _activeTracks[curriculumId] ?? [TrackType.personal];
    tracks.remove(track);
    _activeTracks[curriculumId] = tracks;
  }

  /// Determines the track to use for a completion.
  ///
  /// If only personal track is active, returns [TrackType.personal].
  /// If multiple tracks are active, returns null to indicate that
  /// the user should be prompted to select a track.
  Future<TrackType?> getAutoAssignedTrack(String curriculumId) async {
    final tracks = await getActiveTracks(curriculumId);
    return tracks.length == 1 ? tracks.first : null;
  }
}

/// Exception thrown when an invalid operation is attempted.
class InvalidOperationException implements Exception {
  final String message;

  InvalidOperationException(this.message);

  @override
  String toString() => 'InvalidOperationException: $message';
}
