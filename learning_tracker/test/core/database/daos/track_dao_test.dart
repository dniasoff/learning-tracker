import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  group('TrackDao', () {
    test('getActiveTracks returns empty list initially', () async {
      final tracks = await database.trackDao.getActiveTracks(CurriculumId.bavli);
      expect(tracks, isEmpty);
    });

    test('activateTrack creates a new active track', () async {
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.personal,
      );

      final tracks = await database.trackDao.getActiveTracks(CurriculumId.bavli);
      expect(tracks, hasLength(1));
      expect(tracks.first.trackType, TrackType.personal.storageKey);
      expect(tracks.first.isActive, isTrue);
    });

    test('activateTrack is idempotent for already-active track', () async {
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.personal,
      );
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.personal,
      );

      final tracks = await database.trackDao.getAllTracks(CurriculumId.bavli);
      expect(tracks, hasLength(1));
    });

    test('deactivateTrack sets isActive to false', () async {
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.school,
      );

      await database.trackDao.deactivateTrack(
        CurriculumId.bavli,
        TrackType.school,
      );

      final isActive = await database.trackDao.isTrackActive(
        CurriculumId.bavli,
        TrackType.school,
      );
      expect(isActive, isFalse);

      // Track record still exists
      final allTracks = await database.trackDao.getAllTracks(CurriculumId.bavli);
      expect(allTracks, hasLength(1));
    });

    test('deactivateTrack throws for personal track', () async {
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.personal,
      );

      expect(
        () => database.trackDao.deactivateTrack(
          CurriculumId.bavli,
          TrackType.personal,
        ),
        throwsA(isA<InvalidOperationException>()),
      );
    });

    test('deactivateTrack does nothing for non-existent track', () async {
      // Should not throw
      await database.trackDao.deactivateTrack(
        CurriculumId.bavli,
        TrackType.school,
      );

      final tracks = await database.trackDao.getAllTracks(CurriculumId.bavli);
      expect(tracks, isEmpty);
    });

    test('reactivating a deactivated track works', () async {
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.school,
      );
      await database.trackDao.deactivateTrack(
        CurriculumId.bavli,
        TrackType.school,
      );
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.school,
      );

      final isActive = await database.trackDao.isTrackActive(
        CurriculumId.bavli,
        TrackType.school,
      );
      expect(isActive, isTrue);
    });

    test('isTrackActive returns false for non-existent track', () async {
      final isActive = await database.trackDao.isTrackActive(
        CurriculumId.bavli,
        TrackType.tutor,
      );
      expect(isActive, isFalse);
    });

    test('getAllTracks returns both active and inactive tracks', () async {
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.personal,
      );
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.school,
      );
      await database.trackDao.deactivateTrack(
        CurriculumId.bavli,
        TrackType.school,
      );

      final allTracks = await database.trackDao.getAllTracks(CurriculumId.bavli);
      expect(allTracks, hasLength(2));

      final activeTracks =
          await database.trackDao.getActiveTracks(CurriculumId.bavli);
      expect(activeTracks, hasLength(1));
    });

    test('initializeDefaultTracks creates personal track', () async {
      await database.trackDao.initializeDefaultTracks(CurriculumId.bavli);

      final tracks = await database.trackDao.getActiveTracks(CurriculumId.bavli);
      expect(tracks, hasLength(1));
      expect(tracks.first.trackType, TrackType.personal.storageKey);
    });

    test('initializeDefaultTracks is idempotent', () async {
      await database.trackDao.initializeDefaultTracks(CurriculumId.bavli);
      await database.trackDao.initializeDefaultTracks(CurriculumId.bavli);

      final tracks = await database.trackDao.getAllTracks(CurriculumId.bavli);
      expect(tracks, hasLength(1));
    });

    test('tracks are scoped to curriculum', () async {
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.personal,
      );
      await database.trackDao.activateTrack(
        CurriculumId.mishnayos,
        TrackType.personal,
      );

      final bavliTracks =
          await database.trackDao.getActiveTracks(CurriculumId.bavli);
      final mishnayosTracks =
          await database.trackDao.getActiveTracks(CurriculumId.mishnayos);

      expect(bavliTracks, hasLength(1));
      expect(mishnayosTracks, hasLength(1));
    });
  });
}
