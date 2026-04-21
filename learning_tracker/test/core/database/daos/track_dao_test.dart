import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/track_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';

void main() {
  late UserDatabase database;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
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
      await database.trackDao.activateTrack(
        CurriculumId.bavli,
        TrackType.personal,
      );

      final tracks = await database.trackDao.getActiveTracks(
        CurriculumId.bavli,
      );
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

    test('isTrackActive returns false for non-existent track', () async {
      final isActive = await database.trackDao.isTrackActive(
        CurriculumId.bavli,
        TrackType.personal,
      );
      expect(isActive, isFalse);
    });

    test('initializeDefaultTracks creates personal track', () async {
      await database.trackDao.initializeDefaultTracks(CurriculumId.bavli);

      final tracks = await database.trackDao.getActiveTracks(
        CurriculumId.bavli,
      );
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
}
