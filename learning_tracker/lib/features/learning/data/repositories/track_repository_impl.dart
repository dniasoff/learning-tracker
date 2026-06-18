import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/codec/track_codec.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';

/// Implementation of [TrackRepository] using Drift database.
///
/// W3.28/W3.29: `isActive`, `deactivatedAt`, `deletedAt` columns dropped from
/// `curriculum_tracks`. The UNIQUE key is `{profileId, curriculumId}` — one
/// track per curriculum per profile.
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

  static const _trackCodec = TrackCodec();

  Future<void> _pushCurriculumTrackIfCloud(
    CurriculumId curriculumId, {
    int? profileId,
  }) async {
    final engine = _syncEngine;
    if (engine == null) return;

    final pid = profileId ?? _activeProfileId;
    final row = await _resolveTrackRowForSync(curriculumId, profileId: pid);
    if (row == null) return;

    await engine.pushCurriculumTrack(
      _trackCodec.encode(
        TrackRow(
          profileId: row.profileId,
          trackId: row.id,
          curriculumId: row.curriculumId,
          state: row.state,
          stateChangedAt: row.stateChangedAt,
          activatedAt: row.activatedAt,
          paceResetDate: row.paceResetDate,
        ),
      ),
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
