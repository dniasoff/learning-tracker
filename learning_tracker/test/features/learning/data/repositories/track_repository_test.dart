import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';

void main() {
  late UserDatabase database;
  late TrackRepository repository;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
    repository = TrackRepositoryImpl(database: database);
  });

  tearDown(() async {
    await database.close();
  });

  group('TrackRepository (one track per curriculum)', () {
    group('initializeDefaultTracks', () {
      test('creates a single active track for a new curriculum', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        final activeTracks = await database.trackDao.getActiveTracks(
          CurriculumId.mishnayos,
        );
        expect(activeTracks, hasLength(1));
      });

      test('does nothing if a track already exists', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        final activeTracks = await database.trackDao.getActiveTracks(
          CurriculumId.mishnayos,
        );
        expect(activeTracks, hasLength(1));
      });
    });

    group('per-curriculum isolation', () {
      test('initialization is per-curriculum', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.bavli);

        final mishnayosTracks = await database.trackDao.getActiveTracks(
          CurriculumId.mishnayos,
        );
        final bavliTracks = await database.trackDao.getActiveTracks(
          CurriculumId.bavli,
        );

        expect(mishnayosTracks, hasLength(1));
        expect(bavliTracks, hasLength(1));
      });
    });
  });
}
