import 'package:drift/drift.dart' show Value;
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:test/test.dart';

import '../../../../helpers/drift_memory.dart';
import '../../../../helpers/test_database.dart';

void main() {
  late UserDatabase db;
  late int trackId;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);

    final trackRow = await db
        .into(db.curriculumTracks)
        .insertReturning(
          CurriculumTracksCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            stateChangedAt: DateTime.utc(2026, 1, 1),
            activatedAt: DateTime.utc(2026, 1, 1),
          ),
        );
    trackId = trackRow.id;
  });

  tearDown(() async {
    await db.close();
  });

  /// Helper to create a leaf content item.
  ContentItem leaf({
    required String level1,
    String? level2,
    required String sefariaRef,
  }) {
    return ContentItem(
      curriculumId: 'mishnayos',
      level1: level1,
      level2: level2,
      displayNameHe: sefariaRef,
      displayNameEn: sefariaRef,
      sefariaRef: sefariaRef,
      sortOrder: 0,
      isLeaf: true,
    );
  }

  /// Helper to insert a completion and return the generated row.
  Future<Completion> insertCompletion(
    UserDatabase db, {
    required String sefariaRef,
    required int stageId,
    String trackType = 'personal',
    String curriculumId = 'mishnayos',
  }) async {
    final id = await seedCompletion(
      db,
      CompletionEventsCompanion.insert(
        profileId: 1,
        curriculumId: curriculumId,
        sefariaRef: sefariaRef,
        stageId: stageId,
        trackType: trackType,
        trackId: Value(trackId),
        eventTimestamp: DateTime.utc(2026, 3, 15),
      ),
    );
    return (await db.completionDao.getCompletionById(id))!;
  }

  /// Helper to insert a stage definition and return the domain model.
  Future<domain_stage.StageDefinition> insertStage(
    UserDatabase db, {
    required int stageOrder,
    required String stageName,
    String curriculumId = 'mishnayos',
  }) async {
    final id = await db.stageDao.insertStageDefinition(
      StageDefinitionsCompanion.insert(
        profileId: 1,
        curriculumId: curriculumId,
        trackId: trackId,
        stageOrder: stageOrder,
        stageName: stageName,
        schedule: const Value('{"type":"delay","delay_days":0}'),
      ),
    );
    final curricEnum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => CurriculumId.mishnayos,
    );
    return domain_stage.StageDefinition(
      id: id,
      curriculumId: curricEnum,
      stageOrder: stageOrder,
      stageName: stageName,
      delayDays: 0,
      isDefault: false,
      scheduleType: ScheduleType.delay,
    );
  }

  group('CurriculumProgressService', () {
    test(
      'computes completion percentage for seder with 50% masechtos completed',
      () async {
        // 4 leaf items in Seder Zeraim, 2 completed
        final items = [
          leaf(level1: 'Seder Zeraim', level2: 'Berachos', sefariaRef: 'ref1'),
          leaf(level1: 'Seder Zeraim', level2: 'Peah', sefariaRef: 'ref2'),
          leaf(level1: 'Seder Zeraim', level2: 'Demai', sefariaRef: 'ref3'),
          leaf(level1: 'Seder Zeraim', level2: 'Kilayim', sefariaRef: 'ref4'),
        ];

        final stage = await insertStage(
          db,
          stageOrder: 0,
          stageName: 'Learned',
        );
        final completions = <Completion>[
          await insertCompletion(
            db,
            sefariaRef: 'ref1',
            stageId: stage.stageOrder,
          ),
          await insertCompletion(
            db,
            sefariaRef: 'ref2',
            stageId: stage.stageOrder,
          ),
        ];

        final result = CurriculumProgressService.compute(
          curriculumId: 'mishnayos',
          contentItems: items,
          completions: completions,
          stageDefinitions: [stage],
          levelLabels: ['Seder', 'Masechta'],
        );

        expect(result.hierarchyLevels, hasLength(1));
        final seder = result.hierarchyLevels[0];
        expect(seder.levelName, 'Seder Zeraim');
        expect(seder.totalItems, 4);
        expect(seder.completedItems, 2);
        expect(seder.completionPercentage, 0.5);
      },
    );

    test('stage breakdown counts are accurate per hierarchy level', () async {
      final items = [
        leaf(level1: 'Seder Zeraim', sefariaRef: 'ref1'),
        leaf(level1: 'Seder Zeraim', sefariaRef: 'ref2'),
        leaf(level1: 'Seder Zeraim', sefariaRef: 'ref3'),
      ];

      final learnStage = await insertStage(
        db,
        stageOrder: 0,
        stageName: 'Learned',
      );
      final chazara1 = await insertStage(
        db,
        stageOrder: 1,
        stageName: 'Chazara 1',
      );
      final chazara2 = await insertStage(
        db,
        stageOrder: 2,
        stageName: 'Chazara 2',
      );

      final completions = <Completion>[
        // ref1: learned + chazara1
        await insertCompletion(
          db,
          sefariaRef: 'ref1',
          stageId: learnStage.stageOrder,
        ),
        await insertCompletion(
          db,
          sefariaRef: 'ref1',
          stageId: chazara1.stageOrder,
        ),
        // ref2: learned only
        await insertCompletion(
          db,
          sefariaRef: 'ref2',
          stageId: learnStage.stageOrder,
        ),
        // ref3: learned + chazara1 + chazara2
        await insertCompletion(
          db,
          sefariaRef: 'ref3',
          stageId: learnStage.stageOrder,
        ),
        await insertCompletion(
          db,
          sefariaRef: 'ref3',
          stageId: chazara1.stageOrder,
        ),
        await insertCompletion(
          db,
          sefariaRef: 'ref3',
          stageId: chazara2.stageOrder,
        ),
      ];

      final result = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: items,
        completions: completions,
        stageDefinitions: [learnStage, chazara1, chazara2],
        levelLabels: ['Seder'],
      );

      final seder = result.hierarchyLevels[0];
      expect(seder.stageBreakdown[0].stageName, 'Learned');
      expect(seder.stageBreakdown[0].count, 3); // all 3 refs learned
      expect(seder.stageBreakdown[1].stageName, 'Chazara 1');
      expect(seder.stageBreakdown[1].count, 2); // ref1 + ref3
      expect(seder.stageBreakdown[2].stageName, 'Chazara 2');
      expect(seder.stageBreakdown[2].count, 1); // ref3 only
    });

    test('track breakdown counts personal completions', () async {
      final items = [
        leaf(level1: 'Seder Zeraim', level2: 'Berachos', sefariaRef: 'ref1'),
      ];

      final stage = await insertStage(db, stageOrder: 0, stageName: 'Learned');
      final completions = <Completion>[
        await insertCompletion(
          db,
          sefariaRef: 'ref1',
          stageId: stage.stageOrder,
          trackType: 'personal',
        ),
        await insertCompletion(
          db,
          sefariaRef: 'ref1',
          stageId: stage.stageOrder,
          trackType: 'personal',
        ),
        await insertCompletion(
          db,
          sefariaRef: 'ref1',
          stageId: stage.stageOrder,
          trackType: 'personal',
        ),
      ];

      final result = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: items,
        completions: completions,
        stageDefinitions: [stage],
        levelLabels: ['Seder', 'Masechta'],
      );

      final seder = result.hierarchyLevels[0];
      expect(seder.trackBreakdown['personal'], 3);
    });

    test('overall stats categorize items correctly', () async {
      final items = [
        leaf(level1: 'S1', sefariaRef: 'ref1'),
        leaf(level1: 'S1', sefariaRef: 'ref2'),
        leaf(level1: 'S1', sefariaRef: 'ref3'),
        leaf(level1: 'S1', sefariaRef: 'ref4'),
      ];

      final s1 = await insertStage(db, stageOrder: 0, stageName: 'Learned');
      final s2 = await insertStage(db, stageOrder: 1, stageName: 'Chazara 1');

      final completions = <Completion>[
        // ref1: completed all stages
        await insertCompletion(db, sefariaRef: 'ref1', stageId: s1.stageOrder),
        await insertCompletion(db, sefariaRef: 'ref1', stageId: s2.stageOrder),
        // ref2: in progress (only 1 of 2 stages)
        await insertCompletion(db, sefariaRef: 'ref2', stageId: s1.stageOrder),
        // ref3, ref4: not started
      ];

      final result = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: items,
        completions: completions,
        stageDefinitions: [s1, s2],
        levelLabels: ['Seder'],
      );

      expect(result.overallStats.totalItems, 4);
      expect(result.overallStats.completedAllStages, 1);
      expect(result.overallStats.inProgress, 1);
      expect(result.overallStats.notStarted, 2);
    });

    test('hierarchy has correct sub-levels', () async {
      final items = [
        leaf(level1: 'Seder Zeraim', level2: 'Berachos', sefariaRef: 'ref1'),
        leaf(level1: 'Seder Zeraim', level2: 'Berachos', sefariaRef: 'ref2'),
        leaf(level1: 'Seder Zeraim', level2: 'Peah', sefariaRef: 'ref3'),
        leaf(level1: 'Seder Moed', level2: 'Shabbos', sefariaRef: 'ref4'),
      ];

      final stage = await insertStage(db, stageOrder: 0, stageName: 'Learned');
      final completions = <Completion>[
        await insertCompletion(
          db,
          sefariaRef: 'ref1',
          stageId: stage.stageOrder,
        ),
        await insertCompletion(
          db,
          sefariaRef: 'ref4',
          stageId: stage.stageOrder,
        ),
      ];

      final result = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: items,
        completions: completions,
        stageDefinitions: [stage],
        levelLabels: ['Seder', 'Masechta'],
      );

      expect(result.hierarchyLevels, hasLength(2));

      final zeraim = result.hierarchyLevels[0];
      expect(zeraim.levelName, 'Seder Zeraim');
      expect(zeraim.totalItems, 3);
      expect(zeraim.completedItems, 1);
      expect(zeraim.subLevels, hasLength(2));
      expect(zeraim.subLevels![0].levelName, 'Berachos');
      expect(zeraim.subLevels![0].totalItems, 2);
      expect(zeraim.subLevels![0].completedItems, 1);
      expect(zeraim.subLevels![1].levelName, 'Peah');
      expect(zeraim.subLevels![1].totalItems, 1);
      expect(zeraim.subLevels![1].completedItems, 0);

      final moed = result.hierarchyLevels[1];
      expect(moed.levelName, 'Seder Moed');
      expect(moed.totalItems, 1);
      expect(moed.completedItems, 1);
    });

    test('empty curriculum returns zero stats', () {
      final result = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: [],
        completions: [],
        stageDefinitions: [],
        levelLabels: ['Seder', 'Masechta'],
      );

      expect(result.hierarchyLevels, isEmpty);
      expect(result.overallStats.totalItems, 0);
      expect(result.overallStats.completedAllStages, 0);
      expect(result.overallStats.inProgress, 0);
      expect(result.overallStats.notStarted, 0);
    });
  });
}
