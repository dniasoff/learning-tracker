import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:mocktail/mocktail.dart';

class MockFirestoreSync extends Mock {
  Future<void> pushActiveCurricula(List<String> curricula);
  Future<List<String>> fetchActiveCurricula();
}

void main() {
  late AppDatabase database;
  late CurriculumActivationService service;
  late MockFirestoreSync mockFirestore;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    mockFirestore = MockFirestoreSync();
    service = CurriculumActivationService(
      database: database,
      pushActiveCurricula: mockFirestore.pushActiveCurricula,
    );

    // Mock Firestore calls to succeed silently
    when(
      () => mockFirestore.pushActiveCurricula(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockFirestore.fetchActiveCurricula(),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    await database.close();
  });

  group('CurriculumActivationService', () {
    test(
      'activate adds curriculum to database and syncs to Firestore',
      () async {
        await service.activate(CurriculumId.bavli);

        // Verify in database
        final isActive = await database.activeCurriculumDao.isActive(
          CurriculumId.bavli,
        );
        expect(isActive, isTrue);

        // Verify Firestore sync called
        verify(
          () => mockFirestore.pushActiveCurricula(
            any(that: contains(CurriculumId.bavli.storageKey)),
          ),
        ).called(1);
      },
    );

    test(
      'deactivate removes curriculum from database and syncs to Firestore',
      () async {
        // Activate two curricula
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.yerushalmi);

        // Deactivate one
        await service.deactivate(CurriculumId.bavli);

        // Verify in database
        final isActive = await database.activeCurriculumDao.isActive(
          CurriculumId.bavli,
        );
        expect(isActive, isFalse);

        // Verify Firestore sync called
        verify(
          () => mockFirestore.pushActiveCurricula(
            any(that: isNot(contains(CurriculumId.bavli.storageKey))),
          ),
        ).called(1);
      },
    );

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
      'attempting to deactivate the last curriculum throws StateError',
      () async {
        await service.activate(CurriculumId.mishnayos);

        expect(
          () => service.deactivate(CurriculumId.mishnayos),
          throwsA(isA<StateError>()),
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

    test('Firestore sync fails gracefully (offline scenario)', () async {
      // Simulate Firestore failure
      when(
        () => mockFirestore.pushActiveCurricula(any()),
      ).thenThrow(Exception('Offline'));

      // Activation should still succeed locally
      await service.activate(CurriculumId.bavli);

      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isTrue);
    });

    test('all 5 curricula can be activated simultaneously', () async {
      for (final curriculum in CurriculumId.values) {
        await service.activate(curriculum);
      }

      final activeCurricula = await service.getActiveCurricula();
      expect(activeCurricula, hasLength(5));
      expect(activeCurricula, containsAll(CurriculumId.values));
    });

    test(
      'deactivation preserves completion data (does not delete completions)',
      () async {
        // Activate two curricula
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        // Insert a completion for Bavli
        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now(),
            points: const Value(10),
          ),
        );

        // Deactivate Bavli
        await service.deactivate(CurriculumId.bavli);

        // Verify completion data is still present
        final completions = await database.completionDao
            .getCompletionsByCurriculum(CurriculumId.bavli.storageKey);
        expect(completions, hasLength(1));
        expect(completions.first.sefariaRef, equals('Berakhot.2a'));
      },
    );

    test(
      'deactivation preserves bookmark data (does not delete bookmarks)',
      () async {
        // Activate two curricula
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        // Insert a bookmark for Bavli
        await database.bookmarkDao.upsertBookmark(
          curriculumId: CurriculumId.bavli.storageKey,
          trackType: TrackType.personal.storageKey,
          sefariaRef: 'Berakhot.2a',
          updatedAt: DateTime.now().toUtc(),
        );

        // Deactivate Bavli
        await service.deactivate(CurriculumId.bavli);

        // Verify bookmark data is still present
        final bookmark = await database.bookmarkDao
            .getBookmarkByCurriculumAndTrack(
              CurriculumId.bavli.storageKey,
              TrackType.personal.storageKey,
            );
        expect(bookmark, isNotNull);
        expect(bookmark!.sefariaRef, equals('Berakhot.2a'));
      },
    );

    test(
      're-activating a previously deactivated curriculum restores all prior data',
      () async {
        // Activate two curricula and add data to Bavli
        await service.activate(CurriculumId.bavli);
        await service.activate(CurriculumId.mishnayos);

        await database.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: CurriculumId.bavli.storageKey,
            sefariaRef: 'Berakhot.2a',
            stageId: 1,
            trackType: TrackType.personal.storageKey,
            completedAt: DateTime.now(),
            points: const Value(10),
          ),
        );

        await database.bookmarkDao.upsertBookmark(
          curriculumId: CurriculumId.bavli.storageKey,
          trackType: TrackType.personal.storageKey,
          sefariaRef: 'Berakhot.5a',
          updatedAt: DateTime.now().toUtc(),
        );

        // Deactivate Bavli
        await service.deactivate(CurriculumId.bavli);
        expect(
          await database.activeCurriculumDao.isActive(CurriculumId.bavli),
          isFalse,
        );

        // Re-activate Bavli
        await service.activate(CurriculumId.bavli);
        expect(
          await database.activeCurriculumDao.isActive(CurriculumId.bavli),
          isTrue,
        );

        // Verify all prior data is still accessible
        final completions = await database.completionDao
            .getCompletionsByCurriculum(CurriculumId.bavli.storageKey);
        expect(completions, hasLength(1));
        expect(completions.first.sefariaRef, equals('Berakhot.2a'));

        final bookmark = await database.bookmarkDao
            .getBookmarkByCurriculumAndTrack(
              CurriculumId.bavli.storageKey,
              TrackType.personal.storageKey,
            );
        expect(bookmark, isNotNull);
        expect(bookmark!.sefariaRef, equals('Berakhot.5a'));
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
          throwsA(isA<StateError>()),
        );

        // Verify mishnayos is still active
        final active = await service.getActiveCurricula();
        expect(active, contains(CurriculumId.mishnayos));
        expect(active, hasLength(1));
      },
    );
  });
}
