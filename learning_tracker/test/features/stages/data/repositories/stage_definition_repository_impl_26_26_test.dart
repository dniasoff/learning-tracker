// Tests for story 26.26 (DNI-369):
// - addStage accepts scheduleType / daysOfWeek / rollingWindowSize
// - reorderStages is atomic (real in-memory Drift DB)
// - reorderStages throws ProtectedStageException when Learn displaced
// - deleteStage throws ProtectedStageException for the Learn stage
// - StageValidator is consulted on addStage and updateStage
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart' show seedProfile, seedProfileZero;

class MockStageDao extends Mock implements StageDao {}

class MockCompletionDao extends Mock implements CompletionDao {}

class FakeStageDefinitionsCompanion extends Fake
    implements db.StageDefinitionsCompanion {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a real in-memory UserDatabase, inserts a curriculum track, and
/// returns the (database, trackId, repository) tuple.
Future<
  ({
    db.UserDatabase database,
    int trackId,
    StageDefinitionRepositoryImpl repository,
    List<Map<String, dynamic>> pushedSettings,
  })
>
_makeRealRepo() async {
  final database = db.UserDatabase(NativeDatabase.memory());
  await seedProfile(database);
  await seedProfileZero(database); // needed by initializeDefaults (profileId=0, DNI-322)
  final trackId = await database
      .into(database.curriculumTracks)
      .insert(
        db.CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackType: 'personal',
          activatedAt: DateTime.now(),
        ),
      );
  final pushedSettings = <Map<String, dynamic>>[];
  final repository = StageDefinitionRepositoryImpl(
    stageDao: database.stageDao,
    completionDao: database.completionDao,
    pushSettings: (s) async => pushedSettings.add(s),
  );
  return (
    database: database,
    trackId: trackId,
    repository: repository,
    pushedSettings: pushedSettings,
  );
}

db.StageDefinition _makeRow({
  int id = 1,
  int stageOrder = 1,
  String stageName = 'Learn',
  int delayDays = 0,
  bool isDefault = true,
  String scheduleType = 'delay',
  String? daysOfWeek,
  int? rollingWindowSize,
}) => db.StageDefinition(
  id: id,
  profileId: 0,
  curriculumId: 'mishnayos',
  trackId: 1,
  stageOrder: stageOrder,
  stageName: stageName,
  delayDays: delayDays,
  isDefault: isDefault,
  scheduleType: scheduleType,
  daysOfWeek: daysOfWeek,
  rollingWindowSize: rollingWindowSize,
);

