import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/sync/data/sync_engine.dart';

/// Implementation of [TrackRepository] using Drift database and sync engine.
class TrackRepositoryImpl implements TrackRepository {
  final AppDatabase _database;
  final SyncEngine _syncEngine;

  TrackRepositoryImpl({
    required AppDatabase database,
    required SyncEngine syncEngine,
  })  : _database = database,
        _syncEngine = syncEngine;

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

    // Trigger Firestore sync for track activation
    await _syncEngine.queueSync(
      collection: 'curriculum_tracks',
      documentId: '${curriculumId.storageKey}_${trackType.storageKey}',
      operation: SyncOperation.upsert,
    );
  }

  @override
  Future<void> deactivateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    try {
      await _database.trackDao.deactivateTrack(curriculumId, trackType);

      // Trigger Firestore sync for track deactivation
      await _syncEngine.queueSync(
        collection: 'curriculum_tracks',
        documentId: '${curriculumId.storageKey}_${trackType.storageKey}',
        operation: SyncOperation.upsert,
      );
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
  Future<void> initializeDefaultTracks(CurriculumId curriculumId) async {
    await _database.trackDao.initializeDefaultTracks(curriculumId);

    // Trigger Firestore sync for initial personal track
    await _syncEngine.queueSync(
      collection: 'curriculum_tracks',
      documentId: '${curriculumId.storageKey}_${TrackType.personal.storageKey}',
      operation: SyncOperation.upsert,
    );
  }
}
