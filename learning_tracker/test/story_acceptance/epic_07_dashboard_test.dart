/// Story acceptance tests for Epic 7 -- Dashboard.
@Tags(['epic_7'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:test/test.dart';

import '../helpers/test_database.dart';

ContentItem _leaf({
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

void main() {
  // ── Story 7.1: Dashboard screen ───────────────────────────────

  group(
    'Story 7.1 -- Dashboard screen',
    tags: ['story_7_1'],
    skip: 'Backlog: dashboard screen not yet implemented',
    () {
      test('dashboard shows active curricula cards', () {
        // TODO: verify curriculum cards render for each active curriculum
      });

      test('tapping a curriculum card navigates to its content', () {
        // TODO: verify navigation
      });

      test('dashboard shows today\'s review count', () {
        // TODO: verify review count widget
      });
    },
  );

  // ── Story 7.2: Per-Curriculum Progress Views ────────────────

  group('Story 7.2 -- Per-Curriculum Progress Views', tags: ['story_7_2'], () {
    late AppDatabase db;

    setUp(() {
      db = createTestDatabase();
    });

    tearDown(() async {
      await db.close();
    });

    Future<StageDefinition> insertStage(
      int stageOrder,
      String stageName,
    ) async {
      final id = await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          curriculumId: 'mishnayos',
          stageOrder: stageOrder,
          stageName: stageName,
          delayDays: 0,
        ),
      );
      return (await db.stageDao.getStageDefinitionById(id))!;
    }

    Future<Completion> insertCompletion({
      required String sefariaRef,
      required int stageId,
      String trackType = 'personal',
    }) async {
      final id = await db.completionDao.insertCompletion(
        CompletionsCompanion.insert(
          curriculumId: 'mishnayos',
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          completedAt: DateTime.utc(2026, 3, 15),
        ),
      );
      return (await db.completionDao.getCompletionById(id))!;
    }

    // --- Unit tests ---

    test(
      'progress aggregation computes completion percentage for seder with 50% completed',
      () async {
        final items = [
          _leaf(level1: 'Seder Zeraim', level2: 'Berachos', sefariaRef: 'r1'),
          _leaf(level1: 'Seder Zeraim', level2: 'Peah', sefariaRef: 'r2'),
          _leaf(level1: 'Seder Zeraim', level2: 'Demai', sefariaRef: 'r3'),
          _leaf(level1: 'Seder Zeraim', level2: 'Kilayim', sefariaRef: 'r4'),
        ];

        final s = await insertStage(0, 'Learned');
        final completions = <Completion>[
          await insertCompletion(sefariaRef: 'r1', stageId: s.id),
          await insertCompletion(sefariaRef: 'r2', stageId: s.id),
        ];

        final result = CurriculumProgressService.compute(
          curriculumId: 'mishnayos',
          contentItems: items,
          completions: completions,
          stageDefinitions: [s],
          levelLabels: ['Seder', 'Masechta'],
        );

        expect(result.hierarchyLevels[0].completionPercentage, equals(0.5));
      },
    );

    test('stage breakdown counts are accurate', () async {
      final items = [
        _leaf(level1: 'S1', sefariaRef: 'a'),
        _leaf(level1: 'S1', sefariaRef: 'b'),
      ];

      final learn = await insertStage(0, 'Learned');
      final ch1 = await insertStage(1, 'Chazara 1');
      final ch2 = await insertStage(2, 'Chazara 2');

      final completions = <Completion>[
        await insertCompletion(sefariaRef: 'a', stageId: learn.id),
        await insertCompletion(sefariaRef: 'a', stageId: ch1.id),
        await insertCompletion(sefariaRef: 'b', stageId: learn.id),
        await insertCompletion(sefariaRef: 'b', stageId: ch1.id),
        await insertCompletion(sefariaRef: 'b', stageId: ch2.id),
      ];

      final result = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: items,
        completions: completions,
        stageDefinitions: [learn, ch1, ch2],
        levelLabels: ['Seder'],
      );

      final sb = result.hierarchyLevels[0].stageBreakdown;
      expect(sb[0].count, equals(2)); // Learned: 2
      expect(sb[1].count, equals(2)); // Chazara 1: 2
      expect(sb[2].count, equals(1)); // Chazara 2: 1
    });

    test('track breakdown separates personal, school, tutor', () async {
      final items = [_leaf(level1: 'S1', sefariaRef: 'x')];
      final s = await insertStage(0, 'Learned');
      final completions = <Completion>[
        await insertCompletion(
          sefariaRef: 'x',
          stageId: s.id,
          trackType: 'personal',
        ),
        await insertCompletion(
          sefariaRef: 'x',
          stageId: s.id,
          trackType: 'school',
        ),
        await insertCompletion(
          sefariaRef: 'x',
          stageId: s.id,
          trackType: 'tutor',
        ),
        await insertCompletion(
          sefariaRef: 'x',
          stageId: s.id,
          trackType: 'tutor',
        ),
      ];

      final result = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: items,
        completions: completions,
        stageDefinitions: [s],
        levelLabels: ['Seder'],
      );

      final tb = result.hierarchyLevels[0].trackBreakdown;
      expect(tb[TrackType.personal], equals(1));
      expect(tb[TrackType.school], equals(1));
      expect(tb[TrackType.tutor], equals(2));
    });

    test(
      'overall stats categorize into completed/in-progress/not-started',
      () async {
        final items = [
          _leaf(level1: 'S', sefariaRef: 'a'),
          _leaf(level1: 'S', sefariaRef: 'b'),
          _leaf(level1: 'S', sefariaRef: 'c'),
        ];

        final s1 = await insertStage(0, 'Learned');
        final s2 = await insertStage(1, 'Chazara 1');

        final completions = <Completion>[
          await insertCompletion(sefariaRef: 'a', stageId: s1.id),
          await insertCompletion(sefariaRef: 'a', stageId: s2.id),
          await insertCompletion(sefariaRef: 'b', stageId: s1.id),
        ];

        final result = CurriculumProgressService.compute(
          curriculumId: 'mishnayos',
          contentItems: items,
          completions: completions,
          stageDefinitions: [s1, s2],
          levelLabels: ['Seder'],
        );

        expect(result.overallStats.completedAllStages, equals(1));
        expect(result.overallStats.inProgress, equals(1));
        expect(result.overallStats.notStarted, equals(1));
      },
    );

    test('pace status is null when no goal exists', () async {
      final goals = await db.goalDao.getGoalsByCurriculum('mishnayos');
      expect(goals, isEmpty);
    });

    test('family provider returns independent state per curriculum', () async {
      final items1 = [_leaf(level1: 'S', sefariaRef: 'r1')];
      final items2 = [_leaf(level1: 'S', sefariaRef: 'r2')];

      final s = await insertStage(0, 'Learned');
      final c1 = <Completion>[
        await insertCompletion(sefariaRef: 'r1', stageId: s.id),
      ];

      final result1 = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: items1,
        completions: c1,
        stageDefinitions: [s],
        levelLabels: ['Seder'],
      );
      final result2 = CurriculumProgressService.compute(
        curriculumId: 'bavli',
        contentItems: items2,
        completions: [],
        stageDefinitions: [s],
        levelLabels: ['Seder'],
      );

      expect(result1.overallStats.completedAllStages, equals(1));
      expect(result2.overallStats.completedAllStages, equals(0));
    });

    // --- Integration tests ---

    test('import content, mark completions, verify counts match', () async {
      final items = [
        _leaf(level1: 'Zeraim', level2: 'Berachos', sefariaRef: 'M_B_1'),
        _leaf(level1: 'Zeraim', level2: 'Berachos', sefariaRef: 'M_B_2'),
        _leaf(level1: 'Zeraim', level2: 'Peah', sefariaRef: 'M_P_1'),
        _leaf(level1: 'Moed', level2: 'Shabbos', sefariaRef: 'M_S_1'),
      ];

      final learn = await insertStage(0, 'Learned');
      final ch1 = await insertStage(1, 'Chazara 1');

      final completions = <Completion>[
        await insertCompletion(sefariaRef: 'M_B_1', stageId: learn.id),
        await insertCompletion(
          sefariaRef: 'M_B_1',
          stageId: ch1.id,
          trackType: 'school',
        ),
        await insertCompletion(sefariaRef: 'M_B_2', stageId: learn.id),
        await insertCompletion(
          sefariaRef: 'M_S_1',
          stageId: learn.id,
          trackType: 'tutor',
        ),
      ];

      final result = CurriculumProgressService.compute(
        curriculumId: 'mishnayos',
        contentItems: items,
        completions: completions,
        stageDefinitions: [learn, ch1],
        levelLabels: ['Seder', 'Masechta'],
      );

      expect(result.overallStats.totalItems, equals(4));
      expect(result.overallStats.completedAllStages, equals(1));
      expect(result.overallStats.inProgress, equals(2));
      expect(result.overallStats.notStarted, equals(1));

      final zeraim = result.hierarchyLevels[0];
      expect(zeraim.totalItems, equals(3));
      expect(zeraim.completedItems, equals(2));

      final moed = result.hierarchyLevels[1];
      expect(moed.totalItems, equals(1));
      expect(moed.completedItems, equals(1));
    });

    test('set goal, make progress, verify pace status', () async {
      await db.goalDao.insertGoal(
        GoalsCompanion.insert(
          curriculumId: 'mishnayos',
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          targetDate: Value(DateTime.utc(2026, 6, 1)),
          targetPercent: const Value(100.0),
        ),
      );

      for (var i = 1; i <= 7; i++) {
        await db.completionDao.insertCompletion(
          CompletionsCompanion.insert(
            curriculumId: 'mishnayos',
            sefariaRef: 'ref_$i',
            stageId: 1,
            trackType: 'personal',
            completedAt: DateTime.utc(2026, 3, 16 - i),
          ),
        );
      }

      final goals = await db.goalDao.getGoalsByCurriculum('mishnayos');
      final goal = goals.first;

      final allCompletions = await db.completionDao.getCompletionsByCurriculum(
        'mishnayos',
      );
      final personalCompletions = allCompletions
          .where((c) => c.trackType == TrackType.personal.storageKey)
          .toList();

      final dailyCounts = <DateTime, int>{};
      for (final c in personalCompletions) {
        final date = DateTime.utc(
          c.completedAt.year,
          c.completedAt.month,
          c.completedAt.day,
        );
        dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
      }

      final pace = PaceCalculator.calculate(
        goalStartDate: goal.createdAt,
        goalDeadline: goal.targetDate!,
        totalItems: 100,
        completedItems: personalCompletions.length,
        dailyCompletionCounts: dailyCounts,
        today: DateTime.utc(2026, 3, 16),
      );

      expect(pace, isNotNull);
      expect(pace.rollingAverage, equals(1.0));
      expect(pace.status, equals(PaceStatusType.behind));
    });
  });

  // ── Story 7.3: Daily summary ──────────────────────────────────

  group(
    'Story 7.3 -- Daily summary',
    tags: ['story_7_3'],
    skip: 'Backlog: daily summary not yet implemented',
    () {
      test('summary shows items completed today', () {
        // TODO: verify today filter on completions
      });

      test('summary shows points earned today', () {
        // TODO: verify points aggregation
      });
    },
  );
}
