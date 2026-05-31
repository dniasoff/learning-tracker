/// Tests for TrackDao.deleteTrackAndData, purgeHistory, and
/// initializeDefaultTracks — branches not yet exercised by existing track_dao
/// tests.
library;

import 'dart:convert';

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/exceptions/invalid_track_operation_exception.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';

import '../../../helpers/drift_memory.dart' show inMemoryDb, seedProfile;

void main() {
  late UserDatabase db;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
  });

  tearDown(() async {
    await db.close();
  });

  // ── helpers ────────────────────────────────────────────────────────────────

  Future<int> insertTrack({
    String curriculumId = 'mishnayos',
    String trackType = 'personal',
    int profileId = 1,
    bool isActive = true,
  }) => db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: profileId,
          curriculumId: curriculumId,
          stateChangedAt: DateTime.utc(2026, 1, 1),
          activatedAt: DateTime.utc(2026, 1, 1),
        ),
      );

  Future<int> insertGoal(int trackId) => db.goalDao.insertGoal(
    GoalsCompanion.insert(
      profileId: 1,
      curriculumId: 'mishnayos',
      trackId: trackId,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: DateTime.utc(2026, 1, 1),
    ),
  );

  Future<int> insertStage(int trackId) => db
      .into(db.stageDefinitions)
      .insert(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          schedule: const Value('{"type":"delay","delay_days":0}'),
        ),
      );

  // ── deleteTrackAndData ─────────────────────────────────────────────────────

  group('TrackDao.deleteTrackAndData', () {
    test('soft-deletes the track row (stamps deletedAt)', () async {
      final trackId = await insertTrack();

      await db.trackDao.deleteTrackAndData(trackId);

      final track = await db.trackDao.getTrackById(trackId);
      expect(track, isNotNull);
      expect(track!.state, 'deleted');
      expect(track.state, isNot('active'));
    });

    test('hard-deletes associated goals', () async {
      final trackId = await insertTrack();
      await insertGoal(trackId);

      final goalsBefore = await db.goalDao.getGoalsByTrack(trackId);
      expect(goalsBefore, hasLength(1));

      await db.trackDao.deleteTrackAndData(trackId);

      final goalsAfter = await db.goalDao.getGoalsByTrack(trackId);
      expect(goalsAfter, isEmpty);
    });

    test('hard-deletes associated stage definitions', () async {
      final trackId = await insertTrack();
      await insertStage(trackId);

      final stagesBefore = await db.stageDao.getStagesByTrack(trackId);
      expect(stagesBefore, hasLength(1));

      await db.trackDao.deleteTrackAndData(trackId);

      final stagesAfter = await db.stageDao.getStagesByTrack(trackId);
      expect(stagesAfter, isEmpty);
    });

    test('is a no-op when track does not exist', () async {
      // Should not throw.
      await db.trackDao.deleteTrackAndData(9999);
    });

    test('track row is preserved after soft-delete (not removed)', () async {
      final trackId = await insertTrack();

      await db.trackDao.deleteTrackAndData(trackId);

      // The row still exists — only soft-deleted.
      final all = await db.trackDao.getAllForProfile(1);
      expect(all.any((t) => t.id == trackId), isTrue);
    });

    test(
      'soft-deleted track does not appear in getActiveTracksForProfile',
      () async {
        final trackId = await insertTrack();

        final activeBefore = await db.trackDao.getActiveTracksForProfile(1);
        expect(activeBefore, isNotEmpty);

        await db.trackDao.deleteTrackAndData(trackId);

        final activeAfter = await db.trackDao.getActiveTracksForProfile(1);
        expect(activeAfter, isEmpty);
      },
    );
  });

  // ── initializeDefaultTracks ───────────────────────────────────────────────

  group('TrackDao.initializeDefaultTracks', () {
    test('creates a personal track when none exist', () async {
      await db.trackDao.initializeDefaultTracks(
        CurriculumId.mishnayos,
        profileId: 1,
      );

      final tracks = await db.trackDao.getActiveTracks(CurriculumId.mishnayos);
      expect(tracks, hasLength(1));
      expect(tracks.first.state, 'active');
      expect(tracks.first.state, 'active');
    });

    test(
      'is a no-op when tracks already exist for the curriculum+profile',
      () async {
        // Pre-insert a track.
        await insertTrack(curriculumId: 'mishnayos', profileId: 1);

        await db.trackDao.initializeDefaultTracks(
          CurriculumId.mishnayos,
          profileId: 1,
        );

        // Still only one track.
        final tracks = await db.trackDao.getAllTracks(CurriculumId.mishnayos);
        expect(tracks, hasLength(1));
      },
    );

    test('does not affect tracks for other profiles', () async {
      await db.trackDao.initializeDefaultTracks(
        CurriculumId.mishnayos,
        profileId: 2,
      );

      final tracksProfile1 = await db.trackDao.getActiveTracksForProfile(1);
      expect(tracksProfile1, isEmpty);

      final tracksProfile2 = await db.trackDao.getActiveTracksForProfile(2);
      expect(tracksProfile2, hasLength(1));
    });

    test('does not affect tracks for other curricula', () async {
      await db.trackDao.initializeDefaultTracks(
        CurriculumId.mishnayos,
        profileId: 1,
      );

      final bavliTracks = await db.trackDao.getAllTracks(CurriculumId.bavli);
      expect(bavliTracks, isEmpty);
    });
  });

  // ── purgeHistory — outbox tombstone (R5-3) ──────────────────────────────

  group('TrackDao.purgeHistory — sync tombstone', () {
    test(
      'enqueues an OutboxEntityKind.track tombstone row inside the transaction',
      () async {
        final trackId = await insertTrack(curriculumId: 'mishnayos');

        // Outbox must be empty before the purge.
        final before = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.track,
          1,
        );
        expect(before, isEmpty, reason: 'no outbox rows before purge');

        await db.trackDao.purgeHistory(trackId);

        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.track,
          1,
        );
        expect(
          rows,
          hasLength(1),
          reason: 'exactly one track outbox tombstone should be enqueued',
        );

        final row = rows.first;
        expect(row.entityKind, OutboxEntityKind.track);
        expect(
          row.entityKey,
          'track_purge:$trackId',
          reason: 'entityKey must identify the purge tombstone',
        );
        expect(row.profileId, 1);

        final payload = jsonDecode(row.payload) as Map<String, dynamic>;
        expect(payload['track_id'], trackId);
        expect(payload['curriculum_id'], 'mishnayos');
        // state must be 'deleted' so the receiving _upsertTrack can apply it.
        expect(
          payload['state'],
          'deleted',
          reason: 'state must be deleted so remote track is removed',
        );
        expect(
          payload['purged'],
          isTrue,
          reason: 'purged flag distinguishes a history-wipe from a soft-delete',
        );
        expect(
          payload.containsKey('purged_at'),
          isTrue,
          reason: 'purged_at timestamp must be present in payload',
        );
        expect(payload['profile_id'], 1);
      },
    );

    test(
      'does NOT enqueue an outbox tombstone when the track does not exist',
      () async {
        await db.trackDao.purgeHistory(9999);

        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.track,
          1,
        );
        expect(
          rows,
          isEmpty,
          reason: 'no-op for missing track — no outbox row',
        );
      },
    );

    test('hard-deletes the track row (not a soft-delete)', () async {
      final trackId = await insertTrack(curriculumId: 'mishnayos');

      await db.trackDao.purgeHistory(trackId);

      final track = await db.trackDao.getTrackById(trackId);
      expect(
        track,
        isNull,
        reason: 'purgeHistory hard-deletes the row; it should not exist',
      );
    });

    test(
      'enqueued tombstone entityKey differs from deleteTrackAndData tombstone key pattern',
      () async {
        // Regression: purge and soft-delete must not share the same outbox key
        // so that both can coexist in the outbox without conflict.
        final trackId = await insertTrack(curriculumId: 'mishnayos');

        await db.trackDao.purgeHistory(trackId);

        final rows = await db.outboxDao.getPendingByKind(
          OutboxEntityKind.track,
          1,
        );
        expect(rows, hasLength(1));
        expect(rows.first.entityKey, isNot('track_delete:$trackId'));
        expect(rows.first.entityKey, 'track_purge:$trackId');
      },
    );
  });

  // ── deactivateTrack ──────────────────────────────────────────────────────

  group('TrackDao.deactivateTrack', () {
    test('retires (no longer throws) — W3.22', () async {
      // W3.22: deactivateTrack now delegates to retireTrack instead of
      // throwing InvalidTrackOperationException. Verify it completes cleanly.
      await db.trackDao.activateTrack(CurriculumId.mishnayos);

      await expectLater(
        db.trackDao.deactivateTrack(CurriculumId.mishnayos),
        completes,
      );
    });

    test('InvalidTrackOperationException.toString contains message', () {
      const e = InvalidTrackOperationException('test message');
      expect(e.toString(), contains('test message'));
      expect(e.toString(), contains('InvalidTrackOperationException'));
    });
  });
}
