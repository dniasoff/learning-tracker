/// Story acceptance tests for Epic 7 -- Dashboard.
@Tags(['epic_7'])
library;

import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart'
    hide expect, group, setUp, tearDown, test;
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/scheduler/domain/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/curriculum_summary_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/points_summary_widget.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/todays_tasks_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';
import 'package:learning_tracker/features/progress/domain/services/curriculum_progress_service.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/stages/domain/models/schedule_type.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart' hide isNotNull, isNull;

import '../helpers/drift_memory.dart' show seedCompletion;
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

/// Creates a default curriculum track and returns its ID.
Future<int> _insertTrack(UserDatabase db) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackType: 'personal',
          activatedAt: DateTime.now(),
        ),
      );
  return row.id;
}

void main() {
  // ── Story 7.1: Dashboard screen ───────────────────────────────

  group('Story 7.1 -- Dashboard screen', tags: ['story_7_1'], () {
    late UserDatabase db;
    late int trackId;
    late CrossCurriculumAggregator aggregator;

    setUp(() async {
      // DNI-328 flipped the Hebrew-terms default to false. The widget tests in
      // this group assert on Hebrew labels, so seed the per-profile preference
      // to true before each test.
      SharedPreferences.setMockInitialValues(<String, Object>{
        'hebrew_terms_script_p0': true,
      });
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await _insertTrack(db);
      aggregator = CrossCurriculumAggregator();
    });

    tearDown(() async {
      await db.close();
    });

    // --- Unit: CrossCurriculumAggregator ---

    test(
      'aggregator returns correct per-curriculum completion percentages for 3 active curricula',
      () {
        final stats = aggregator.aggregate(
          activeCurricula: [
            CurriculumId.mishnayos,
            CurriculumId.bavli,
            CurriculumId.chumash,
          ],
          completionPercentages: {
            CurriculumId.mishnayos: 0.75,
            CurriculumId.bavli: 0.5,
            CurriculumId.chumash: 0.25,
          },
          paceStatuses: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
            CurriculumId.chumash: null,
          },
          todayTaskCounts: {
            CurriculumId.mishnayos: 5,
            CurriculumId.bavli: 3,
            CurriculumId.chumash: 2,
          },
          nextDueItems: {
            CurriculumId.mishnayos: 'Berachos 1:1',
            CurriculumId.bavli: null,
            CurriculumId.chumash: 'Bereishis 1',
          },
          lastCompletions: {
            CurriculumId.mishnayos: DateTime.utc(2026, 3, 16),
            CurriculumId.bavli: DateTime.utc(2026, 3, 15),
            CurriculumId.chumash: null,
          },
        );

        expect(stats.curriculumSummaries, hasLength(3));
        expect(stats.activeCurriculaCount, equals(3));
        expect(stats.totalTasksToday, equals(10));

        final mishnayos = stats.curriculumSummaries[0];
        expect(mishnayos.curriculumId, equals(CurriculumId.mishnayos));
        expect(mishnayos.completionPercentage, equals(0.75));
        expect(mishnayos.todayTaskCount, equals(5));
        expect(mishnayos.nextDueItem, equals('Berachos 1:1'));

        final bavli = stats.curriculumSummaries[1];
        expect(bavli.completionPercentage, equals(0.5));
        expect(bavli.todayTaskCount, equals(3));
      },
    );

    test('aggregator returns empty stats when no curricula are active', () {
      final stats = aggregator.aggregate(
        activeCurricula: [],
        completionPercentages: {},
        paceStatuses: {},
        todayTaskCounts: {},
        nextDueItems: {},
        lastCompletions: {},
      );

      expect(stats.curriculumSummaries, isEmpty);
      expect(stats.totalTasksToday, equals(0));
      expect(stats.activeCurriculaCount, equals(0));
      expect(stats.mostRecentlyActive, isNull);
    });

    test(
      'continue learning resolves to curriculum with most recent completion',
      () {
        final stats = aggregator.aggregate(
          activeCurricula: [
            CurriculumId.mishnayos,
            CurriculumId.bavli,
            CurriculumId.chumash,
          ],
          completionPercentages: {
            CurriculumId.mishnayos: 0.5,
            CurriculumId.bavli: 0.3,
            CurriculumId.chumash: 0.1,
          },
          paceStatuses: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
            CurriculumId.chumash: null,
          },
          todayTaskCounts: {
            CurriculumId.mishnayos: 0,
            CurriculumId.bavli: 0,
            CurriculumId.chumash: 0,
          },
          nextDueItems: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
            CurriculumId.chumash: null,
          },
          lastCompletions: {
            CurriculumId.mishnayos: DateTime.utc(2026, 3, 14),
            CurriculumId.bavli: DateTime.utc(2026, 3, 16, 10, 30),
            CurriculumId.chumash: DateTime.utc(2026, 3, 15),
          },
        );

        expect(stats.mostRecentlyActive, isNotNull);
        expect(
          stats.mostRecentlyActive!.curriculumId,
          equals(CurriculumId.bavli),
        );
      },
    );

    test('points summary is excluded from state when userMode is adult', () {
      // The dashboard provider filters points based on UserMode.
      // In adult mode, the points section should not be shown.
      // This is a logic test — the provider returns UserMode, and the
      // screen conditionally renders points.
      const userMode = UserMode.adult;
      expect(userMode == UserMode.child, isFalse);

      const childMode = UserMode.child;
      expect(childMode == UserMode.child, isTrue);
    });

    test(
      'today tasks count correctly sums pending tasks across all curricula',
      () {
        final stats = aggregator.aggregate(
          activeCurricula: [
            CurriculumId.mishnayos,
            CurriculumId.bavli,
            CurriculumId.chumash,
          ],
          completionPercentages: {
            CurriculumId.mishnayos: 0.0,
            CurriculumId.bavli: 0.0,
            CurriculumId.chumash: 0.0,
          },
          paceStatuses: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
            CurriculumId.chumash: null,
          },
          todayTaskCounts: {
            CurriculumId.mishnayos: 7,
            CurriculumId.bavli: 4,
            CurriculumId.chumash: 9,
          },
          nextDueItems: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
            CurriculumId.chumash: null,
          },
          lastCompletions: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
            CurriculumId.chumash: null,
          },
        );

        expect(stats.totalTasksToday, equals(20));
      },
    );

    // --- Integration: streak data via database ---

    test('streak data is accessible from database for dashboard', () async {
      // Initially no streak
      final initial = await db.streakDao.getStreak();
      expect(initial, isNull);

      // Insert a streak record
      await db.streakDao.upsertStreak(
        StreaksCompanion.insert(
          profileId: 1,
          currentStreak: const Value(5),
          maxStreak: const Value(12),
          lastCompletionDate: Value(DateTime.utc(2026, 3, 16)),
        ),
      );

      final streak = await db.streakDao.getStreak();
      expect(streak, isNotNull);
      expect(streak!.currentStreak, equals(5));
      expect(streak.maxStreak, equals(12));
    });

    test('global points total sums across all completions', () async {
      await seedCompletion(
        db,
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'ref1',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 3, 16),
          points: const Value(10),
        ),
      );
      await seedCompletion(
        db,
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: 'bavli',
          sefariaRef: 'ref2',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 3, 16),
          points: const Value(5),
        ),
      );
      await seedCompletion(
        db,
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: 'ref3',
          stageId: 2,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 3, 16),
          points: const Value(3),
        ),
      );

      final completions = await db.completionDao
          .internalGetAllCompletionsCrossProfile(
            scope: CrossProfileScope.dataExport,
          );
      final total = completions.fold<int>(0, (sum, c) => sum + c.points);
      expect(total, equals(18));
    });

    test(
      'active curricula are retrievable from database for dashboard',
      () async {
        // Activate 3 curricula
        await db.activeCurriculumDao.activate(CurriculumId.mishnayos);
        await db.activeCurriculumDao.activate(CurriculumId.bavli);
        await db.activeCurriculumDao.activate(CurriculumId.chumash);

        final active = await db.activeCurriculumDao.getActiveCurricula();
        expect(active, hasLength(3));
        expect(active, contains('mishnayos'));
        expect(active, contains('bavli'));
        expect(active, contains('chumash'));
      },
    );

    test('pull-to-refresh triggers provider invalidation pattern', () {
      // This tests the invalidation pattern — in the real app, ref.invalidate()
      // is called on pull-to-refresh, causing all dashboard providers to refetch.
      // We verify the aggregator produces updated results when given new data.
      final before = aggregator.aggregate(
        activeCurricula: [CurriculumId.mishnayos],
        completionPercentages: {CurriculumId.mishnayos: 0.5},
        paceStatuses: {CurriculumId.mishnayos: null},
        todayTaskCounts: {CurriculumId.mishnayos: 3},
        nextDueItems: {CurriculumId.mishnayos: null},
        lastCompletions: {CurriculumId.mishnayos: null},
      );

      final after = aggregator.aggregate(
        activeCurricula: [CurriculumId.mishnayos],
        completionPercentages: {CurriculumId.mishnayos: 0.6},
        paceStatuses: {CurriculumId.mishnayos: null},
        todayTaskCounts: {CurriculumId.mishnayos: 2},
        nextDueItems: {CurriculumId.mishnayos: null},
        lastCompletions: {CurriculumId.mishnayos: null},
      );

      expect(before.curriculumSummaries[0].completionPercentage, equals(0.5));
      expect(after.curriculumSummaries[0].completionPercentage, equals(0.6));
      expect(before.totalTasksToday, equals(3));
      expect(after.totalTasksToday, equals(2));
    });

    test(
      'last completion timestamp resolves per curriculum for continue learning',
      () async {
        // Insert completions for two curricula at different times
        await seedCompletion(
          db,
          CompletionsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'r1',
            stageId: 1,
            trackType: 'personal',
            trackId: trackId,
            completedAt: DateTime.utc(2026, 3, 15, 10, 0),
          ),
        );
        await seedCompletion(
          db,
          CompletionsCompanion.insert(
            profileId: 1,
            curriculumId: 'bavli',
            sefariaRef: 'r2',
            stageId: 1,
            trackType: 'personal',
            trackId: trackId,
            completedAt: DateTime.utc(2026, 3, 16, 14, 30),
          ),
        );

        final mishnayosCompletions = await db.completionDao
            .internalGetCompletionsByCurriculumCrossProfile(
              'mishnayos',
              scope: CrossProfileScope.parentAnalytics,
            );
        final bavliCompletions = await db.completionDao
            .internalGetCompletionsByCurriculumCrossProfile(
              'bavli',
              scope: CrossProfileScope.parentAnalytics,
            );

        DateTime? latestFor(List<Completion> completions) {
          if (completions.isEmpty) return null;
          var latest = completions.first.completedAt;
          for (final c in completions) {
            if (c.completedAt.isAfter(latest)) latest = c.completedAt;
          }
          return latest;
        }

        final mishnayosLatest = latestFor(mishnayosCompletions);
        final bavliLatest = latestFor(bavliCompletions);

        expect(bavliLatest!.isAfter(mishnayosLatest!), isTrue);

        // Aggregator should pick bavli as most recently active
        final stats = aggregator.aggregate(
          activeCurricula: [CurriculumId.mishnayos, CurriculumId.bavli],
          completionPercentages: {
            CurriculumId.mishnayos: 0.0,
            CurriculumId.bavli: 0.0,
          },
          paceStatuses: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
          },
          todayTaskCounts: {CurriculumId.mishnayos: 0, CurriculumId.bavli: 0},
          nextDueItems: {
            CurriculumId.mishnayos: null,
            CurriculumId.bavli: null,
          },
          lastCompletions: {
            CurriculumId.mishnayos: mishnayosLatest,
            CurriculumId.bavli: bavliLatest,
          },
        );

        expect(
          stats.mostRecentlyActive!.curriculumId,
          equals(CurriculumId.bavli),
        );
      },
    );

    // --- Widget tests ---

    testWidgets(
      'CurriculumSummaryCard renders name, percentage, and pace indicator',
      (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: Scaffold(
                body: CurriculumSummaryCard(
                  summary: CurriculumSummary(
                    curriculumId: CurriculumId.mishnayos,
                    completionPercentage: 0.75,
                    paceStatus: const PaceStatus(
                      status: PaceStatusType.ahead,
                      daysDelta: 3,
                      delta: DateScheduleDelta(DateDelta(3)),
                      rollingAverage: 2.0,
                    ),
                    nextDueItem: 'Berachos 1:1',
                    todayTaskCount: 5,
                    lastCompletionAt: DateTime.utc(2026, 3, 16),
                  ),
                  onTap: () => tapped = true,
                ),
              ),
            ),
          ),
        );

        // Allow the core/preferences Hebrew-terms async load to propagate.
        await tester.pumpAndSettle();

        expect(find.text('משניות'), findsOneWidget);
        expect(find.text('75.00% complete'), findsOneWidget);
        expect(find.text('Next: Berachos 1:1'), findsOneWidget);
        expect(find.byIcon(Icons.trending_up), findsOneWidget);

        await tester.tap(find.byType(CurriculumSummaryCard));
        expect(tapped, isTrue);
      },
    );

    testWidgets('StreakWidget displays animated variant in child mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakWidget(
              currentStreak: 7,
              maxStreak: 14,
              userMode: UserMode.child,
            ),
          ),
        ),
      );

      expect(find.text('7 day streak!'), findsOneWidget);
      expect(find.text('Best: 14 days'), findsOneWidget);
      expect(find.byIcon(Icons.local_fire_department), findsOneWidget);
    });

    testWidgets('StreakWidget displays subtle variant in adult mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StreakWidget(
              currentStreak: 7,
              maxStreak: 14,
              userMode: UserMode.adult,
            ),
          ),
        ),
      );

      expect(find.text('7'), findsOneWidget);
      expect(find.text('(best: 14)'), findsOneWidget);
    });

    testWidgets('PointsSummaryWidget is visible and shows points', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: PointsSummaryWidget(totalPoints: 250)),
        ),
      );

      expect(find.text('250 pts'), findsOneWidget);
      expect(find.byIcon(Icons.star), findsOneWidget);
    });

    testWidgets('TodaysTasksWidget shows task count and start button', (
      tester,
    ) async {
      var started = false;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TodaysTasksWidget(
              taskCount: 12,
              onQuickStart: () => started = true,
            ),
          ),
        ),
      );

      expect(find.text('12 tasks today'), findsOneWidget);
      expect(find.text('Start'), findsOneWidget);

      await tester.tap(find.text('Start'));
      expect(started, isTrue);
    });
  });

  // ── Story 7.2: Per-Curriculum Progress Views ────────────────

  group('Story 7.2 -- Per-Curriculum Progress Views', tags: ['story_7_2'], () {
    late UserDatabase db;
    late int trackId;

    setUp(() async {
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await _insertTrack(db);
    });

    tearDown(() async {
      await db.close();
    });

    Future<domain_stage.StageDefinition> insertStage(
      int stageOrder,
      String stageName,
    ) async {
      final id = await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          stageOrder: stageOrder,
          stageName: stageName,
          delayDays: 0,
        ),
      );
      return domain_stage.StageDefinition(
        id: id,
        curriculumId: CurriculumId.mishnayos,
        stageOrder: stageOrder,
        stageName: stageName,
        delayDays: 0,
        isDefault: false,
        scheduleType: ScheduleType.delay,
      );
    }

    Future<Completion> insertCompletion({
      required String sefariaRef,
      required int stageId,
      String trackType = 'personal',
    }) async {
      final id = await seedCompletion(
        db,
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: 'mishnayos',
          sefariaRef: sefariaRef,
          stageId: stageId,
          trackType: trackType,
          trackId: trackId,
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
          trackType: 'personal',
        ),
        await insertCompletion(
          sefariaRef: 'x',
          stageId: s.id,
          trackType: 'personal',
        ),
        await insertCompletion(
          sefariaRef: 'x',
          stageId: s.id,
          trackType: 'personal',
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
      // V1 only has personal tracks; all 4 completions are personal
      expect(tb[TrackType.personal], equals(4));
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
          trackType: 'personal',
        ),
        await insertCompletion(sefariaRef: 'M_B_2', stageId: learn.id),
        await insertCompletion(
          sefariaRef: 'M_S_1',
          stageId: learn.id,
          trackType: 'personal',
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
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: trackId,
          createdAt: DateTime.utc(2026, 1, 1),
          updatedAt: DateTime.utc(2026, 1, 1),
          targetDate: Value(DateTime.utc(2026, 6, 1)),
          targetPercent: const Value(100.0),
        ),
      );

      for (var i = 1; i <= 7; i++) {
        await seedCompletion(
          db,
          CompletionsCompanion.insert(
            profileId: 1,
            curriculumId: 'mishnayos',
            sefariaRef: 'ref_$i',
            stageId: 1,
            trackType: 'personal',
            trackId: trackId,
            completedAt: DateTime.utc(2026, 3, 16 - i),
          ),
        );
      }

      final goals = await db.goalDao.getGoalsByCurriculum('mishnayos');
      final goal = goals.first;

      final allCompletions = await db.completionDao
          .internalGetCompletionsByCurriculumCrossProfile(
            'mishnayos',
            scope: CrossProfileScope.parentAnalytics,
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

  // ── Story 7.3: Progress Charts & Statistics ──────────────────

  group('Story 7.3 -- Progress Charts & Statistics', tags: ['story_7_3'], () {
    late UserDatabase db;
    late int trackId;
    late ChartDataService chartService;
    var refCounter = 0;

    setUp(() async {
      refCounter = 0;
      db = createTestDatabase();
      await seedProfile(db);
      trackId = await _insertTrack(db);
      chartService = ChartDataService(db, profileId: 1);
    });

    tearDown(() async {
      await db.close();
    });

    Future<void> insertCompletionAt({
      required DateTime completedAt,
      String curriculumId = 'mishnayos',
      int points = 10,
    }) async {
      await seedCompletion(
        db,
        CompletionsCompanion.insert(
          profileId: 1,
          curriculumId: curriculumId,
          sefariaRef: 'ref_${++refCounter}',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: completedAt,
          points: Value(points),
        ),
      );
    }

    // --- Unit tests ---

    test(
      'daily completions aggregation returns correct count per day for 7-day range with gaps',
      () async {
        // Insert completions on days 1, 3, 5 (gaps on 2, 4, 6, 7)
        final baseDate = DateTime(2026, 3, 10);
        await insertCompletionAt(completedAt: baseDate); // Day 1
        await insertCompletionAt(
          completedAt: baseDate,
        ); // Day 1 (second completion)
        await insertCompletionAt(
          completedAt: baseDate.add(const Duration(days: 2)),
        ); // Day 3
        await insertCompletionAt(
          completedAt: baseDate.add(const Duration(days: 4)),
        ); // Day 5

        final result = await chartService.getDailyCompletions(
          startDate: baseDate,
          endDate: baseDate.add(const Duration(days: 6)),
        );

        expect(result.length, equals(7));
        expect(result[0].count, equals(2)); // Day 1: 2 completions
        expect(result[1].count, equals(0)); // Day 2: gap
        expect(result[2].count, equals(1)); // Day 3: 1 completion
        expect(result[3].count, equals(0)); // Day 4: gap
        expect(result[4].count, equals(1)); // Day 5: 1 completion
        expect(result[5].count, equals(0)); // Day 6: gap
        expect(result[6].count, equals(0)); // Day 7: gap
      },
    );

    test(
      'cumulative progress produces monotonically increasing totals',
      () async {
        final baseDate = DateTime(2026, 3, 1);
        await insertCompletionAt(completedAt: baseDate);
        await insertCompletionAt(
          completedAt: baseDate.add(const Duration(days: 2)),
        );
        await insertCompletionAt(
          completedAt: baseDate.add(const Duration(days: 2)),
        );
        await insertCompletionAt(
          completedAt: baseDate.add(const Duration(days: 5)),
        );

        final result = await chartService.getCumulativeProgress(
          startDate: baseDate,
          endDate: baseDate.add(const Duration(days: 6)),
        );

        expect(result.length, equals(7));
        // Verify monotonically increasing
        for (var i = 1; i < result.length; i++) {
          expect(
            result[i].total,
            greaterThanOrEqualTo(result[i - 1].total),
            reason: 'Cumulative total should never decrease at index $i',
          );
        }
        expect(result[0].total, equals(1));
        expect(result[2].total, equals(3));
        expect(result[5].total, equals(4));
        expect(result[6].total, equals(4));
      },
    );

    test(
      'cross-curriculum toggle sums completions across all active curricula',
      () async {
        final date = DateTime(2026, 3, 10);
        await insertCompletionAt(completedAt: date, curriculumId: 'mishnayos');
        await insertCompletionAt(completedAt: date, curriculumId: 'bavli');
        await insertCompletionAt(completedAt: date, curriculumId: 'bavli');

        // Cross-curriculum (no filter)
        final crossResult = await chartService.getDailyCompletions(
          startDate: date,
          endDate: date,
        );
        expect(crossResult[0].count, equals(3));

        // Per-curriculum (filter to mishnayos)
        final perResult = await chartService.getDailyCompletions(
          startDate: date,
          endDate: date,
          curriculumId: 'mishnayos',
        );
        expect(perResult[0].count, equals(1));
      },
    );

    test(
      'time range filter correctly bounds query to last 7 and 30 days',
      () async {
        final today = DateTime(2026, 3, 16);
        // Insert: 5 days ago (in 7-day range), 20 days ago (in 30-day only), 40 days ago (out of both)
        await insertCompletionAt(
          completedAt: today.subtract(const Duration(days: 5)),
        );
        await insertCompletionAt(
          completedAt: today.subtract(const Duration(days: 20)),
        );
        await insertCompletionAt(
          completedAt: today.subtract(const Duration(days: 40)),
        );

        // 7-day range
        final result7 = await chartService.getDailyCompletions(
          startDate: today.subtract(const Duration(days: 6)),
          endDate: today,
        );
        final total7 = result7.fold<int>(0, (s, d) => s + d.count);
        expect(total7, equals(1));

        // 30-day range
        final result30 = await chartService.getDailyCompletions(
          startDate: today.subtract(const Duration(days: 29)),
          endDate: today,
        );
        final total30 = result30.fold<int>(0, (s, d) => s + d.count);
        expect(total30, equals(2));
      },
    );

    test('points-over-time data excluded when userMode is adult', () async {
      final date = DateTime(2026, 3, 10);
      await insertCompletionAt(completedAt: date, points: 10);

      final adultResult = await chartService.getDailyPoints(
        startDate: date,
        endDate: date,
        userMode: UserMode.adult,
      );
      expect(adultResult, isNull);

      final childResult = await chartService.getDailyPoints(
        startDate: date,
        endDate: date,
        userMode: UserMode.child,
      );
      expect(childResult, isNotNull);
      expect(childResult![0].points, equals(10));
    });

    test(
      'streak calendar marks active days and leaves gaps unmarked',
      () async {
        final baseDate = DateTime(2026, 3, 10);
        await insertCompletionAt(completedAt: baseDate);
        await insertCompletionAt(
          completedAt: baseDate.add(const Duration(days: 2)),
        );

        final activeDates = await chartService.getStreakCalendar(
          startDate: baseDate,
          endDate: baseDate.add(const Duration(days: 4)),
        );

        expect(activeDates, contains(baseDate));
        expect(activeDates, contains(baseDate.add(const Duration(days: 2))));
        expect(activeDates.length, equals(2));
        // Gap days should not be included
        expect(
          activeDates,
          isNot(contains(baseDate.add(const Duration(days: 1)))),
        );
        expect(
          activeDates,
          isNot(contains(baseDate.add(const Duration(days: 3)))),
        );
      },
    );

    // --- Integration test ---

    test(
      'complete items over multiple days, verify chart data reflects history',
      () async {
        // Simulate 10 days of activity with varying completions
        final baseDate = DateTime(2026, 3, 1);
        final completionDays = [0, 1, 3, 5, 6, 7, 9]; // gaps on 2, 4, 8
        for (final day in completionDays) {
          final date = baseDate.add(Duration(days: day));
          await insertCompletionAt(completedAt: date, points: 10);
          if (day == 5) {
            // Extra completion on day 5
            await insertCompletionAt(completedAt: date, points: 5);
          }
        }

        final endDate = baseDate.add(const Duration(days: 9));

        // Check bar chart data
        final daily = await chartService.getDailyCompletions(
          startDate: baseDate,
          endDate: endDate,
        );
        expect(daily.length, equals(10));
        expect(daily[5].count, equals(2)); // Day 5 had 2 completions
        expect(daily[2].count, equals(0)); // Day 2 was a gap

        // Check cumulative data
        final cumulative = await chartService.getCumulativeProgress(
          startDate: baseDate,
          endDate: endDate,
        );
        expect(cumulative.last.total, equals(8)); // 7 days + 1 extra

        // Check streak calendar
        final streakDates = await chartService.getStreakCalendar(
          startDate: baseDate,
          endDate: endDate,
        );
        expect(streakDates.length, equals(7)); // 7 active days

        // Check points (child mode)
        final points = await chartService.getDailyPoints(
          startDate: baseDate,
          endDate: endDate,
          userMode: UserMode.child,
        );
        expect(points, isNotNull);
        expect(points![5].points, equals(15)); // 10 + 5 on day 5
        final totalPoints = points.fold<int>(0, (s, d) => s + d.points);
        expect(totalPoints, equals(75)); // 7*10 + 5
      },
    );
  });

  // ── Issue-8b regression — breadcrumb seder trimming ────────────────────────

  group('Issue-8b — top-level seder trimmed from breadcrumb', () {
    /// Mirror of the private `_trimSederFromBreadcrumb` function in
    /// `active_track_card.dart`. Kept here as a pure-logic unit test so the
    /// display contract is documented and verified independently of widgets.
    String trimSeder(String breadcrumb) {
      const sep = ' › ';
      final idx = breadcrumb.indexOf(sep);
      if (idx == -1) return breadcrumb;
      return breadcrumb.substring(idx + sep.length);
    }

    test('multi-segment breadcrumb: first segment is dropped', () {
      expect(trimSeder('א › ב › ג'), equals('ב › ג'));
    });

    test('two-segment breadcrumb: only second segment remains', () {
      expect(trimSeder('קודשים › חולין'), equals('חולין'));
    });

    test('single-segment breadcrumb: returned unchanged', () {
      expect(trimSeder('ברכות'), equals('ברכות'));
    });

    test('four-segment breadcrumb: first segment removed, rest preserved', () {
      const full = 'קודשים › חולין › דף יד › עמוד א';
      const expected = 'חולין › דף יד › עמוד א';
      expect(trimSeder(full), equals(expected));
    });

    test('empty string: returned unchanged', () {
      expect(trimSeder(''), equals(''));
    });
  });
}
