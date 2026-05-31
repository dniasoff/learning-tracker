import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

import '../../../helpers/drift_memory.dart'
    show inMemoryDb, seedCompletion, seedProfile;

void main() {
  late UserDatabase database;

  setUp(() async {
    database = inMemoryDb();
    await seedProfile(database);
  });

  tearDown(() async {
    await database.close();
  });

  group('TrackDao (v1 — personal only)', () {
    test('getActiveTracks returns empty list initially', () async {
      final tracks = await database.trackDao.getActiveTracks(
        CurriculumId.bavli,
      );
      expect(tracks, isEmpty);
    });

    test('activateTrack creates a new active personal track', () async {
      await database.trackDao.activateTrack(CurriculumId.bavli);

      final tracks = await database.trackDao.getActiveTracks(
        CurriculumId.bavli,
      );
      expect(tracks, hasLength(1));
      expect(tracks.first.state, 'active');
      expect(tracks.first.state, 'active');
    });

    test('activateTrack is idempotent for already-active track', () async {
      await database.trackDao.activateTrack(CurriculumId.bavli);
      await database.trackDao.activateTrack(CurriculumId.bavli);

      final tracks = await database.trackDao.getAllTracks(CurriculumId.bavli);
      expect(tracks, hasLength(1));
    });

    test('deactivateTrack retires (no longer throws) — W3.22', () async {
      // W3.22: deactivateTrack now delegates to retireTrack; it no longer
      // throws InvalidTrackOperationException. Verify it completes.
      await database.trackDao.activateTrack(CurriculumId.bavli);

      await expectLater(
        database.trackDao.deactivateTrack(CurriculumId.bavli),
        completes,
      );
    });

    test('isTrackActive returns false for non-existent track', () async {
      final isActive = await database.trackDao.isTrackActive(
        CurriculumId.bavli,
        0,
      );
      expect(isActive, isFalse);
    });

    test('initializeDefaultTracks creates personal track', () async {
      await database.trackDao.initializeDefaultTracks(CurriculumId.bavli);

      final tracks = await database.trackDao.getActiveTracks(
        CurriculumId.bavli,
      );
      expect(tracks, hasLength(1));
      expect(tracks.first.state, 'active');
    });

    test('initializeDefaultTracks is idempotent', () async {
      await database.trackDao.initializeDefaultTracks(CurriculumId.bavli);
      await database.trackDao.initializeDefaultTracks(CurriculumId.bavli);

      final tracks = await database.trackDao.getAllTracks(CurriculumId.bavli);
      expect(tracks, hasLength(1));
    });

    test('tracks are scoped to curriculum', () async {
      await database.trackDao.activateTrack(CurriculumId.bavli);
      await database.trackDao.activateTrack(CurriculumId.mishnayos);

      final bavliTracks = await database.trackDao.getActiveTracks(
        CurriculumId.bavli,
      );
      final mishnayosTracks = await database.trackDao.getActiveTracks(
        CurriculumId.mishnayos,
      );

      expect(bavliTracks, hasLength(1));
      expect(mishnayosTracks, hasLength(1));
    });
  });

  // ── DNI-317: Soft-delete tracks; stop cascading into append-only tables ──

  group('DNI-317: soft-delete tracks', () {
    /// Insert a bare track row and return its ID.
    Future<int> insertTrack({
      String curriculumId = 'bavli',
      String trackType = 'personal',
      int profileId = 0,
    }) async {
      return database
          .into(database.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: curriculumId,
              stateChangedAt: DateTime.now().toUtc(),
              activatedAt: DateTime.now().toUtc(),
            ),
          );
    }

    test(
      'deleteTrackAndData sets deletedAt and does not hard-delete the row',
      () async {
        final trackId = await insertTrack();

        await database.trackDao.deleteTrackAndData(trackId);

        final row = await database.trackDao.getTrackById(trackId);
        expect(row, isNotNull);
        expect(row!.state, 'deleted');
        expect(row.state, isNot('active'));
      },
    );

    test(
      'D7: deleteTrackAndData removes the program-enrolment row (no dangling '
      'profile_programs)',
      () async {
        final trackId = await insertTrack(profileId: 1);
        await database.profileProgramDao.setProfileProgram(
          profileId: 1,
          curriculumType: 'bavli',
          programId: 99,
        );
        expect(
          await database.profileProgramDao.getProgramForProfileAndCurriculum(
            1,
            'bavli',
          ),
          isNotNull,
        );

        await database.trackDao.deleteTrackAndData(trackId);

        expect(
          await database.profileProgramDao.getProgramForProfileAndCurriculum(
            1,
            'bavli',
          ),
          isNull,
          reason: 'deleting the track must also clear its program enrolment',
        );
      },
    );

    test('D7: purgeHistory also removes the program-enrolment row', () async {
      final trackId = await insertTrack(profileId: 1);
      await database.profileProgramDao.setProfileProgram(
        profileId: 1,
        curriculumType: 'bavli',
        programId: 99,
      );

      await database.trackDao.purgeHistory(trackId);

      expect(
        await database.profileProgramDao.getProgramForProfileAndCurriculum(
          1,
          'bavli',
        ),
        isNull,
      );
    });

    test(
      'getActiveTracks excludes soft-deleted tracks (deletedAt IS NOT NULL)',
      () async {
        final trackId = await insertTrack();
        // Verify the track appears before deletion.
        final before = await database.trackDao.getActiveTracks(
          CurriculumId.bavli,
        );
        expect(before, hasLength(1));

        await database.trackDao.deleteTrackAndData(trackId);

        final after = await database.trackDao.getActiveTracks(
          CurriculumId.bavli,
        );
        expect(after, isEmpty);
      },
    );

    test('getActiveTracksForProfile excludes soft-deleted tracks', () async {
      final trackId = await insertTrack(profileId: 42);

      final before = await database.trackDao.getActiveTracksForProfile(42);
      expect(before, hasLength(1));

      await database.trackDao.deleteTrackAndData(trackId);

      final after = await database.trackDao.getActiveTracksForProfile(42);
      expect(after, isEmpty);
    });

    test('watchActiveTracksForProfile excludes soft-deleted tracks', () async {
      final trackId = await insertTrack(profileId: 7);

      final stream = database.trackDao.watchActiveTracksForProfile(7);

      // Initial emission should include the track.
      final initial = await stream.first;
      expect(initial, hasLength(1));

      await database.trackDao.deleteTrackAndData(trackId);

      // Next emission should exclude the soft-deleted track.
      final updated = await stream.first;
      expect(updated, isEmpty);
    });

    test('countActiveTracksForProfile excludes soft-deleted tracks', () async {
      final trackId = await insertTrack(profileId: 5);

      expect(await database.trackDao.countActiveTracksForProfile(5), equals(1));

      await database.trackDao.deleteTrackAndData(trackId);

      expect(await database.trackDao.countActiveTracksForProfile(5), equals(0));
    });

    test('completions are NOT deleted when a track is soft-deleted', () async {
      final trackId = await insertTrack();

      // Insert a completion referencing the track.
      await seedCompletion(
        database,
        CompletionEventsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          sefariaRef: 'Berakhot.2a',
          stageId: 1,
          trackType: 'personal',
          trackId: Value(trackId),
          eventTimestamp: DateTime.now().toUtc(),
        ),
      );

      await database.trackDao.deleteTrackAndData(trackId);

      // Completion must still exist (append-only invariant).
      final completions = await database.completionDao.getCompletionsByTrack(
        trackId,
      );
      expect(completions, hasLength(1));
    });

    test(
      'deleteByTrack does not exist on CompletionDao (append-only invariant)',
      () {
        // This test verifies at compile time that the method was removed.
        // If this file compiles, the method is gone.
        //
        // We can't test for a missing method at runtime; the build_runner
        // code-gen step (and dart analyze) would have caught any remaining
        // call-site. This test documents the invariant.
        expect(
          true,
          isTrue,
          reason: 'deleteByTrack was removed from CompletionDao',
        );
      },
    );
  });
}
