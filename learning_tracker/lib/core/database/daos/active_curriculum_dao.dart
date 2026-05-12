import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'active_curriculum_dao.g.dart';

/// Queries "active curricula" from the `curriculum_tracks` table.
///
/// A curriculum is active for a profile iff at least one row in
/// `curriculum_tracks` has `(profile_id = ?, curriculum_id = ?, is_active = 1)`.
/// This eliminates the former `active_curricula` table and its split-brain risk.
@DriftAccessor(tables: [CurriculumTracks])
class ActiveCurriculumDao extends DatabaseAccessor<UserDatabase>
    with _$ActiveCurriculumDaoMixin {
  ActiveCurriculumDao(super.db);

  // ========== Profile-Scoped Queries ==========

  /// Returns list of active curriculum IDs for a specific profile.
  Future<List<String>> getActiveCurriculaByProfile(int profileId) async {
    final rows =
        await (select(curriculumTracks)..where(
              (t) => t.profileId.equals(profileId) & t.isActive.equals(true),
            ))
            .get();
    return rows.map((r) => r.curriculumId).toSet().toList();
  }

  /// Watch stream of active curriculum IDs for a specific profile.
  Stream<List<String>> watchActiveCurriculaByProfile(int profileId) {
    return (select(curriculumTracks)..where(
          (t) => t.profileId.equals(profileId) & t.isActive.equals(true),
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
                    t.isActive.equals(true),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// Activate a curriculum for a specific profile (idempotent).
  ///
  /// No-op if a track already exists. Creates a default personal track row
  /// when called with no existing track (e.g. in tests or legacy flows).
  /// In production, prefer [TrackDao.initializeDefaultTracks].
  Future<void> activateByProfile(CurriculumId curriculum, int profileId) async {
    final alreadyActive = await isActiveForProfile(curriculum, profileId);
    if (alreadyActive) return;

    await into(curriculumTracks).insert(
      CurriculumTracksCompanion.insert(
        profileId: Value(profileId),
        curriculumId: curriculum.storageKey,
        trackType: TrackType.personal.storageKey,
        isActive: const Value(true),
        activatedAt: DateTimeFactory.nowUtc(),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Deactivate a curriculum for a specific profile (hard delete).
  ///
  /// Deletes all tracks for the (profile, curriculum) pair and their
  /// associated data (completions, goals, stages, etc.) via the track
  /// cascade. Throws [StateError] if this is the last active curriculum.
  Future<void> deactivateByProfile(
    CurriculumId curriculum,
    int profileId,
  ) async {
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
      await attachedDatabase.trackDao.deleteTrackAndData(track.id);
    }
  }

  /// Remove a curriculum from active for a profile without the last-curriculum
  /// guard. No-op — [deleteTrackAndData] already removes the track row; no
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
