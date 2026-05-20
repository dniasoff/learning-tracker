import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/stage_limit_exceeded_exception.dart';
import 'package:mocktail/mocktail.dart';

class MockStageDao extends Mock implements StageDao {}

class MockCompletionDao extends Mock implements CompletionDao {}

class FakeStageDefinitionsCompanion extends Fake
    implements db.StageDefinitionsCompanion {}

void main() {
  late MockStageDao mockStageDao;
  late MockCompletionDao mockCompletionDao;
  late List<Map<String, dynamic>> pushedSettings;
  late StageDefinitionRepositoryImpl repository;

  const curriculum = CurriculumId.mishnayos;
  const curriculumKey = 'mishnayos';

  db.StageDefinition makeRow({
    int id = 1,
    int stageOrder = 1,
    String stageName = 'Learn',
    int delayDays = 0,
    bool isDefault = true,
  }) {
    // W3.27: schedule quartet replaced by single JSON schedule column.
    final schedule = '{"type":"delay","delay_days":$delayDays}';
    return db.StageDefinition(
      id: id,
      profileId: 0,
      curriculumId: curriculumKey,
      trackId: 1,
      stageOrder: stageOrder,
      stageName: stageName,
      isDefault: isDefault,
      schedule: schedule,
      updatedAt: DateTime.utc(2026, 1, 1),
    );
  }

  setUpAll(() {
    registerFallbackValue(FakeStageDefinitionsCompanion());
  });

  setUp(() {
    mockStageDao = MockStageDao();
    mockCompletionDao = MockCompletionDao();
    pushedSettings = [];

    repository = StageDefinitionRepositoryImpl(
      stageDao: mockStageDao,
      completionDao: mockCompletionDao,
      pushSettings: (settings) async => pushedSettings.add(settings),
    );
  });

  group('StageDefinitionRepositoryImpl', () {
    // Scenario 1: getStagesForCurriculum returns sorted stages
    test('getStagesForCurriculum returns stages in stageOrder', () async {
      final rows = [
        makeRow(id: 1, stageOrder: 1, stageName: 'Learn'),
        makeRow(
          id: 2,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
          isDefault: true,
        ),
        makeRow(
          id: 3,
          stageOrder: 3,
          stageName: 'Chazara 2',
          delayDays: 7,
          isDefault: true,
        ),
      ];
      when(
        () => mockStageDao.getStageDefinitionsByCurriculum(curriculumKey),
      ).thenAnswer((_) async => rows);

      final result = await repository.getStagesForCurriculum(curriculum);

      expect(result.length, 3);
      expect(result[0].stageName, 'Learn');
      expect(result[0].curriculumId, curriculum);
    });

    // Scenario 2: addStage assigns stageOrder = max + 1, isDefault = false
    test(
      'addStage assigns stageOrder = max + 1 and isDefault = false',
      () async {
        when(
          () => mockStageDao.countStagesForCurriculum(curriculumKey),
        ).thenAnswer((_) async => 3);
        when(
          () => mockStageDao.getMaxStageOrder(curriculumKey),
        ).thenAnswer((_) async => 3);
        when(
          () => mockStageDao.insertStageDefinition(any()),
        ).thenAnswer((_) async => 4);
        when(() => mockStageDao.getStageDefinitionById(4)).thenAnswer(
          (_) async => makeRow(
            id: 4,
            stageOrder: 4,
            stageName: 'Chazara 3',
            delayDays: 30,
            isDefault: false,
          ),
        );
        when(
          () => mockStageDao.getStageDefinitionsByCurriculum(curriculumKey),
        ).thenAnswer(
          (_) async => [
            makeRow(id: 1),
            makeRow(id: 2, stageOrder: 2, stageName: 'Chazara 1', delayDays: 1),
            makeRow(id: 3, stageOrder: 3, stageName: 'Chazara 2', delayDays: 7),
            makeRow(
              id: 4,
              stageOrder: 4,
              stageName: 'Chazara 3',
              delayDays: 30,
              isDefault: false,
            ),
          ],
        );

        final result = await repository.addStage(
          curriculum,
          'Chazara 3',
          profileId: 1,
          trackId: 1,
          schedule: const DelaySchedule(30),
        );

        expect(result.stageOrder, 4);
        expect(result.isDefault, false);

        final captured =
            verify(
                  () => mockStageDao.insertStageDefinition(captureAny()),
                ).captured.single
                as db.StageDefinitionsCompanion;
        expect(captured.stageOrder.value, 4);
        expect(captured.isDefault.value, false);
      },
    );

    // Scenario 3: deleteStage throws ProtectedStageException for stageOrder==1
    test(
      'deleteStage throws ProtectedStageException for Learn stage',
      () async {
        when(
          () => mockStageDao.getStageDefinitionById(1),
        ).thenAnswer((_) async => makeRow(id: 1, stageOrder: 1));

        expect(
          () => repository.deleteStage(1),
          throwsA(isA<ProtectedStageException>()),
        );
      },
    );

    // Scenario 4: deleteStage succeeds for custom stage, does not delete completions
    test(
      'deleteStage succeeds for custom stage and preserves completions',
      () async {
        when(() => mockStageDao.getStageDefinitionById(5)).thenAnswer(
          (_) async => makeRow(
            id: 5,
            stageOrder: 4,
            stageName: 'Custom',
            delayDays: 30,
            isDefault: false,
          ),
        );
        when(
          () => mockStageDao.deleteStageDefinition(5),
        ).thenAnswer((_) async => 1);
        when(
          () => mockStageDao.getStageDefinitionsByCurriculum(curriculumKey),
        ).thenAnswer((_) async => [makeRow(id: 1)]);

        await repository.deleteStage(5);

        verify(() => mockStageDao.deleteStageDefinition(5)).called(1);
        verifyNever(() => mockCompletionDao.hasCompletionsForStage(any()));
      },
    );

    // Scenario 5: updateStage writes correct name and delayDays
    test('updateStage updates name and delayDays', () async {
      when(() => mockStageDao.getStageDefinitionById(2)).thenAnswer(
        (_) async =>
            makeRow(id: 2, stageOrder: 2, stageName: 'Chazara 1', delayDays: 1),
      );
      when(
        () => mockStageDao.updateStageDefinition(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockStageDao.getStageDefinitionsByCurriculum(curriculumKey),
      ).thenAnswer((_) async => [makeRow(id: 1)]);

      await repository.updateStage(2, name: 'Review', delayDays: 3);

      final captured =
          verify(
                () => mockStageDao.updateStageDefinition(captureAny()),
              ).captured.single
              as db.StageDefinitionsCompanion;
      expect(captured.stageName.value, 'Review');
      // W3.27: schedule is a JSON string; check it encodes delay_days=3.
      expect(captured.schedule.value, contains('"delay_days":3'));
    });

    // Scenario 6: resetToDefaults deletes all and inserts 3 defaults
    test(
      'resetToDefaults deletes all and inserts exactly 3 defaults',
      () async {
        when(
          () => mockStageDao.deleteAllForCurriculum(curriculumKey),
        ).thenAnswer((_) async => 3);
        when(
          () => mockStageDao.insertStageDefinition(any()),
        ).thenAnswer((_) async => 1);
        when(
          () => mockStageDao.getStageDefinitionsByCurriculum(curriculumKey),
        ).thenAnswer(
          (_) async => [
            makeRow(id: 1),
            makeRow(id: 2, stageOrder: 2, stageName: 'Chazara 1', delayDays: 1),
            makeRow(id: 3, stageOrder: 3, stageName: 'Chazara 2', delayDays: 7),
          ],
        );

        await repository.resetToDefaults(curriculum, profileId: 1, trackId: 1);

        verify(
          () => mockStageDao.deleteAllForCurriculum(curriculumKey),
        ).called(1);
        verify(() => mockStageDao.insertStageDefinition(any())).called(3);
      },
    );

    // Scenario 7: addStage throws StageLimitExceededException at 10 stages
    test('addStage throws StageLimitExceededException when at limit', () async {
      when(
        () => mockStageDao.countStagesForCurriculum(curriculumKey),
      ).thenAnswer((_) async => 10);

      expect(
        () => repository.addStage(
          curriculum,
          'Extra Stage',
          profileId: 1,
          trackId: 1,
          schedule: const DelaySchedule(60),
        ),
        throwsA(isA<StageLimitExceededException>()),
      );
    });

    // Scenario 8: initializeDefaults is no-op when stages exist for this track
    test('initializeDefaults is a no-op when stages already exist', () async {
      when(
        () => mockStageDao.getStagesByTrack(1),
      ).thenAnswer((_) async => [makeRow(id: 1)]);

      await repository.initializeDefaults(curriculum, profileId: 1, trackId: 1);

      verifyNever(() => mockStageDao.insertStageDefinition(any()));
    });

    // Scenario 8b: initializeDefaults inserts defaults when track has no stages
    test('initializeDefaults inserts 3 defaults when track is empty', () async {
      when(() => mockStageDao.getStagesByTrack(1)).thenAnswer((_) async => []);
      when(
        () => mockStageDao.insertStageDefinition(any()),
      ).thenAnswer((_) async => 1);

      await repository.initializeDefaults(curriculum, profileId: 1, trackId: 1);

      verify(() => mockStageDao.insertStageDefinition(any())).called(3);
    });

    // Scenario 8c: initializeDefaults passes profileId through to DAO (DNI-322)
    test(
      'initializeDefaults writes the supplied profileId to inserted rows',
      () async {
        when(
          () => mockStageDao.getStagesByTrack(1),
        ).thenAnswer((_) async => []);
        when(
          () => mockStageDao.insertStageDefinition(any()),
        ).thenAnswer((_) async => 1);

        await repository.initializeDefaults(
          curriculum,
          profileId: 42,
          trackId: 1,
        );

        final calls = verify(
          () => mockStageDao.insertStageDefinition(captureAny()),
        ).captured;
        expect(calls, hasLength(3));
        for (final call in calls) {
          final companion = call as db.StageDefinitionsCompanion;
          expect(companion.profileId.value, 42);
        }
      },
    );

    // Scenario 9: Firestore push is called after each mutation
    test('addStage calls pushSettings after insert', () async {
      when(
        () => mockStageDao.countStagesForCurriculum(curriculumKey),
      ).thenAnswer((_) async => 3);
      when(
        () => mockStageDao.getMaxStageOrder(curriculumKey),
      ).thenAnswer((_) async => 3);
      when(
        () => mockStageDao.insertStageDefinition(any()),
      ).thenAnswer((_) async => 4);
      when(() => mockStageDao.getStageDefinitionById(4)).thenAnswer(
        (_) async => makeRow(
          id: 4,
          stageOrder: 4,
          stageName: 'Extra',
          delayDays: 30,
          isDefault: false,
        ),
      );
      when(
        () => mockStageDao.getStageDefinitionsByCurriculum(curriculumKey),
      ).thenAnswer((_) async => [makeRow(id: 1)]);

      await repository.addStage(
        curriculum,
        'Extra',
        profileId: 1,
        trackId: 1,
        schedule: const DelaySchedule(30),
      );

      expect(pushedSettings, hasLength(1));
      expect(pushedSettings[0]['curriculum_id'], curriculumKey);
      expect(pushedSettings[0]['stages'], isList);
    });

    test('deleteStage calls pushSettings after delete', () async {
      when(() => mockStageDao.getStageDefinitionById(5)).thenAnswer(
        (_) async => makeRow(
          id: 5,
          stageOrder: 4,
          stageName: 'Custom',
          delayDays: 30,
          isDefault: false,
        ),
      );
      when(
        () => mockStageDao.deleteStageDefinition(5),
      ).thenAnswer((_) async => 1);
      when(
        () => mockStageDao.getStageDefinitionsByCurriculum(curriculumKey),
      ).thenAnswer((_) async => [makeRow(id: 1)]);

      await repository.deleteStage(5);

      expect(pushedSettings, hasLength(1));
    });

    test('resetToDefaults calls pushSettings', () async {
      when(
        () => mockStageDao.deleteAllForCurriculum(curriculumKey),
      ).thenAnswer((_) async => 3);
      when(
        () => mockStageDao.insertStageDefinition(any()),
      ).thenAnswer((_) async => 1);
      when(
        () => mockStageDao.getStageDefinitionsByCurriculum(curriculumKey),
      ).thenAnswer((_) async => [makeRow(id: 1)]);

      await repository.resetToDefaults(curriculum, profileId: 1, trackId: 1);

      expect(pushedSettings, hasLength(1));
    });
  });
}
