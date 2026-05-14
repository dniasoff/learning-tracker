import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';

/// Implementation of [TrackRepository] using Drift database.
class TrackRepositoryImpl implements TrackRepository {
  TrackRepositoryImpl({
    required UserDatabase database,
    SyncWriteFacade? syncEngine,
    int activeProfileId = 0,
  }) : _database = database,
       _syncEngine = syncEngine,
       _activeProfileId = activeProfileId;

  final UserDatabase _database;
  final SyncWriteFacade? _syncEngine;
  final int _activeProfileId;

  Future<CurriculumTrack?> _resolveTrackRowForSync(
    CurriculumId curriculumId,
    TrackType trackType, {
    required int profileId,
  }) async {
    final all = await _database.trackDao.getAllTracks(curriculumId);
    final preferred = all.where(
      (t) => t.trackType == trackType.storageKey && t.profileId == profileId,
    );
    if (preferred.isNotEmpty) return preferred.first;
    final legacy = all.where((t) => t.trackType == trackType.storageKey);
    if (legacy.isNotEmpty) return legacy.first;
    return null;
  }

  Future<void> _pushCurriculumTrackIfCloud(
    CurriculumId curriculumId,
    TrackType trackType, {
    int? profileId,
  }) async {
    final engine = _syncEngine;
    if (engine == null) return;

    final pid = profileId ?? _activeProfileId;
    final row = await _resolveTrackRowForSync(
      curriculumId,
      trackType,
      profileId: pid,
    );
    if (row == null) return;

    await engine.pushCurriculumTrack({
      'profile_id': row.profileId,
      'track_id': row.id,
      'curriculum_id': row.curriculumId,
      'track_type': row.trackType,
      'is_active': row.isActive,
      'activated_at': row.activatedAt.toIso8601String(),
      'deactivated_at': row.deactivatedAt?.toIso8601String(),
      'pace_reset_date': row.paceResetDate?.toIso8601String(),
    });
  }

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
    await _pushCurriculumTrackIfCloud(curriculumId, trackType);
  }

  @override
  Future<void> deactivateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    try {
      await _database.trackDao.deactivateTrack(curriculumId, trackType);
      await _pushCurriculumTrackIfCloud(curriculumId, trackType);
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
    await _pushCurriculumTrackIfCloud(
      curriculumId,
      TrackType.personal,
      profileId: profileId,
    );
  }
}
