import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';

/// Implementation of [TrackRepository] using Drift database.
///
/// W3.22/W3.28/W3.29: `trackType`, `isActive`, `deactivatedAt`, `deletedAt`
/// columns dropped from `curriculum_tracks`. The UNIQUE key is now
/// `{profileId, curriculumId}` — one track per curriculum per profile.
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
    CurriculumId curriculumId, {
    required int profileId,
  }) async {
    final all = await _database.trackDao.getAllTracks(curriculumId);
    final preferred = all.where((t) => t.profileId == profileId);
    if (preferred.isNotEmpty) return preferred.first;
    return all.isEmpty ? null : all.first;
  }

  Future<void> _pushCurriculumTrackIfCloud(
    CurriculumId curriculumId, {
    int? profileId,
  }) async {
    final engine = _syncEngine;
    if (engine == null) return;

    final pid = profileId ?? _activeProfileId;
    final row = await _resolveTrackRowForSync(curriculumId, profileId: pid);
    if (row == null) return;

    await engine.pushCurriculumTrack({
      'profile_id': row.profileId,
      'track_id': row.id,
      'curriculum_id': row.curriculumId,
      'state': row.state,
      'state_changed_at': row.stateChangedAt?.toIso8601String(),
      'activated_at': row.activatedAt.toIso8601String(),
      'pace_reset_date': row.paceResetDate?.toIso8601String(),
    });
  }

  @override
  Future<List<TrackType>> getActiveTracks(CurriculumId curriculumId) async {
    final tracks = await _database.trackDao.getActiveTracks(curriculumId);
    // W3.22: trackType dropped — all active tracks are implicitly 'personal'.
    return tracks.map((_) => TrackType.personal).toList();
  }

  @override
  Future<void> activateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    await _database.trackDao.activateTrack(curriculumId);
    await _pushCurriculumTrackIfCloud(curriculumId);
  }

  @override
  Future<void> deactivateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    // InvalidTrackOperationException from track_dao.dart propagates naturally
    // (no wrapping needed — both DAO and domain now throw the same type).
    await _database.trackDao.deactivateTrack(curriculumId, trackType);
    await _pushCurriculumTrackIfCloud(curriculumId);
  }

  @override
  Future<bool> isTrackActive(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    // W3.22: trackType dropped — check by profileId instead.
    return await _database.trackDao.isTrackActive(
      curriculumId,
      _activeProfileId,
    );
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
    await _pushCurriculumTrackIfCloud(curriculumId, profileId: profileId);
  }
}
