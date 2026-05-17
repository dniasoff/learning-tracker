import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'track_dao.g.dart';

@DriftAccessor(tables: [CurriculumTracks])
class TrackDao extends DatabaseAccessor<UserDatabase>
    with
        _$TrackDaoMixin,
        BaseDao<$CurriculumTracksTable, CurriculumTrack, UserDatabase> {
  TrackDao(super.db);

  @override
  TableInfo<$CurriculumTracksTable, CurriculumTrack> get table =>
      curriculumTracks;

  @override
  Expression<int> idColumn($CurriculumTracksTable t) => t.id;

  @override
  Expression<int> profileIdColumn($CurriculumTracksTable t) => t.profileId;

  /// Get all active tracks for a curriculum.
  ///
  /// Returns only tracks where isActive = true and deletedAt IS NULL.
  Future<List<CurriculumTrack>> getActiveTracks(CurriculumId curriculumId) =>
      (select(curriculumTracks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId.storageKey) &
                t.isActive.equals(true) &
                t.deletedAt.isNull(),
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
    TrackType trackType, {
    int profileId = 0,
  }) async {
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
          profileId: profileId,
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

  /// Get all active tracks for a profile.
  ///
  /// Returns only tracks where isActive = true and deletedAt IS NULL.
  Future<List<CurriculumTrack>> getActiveTracksForProfile(int profileId) =>
      (select(curriculumTracks)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.isActive.equals(true) &
                  t.deletedAt.isNull(),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.curriculumId)]))
          .get();

  /// Get a single track by its ID.
  Future<CurriculumTrack?> getTrackById(int trackId) => (select(
    curriculumTracks,
  )..where((t) => t.id.equals(trackId))).getSingleOrNull();

  /// Watch all active tracks for a profile.
  ///
  /// Emits only tracks where isActive = true and deletedAt IS NULL.
  Stream<List<CurriculumTrack>> watchActiveTracksForProfile(int profileId) {
    return (select(curriculumTracks)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.isActive.equals(true) &
                t.deletedAt.isNull(),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.curriculumId)]))
        .watch();
  }

  /// Soft-delete a track by stamping [deletedAt] and clearing configuration
  /// data. Completions, streak events, and ledger rows are intentionally
  /// preserved (append-only invariant, FR5 / E24).
  ///
  /// Non-append-only configuration tables (goals, stages, daily plans, point
  /// configs, curriculum scopes, study day configs, learning order) are still
  /// hard-deleted because they hold no historical value once the track is gone.
  /// The track row itself is never removed; [deletedAt] is the tombstone.
  Future<void> deleteTrackAndData(int trackId) async {
    final track = await getTrackById(trackId);
    if (track == null) return;

    await db.transaction(() async {
      await db.goalDao.deleteGoalsForTrack(trackId);
      await (db.delete(
        db.stageDefinitions,
      )..where((t) => t.trackId.equals(trackId))).go();
      // Completions are NOT deleted — they are append-only (FR5 / E24).
      await db.dailyPlanDao.deletePlansByTrack(trackId);
      await db.pointConfigDao.deleteAllForTrack(trackId);
      await db.curriculumScopeDao.clearScopesForTrack(trackId);
      await db.studyDayConfigDao.deleteConfigsForTrack(trackId);
      await db.trackLearningOrderDao.deleteByTrack(trackId);
      // Soft-delete: stamp deletedAt instead of removing the row.
      await (update(
        curriculumTracks,
      )..where((t) => t.id.equals(trackId))).write(
        CurriculumTracksCompanion(
          isActive: const Value(false),
          deletedAt: Value(DateTimeFactory.nowUtc()),
        ),
      );
      final curriculum = CurriculumId.values
          .where((c) => c.storageKey == track.curriculumId)
          .firstOrNull;
      if (curriculum != null) {
        await db.activeCurriculumDao.forceRemoveForProfile(
          curriculum,
          track.profileId,
        );
      }
    });
  }

  /// Get every track row for a profile (active and inactive).
  ///
  /// Used by the sync engine to push the full per-profile track state to
  /// Firestore.
  Future<List<CurriculumTrack>> getAllForProfile(int profileId) => (select(
    curriculumTracks,
  )..where((t) => t.profileId.equals(profileId))).get();

  /// Upsert a track row from a remote sync payload keyed by the
  /// (profileId, curriculumId, trackType) composite. Replaces the current
  /// state fields with the remote values.
  Future<void> upsertFromSync({
    required int profileId,
    required CurriculumId curriculumId,
    required TrackType trackType,
    required bool isActive,
    required DateTime activatedAt,
    DateTime? deactivatedAt,
    DateTime? paceResetDate,
  }) async {
    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.trackType.equals(trackType.storageKey),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await into(curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId.storageKey,
          trackType: trackType.storageKey,
          isActive: Value(isActive),
          activatedAt: activatedAt,
          deactivatedAt: Value(deactivatedAt),
          paceResetDate: Value(paceResetDate),
        ),
      );
    } else {
      await (update(
        curriculumTracks,
      )..where((t) => t.id.equals(existing.id))).write(
        CurriculumTracksCompanion(
          isActive: Value(isActive),
          activatedAt: Value(activatedAt),
          deactivatedAt: Value(deactivatedAt),
          paceResetDate: Value(paceResetDate),
        ),
      );
    }
  }

  /// Count active tracks for a profile.
  ///
  /// Excludes soft-deleted tracks (deletedAt IS NOT NULL).
  Future<int> countActiveTracksForProfile(int profileId) async {
    final tracks =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.isActive.equals(true) &
                  t.deletedAt.isNull(),
            ))
            .get();
    return tracks.length;
  }

  /// Restore a soft-deleted track or create a new one.
  ///
  /// Looks up the (profileId, curriculumId, trackType) triple, ignoring deletedAt.
  ///
  /// * Found + soft-deleted  → clears deletedAt, reactivates row, resets
  ///   [activatedAt] to now (new learning session). Returns its id.
  /// * Found + active        → returns id (idempotent).
  /// * Not found             → inserts new row. Returns new id.
  ///
  /// Completions from before the restore are intentionally preserved — they
  /// count toward lifetime stats. The new [activatedAt] acts as a session
  /// boundary: current-session progress is computed from completions where
  /// completedAt >= activatedAt, so the track starts at 0% for the new cycle.
  ///
  /// Use this instead of [initializeDefaultTracks] when re-adding a previously
  /// deleted track to avoid UNIQUE(profileId, curriculumId, trackType) violations.
  Future<int> restoreOrCreate({
    required int profileId,
    required CurriculumId curriculumId,
    required TrackType trackType,
  }) async {
    final existing =
        await (select(curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId.storageKey) &
                    t.trackType.equals(trackType.storageKey),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      if (existing.deletedAt != null) {
        // Reset activatedAt to now so this is treated as a new learning session.
        // Old completions stay in the DB for lifetime stats; current-session
        // progress queries filter by completedAt >= activatedAt.
        await (update(curriculumTracks)
              ..where((t) => t.id.equals(existing.id)))
            .write(
          CurriculumTracksCompanion(
            isActive: const Value(true),
            activatedAt: Value(DateTimeFactory.nowUtc()),
            deactivatedAt: const Value(null),
            deletedAt: const Value(null),
          ),
        );
      }
      return existing.id;
    }

    return into(curriculumTracks).insert(
      CurriculumTracksCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId.storageKey,
        trackType: trackType.storageKey,
        isActive: const Value(true),
        activatedAt: DateTimeFactory.nowUtc(),
      ),
    );
  }

  /// Physically remove all data for [trackId] — completions, config, and the
  /// track row itself.
  ///
  /// Use this when the user explicitly requests "Delete and wipe history".
  /// Unlike [deleteTrackAndData], this leaves no tombstone: the track row is
  /// hard-deleted so [restoreOrCreate] will create a brand-new row next time.
  /// streak_events are profile-scoped and are not touched.
  Future<void> purgeHistory(int trackId) async {
    // Fetch before the transaction — the row will be gone afterwards.
    final track = await getTrackById(trackId);
    if (track == null) return;

    await db.transaction(() async {
      await (db.delete(
        db.completions,
      )..where((t) => t.trackId.equals(trackId))).go();
      await db.goalDao.deleteGoalsForTrack(trackId);
      await (db.delete(
        db.stageDefinitions,
      )..where((t) => t.trackId.equals(trackId))).go();
      await db.dailyPlanDao.deletePlansByTrack(trackId);
      await db.pointConfigDao.deleteAllForTrack(trackId);
      await db.curriculumScopeDao.clearScopesForTrack(trackId);
      await db.studyDayConfigDao.deleteConfigsForTrack(trackId);
      await db.trackLearningOrderDao.deleteByTrack(trackId);
      // Hard-delete the track row — no tombstone left behind.
      await (db.delete(
        curriculumTracks,
      )..where((t) => t.id.equals(trackId))).go();
    });

    final curriculum = CurriculumId.values
        .where((c) => c.storageKey == track.curriculumId)
        .firstOrNull;
    if (curriculum != null) {
      await db.activeCurriculumDao.forceRemoveForProfile(
        curriculum,
        track.profileId,
      );
    }
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
          profileId: profileId,
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
