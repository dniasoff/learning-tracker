import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
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
  });
}
