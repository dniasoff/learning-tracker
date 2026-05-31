import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/base_dao.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

part 'track_dao.g.dart';

/// Track lifecycle state constants. Must match the `state` column values
/// in [CurriculumTracks] (W3.28).
class TrackState {
  const TrackState._();

  static const active = 'active';
  static const retired = 'retired';
  static const archived = 'archived';
  static const deleted = 'deleted';
}

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

  /// Get all active tracks for a curriculum (state = 'active').
  Future<List<CurriculumTrack>> getActiveTracks(CurriculumId curriculumId) =>
      (select(curriculumTracks)..where(
            (t) =>
                t.curriculumId.equals(curriculumId.storageKey) &
                t.state.equals(TrackState.active),
          ))
          .get();

  /// Get all tracks (active and inactive) for a curriculum.
  Future<List<CurriculumTrack>> getAllTracks(CurriculumId curriculumId) =>
      (select(
        curriculumTracks,
      )..where((t) => t.curriculumId.equals(curriculumId.storageKey))).get();

  /// Check if the track for a curriculum is active (state = 'active').
  ///
  /// W3.22: trackType removed — one track per (profileId, curriculumId).
  Future<bool> isTrackActive(CurriculumId curriculumId, int profileId) async {
    final track =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.profileId.equals(profileId),
            ))
            .getSingleOrNull();

    return track?.state == TrackState.active;
  }

  /// Activate a track for a curriculum.
  ///
  /// If the track doesn't exist, creates it. If it exists and is not active,
  /// reactivates it with a new activatedAt + stateChangedAt timestamp.
  Future<void> activateTrack(
    CurriculumId curriculumId, {
    int profileId = 0,
  }) async {
    final now = DateTimeFactory.nowUtc();
    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.profileId.equals(profileId),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await into(curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId.storageKey,
          state: const Value(TrackState.active),
          stateChangedAt: now,
          activatedAt: now,
          lastReorderAt: Value(now),
        ),
      );
    } else if (existing.state != TrackState.active) {
      await (update(
        curriculumTracks,
      )..where((t) => t.id.equals(existing.id))).write(
        CurriculumTracksCompanion(
          state: const Value(TrackState.active),
          stateChangedAt: Value(now),
          activatedAt: Value(now),
          lastReorderAt: Value(now),
        ),
      );
    }
    // If already active, do nothing.
  }

  /// Retire a track for a curriculum (soft-deactivation, reversible).
  ///
  /// Sets state = 'retired'. The track can be reactivated via [activateTrack].
  Future<void> retireTrack(
    CurriculumId curriculumId, {
    int profileId = 0,
  }) async {
    final now = DateTimeFactory.nowUtc();
    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.curriculumId.equals(curriculumId.storageKey) &
                  t.profileId.equals(profileId),
            ))
            .getSingleOrNull();

    if (existing != null && existing.state == TrackState.active) {
      await (update(
        curriculumTracks,
      )..where((t) => t.id.equals(existing.id))).write(
        CurriculumTracksCompanion(
          state: const Value(TrackState.retired),
          stateChangedAt: Value(now),
        ),
      );
    }
  }

  /// Kept for API compatibility with callers that passed a TrackType.
  /// W3.22: trackType is no longer stored; the argument is ignored.
  Future<void> deactivateTrack(
    CurriculumId curriculumId, [
    // ignore: avoid_unused_constructor_parameters
    dynamic trackType,
  ]) => retireTrack(curriculumId);

  /// Get all active tracks for a profile.
  ///
  /// Returns only tracks where state = 'active'.
  Future<List<CurriculumTrack>> getActiveTracksForProfile(int profileId) =>
      (select(curriculumTracks)
            ..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.state.equals(TrackState.active),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.curriculumId)]))
          .get();

  /// Get all active tracks across every profile.
  ///
  /// Used by the device-restore path, which runs before any profile is
  /// selected (the active profile id is the sentinel 0 at that point), so it
  /// cannot scope to a single profile. Returns active tracks for ALL restored
  /// profiles so content re-import covers each one.
  Future<List<CurriculumTrack>> getAllActiveTracks() =>
      (select(curriculumTracks)
            ..where((t) => t.state.equals(TrackState.active))
            ..orderBy([(t) => OrderingTerm.asc(t.curriculumId)]))
          .get();

  /// Get a single track by its ID.
  Future<CurriculumTrack?> getTrackById(int trackId) => (select(
    curriculumTracks,
  )..where((t) => t.id.equals(trackId))).getSingleOrNull();

  /// Watch all active tracks for a profile.
  Stream<List<CurriculumTrack>> watchActiveTracksForProfile(int profileId) {
    return (select(curriculumTracks)
          ..where(
            (t) =>
                t.profileId.equals(profileId) &
                t.state.equals(TrackState.active),
          )
          ..orderBy([(t) => OrderingTerm.asc(t.curriculumId)]))
        .watch();
  }

  /// Soft-delete a track by setting state = 'deleted' and clearing config.
  ///
  /// Completions, streak events, and ledger rows are intentionally
  /// preserved (append-only invariant, FR5 / E24).
  ///
  /// Non-append-only configuration tables (goals, stages, daily plans, point
  /// configs, curriculum scopes, study day configs, learning order) are still
  /// hard-deleted because they hold no historical value once the track is gone.
  /// The track row itself is never removed; `state = 'deleted'` is the tombstone.
  Future<void> deleteTrackAndData(int trackId) async {
    final track = await getTrackById(trackId);
    if (track == null) return;

    final now = DateTimeFactory.nowUtc();
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
      // D7: also remove the program-enrolment row — otherwise a deleted program
      // track leaves a dangling profile_programs row (the scheduler would keep
      // projecting that program's tasks against a now-deleted track).
      await db.profileProgramDao.clearProgramForProfileAndCurriculum(
        track.profileId,
        track.curriculumId,
      );
      // Soft-delete: set state = 'deleted' instead of removing the row.
      await (update(
        curriculumTracks,
      )..where((t) => t.id.equals(trackId))).write(
        CurriculumTracksCompanion(
          state: const Value(TrackState.deleted),
          stateChangedAt: Value(now),
        ),
      );
      // I-5: push soft-delete to Firestore so other devices apply it.
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: track.profileId,
          entityKind: OutboxEntityKind.track,
          entityKey: 'track_delete:$trackId',
          payload: jsonEncode({
            'track_id': trackId,
            'curriculum_id': track.curriculumId,
            'state': TrackState.deleted,
            'deleted_at': now.toUtc().toIso8601String(),
            'profile_id': track.profileId,
          }),
          createdAt: now,
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

  /// Upsert a track row from a remote sync payload keyed by
  /// (profileId, curriculumId). Replaces the current state fields with
  /// the remote values.
  ///
  /// W3.22: trackType parameter removed — use state instead.
  Future<void> upsertFromSync({
    required int profileId,
    required CurriculumId curriculumId,
    required String state,
    required DateTime activatedAt,
    required DateTime stateChangedAt,
    DateTime? paceResetDate,
  }) async {
    final existing =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.curriculumId.equals(curriculumId.storageKey),
            ))
            .getSingleOrNull();

    if (existing == null) {
      await into(curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId.storageKey,
          state: Value(state),
          stateChangedAt: stateChangedAt,
          activatedAt: activatedAt,
          paceResetDate: Value(paceResetDate),
        ),
      );
    } else {
      await (update(
        curriculumTracks,
      )..where((t) => t.id.equals(existing.id))).write(
        CurriculumTracksCompanion(
          state: Value(state),
          stateChangedAt: Value(stateChangedAt),
          activatedAt: Value(activatedAt),
          paceResetDate: Value(paceResetDate),
        ),
      );
    }
  }

  /// Count active tracks for a profile.
  Future<int> countActiveTracksForProfile(int profileId) async {
    final tracks =
        await (select(curriculumTracks)..where(
              (t) =>
                  t.profileId.equals(profileId) &
                  t.state.equals(TrackState.active),
            ))
            .get();
    return tracks.length;
  }

  /// Restore a soft-deleted track or create a new one.
  ///
  /// * Found + deleted/retired  → reactivates row, resets [activatedAt] to now.
  ///   Returns its id.
  /// * Found + active           → returns id (idempotent).
  /// * Not found                → inserts new row. Returns new id.
  Future<int> restoreOrCreate({
    required int profileId,
    required CurriculumId curriculumId,
  }) async {
    final now = DateTimeFactory.nowUtc();
    final existing =
        await (select(curriculumTracks)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId.storageKey),
              )
              ..limit(1))
            .getSingleOrNull();

    if (existing != null) {
      if (existing.state != TrackState.active) {
        await (update(
          curriculumTracks,
        )..where((t) => t.id.equals(existing.id))).write(
          CurriculumTracksCompanion(
            state: const Value(TrackState.active),
            stateChangedAt: Value(now),
            activatedAt: Value(now),
            // Reset amnesty to activation time so no pre-existing tasks are
            // erroneously amnestied on re-activation.
            lastReorderAt: Value(now),
          ),
        );
      }
      return existing.id;
    }

    return into(curriculumTracks).insert(
      CurriculumTracksCompanion.insert(
        profileId: profileId,
        curriculumId: curriculumId.storageKey,
        state: const Value(TrackState.active),
        stateChangedAt: now,
        activatedAt: now,
        // lastReorderAt = activatedAt so the default (canonical) order is
        // treated as the initial reorder baseline and no overdue amnesty fires
        // on first activation.
        lastReorderAt: Value(now),
      ),
    );
  }

  /// Physically remove all data for [trackId] — completions (tombstoned),
  /// config, and the track row itself.
  ///
  /// Use this when the user explicitly requests "Delete and wipe history".
  /// Unlike [deleteTrackAndData], this leaves no tombstone.
  /// streak_events are profile-scoped and are not touched.
  ///
  /// C3: completion_events are never deleted (append-only, N8 invariant).
  /// Instead, each event row is stamped with [purgedAt] as a tombstone.
  /// N8 guarantees: completion_events row count never decreases after purge.
  Future<void> purgeHistory(int trackId) async {
    final track = await getTrackById(trackId);
    if (track == null) return;

    await db.transaction(() async {
      // C3: stamp purgedAt on completion_events (tombstone — never delete rows).
      final purgedAt = DateTimeFactory.nowUtc();
      final completionsForTrack = await db.completionDao.getCompletionsByTrack(
        trackId,
      );
      for (final c in completionsForTrack) {
        await (db.update(db.completionEvents)..where(
              (t) =>
                  t.profileId.equals(c.profileId) &
                  t.sefariaRef.equals(c.sefariaRef) &
                  t.stageId.equals(c.stageId) &
                  t.trackType.equals(c.trackType) &
                  t.curriculumId.equals(c.curriculumId),
            ))
            .write(CompletionEventsCompanion(purgedAt: Value(purgedAt)));
      }
      await db.goalDao.deleteGoalsForTrack(trackId);
      await (db.delete(
        db.stageDefinitions,
      )..where((t) => t.trackId.equals(trackId))).go();
      await db.dailyPlanDao.deletePlansByTrack(trackId);
      await db.pointConfigDao.deleteAllForTrack(trackId);
      await db.curriculumScopeDao.clearScopesForTrack(trackId);
      await db.studyDayConfigDao.deleteConfigsForTrack(trackId);
      await db.trackLearningOrderDao.deleteByTrack(trackId);
      // D7: also remove the program-enrolment row (see deleteTrackAndData).
      await db.profileProgramDao.clearProgramForProfileAndCurriculum(
        track.profileId,
        track.curriculumId,
      );
      // Hard-delete the track row. Bookmarks cascade-delete via ON DELETE CASCADE (C2).
      // Learning ledger trackId is SET NULL via ON DELETE SET NULL.
      await (db.delete(
        curriculumTracks,
      )..where((t) => t.id.equals(trackId))).go();
      // R5-3: push a purge tombstone so other devices replicate the wipe.
      //
      // purgeHistory hard-deletes the track row (unlike deleteTrackAndData which
      // soft-deletes to 'deleted'). We use the same OutboxEntityKind.track kind
      // so the existing pushTrack pipeline carries it to Firestore. The payload
      // uses state = 'deleted' — the closest expressible state in the current
      // track_config merge path — plus a 'purged: true' flag and 'purged_at'
      // timestamp so a future purge-aware merger can distinguish a full history
      // wipe from a simple soft-delete. Completion-level purgedAt stamps are
      // NOT individually replicated here: the track tombstone ensures the track
      // is removed on remote, preventing further completions against it; the
      // orphaned completion documents (already stamped with purged_at locally)
      // will be superseded if the remote ever re-syncs from this device's
      // completion outbox rows (each completion push is idempotent via its
      // natural-key doc ID).
      await db.outboxDao.insertOutboxRow(
        OutboxCompanion.insert(
          profileId: track.profileId,
          entityKind: OutboxEntityKind.track,
          entityKey: 'track_purge:$trackId',
          payload: jsonEncode({
            'track_id': trackId,
            'curriculum_id': track.curriculumId,
            'state': TrackState.deleted,
            'purged_at': purgedAt.toUtc().toIso8601String(),
            'purged': true,
            'profile_id': track.profileId,
          }),
          createdAt: purgedAt,
        ),
      );
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

  /// Stamp the reorder amnesty timestamp for [trackId].
  ///
  /// Must be called immediately after any content-order change (sedarim,
  /// masechtos, or whole-curriculum reorder / reset). The projection filter in
  /// `_buildProjectionTasks` uses this timestamp to amnesty overdue items that
  /// were scheduled before the most recent reorder.
  ///
  /// Do NOT call this for pace changes, stage-config changes, bookmark
  /// advances, or profile-level edits — only for content order changes.
  Future<void> stampReorderAt(int trackId, {DateTime? at}) async {
    final ts = at ?? DateTimeFactory.nowUtc();
    await (update(curriculumTracks)..where((t) => t.id.equals(trackId))).write(
      CurriculumTracksCompanion(lastReorderAt: Value(ts)),
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
      final now = DateTimeFactory.nowUtc();
      await into(curriculumTracks).insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId.storageKey,
          state: const Value(TrackState.active),
          stateChangedAt: now,
          activatedAt: now,
          lastReorderAt: Value(now),
        ),
      );
    }
  }
}
