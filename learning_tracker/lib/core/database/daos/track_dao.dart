import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'track_dao.g.dart';

@DriftAccessor(tables: [CurriculumTracks])
class TrackDao extends DatabaseAccessor<UserDatabase> with _$TrackDaoMixin {
  TrackDao(super.db);

  /// Get all active tracks for a curriculum.
  ///
  /// Returns only tracks where isActive = true.
  Future<List<CurriculumTrack>> getActiveTracks(CurriculumId curriculumId) =>
      (select(curriculumTracks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId.storageKey) &
                t.isActive.equals(true),
          ))
          .get();

  /// Get all tracks (active and inactive) for a curriculum.
  Future<List<CurriculumTrack>> getAllTracks(CurriculumId curriculumId) =>
      (select(
        curriculumTracks,
      )..where((t) => t.curriculumId.equals(curriculumId.storageKey))).get();

  /// Check if a specific track is active for a curriculum.
  Future<bool> isTrackActive(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    final track =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.trackType.equals(trackType.storageKey),
            ))
            .getSingleOrNull();

    return track?.isActive ?? false;
  }

  /// Activate a track for a curriculum.
  ///
  /// If the track doesn't exist, creates it. If it exists and is inactive,
  /// reactivates it with a new activatedAt timestamp.
  Future<void> activateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.trackType.equals(trackType.storageKey),
            ))
            .getSingleOrNull();

    if (existing == null) {
      // Create new active track
      await into(curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          curriculumId: curriculumId.storageKey,
          trackType: trackType.storageKey,
          isActive: const Value(true),
          activatedAt: DateTimeFactory.nowUtc(),
        ),
      );
    } else if (!existing.isActive) {
      // Reactivate existing track
      await (update(curriculumTracks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId.storageKey) &
                t.trackType.equals(trackType.storageKey),
          ))
          .write(
            CurriculumTracksCompanion(
              isActive: const Value(true),
              activatedAt: Value(DateTimeFactory.nowUtc()),
              deactivatedAt: const Value(null),
            ),
          );
    }
    // If already active, do nothing
  }

  /// Deactivate a track for a curriculum.
  ///
  /// Cannot deactivate the personal track. Preserves the track record
  /// (doesn't delete) to maintain history.
  Future<void> deactivateTrack(
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    if (trackType == TrackType.personal) {
      throw const InvalidOperationException(
        'Cannot deactivate personal track - it is always active',
      );
    }

    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.trackType.equals(trackType.storageKey),
            ))
            .getSingleOrNull();

    if (existing != null && existing.isActive) {
      await (update(curriculumTracks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId.storageKey) &
                t.trackType.equals(trackType.storageKey),
          ))
          .write(
            CurriculumTracksCompanion(
              isActive: const Value(false),
              deactivatedAt: Value(DateTimeFactory.nowUtc()),
            ),
          );
    }
  }

  /// Get all active (non-archived) tracks for a profile.
  Future<List<CurriculumTrack>> getActiveTracksForProfile(int profileId) =>
      (select(curriculumTracks)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.isActive.equals(true) &
                  t.archivedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.curriculumId)]))
          .get();

  /// Get a single track by its ID.
  Future<CurriculumTrack?> getTrackById(int trackId) => (select(
    curriculumTracks,
  )..where((t) => t.id.equals(trackId))).getSingleOrNull();

  /// Watch all active (non-archived) tracks for a profile.
  Stream<List<CurriculumTrack>> watchActiveTracksForProfile(int profileId) {
    return (select(curriculumTracks)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.isActive.equals(true) &
                t.archivedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.curriculumId)]))
        .watch();
  }

  /// Watch all archived tracks for a profile.
  Stream<List<CurriculumTrack>> watchArchivedTracksForProfile(int profileId) {
    return (select(curriculumTracks)
          ..where(
            (t) => t.profileId.equals(profileId) & t.archivedAt.isNotNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.curriculumId)]))
        .watch();
  }

  /// Archive a track — hides from dashboard/scheduler but preserves data.
  Future<void> archiveTrack(
    int profileId,
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    await (update(curriculumTracks)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.curriculumId.equals(curriculumId.storageKey) &
              t.trackType.equals(trackType.storageKey),
        ))
        .write(
          CurriculumTracksCompanion(
            archivedAt: Value(DateTimeFactory.nowUtc()),
          ),
        );
  }

  /// Unarchive a track — makes it active again.
  Future<void> unarchiveTrack(
    int profileId,
    CurriculumId curriculumId,
    TrackType trackType,
  ) async {
    await (update(curriculumTracks)..where(
          (t) =>
              t.profileId.equals(profileId) &
              t.curriculumId.equals(curriculumId.storageKey) &
              t.trackType.equals(trackType.storageKey),
        ))
        .write(const CurriculumTracksCompanion(archivedAt: Value(null)));
  }

  /// Count active (non-archived) tracks for a profile.
  Future<int> countActiveTracksForProfile(int profileId) async {
    final tracks =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.isActive.equals(true) &
                  t.archivedAt.isNull(),
            ))
            .get();
    return tracks.length;
  }

  /// Reset the pace baseline for a track (Recovery Action).
  ///
  /// Sets `paceResetDate` to now. Does NOT touch completions or chazara data.
  Future<void> resetPace(int trackId) async {
    await (update(curriculumTracks)..where((t) => t.id.equals(trackId))).write(
      CurriculumTracksCompanion(paceResetDate: Value(DateTimeFactory.nowUtc())),
    );
  }

  /// Initialize default tracks for a curriculum and profile.
  ///
  /// Creates only the personal track (active by default).
  /// Should be called when a curriculum is first activated.
  Future<void> initializeDefaultTracks(
    CurriculumId curriculumId, {
    int profileId = 0,
  }) async {
    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.profileId.equals(profileId),
            ))
            .get();

    if (existing.isEmpty) {
      await into(curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          profileId: Value(profileId),
          curriculumId: curriculumId.storageKey,
          trackType: TrackType.personal.storageKey,
          isActive: const Value(true),
          activatedAt: DateTimeFactory.nowUtc(),
        ),
      );
    }
  }
}

/// Exception thrown when attempting an invalid track operation.
class InvalidOperationException implements Exception {
  const InvalidOperationException(this.message);
  final String message;

  @override
  String toString() => 'InvalidOperationException: $message';
}