void main() {
  const curriculum = CurriculumId.mishnayos;

  setUpAll(() {
    registerFallbackValue(FakeStageDefinitionsCompanion());
  });

  // =========================================================================
  // Group 1: addStage with new schedule params (mock-based unit tests)
  // =========================================================================

  group('addStage — new schedule params (unit)', () {
    late MockStageDao mockStageDao;
    late MockCompletionDao mockCompletionDao;
    late List<Map<String, dynamic>> pushedSettings;
    late StageDefinitionRepositoryImpl repository;

    setUp(() {
      mockStageDao = MockStageDao();
      mockCompletionDao = MockCompletionDao();
      pushedSettings = [];
      repository = StageDefinitionRepositoryImpl(
        stageDao: mockStageDao,
        completionDao: mockCompletionDao,
        pushSettings: (s) async => pushedSettings.add(s),
      );

      when(
        () => mockStageDao.countStagesForCurriculum(any()),
      ).thenAnswer((_) async => 3);
      when(
        () => mockStageDao.getMaxStageOrder(any()),
      ).thenAnswer((_) async => 3);
      when(
        () => mockStageDao.insertStageDefinition(any()),
      ).thenAnswer((_) async => 4);
      when(
        () => mockStageDao.getStageDefinitionsByCurriculum(any()),
      ).thenAnswer((_) async => [_makeRow()]);
    });

    test('addStage(delay) writes scheduleType=delay to DAO', () async {
      when(() => mockStageDao.getStageDefinitionById(4)).thenAnswer(
        (_) async => _makeRow(
          id: 4,
          stageOrder: 4,
          stageName: 'Extra',
          delayDays: 14,
          isDefault: false,
          scheduleType: 'delay',
        ),
      );

      final result = await repository.addStage(
        curriculum,
        'Extra',
        14,
        trackId: 1,
      );

      expect(result.scheduleType, ScheduleType.delay);
      expect(result.stageOrder, 4);
      expect(result.daysOfWeek, isNull);
      expect(result.rollingWindowSize, isNull);

      final captured =
          verify(
                () => mockStageDao.insertStageDefinition(captureAny()),
              ).captured.single
              as db.StageDefinitionsCompanion;
      expect(captured.scheduleType.value, 'delay');
    });

    test(
      'addStage(weekly) writes scheduleType=weekly and daysOfWeek to DAO',
      () async {
        when(() => mockStageDao.getStageDefinitionById(4)).thenAnswer(
          (_) async => _makeRow(
            id: 4,
            stageOrder: 4,
            stageName: 'Weekly Review',
            delayDays: 0,
            isDefault: false,
            scheduleType: 'weekly',
            daysOfWeek: '[1,3,5]',
          ),
        );

        final result = await repository.addStage(
          curriculum,
          'Weekly Review',
          0,
          trackId: 1,
          scheduleType: ScheduleType.weekly,
          daysOfWeek: [1, 3, 5],
        );

        expect(result.scheduleType, ScheduleType.weekly);
        expect(result.daysOfWeek, [1, 3, 5]);

        final captured =
            verify(
                  () => mockStageDao.insertStageDefinition(captureAny()),
                ).captured.single
                as db.StageDefinitionsCompanion;
        expect(captured.scheduleType.value, 'weekly');
        expect(captured.daysOfWeek.value, '[1,3,5]');
      },
    );

    test(
      'addStage(rolling) writes scheduleType=rolling and windowSize to DAO',
      () async {
        when(() => mockStageDao.getStageDefinitionById(4)).thenAnswer(
          (_) async => _makeRow(
            id: 4,
            stageOrder: 4,
            stageName: 'Rolling',
            delayDays: 0,
            isDefault: false,
            scheduleType: 'rolling',
            rollingWindowSize: 10,
          ),
        );

        final result = await repository.addStage(
          curriculum,
          'Rolling',
          0,
          trackId: 1,
          scheduleType: ScheduleType.rolling,
          rollingWindowSize: 10,
        );

        expect(result.scheduleType, ScheduleType.rolling);
        expect(result.rollingWindowSize, 10);

        final captured =
            verify(
                  () => mockStageDao.insertStageDefinition(captureAny()),
                ).captured.single
                as db.StageDefinitionsCompanion;
        expect(captured.scheduleType.value, 'rolling');
        expect(captured.rollingWindowSize.value, 10);
      },
    );

    test(
      'addStage(weekly) without daysOfWeek throws ArgumentError (validator)',
      () async {
        expect(
          () => repository.addStage(
            curriculum,
            'Bad Weekly',
            0,
            trackId: 1,
            scheduleType: ScheduleType.weekly,
            // daysOfWeek deliberately omitted
          ),
          throwsA(isA<ArgumentError>()),
        );

        verifyNever(() => mockStageDao.insertStageDefinition(any()));
      },
    );

    test(
      'addStage(rolling) without rollingWindowSize throws ArgumentError (validator)',
      () async {
        expect(
          () => repository.addStage(
            curriculum,
            'Bad Rolling',
            0,
            trackId: 1,
            scheduleType: ScheduleType.rolling,
            // rollingWindowSize deliberately omitted
          ),
          throwsA(isA<ArgumentError>()),
        );

        verifyNever(() => mockStageDao.insertStageDefinition(any()));
      },
    );

    test(
      'addStage(weekly) with empty daysOfWeek throws ArgumentError',
      () async {
        expect(
          () => repository.addStage(
            curriculum,
            'Bad Weekly',
            0,
            trackId: 1,
            scheduleType: ScheduleType.weekly,
            daysOfWeek: [], // empty list
          ),
          throwsA(isA<ArgumentError>()),
        );

        verifyNever(() => mockStageDao.insertStageDefinition(any()));
      },
    );

    test('addStage(rolling) with windowSize=0 throws ArgumentError', () async {
      expect(
        () => repository.addStage(
          curriculum,
          'Bad Rolling',
          0,
          trackId: 1,
          scheduleType: ScheduleType.rolling,
          rollingWindowSize: 0, // non-positive
        ),
        throwsA(isA<ArgumentError>()),
      );

      verifyNever(() => mockStageDao.insertStageDefinition(any()));
    });
  });

  // =========================================================================
  // Group 2: addStage round-trip (real in-memory DB)
  // =========================================================================

  group('addStage — round-trip with real DB', () {
    test('scheduleType/daysOfWeek round-trips for weekly stage', () async {
      final ctx = await _makeRealRepo();
      addTearDown(() => ctx.database.close());

      await ctx.repository.initializeDefaults(curriculum, trackId: ctx.trackId);

      final stage = await ctx.repository.addStage(
        curriculum,
        'Weekly Review',
        0,
        trackId: ctx.trackId,
        scheduleType: ScheduleType.weekly,
        daysOfWeek: [2, 4],
      );

      expect(stage.scheduleType, ScheduleType.weekly);
      expect(stage.daysOfWeek, [2, 4]);
      expect(stage.rollingWindowSize, isNull);

      // Verify persisted value is readable back
      final stages = await ctx.repository.getStagesForCurriculum(curriculum);
      final persisted = stages.firstWhere((s) => s.id == stage.id);
      expect(persisted.scheduleType, ScheduleType.weekly);
      expect(persisted.daysOfWeek, [2, 4]);
    });

    test(
      'scheduleType/rollingWindowSize round-trips for rolling stage',
      () async {
        final ctx = await _makeRealRepo();
        addTearDown(() => ctx.database.close());

        await ctx.repository.initializeDefaults(
          curriculum,
          trackId: ctx.trackId,
        );

        final stage = await ctx.repository.addStage(
          curriculum,
          'Rolling',
          0,
          trackId: ctx.trackId,
          scheduleType: ScheduleType.rolling,
          rollingWindowSize: 7,
        );

        expect(stage.scheduleType, ScheduleType.rolling);
        expect(stage.rollingWindowSize, 7);
        expect(stage.daysOfWeek, isNull);

        final stages = await ctx.repository.getStagesForCurriculum(curriculum);
        final persisted = stages.firstWhere((s) => s.id == stage.id);
        expect(persisted.scheduleType, ScheduleType.rolling);
        expect(persisted.rollingWindowSize, 7);
      },
    );
  });

  // =========================================================================
  // Group 3: reorderStages — atomicity (real in-memory DB)
  // =========================================================================

  group('reorderStages — atomicity and Learn-at-1 guard (real DB)', () {
    test('reorderStages persists correct new positions', () async {
      final ctx = await _makeRealRepo();
      addTearDown(() => ctx.database.close());

      await ctx.repository.initializeDefaults(curriculum, trackId: ctx.trackId);

      final before = await ctx.repository.getStagesForCurriculum(curriculum);
      // Default order: Learn(1), Chazara1(2), Chazara2(3)
      expect(before.map((s) => s.stageOrder).toList(), [1, 2, 3]);

      // Reorder: keep Learn first, swap Chazara1 and Chazara2
      final learnId = before[0].id;
      final chazara1Id = before[1].id;
      final chazara2Id = before[2].id;

      await ctx.repository.reorderStages(curriculum, [
        learnId,
        chazara2Id,
        chazara1Id,
      ]);

      final after = await ctx.repository.getStagesForCurriculum(curriculum);
      expect(after[0].id, learnId);
      expect(after[0].stageOrder, 1);
      expect(after[1].id, chazara2Id);
      expect(after[1].stageOrder, 2);
      expect(after[2].id, chazara1Id);
      expect(after[2].stageOrder, 3);
    });

    test(
      'reorderStages throws ProtectedStageException when Learn not at position 1',
      () async {
        final ctx = await _makeRealRepo();
        addTearDown(() => ctx.database.close());

        await ctx.repository.initializeDefaults(
          curriculum,
          trackId: ctx.trackId,
        );

        final stages = await ctx.repository.getStagesForCurriculum(curriculum);
        final learnId = stages[0].id;
        final chazara1Id = stages[1].id;
        final chazara2Id = stages[2].id;

        // Put Chazara1 first — should throw because Learn would move from pos 1
        expect(
          () => ctx.repository.reorderStages(curriculum, [
            chazara1Id,
            learnId,
            chazara2Id,
          ]),
          throwsA(isA<ProtectedStageException>()),
        );
      },
    );

    test(
      'reorderStages leaves stages unchanged when Learn guard fires',
      () async {
        final ctx = await _makeRealRepo();
        addTearDown(() => ctx.database.close());

        await ctx.repository.initializeDefaults(
          curriculum,
          trackId: ctx.trackId,
        );

        final before = await ctx.repository.getStagesForCurriculum(curriculum);
        final learnId = before[0].id;
        final chazara1Id = before[1].id;
        final chazara2Id = before[2].id;

        try {
          await ctx.repository.reorderStages(curriculum, [
            chazara1Id,
            learnId,
            chazara2Id,
          ]);
        } on ProtectedStageException {
          // expected
        }

        // Stages must be unchanged
        final after = await ctx.repository.getStagesForCurriculum(curriculum);
        expect(after[0].id, learnId);
        expect(after[0].stageOrder, 1);
      },
    );
  });

  // =========================================================================
  // Group 4: deleteStage — ProtectedStageException (mock-based)
  // =========================================================================

  group('deleteStage — ProtectedStageException (unit)', () {
    late MockStageDao mockStageDao;
    late MockCompletionDao mockCompletionDao;
    late StageDefinitionRepositoryImpl repository;

    setUp(() {
      mockStageDao = MockStageDao();
      mockCompletionDao = MockCompletionDao();
      repository = StageDefinitionRepositoryImpl(
        stageDao: mockStageDao,
        completionDao: mockCompletionDao,
        pushSettings: null,
      );
    });

    test(
      'deleteStage throws ProtectedStageException for stageOrder==1',
      () async {
        when(
          () => mockStageDao.getStageDefinitionById(1),
        ).thenAnswer((_) async => _makeRow(id: 1, stageOrder: 1));

        expect(
          () => repository.deleteStage(1),
          throwsA(isA<ProtectedStageException>()),
        );
      },
    );

    test('deleteStage succeeds for non-Learn stage', () async {
      when(() => mockStageDao.getStageDefinitionById(3)).thenAnswer(
        (_) async => _makeRow(
          id: 3,
          stageOrder: 3,
          stageName: 'Chazara 2',
          delayDays: 7,
          isDefault: false,
        ),
      );
      when(
        () => mockStageDao.deleteStageDefinition(3),
      ).thenAnswer((_) async => 1);
      when(
        () => mockStageDao.getStageDefinitionsByCurriculum(any()),
      ).thenAnswer((_) async => [_makeRow()]);

      await repository.deleteStage(3);

      verify(() => mockStageDao.deleteStageDefinition(3)).called(1);
    });
  });

  // =========================================================================
  // Group 5: StageValidator called on updateStage
  // =========================================================================

  group('updateStage — StageValidator consulted (unit)', () {
    late MockStageDao mockStageDao;
    late MockCompletionDao mockCompletionDao;
    late StageDefinitionRepositoryImpl repository;

    setUp(() {
      mockStageDao = MockStageDao();
      mockCompletionDao = MockCompletionDao();
      repository = StageDefinitionRepositoryImpl(
        stageDao: mockStageDao,
        completionDao: mockCompletionDao,
        pushSettings: null,
      );
    });

    test('updateStage on delay stage passes validator and calls DAO', () async {
      when(() => mockStageDao.getStageDefinitionById(2)).thenAnswer(
        (_) async => _makeRow(
          id: 2,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
          isDefault: false,
        ),
      );
      when(
        () => mockStageDao.updateStageDefinition(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockStageDao.getStageDefinitionsByCurriculum(any()),
      ).thenAnswer((_) async => [_makeRow()]);

      await repository.updateStage(2, name: 'Review', delayDays: 3);

      verify(() => mockStageDao.updateStageDefinition(any())).called(1);
    });
  });
}
