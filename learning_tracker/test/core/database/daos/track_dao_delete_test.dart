/// Tests for TrackDao.deleteTrackAndData and initializeDefaultTracks —
/// branches not yet exercised by existing track_dao tests.
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

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
          delayDays: 0,
        ),
      );

  // ── deleteTrackAndData ─────────────────────────────────────────────────────

  group('TrackDao.deleteTrackAndData', () {
    test('soft-deletes the track row (stamps deletedAt)', () async {
      final trackId = await insertTrack();

      await db.trackDao.deleteTrackAndData(trackId);

      final track = await db.trackDao.getTrackById(trackId);
      expect(track, isNotNull);
      expect(track!.deletedAt, isNotNull);
      expect(track.isActive, isFalse);
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
      expect(tracks.first.trackType, TrackType.personal.storageKey);
      expect(tracks.first.isActive, isTrue);
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

  // ── deactivateTrack ──────────────────────────────────────────────────────

  group('TrackDao.deactivateTrack', () {
    test(
      'throws InvalidOperationException when deactivating personal track',
      () async {
        await db.trackDao.activateTrack(
          CurriculumId.mishnayos,
          TrackType.personal,
        );

        expect(
          () => db.trackDao.deactivateTrack(
            CurriculumId.mishnayos,
            TrackType.personal,
          ),
          throwsA(isA<InvalidOperationException>()),
        );
      },
    );

    test('InvalidOperationException.toString contains message', () {
      const e = InvalidOperationException('test message');
      expect(e.toString(), contains('test message'));
      expect(e.toString(), contains('InvalidOperationException'));
    });
  });
}
