import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
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

  group('TrackRepository (v1 — personal only)', () {
    group('getActiveTracks', () {
      test('returns only personal track after initialization', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        final activeTracks = await repository.getActiveTracks(
          CurriculumId.mishnayos,
        );

        expect(activeTracks, hasLength(1));
        expect(activeTracks.first, TrackType.personal);
      });
    });

    group('deactivateTrack', () {
      test(
        'throws InvalidTrackOperationException when deactivating personal',
        () async {
          await repository.initializeDefaultTracks(CurriculumId.mishnayos);

          expect(
            () => repository.deactivateTrack(
              CurriculumId.mishnayos,
              TrackType.personal,
            ),
            throwsA(isA<InvalidTrackOperationException>()),
          );
        },
      );
    });

    group('isTrackActive', () {
      test('returns true for personal track after init', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        final isActive = await repository.isTrackActive(
          CurriculumId.mishnayos,
          TrackType.personal,
        );
        expect(isActive, isTrue);
      });
    });

    group('initializeDefaultTracks', () {
      test('creates only personal track for new curriculum', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        final activeTracks = await repository.getActiveTracks(
          CurriculumId.mishnayos,
        );
        expect(activeTracks, hasLength(1));
        expect(activeTracks.first, TrackType.personal);
      });

      test('does nothing if tracks already exist', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);

        final activeTracks = await repository.getActiveTracks(
          CurriculumId.mishnayos,
        );
        expect(activeTracks, hasLength(1));
      });
    });

    group('per-curriculum isolation', () {
      test('initialization is per-curriculum', () async {
        await repository.initializeDefaultTracks(CurriculumId.mishnayos);
        await repository.initializeDefaultTracks(CurriculumId.bavli);

        final mishnayosTracks = await repository.getActiveTracks(
          CurriculumId.mishnayos,
        );
        final bavliTracks = await repository.getActiveTracks(
          CurriculumId.bavli,
        );

        expect(mishnayosTracks, hasLength(1));
        expect(bavliTracks, hasLength(1));
      });
    });
  });
}
