import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/learning/domain/repositories/track_repository.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/last_active_curriculum_exception.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart' as drift_helpers;

class MockTrackRepository extends Mock implements TrackRepository {}

Future<void> _dummyPushCurriculumTrack(Map<String, dynamic> data) async {}

void main() {
  setUpAll(() {
    registerFallbackValue(CurriculumId.mishnayos);
  });
  late UserDatabase database;
  late CurriculumActivationService service;
  late MockTrackRepository mockTrackRepository;

  setUp(() async {
    database = UserDatabase(NativeDatabase.memory());
    mockTrackRepository = MockTrackRepository();
    service = CurriculumActivationService(
      database: database,
      pushCurriculumTrack: _dummyPushCurriculumTrack,
      trackRepository: mockTrackRepository,
    );

    // Seed parent rows required by FK constraints.
    await drift_helpers.seedProfile(database);
    await drift_helpers.seedProfileZero(database);

    // Mock TrackRepository to create the personal track in the test database
    // (mirrors real impl, skips the cloud push)
    when(
      () => mockTrackRepository.initializeDefaultTracks(
        any(),
        profileId: any(named: 'profileId'),
      ),
    ).thenAnswer((invocation) async {
      final curriculum = invocation.positionalArguments[0] as CurriculumId;
      final profileId = (invocation.namedArguments[#profileId] as int?) ?? 0;
      await database.trackDao.initializeDefaultTracks(
        curriculum,
        profileId: profileId,
      );
    });
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> getTrackId(CurriculumId curriculum) async {
    final tracks = await database.trackDao.getAllTracks(curriculum);
    return tracks.first.id;
  }

  group('CurriculumActivationService', () {
    test('activate adds curriculum to database', () async {
      await service.activate(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isTrue);
    });

    test('deactivate removes curriculum from database', () async {
      // Activate two curricula
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      // Deactivate one
      await service.deactivate(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isFalse);
    });

    test('toggle activates an inactive curriculum', () async {
      await service.toggle(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isTrue);
    });

    test('toggle deactivates an active curriculum', () async {
      // Activate two curricula
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      // Toggle off Bavli
      await service.toggle(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isFalse);
    });

    test(
      'attempting to deactivate the last curriculum throws LastActiveCurriculumException',
      () async {
        await service.activate(CurriculumId.mishnayos);

        expect(
          () => service.deactivate(CurriculumId.mishnayos),
          throwsA(isA<LastActiveCurriculumException>()),
        );
      },
    );

    test(
      'initialize sets default active curriculum (Mishnayos) if none active',
      () async {
        await service.initialize();

        final activeCurricula = await database.activeCurriculumDao
            .getActiveCurricula();
        expect(activeCurricula, contains(CurriculumId.mishnayos.storageKey));
      },
    );

    test('initialize does not override existing active curricula', () async {
      // Pre-activate Bavli
      await database.activeCurriculumDao.activate(CurriculumId.bavli);

      await service.initialize();

      final activeCurricula = await database.activeCurriculumDao
          .getActiveCurricula();
      expect(activeCurricula, contains(CurriculumId.bavli.storageKey));
      expect(
        activeCurricula,
        isNot(contains(CurriculumId.mishnayos.storageKey)),
      );
    });

    test(
      'watchActiveCurricula emits stream of active curriculum IDs',
      () async {
        final stream = service.watchActiveCurricula();

        expect(
          stream,
          emitsInOrder([
            <String>[], // Initial empty state
            [CurriculumId.bavli.storageKey], // After activation
          ]),
        );

        await Future<void>.delayed(
          Duration.zero,
        ); // Let stream emit initial value
        await service.activate(CurriculumId.bavli);
      },
    );

    test('getActiveCurricula returns list of CurriculumId enums', () async {
      await service.activate(CurriculumId.bavli);
      await service.activate(CurriculumId.yerushalmi);

      final activeCurricula = await service.getActiveCurricula();
      expect(
        activeCurricula,
        containsAll([CurriculumId.bavli, CurriculumId.yerushalmi]),
      );
    });

    test('all curricula can be activated simultaneously', () async {
      for (final curriculum in CurriculumId.values) {
        await service.activate(curriculum);
      }

      final activeCurricula = await service.getActiveCurricula();
      expect(activeCurricula, hasLength(CurriculumId.values.length));
      expect(activeCurricula, containsAll(CurriculumId.values));
    });

    test(
      'deactivation soft-deletes the track and preserves completions (DNI-317)',
      () async {
        // Activate two curricula
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        // Insert a completion for Bavli
        final bavliTrackId = await getTrackId(CurriculumId.bavli);
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            trackId: bavliTrackId,
            completedAt: DateTime.now(),
            points: const Value(10),
          ),
        );

        // Deactivate Bavli
        await service.deactivate(CurriculumId.bavli);

        // The track row is soft-deleted (deletedAt IS NOT NULL), not hard-deleted.
        final allTracks = await database.trackDao.getAllTracks(
          CurriculumId.bavli,
        );
        expect(allTracks, hasLength(1));
        expect(allTracks.first.deletedAt, isNotNull);

        // Completion data is preserved — completions are append-only (FR5 / E24).
        final completions = await database.completionDao
            .internalGetCompletionsByCurriculumCrossProfile(
              CurriculumId.bavli.storageKey,
              scope: CrossProfileScope.dataExport,
            );
        expect(completions, hasLength(1));
      },
    );

    test(
      'deactivation preserves bookmarks (curriculum-scoped, not track-scoped)',
      () async {
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        final bavliTrackId = await getTrackId(CurriculumId.bavli);

        await database.bookmarkDao.upsertBookmark(
          curriculumId: CurriculumId.bavli.storageKey,
          trackId: bavliTrackId,
          profileId: 0,
          sefariaRef: 'Berakhot.2a',
          updatedAt: DateTime.now().toUtc(),
        );

        await service.deactivate(CurriculumId.bavli);

        final bookmark = await database.bookmarkDao
            .getBookmarkByCurriculumAndTrack(
              CurriculumId.bavli.storageKey,
              bavliTrackId,
            );
        expect(bookmark, isNotNull);
        expect(bookmark!.sefariaRef, equals('Berakhot.2a'));
      },
    );

    test(
      'cannot deactivate all curricula via toggle (last-one-standing)',
      () async {
        // Activate two, then deactivate down to one
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        await service.toggle(CurriculumId.bavli);

        // Mishnayos is the last one -- toggling should throw
        expect(
          () => service.toggle(CurriculumId.mishnayos),
          throwsA(isA<LastActiveCurriculumException>()),
        );

        // Verify mishnayos is still active
        final active = await service.getActiveCurricula();
        expect(active, contains(CurriculumId.mishnayos));
        expect(active, hasLength(1));
      },
    );
  });
}
