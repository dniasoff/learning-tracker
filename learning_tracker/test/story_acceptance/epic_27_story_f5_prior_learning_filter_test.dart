/// F5 — prior-learning sentinels must not hide today's tasks.
@Tags(['epic_27', 'story_f5'])
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:test/test.dart';

void main() {
  test('bulk-prior sentinel keeps the item in new learning', () async {
    const curriculum = CurriculumId.mishnayos;
    const ref = 'Mishnah Berakhot 1.1';
    final engine = SchedulerEngine(
      contentRepository: const _ContentRepo(ref),
      completionRepository: _CompletionRepo(
        SchedulerCompletion(
          sefariaRef: ref,
          stageOrder: 1,
          trackType: 'personal',
          completedAt: SchedulerEngine.kBulkPriorSentinel,
        ),
      ),
      stageRepository: const _StageRepo(),
      learningOrderRepository: const _OrderRepo(),
    );

    final tasks = await engine.generateDailyTasks(
      ScheduleConfig(
        curriculumId: curriculum,
        trackLabel: 'Mishnayos',
        currentDate: DateTime.utc(2026, 8, 12),
        defaultNewItemsPerDay: 1,
      ),
    );

    expect(tasks, hasLength(1));
    expect(tasks.single.contentItemSefariaRef, ref);
    expect(tasks.single.priority, DailyTaskPriority.newLearning);
  });

  group('F5 — scheduler persistence regression', skip:
      'Blocked: the original regression constructs Completion rows through Drift completion_events and calls CompletionDao. Firestore completion documents are not consumed by this scheduler path yet.',
      () {
    test('placeholder for the pending Firestore sentinel harness', () {});
  });
}

class _ContentRepo implements SchedulerContentRepository {
  const _ContentRepo(this.ref);
  final String ref;

  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async => [
    SchedulerContentItem(sefariaRef: ref, sortOrder: 0),
  ];
}

class _CompletionRepo implements SchedulerCompletionRepository {
  const _CompletionRepo(this.completion);
  final SchedulerCompletion completion;

  @override
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId id) async => [
    completion,
  ];
}

class _StageRepo implements SchedulerStageRepository {
  const _StageRepo();

  @override
  Future<List<SchedulerStage>> getStages(CurriculumId id) async => const [
    SchedulerStage(stageOrder: 1, stageName: 'Learn', delayDays: 0),
  ];
}

class _OrderRepo implements SchedulerLearningOrderRepository {
  const _OrderRepo();

  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId id) async => const [];
}
