import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';

void main() {
  late AppDatabase database;
  late TrackRepository repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = TrackRepositoryImpl(
      database: database,
    );
  });

  tearDown(() async {
    await database.close();
  });

  group('TrackRepository', () {
    group('getActiveTracks', () {
      test('returns only personal track for freshly activated curriculum',
          () async {
        // Initialize default tracks (only personal)
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        // Get active tracks
        final activeTracks =
            await repository.getActiveTracks(CurriculumId.mishnayos);

        expect(activeTracks, hasLength(1));
        expect(activeTracks.first, TrackType.personal);
      });

      test('returns [personal, school] after activating school track',
          () async {
        // Initialize default tracks
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        // Activate school track
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Get active tracks
        final activeTracks =
            await repository.getActiveTracks(CurriculumId.mishnayos);

        expect(activeTracks, hasLength(2));
        expect(activeTracks, contains(TrackType.personal));
        expect(activeTracks, contains(TrackType.school));
      });

      test('excludes deactivated tracks from results', () async {
        // Initialize and activate all tracks
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.tutor,
        );

        // Deactivate school track
        await repository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Get active tracks
        final activeTracks =
            await repository.getActiveTracks(CurriculumId.mishnayos);

        expect(activeTracks, hasLength(2));
        expect(activeTracks, contains(TrackType.personal));
        expect(activeTracks, contains(TrackType.tutor));
        expect(activeTracks, isNot(contains(TrackType.school)));
      });
    });

    group('activateTrack', () {
      test('creates new track record when not exists', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        final isActive = await repository.isTrackActive(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        expect(isActive, isTrue);
      });

      test('reactivates previously deactivated track', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Deactivate then reactivate
        await repository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        final isActive = await repository.isTrackActive(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        expect(isActive, isTrue);
      });

      // TODO(DNI-38): Add test for Firestore sync once implemented
    });

    group('deactivateTrack', () {
      test('sets track inactive but preserves database record', () async {
        // Initialize, activate school, then deactivate
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Verify school track exists and is active
        final tracksBefore = await database.trackDao
            .getAllTracks(CurriculumId.mishnayos);
        final schoolTrackBefore = tracksBefore.firstWhere(
          (t) => t.trackType == TrackType.school.storageKey,
        );
        expect(schoolTrackBefore.isActive, isTrue);

        // Deactivate school track
        await repository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Verify record still exists but is inactive
        final tracksAfter = await database.trackDao
            .getAllTracks(CurriculumId.mishnayos);
        final schoolTrackAfter = tracksAfter.firstWhere(
          (t) => t.trackType == TrackType.school.storageKey,
        );
        expect(schoolTrackAfter.isActive, isFalse);
        expect(schoolTrackAfter.deactivatedAt, isNotNull);
      });

      test('throws InvalidTrackOperationException when deactivating personal',
          () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        expect(
          () => repository.deactivateTrack(
            CurriculumId.mishnayos,
            TrackType.personal,
          ),
          throwsA(isA<InvalidTrackOperationException>()),
        );
      });

      test('does not delete completion data when deactivating track', () async {
        // Initialize tracks
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Create a mock completion for school track
        // (In real scenario, this would use CompletionRepository)
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: CurriculumId.mishnayos.storageKey,
            contentItemId: 1,
            stageId: 1,
            trackType: TrackType.school.storageKey,
            completedAt: DateTime.now(),
          ),
        );

        // Verify completion exists
        final completionsBefore = await database.completionDao
            .getCompletionsByCurriculum(CurriculumId.mishnayos.storageKey);
        expect(completionsBefore, hasLength(1));

        // Deactivate school track
        await repository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Verify completion still exists
        final completionsAfter = await database.completionDao
            .getCompletionsByCurriculum(CurriculumId.mishnayos.storageKey);
        expect(completionsAfter, hasLength(1));
        expect(
          completionsAfter.first.trackType,
          TrackType.school.storageKey,
        );
      });

      // TODO(DNI-38): Add test for Firestore sync once implemented
    });

    group('isTrackActive', () {
      test('returns false for non-existent track', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        final isActive = await repository.isTrackActive(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        expect(isActive, isFalse);
      });

      test('returns true for active track', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        final isActive = await repository.isTrackActive(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        expect(isActive, isTrue);
      });

      test('returns false for deactivated track', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        await repository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        final isActive = await repository.isTrackActive(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        expect(isActive, isFalse);
      });
    });

    group('initializeDefaultTracks', () {
      test('creates only personal track for new curriculum', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        final activeTracks =
            await repository.getActiveTracks(CurriculumId.mishnayos);
        expect(activeTracks, hasLength(1));
        expect(activeTracks.first, TrackType.personal);
      });

      test('does nothing if tracks already exist', () async {
        // Initialize twice
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        // Should still only have one personal track
        final activeTracks =
            await repository.getActiveTracks(CurriculumId.mishnayos);
        expect(activeTracks, hasLength(1));
      });

      // TODO(DNI-38): Add test for Firestore sync once implemented
    });

    group('independent curriculum states', () {
      test('track activation is per-curriculum (two curricula independent)',
          () async {
        // Initialize both curricula
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.bavli);

        // Activate school for Mishnayos only
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Verify Mishnayos has school track
        final mishnayosTracks =
            await repository.getActiveTracks(CurriculumId.mishnayos);
        expect(mishnayosTracks, contains(TrackType.school));

        // Verify Bavli does NOT have school track
        final bavliTracks =
            await repository.getActiveTracks(CurriculumId.bavli);
        expect(bavliTracks, isNot(contains(TrackType.school)));
        expect(bavliTracks, hasLength(1));
        expect(bavliTracks.first, TrackType.personal);
      });

      test('deactivating track in one curriculum does not affect another',
          () async {
        // Initialize and activate school for both
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.bavli);
        await repository.activateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        await repository.activateTrack(
          CurriculumId.bavli,
          TrackType.school,
        );

        // Deactivate school for Mishnayos
        await repository.deactivateTrack(
          CurriculumId.mishnayos,
          TrackType.school,
        );

        // Verify Mishnayos school is inactive
        final mishnayosSchoolActive = await repository.isTrackActive(
          CurriculumId.mishnayos,
          TrackType.school,
        );
        expect(mishnayosSchoolActive, isFalse);

        // Verify Bavli school is still active
        final bavliSchoolActive = await repository.isTrackActive(
          CurriculumId.bavli,
          TrackType.school,
        );
        expect(bavliSchoolActive, isTrue);
      });
    });
  });
}
