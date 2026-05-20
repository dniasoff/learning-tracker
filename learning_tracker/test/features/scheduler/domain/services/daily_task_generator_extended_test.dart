/// Extended tests for DailyTaskGenerator.generateAll — not covered by
/// daily_task_generator_test.dart.
library;

import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:test/test.dart';

import '../../../../helpers/drift_memory.dart' show seedCompletion;
import '../../../../helpers/test_database.dart';

/// In-memory content repo that returns items per curriculum.
class _InMemoryContentRepo implements SchedulerContentRepository {
  final Map<CurriculumId, List<SchedulerContentItem>> _items;

  _InMemoryContentRepo(this._items);

  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async =>
      _items[id] ?? [];
}

void main() {
  late UserDatabase db;
  late DailyTaskGenerator generator;
  late int trackIdMishnayos;
  late int trackIdBavli;
  final now = DateTime.utc(2026, 4, 20);
  const mishnayos = CurriculumId.mishnayos;
  const bavli = CurriculumId.bavli;

  final mishnayosItems = List.generate(
    5,
    (i) => SchedulerContentItem(sefariaRef: 'M_$i', sortOrder: i),
  );
  final bavliItems = List.generate(
    5,
    (i) => SchedulerContentItem(sefariaRef: 'B_$i', sortOrder: i),
  );

  Future<int> insertTrack(CurriculumId curriculum) => db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: 0,
          curriculumId: curriculum.storageKey,
          stateChangedAt: now,
          activatedAt: now,
        ),
      );

  Future<void> insertStage(CurriculumId curriculum, int trackId) =>
      db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 0,
          curriculumId: curriculum.storageKey,
          trackId: trackId,
          stageOrder: 1,
          stageName: 'Learn',
          delayDays: 0,
        ),
      );

  setUp(() async {
    db = createTestDatabase();
    await seedProfileZero(db);

    trackIdMishnayos = await insertTrack(mishnayos);
    trackIdBavli = await insertTrack(bavli);

    await insertStage(mishnayos, trackIdMishnayos);
    await insertStage(bavli, trackIdBavli);

    final engine = SchedulerEngine(
      contentRepository: _InMemoryContentRepo({
        mishnayos: mishnayosItems,
        bavli: bavliItems,
      }),
      completionRepository: SchedulerCompletionRepositoryImpl(
        completionDao: db.completionDao,
        stageDao: db.stageDao,
      ),
      stageRepository: SchedulerStageRepositoryImpl(stageDao: db.stageDao),
      learningOrderRepository: SchedulerLearningOrderRepositoryImpl(
        learningOrderDao: db.learningOrderDao,
      ),
    );

    generator = DailyTaskGenerator(engine: engine);
  });

  tearDown(() async {
    await db.close();
  });

  // ── generateAll ─────────────────────────────────────────────────────────────

  group('DailyTaskGenerator.generateAll', () {
    test('returns empty list for empty curricula list', () async {
      final tasks = await generator.generateAll([], now);
      expect(tasks, isEmpty);
    });

    test('returns tasks for a single curriculum', () async {
      final tasks = await generator.generateAll(
        [mishnayos],
        now,
        trackIds: {mishnayos: trackIdMishnayos},
        trackLabels: {mishnayos: 'personal'},
      );
      expect(tasks, isNotEmpty);
      expect(tasks.every((t) => t.curriculumId == mishnayos), isTrue);
    });

    test('returns tasks for multiple curricula combined', () async {
      final tasks = await generator.generateAll(
        [mishnayos, bavli],
        now,
        trackIds: {mishnayos: trackIdMishnayos, bavli: trackIdBavli},
        trackLabels: {mishnayos: 'personal', bavli: 'personal'},
      );

      expect(tasks, isNotEmpty);
      final curricula = tasks.map((t) => t.curriculumId).toSet();
      expect(curricula, containsAll([mishnayos, bavli]));
    });

    test('tasks are sorted by priority across curricula', () async {
      // Insert a completion for mishnayos so we get overdue chazara.
      final stages = await db.stageDao.getStageDefinitionsByCurriculum(
        mishnayos.storageKey,
      );
      final learnId = stages.first.id;

      await seedCompletion(
        db,
        CompletionEventsCompanion.insert(
          profileId: 0,
          curriculumId: mishnayos.storageKey,
          trackId: Value(trackIdMishnayos),
          sefariaRef: 'M_0',
          stageId: learnId,
          trackType: 'personal',
          eventTimestamp: now.subtract(const Duration(days: 1)),
          points: const Value(10),
        ),
      );

      // Add a second stage with delay_days=1 to mishnayos so we get scheduled.
      await db.stageDao.insertStageDefinition(
        StageDefinitionsCompanion.insert(
          profileId: 0,
          curriculumId: mishnayos.storageKey,
          trackId: trackIdMishnayos,
          stageOrder: 2,
          stageName: 'Chazara 1',
          delayDays: 1,
        ),
      );

      final tasks = await generator.generateAll(
        [mishnayos, bavli],
        now,
        trackIds: {mishnayos: trackIdMishnayos, bavli: trackIdBavli},
        trackLabels: {mishnayos: 'personal', bavli: 'personal'},
      );

      // Verify sort order: lower priority index = higher priority.
      for (var i = 0; i < tasks.length - 1; i++) {
        expect(
          tasks[i].priority.index,
          lessThanOrEqualTo(tasks[i + 1].priority.index),
          reason: 'Tasks should be sorted by priority ascending',
        );
      }
    });

    test('skippedRefs are excluded from all curricula results', () async {
      final tasks = await generator.generateAll(
        [mishnayos, bavli],
        now,
        trackIds: {mishnayos: trackIdMishnayos, bavli: trackIdBavli},
        trackLabels: {mishnayos: 'personal', bavli: 'personal'},
        skippedRefs: {'M_0', 'B_0'},
      );

      expect(tasks.any((t) => t.contentItemSefariaRef == 'M_0'), isFalse);
      expect(tasks.any((t) => t.contentItemSefariaRef == 'B_0'), isFalse);
    });

    test(
      'non-study day for a curriculum produces no new tasks for that one',
      () async {
        final tasks = await generator.generateAll(
          [mishnayos, bavli],
          now,
          trackIds: {mishnayos: trackIdMishnayos, bavli: trackIdBavli},
          trackLabels: {mishnayos: 'personal', bavli: 'personal'},
          isStudyDayMap: {
            mishnayos: false, // mishnayos is a non-study day
            bavli: true,
          },
        );

        // mishnayos non-study day → no new learning tasks for mishnayos.
        final mishnayosNewTasks = tasks.where(
          (t) =>
              t.curriculumId == mishnayos &&
              t.priority == DailyTaskPriority.newLearning,
        );
        expect(mishnayosNewTasks, isEmpty);

        // bavli study day → has new tasks.
        final bavliNewTasks = tasks.where(
          (t) =>
              t.curriculumId == bavli &&
              t.priority == DailyTaskPriority.newLearning,
        );
        expect(bavliNewTasks, isNotEmpty);
      },
    );

    test(
      'uses default trackId=0 and empty trackLabel when not in maps',
      () async {
        // Should not throw when trackIds/trackLabels maps don't contain entry.
        final tasks = await generator.generateAll(
          [mishnayos],
          now,
          // No trackIds or trackLabels maps → defaults to 0 and ''.
        );
        // May be empty (no stages for trackId=0 match) or non-empty;
        // the important thing is it doesn't throw.
        expect(tasks, isA<List<DailyTask>>());
      },
    );
  });

  // ── generate skipped-refs filter ─────────────────────────────────────────

  group('DailyTaskGenerator.generate — skipped refs filter', () {
    test('empty skippedRefs returns all tasks unfiltered', () async {
      final tasks = await generator.generate(
        mishnayos,
        now,
        trackId: trackIdMishnayos,
        trackLabel: 'personal',
        skippedRefs: const {},
      );
      expect(tasks, isNotEmpty);
    });

    test('skippedRefs containing a task ref removes that task', () async {
      final allTasks = await generator.generate(
        mishnayos,
        now,
        trackId: trackIdMishnayos,
        trackLabel: 'personal',
      );
      expect(allTasks, isNotEmpty);

      final firstRef = allTasks.first.contentItemSefariaRef;
      final filtered = await generator.generate(
        mishnayos,
        now,
        trackId: trackIdMishnayos,
        trackLabel: 'personal',
        skippedRefs: {firstRef},
      );

      expect(filtered.any((t) => t.contentItemSefariaRef == firstRef), isFalse);
    });
  });
}
