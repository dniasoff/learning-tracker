/// F6 regression: overdue tasks must appear after elapsed study days even
/// when the track has no pace-based goal.
///
/// Root cause: `_buildFreshPlan` only ran the snapshot back-fill when
/// `pacePerDay != null`.  Tracks with only study-day config (no pace goal)
/// therefore never had `priorlyShownRefs` populated, so the engine never
/// produced overdue new-learning tasks even after several study days passed.
///
/// Fix: `DailyPlanRepository.backfillStudyDaySnapshots` back-fills elapsed
/// *study* days only (non-study days are skipped).  `_buildFreshPlan` calls
/// this for all tracks that have an `activatedAt` in the past, using
/// `defaultNewItemsPerDay` when no pace goal is set.
library;

import 'package:drift/drift.dart' hide isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

import '../../../../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Minimal in-memory content repository
// ---------------------------------------------------------------------------

class _InMemoryContentRepo implements SchedulerContentRepository {
  final List<SchedulerContentItem> items;
  _InMemoryContentRepo(this.items);

  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async =>
      items;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Insert a curriculum track returning its auto-generated id.
Future<int> _insertTrack(
  UserDatabase db, {
  required DateTime activatedAt,
}) async {
  final row = await db
      .into(db.curriculumTracks)
      .insertReturning(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          trackType: 'personal',
          isActive: const Value(true),
          activatedAt: activatedAt,
        ),
      );
  return row.id;
}

/// Seed a single "Learn" stage for the track.
Future<void> _insertLearnStage(UserDatabase db, {required int trackId}) async {
  await db.stageDao.insertStageDefinition(
    StageDefinitionsCompanion.insert(
      profileId: 1,
      curriculumId: CurriculumId.mishnayos.storageKey,
      trackId: trackId,
      stageOrder: 1,
      stageName: 'Learn',
      delayDays: 0,
    ),
  );
}

// ---------------------------------------------------------------------------
// Test suite
// ---------------------------------------------------------------------------

