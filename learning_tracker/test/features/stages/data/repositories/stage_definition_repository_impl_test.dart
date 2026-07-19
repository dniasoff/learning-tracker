import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/tracks/stages/data/repositories/stage_definition_repository_impl.dart';
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

    // Plan §F Phase 5 deliverable 6 — capture stage-definition push calls
    // via the dedicated `pushStageDefinitions` path. Each call yields a
    // snapshot-shaped map containing the stage list + metadata so the
    // existing assertions ('curriculum_id', 'stages') continue to work.
    repository = StageDefinitionRepositoryImpl(
      stageDao: mockStageDao,
      completionDao: mockCompletionDao,
      pushStageDefinitions:
          ({
            required int trackId,
            required String curriculumId,
            required List<Map<String, dynamic>> stages,
            required DateTime updatedAt,
          }) async {
            pushedSettings.add({
              'track_id': trackId,
              'curriculum_id': curriculumId,
              'stages': stages,
              'updated_at': updatedAt.toIso8601String(),
            });
          },
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

    // Scenario 6: resetToDefaults deletes only the track's stages and inserts 3 defaults
    // R6-12: must call deleteStagesForTrack (track-scoped), NOT deleteAllForCurriculum.
    test(
      'resetToDefaults deletes track stages only and inserts exactly 3 defaults',
      () async {
        when(
          () => mockStageDao.deleteStagesForTrack(1),
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

        // R6-12: track-scoped delete must be called; curriculum-wide must NOT be.
        verify(() => mockStageDao.deleteStagesForTrack(1)).called(1);
        verifyNever(() => mockStageDao.deleteAllForCurriculum(any()));
        verify(() => mockStageDao.insertStageDefinition(any())).called(3);
      },
    );

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
    test('resetToDefaults calls pushSettings', () async {
      when(
        () => mockStageDao.deleteStagesForTrack(1),
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
