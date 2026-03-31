import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';

/// Implementation of [TrackRepository] using Drift database.
class TrackRepositoryImpl implements TrackRepository {
  final AppDatabase _database;

  TrackRepositoryImpl({required AppDatabase database}) : _database = database;

  @override
  Future<List<TrackType>> getActiveTracks(CurriculumId curriculumId) async {
    final tracks = await _database.trackDao.getActiveTracks(curriculumId);
    return tracks
        .map((track) => TrackType.fromStorageKey(track.trackType))
        .toList();
  }

  @override
  Future<void> activateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    await _database.trackDao.activateTrack(curriculumId, trackType);

    // TODO(DNI-38): Add Firestore sync for track activation
    // See CompletionRepositoryImpl._syncCompletion for pattern
  }

  @override
  Future<void> deactivateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    try {
      await _database.trackDao.deactivateTrack(curriculumId, trackType);

      // TODO(DNI-38): Add Firestore sync for track deactivation
    } on InvalidOperationException catch (e) {
      throw InvalidTrackOperationException(e.message);
    }
  }

  @override
  Future<bool> isTrackActive(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    return await _database.trackDao.isTrackActive(curriculumId, trackType);
  }

  @override
  Future<void> initializeDefaultTracks(
    CurriculumId curriculumId, {
    int profileId = 0,
  }) async {
    await _database.trackDao.initializeDefaultTracks(
      curriculumId,
      profileId: profileId,
    );

    // TODO(DNI-38): Add Firestore sync for initial personal track
  }
}
