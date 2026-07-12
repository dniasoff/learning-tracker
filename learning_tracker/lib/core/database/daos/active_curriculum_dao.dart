import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/daos/dao_invariant_error.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'active_curriculum_dao.g.dart';

/// Queries "active curricula" from the `curriculum_tracks` table.
///
/// A curriculum is active for a profile iff at least one row in
/// `curriculum_tracks` has `(profile_id = ?, curriculum_id = ?, state = 'active')`.
/// This eliminates the former `active_curricula` table and its split-brain risk.
///
/// W3.22/W3.28: uses `state = 'active'` instead of `is_active = 1`.
@DriftAccessor(tables: [CurriculumTracks])
class ActiveCurriculumDao extends DatabaseAccessor<UserDatabase>
    with
        _$ActiveCurriculumDaoMixin,
        BaseDao<$CurriculumTracksTable, CurriculumTrack, UserDatabase> {
  ActiveCurriculumDao(super.db);

  @override
  TableInfo<$CurriculumTracksTable, CurriculumTrack> get table =>
      curriculumTracks;

  @override
  Expression<int> idColumn($CurriculumTracksTable t) => t.id;

  @override
  Expression<int> profileIdColumn($CurriculumTracksTable t) => t.profileId;

  // ========== Profile-Scoped Queries ==========

  /// Returns list of active curriculum IDs for a specific profile.
  Future<List<String>> getActiveCurriculaByProfile(int profileId) async {
    final rows =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.state.equals(TrackState.active),
            ))
            .get();
    return rows.map((r) => r.curriculumId).toSet().toList();
  }

  /// Watch stream of active curriculum IDs for a specific profile.
  Stream<List<String>> watchActiveCurriculaByProfile(int profileId) {
    return (select(curriculumTracks)..where(
          (t) =>
              t.profileId.equals(profileId) & t.state.equals(TrackState.active),
        ))
        .watch()
        .map((rows) => rows.map((r) => r.curriculumId).toSet().toList());
  }

  /// Check if a curriculum is currently active for a specific profile.
  Future<bool> isActiveForProfile(
    CurriculumId curriculum,
    int profileId,
  ) async {
    final row =
        await (select(curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculum.storageKey) &
                    t.state.equals(TrackState.active),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Activate a curriculum for a specific profile (idempotent).
  ///
  /// No-op if a track already exists with state = 'active'. Creates a default
  /// track row when called with no existing track.
  /// In production, prefer [TrackDao.initializeDefaultTracks].
  Future<void> activateByProfile(CurriculumId curriculum, int profileId) async {
    final alreadyActive = await isActiveForProfile(curriculum, profileId);
    if (alreadyActive) return;

    final now = DateTimeFactory.nowUtc();
    await into(curriculumTracks).insert(
      CurriculumTracksCompanion.insert(
        profileId: profileId,
        curriculumId: curriculum.storageKey,
        state: const Value(TrackState.active),
        stateChangedAt: now,
        activatedAt: now,
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Deactivate a curriculum for a specific profile.
  ///
  /// Delegates to [TrackDao.deleteTrackAndData] for each track belonging to
  /// the (profile, curriculum) pair. Throws [DaoInvariantError] (code
  /// [DaoErrorCode.lastActiveCurriculum]) if this is the last active
  /// curriculum.
  Future<void> deactivateByProfile(
    CurriculumId curriculum,
    int profileId,
  ) async {
    final activeForProfile = await getActiveCurriculaByProfile(profileId);
    if (activeForProfile.length <= 1) {
      // AUD-core-database-14 (EH-5): stable code, not a pre-formatted
      // English message.
      throw DaoInvariantError(DaoErrorCode.lastActiveCurriculum);
    }

    final tracks =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculum.storageKey),
            ))
            .get();

    for (final track in tracks) {
      await attachedDatabase.trackDao.deleteTrackAndData(track.id);
    }
  }

  /// Archive a curriculum for a specific profile — like [deactivateByProfile]
  /// but preserves the track's configuration data (goals/stages/point
  /// config/etc.) via [TrackDao.archiveTrack] instead of hard-deleting it
  /// via [TrackDao.deleteTrackAndData] (AUD-profiles-01).
  ///
  /// Throws [StateError] if this is the last active curriculum.
  Future<void> archiveByProfile(CurriculumId curriculum, int profileId) async {
    final activeForProfile = await getActiveCurriculaByProfile(profileId);
    if (activeForProfile.length <= 1) {
      throw StateError(
        'Cannot deactivate the last active curriculum for this profile',
      );
    }

    final tracks =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculum.storageKey),
            ))
            .get();

    for (final track in tracks) {
      await attachedDatabase.trackDao.archiveTrack(track.id);
    }
  }

  /// Remove a curriculum from active for a profile without the last-curriculum
  /// guard. No-op — [deleteTrackAndData] already updates the track state; no
  /// separate active_curricula row exists to clean up.
  Future<void> forceRemoveForProfile(
    CurriculumId curriculum,
    int profileId,
  ) async {}

  // ========== Legacy Profile-0 Methods (delegate to ByProfile) ==========

  Future<List<String>> getActiveCurricula() => getActiveCurriculaByProfile(0);

  Stream<List<String>> watchActiveCurricula() =>
      watchActiveCurriculaByProfile(0);

  Future<bool> isActive(CurriculumId curriculum) =>
      isActiveForProfile(curriculum, 0);

  Future<void> activate(CurriculumId curriculum) =>
      activateByProfile(curriculum, 0);

  Future<void> deactivate(CurriculumId curriculum) =>
      deactivateByProfile(curriculum, 0);
}
