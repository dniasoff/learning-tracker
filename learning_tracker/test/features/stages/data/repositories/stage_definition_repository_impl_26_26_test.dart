// Tests for story 26.26 (DNI-369) — updated for W4.10 ScheduleSpec API:
// - addStage accepts ScheduleSpec (DelaySchedule / WeeklySchedule / RollingSchedule)
// - reorderStages is atomic (real in-memory Drift DB)
// - reorderStages throws ProtectedStageException when Learn displaced
// - deleteStage throws ProtectedStageException for the Learn stage
// - StageValidator / ScheduleSpec constructors validate invariants on addStage
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/daos/stage_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart' as db;
import 'package:learning_tracker/core/domain/value_objects/schedule_spec.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/stages/data/repositories/stage_definition_repository_impl.dart';
import 'package:learning_tracker/features/stages/domain/exceptions/protected_stage_exception.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart' show seedProfile;

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
  final trackId = await database
      .into(database.curriculumTracks)
      .insert(
        db.CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          stateChangedAt: DateTime.now(),
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
  // Group 1: addStage with ScheduleSpec (mock-based unit tests)
  // =========================================================================

  group('addStage — ScheduleSpec params (unit)', () {
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

    test('addStage(DelaySchedule) writes scheduleType=delay to DAO', () async {
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
        profileId: 1,
        trackId: 1,
        schedule: const DelaySchedule(14),
      );

      expect(result.scheduleType, ScheduleType.delay);
      expect(result.stageOrder, 4);
      expect(result.daysOfWeek, isNull);
      expect(result.rollingWindowSize, isNull);
      // ScheduleSpec convenience getter
      expect(result.schedule, const DelaySchedule(14));

      final captured =
          verify(
                () => mockStageDao.insertStageDefinition(captureAny()),
              ).captured.single
              as db.StageDefinitionsCompanion;
      expect(captured.scheduleType.value, 'delay');
      expect(captured.delayDays.value, 14);
    });

    test(
      'addStage(WeeklySchedule) writes scheduleType=weekly and daysOfWeek to DAO',
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
          profileId: 1,
          trackId: 1,
          schedule: WeeklySchedule([1, 3, 5]),
        );

        expect(result.scheduleType, ScheduleType.weekly);
        expect(result.daysOfWeek, [1, 3, 5]);
        expect(result.schedule, WeeklySchedule([1, 3, 5]));

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
      'addStage(RollingSchedule) writes scheduleType=rolling and windowSize to DAO',
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
          profileId: 1,
          trackId: 1,
          schedule: RollingSchedule(10),
        );

        expect(result.scheduleType, ScheduleType.rolling);
        expect(result.rollingWindowSize, 10);
        expect(result.schedule, RollingSchedule(10));

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
      'WeeklySchedule() with empty daysOfWeek throws AssertionError',
      () async {
        // Validation now happens at ScheduleSpec construction time
        expect(() => WeeklySchedule([]), throwsA(isA<AssertionError>()));

        verifyNever(() => mockStageDao.insertStageDefinition(any()));
      },
    );

    test(
      'WeeklySchedule() with out-of-range day throws AssertionError',
      () async {
        expect(
          () => WeeklySchedule([0, 3, 5]), // 0 is invalid (Mon=1..Sun=7)
          throwsA(isA<AssertionError>()),
        );

        verifyNever(() => mockStageDao.insertStageDefinition(any()));
      },
    );

    test('RollingSchedule() with windowSize=0 throws AssertionError', () async {
      expect(() => RollingSchedule(0), throwsA(isA<AssertionError>()));

      verifyNever(() => mockStageDao.insertStageDefinition(any()));
    });
  });

  // =========================================================================
  // Group 2: addStage round-trip (real in-memory DB)
  // =========================================================================

  group('addStage — round-trip with real DB', () {
    test('WeeklySchedule round-trips for weekly stage', () async {
      final ctx = await _makeRealRepo();
      addTearDown(() => ctx.database.close());

      await ctx.repository.initializeDefaults(
        curriculum,
        profileId: 1,
        trackId: ctx.trackId,
      );

      final stage = await ctx.repository.addStage(
        curriculum,
        'Weekly Review',
        profileId: 1,
        trackId: ctx.trackId,
        schedule: WeeklySchedule([2, 4]),
      );

      expect(stage.scheduleType, ScheduleType.weekly);
      expect(stage.daysOfWeek, [2, 4]);
      expect(stage.rollingWindowSize, isNull);
      expect(stage.schedule, WeeklySchedule([2, 4]));

      // Verify persisted value is readable back
      final stages = await ctx.repository.getStagesForCurriculum(curriculum);
      final persisted = stages.firstWhere((s) => s.id == stage.id);
      expect(persisted.scheduleType, ScheduleType.weekly);
      expect(persisted.daysOfWeek, [2, 4]);
      expect(persisted.schedule, WeeklySchedule([2, 4]));
    });

    test('RollingSchedule round-trips for rolling stage', () async {
      final ctx = await _makeRealRepo();
      addTearDown(() => ctx.database.close());

      await ctx.repository.initializeDefaults(
        curriculum,
        profileId: 1,
        trackId: ctx.trackId,
      );

      final stage = await ctx.repository.addStage(
        curriculum,
        'Rolling',
        profileId: 1,
        trackId: ctx.trackId,
        schedule: RollingSchedule(7),
      );

      expect(stage.scheduleType, ScheduleType.rolling);
      expect(stage.rollingWindowSize, 7);
      expect(stage.daysOfWeek, isNull);
      expect(stage.schedule, RollingSchedule(7));

      final stages = await ctx.repository.getStagesForCurriculum(curriculum);
      final persisted = stages.firstWhere((s) => s.id == stage.id);
      expect(persisted.scheduleType, ScheduleType.rolling);
      expect(persisted.rollingWindowSize, 7);
      expect(persisted.schedule, RollingSchedule(7));
    });
  });

  // =========================================================================
  // Group 3: reorderStages — atomicity (real in-memory DB)
  // =========================================================================

  group('reorderStages — atomicity and Learn-at-1 guard (real DB)', () {
    test('reorderStages persists correct new positions', () async {
      final ctx = await _makeRealRepo();
      addTearDown(() => ctx.database.close());

      await ctx.repository.initializeDefaults(
        curriculum,
        profileId: 1,
        trackId: ctx.trackId,
      );

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
          profileId: 1,
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
          profileId: 1,
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

  // =========================================================================
  // Group 6: ScheduleSpec.fromParts — reconstruction from raw DB columns
  // =========================================================================

  group('ScheduleSpec.fromParts — reconstruction', () {
    test('fromParts with delay key returns DelaySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'delay',
        delayDays: 7,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, const DelaySchedule(7));
    });

    test('fromParts with weekly key returns WeeklySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'weekly',
        delayDays: 0,
        daysOfWeek: [1, 5],
        rollingWindowSize: null,
      );
      expect(spec, WeeklySchedule([1, 5]));
    });

    test('fromParts with rolling key returns RollingSchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'rolling',
        delayDays: 0,
        daysOfWeek: null,
        rollingWindowSize: 14,
      );
      expect(spec, RollingSchedule(14));
    });

    test('fromParts with unknown key falls back to DelaySchedule', () {
      final spec = ScheduleSpec.fromParts(
        scheduleTypeKey: 'unknown_legacy',
        delayDays: 3,
        daysOfWeek: null,
        rollingWindowSize: null,
      );
      expect(spec, const DelaySchedule(3));
    });
  });
}