void main() {
  // The scenario is fixed to a Wednesday (2026-05-20) so that we have known
  // weekdays for the three elapsed days:
  //   activatedAt = Sunday  2026-05-17 (weekday 7, NOT a study day)
  //   elapsed day 1         Monday 2026-05-18 (weekday 1, IS a study day ✓)
  //   elapsed day 2         Tuesday 2026-05-19 (weekday 2, NOT a study day)
  //   today                 Wednesday 2026-05-20 (weekday 3, IS a study day ✓)
  //
  // Study-day config: Mon(1) + Wed(3) + Fri(5) — Mon is the only elapsed study day.

  final activatedAt = DateTime.utc(2026, 5, 17, 8, 0); // Sunday
  final today = DateTime.utc(2026, 5, 20, 9, 0); // Wednesday
  const studyWeekdays = {1, 3, 5}; // Mon, Wed, Fri

  // 10 content items — enough to fill several study-day batches.
  final contentItems = List.generate(
    10,
    (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
  );

  late UserDatabase db;
  late int trackId;
  late SchedulerEngine engine;
  late DailyPlanRepository planRepo;

  setUp(() async {
    db = createTestDatabase();
    await seedProfile(db);

    trackId = await _insertTrack(db, activatedAt: activatedAt);
    await _insertLearnStage(db, trackId: trackId);

    // Seed Mon(1), Wed(3), Fri(5) as study days; all others as 'review'.
    for (var dow = 1; dow <= 7; dow++) {
      await db.studyDayConfigDao.upsertDayConfig(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos.storageKey,
        trackId: trackId,
        dayOfWeek: dow,
        dayType: studyWeekdays.contains(dow) ? 'study' : 'review',
      );
    }

    engine = SchedulerEngine(
      contentRepository: _InMemoryContentRepo(contentItems),
      completionRepository: SchedulerCompletionRepositoryImpl(
        completionDao: db.completionDao,
        stageDao: db.stageDao,
        profileId: 1,
      ),
      stageRepository: SchedulerStageRepositoryImpl(stageDao: db.stageDao),
      learningOrderRepository: SchedulerLearningOrderRepositoryImpl(
        learningOrderDao: db.learningOrderDao,
      ),
    );

    planRepo = DailyPlanRepository(db);
  });

  tearDown(() => db.close());

  // ── F6 core regression ─────────────────────────────────────────────────────

  group('F6 — overdue derives from studyDayConfig × elapsed days', () {
    test('track with 1 elapsed study day yields ≥1 overdue task', () async {
      // Replicates what _buildFreshPlan does after the F6 fix:
      //   1. Back-fill elapsed study days using the new
      //      DailyPlanRepository.backfillStudyDaySnapshots helper.
      //   2. Retrieve priorlyShownRefs.
      //   3. Run engine in snapshot mode → overdue items appear.

      const defaultPace = 5;

      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        CurriculumId.mishnayos.storageKey,
      );
      final firstStage = stages.reduce(
        (a, b) => a.stageOrder < b.stageOrder ? a : b,
      );

      // Step 1 — study-day-aware back-fill (the F6 fix).
      await planRepo.backfillStudyDaySnapshots(
        profileId: 1,
        trackId: trackId,
        curriculumId: CurriculumId.mishnayos,
        activatedAt: activatedAt,
        currentDate: today,
        pace: defaultPace,
        studyWeekdays: studyWeekdays,
        orderedRefs: contentItems.map((i) => i.sefariaRef).toList(),
        firstStageOrder: firstStage.stageOrder,
        firstStageDefinitionId: firstStage.id,
        firstStageName: firstStage.stageName,
        trackLabel: 'personal',
      );

      // Step 2 — retrieve prior refs.
      final todayLocal = DateTime(
        today.toLocal().year,
        today.toLocal().month,
        today.toLocal().day,
      );
      final priorlyShownRefs = await db.dailyPlanDao
          .getPriorlyShownRefsForTrack(
            trackId: trackId,
            excludeDate: todayLocal,
          );

      // Exactly one elapsed study day (Monday) → pace=5 refs.
      expect(
        priorlyShownRefs,
        hasLength(defaultPace),
        reason:
            'Only the one elapsed study day (Mon) should contribute refs; '
            'non-study days (Sun, Tue) must be skipped',
      );

      // Step 3 — engine in snapshot mode with the backfilled priorlyShownRefs.
      final config = ScheduleConfig(
        curriculumId: CurriculumId.mishnayos,
        trackId: trackId,
        trackLabel: 'personal',
        currentDate: today,
        pacePerDay: defaultPace.toDouble(),
        trackStartedAt: activatedAt,
        priorlyShownRefs: priorlyShownRefs,
        isStudyDay: true, // today (Wed) is a study day
      );

      final tasks = await engine.generateDailyTasks(config);
      final overdueTasks = tasks.where((t) => t.isOverdue).toList();

      expect(
        overdueTasks,
        isNotEmpty,
        reason:
            'After one elapsed study day with no completions, at least one '
            'overdue task must appear on the next study day (F6)',
      );

      // Overdue refs must be exactly the Monday session refs (ref_0..ref_4).
      final overdueRefs = overdueTasks
          .map((t) => t.contentItemSefariaRef)
          .toSet();
      expect(
        overdueRefs,
        containsAll({'ref_0', 'ref_1', 'ref_2', 'ref_3', 'ref_4'}),
      );
    });

    test('non-study elapsed days are not back-filled', () async {
      // elapsed days: Sun(non-study), Mon(study), Tue(non-study)
      // → only Monday snapshot should be written
      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        CurriculumId.mishnayos.storageKey,
      );
      final firstStage = stages.reduce(
        (a, b) => a.stageOrder < b.stageOrder ? a : b,
      );

      await planRepo.backfillStudyDaySnapshots(
        profileId: 1,
        trackId: trackId,
        curriculumId: CurriculumId.mishnayos,
        activatedAt: activatedAt,
        currentDate: today,
        pace: 3,
        studyWeekdays: studyWeekdays,
        orderedRefs: contentItems.map((i) => i.sefariaRef).toList(),
        firstStageOrder: firstStage.stageOrder,
        firstStageDefinitionId: firstStage.id,
        firstStageName: firstStage.stageName,
        trackLabel: 'personal',
      );

      // Sunday and Tuesday must have NO snapshot row.
      final sunExists = await db.dailyPlanDao.hasPlanForTrackOnDay(
        trackId: trackId,
        planDate: DateTime(2026, 5, 17),
      );
      final monExists = await db.dailyPlanDao.hasPlanForTrackOnDay(
        trackId: trackId,
        planDate: DateTime(2026, 5, 18),
      );
      final tueExists = await db.dailyPlanDao.hasPlanForTrackOnDay(
        trackId: trackId,
        planDate: DateTime(2026, 5, 19),
      );

      expect(sunExists, isFalse, reason: 'Sunday is not a study day');
      expect(monExists, isTrue, reason: 'Monday is a study day');
      expect(tueExists, isFalse, reason: 'Tuesday is not a study day');
    });

    test(
      'study-day ordinal determines ref position (not calendar-day index)',
      () async {
        // pace=3, elapsed study days: Mon only (study day #1)
        // → Monday snapshot must contain refs[0,1,2] (index 0*3 .. 1*3)
        // NOT refs[3,4,5] (which is what calendar-day index=1 would give)
        final stages = await db.stageDao.getStageDefinitionsByCurriculum(
          CurriculumId.mishnayos.storageKey,
        );
        final firstStage = stages.reduce(
          (a, b) => a.stageOrder < b.stageOrder ? a : b,
        );

        await planRepo.backfillStudyDaySnapshots(
          profileId: 1,
          trackId: trackId,
          curriculumId: CurriculumId.mishnayos,
          activatedAt: activatedAt,
          currentDate: today,
          pace: 3,
          studyWeekdays: studyWeekdays,
          orderedRefs: contentItems.map((i) => i.sefariaRef).toList(),
          firstStageOrder: firstStage.stageOrder,
          firstStageDefinitionId: firstStage.id,
          firstStageName: firstStage.stageName,
          trackLabel: 'personal',
        );

        final todayLocal = DateTime(
          today.toLocal().year,
          today.toLocal().month,
          today.toLocal().day,
        );
        final priorlyShownRefs = await db.dailyPlanDao
            .getPriorlyShownRefsForTrack(
              trackId: trackId,
              excludeDate: todayLocal,
            );

        expect(
          priorlyShownRefs,
          equals({'ref_0', 'ref_1', 'ref_2'}),
          reason:
              'Monday is study day #1 → position = 0*3..1*3 = refs[0,1,2]; '
              'calendar-day index 1 would incorrectly give refs[3,4,5]',
        );
      },
    );
  });
}
