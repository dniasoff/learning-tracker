import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'scheduler_providers.g.dart';

@riverpod
SchedulerEngine schedulerEngine(Ref ref) {
  final db = ref.watch(appDatabaseProvider);
  final contentRepo = ref.watch(contentRepositoryProvider);

  return SchedulerEngine(
    contentRepository: SchedulerContentRepositoryImpl(
      getContent: contentRepo.getContentForCurriculum,
    ),
    completionRepository: SchedulerCompletionRepositoryImpl(
      completionDao: db.completionDao,
      stageDao: db.stageDao,
    ),
    stageRepository: SchedulerStageRepositoryImpl(stageDao: db.stageDao),
    learningOrderRepository: SchedulerLearningOrderRepositoryImpl(
      learningOrderDao: db.learningOrderDao,
    ),
  );
}

@riverpod
DailyTaskGenerator dailyTaskGenerator(Ref ref) {
  final engine = ref.watch(schedulerEngineProvider);
  return DailyTaskGenerator(engine: engine);
}

@riverpod
Future<List<DailyTask>> dailyTasks(
  Ref ref, {
  required CurriculumId curriculumId,
  DateTime? goalDeadline,
}) async {
  final engine = ref.watch(schedulerEngineProvider);
  final config = ScheduleConfig(
    curriculumId: curriculumId,
    goalDeadline: goalDeadline,
    currentDate: DateTime.now().toUtc(),
  );
  return engine.generateDailyTasks(config);
}

/// Holds the set of sefaria refs skipped (dismissed) today.
@riverpod
class SkippedTasks extends _$SkippedTasks {
  @override
  Set<String> build() => {};

  void skip(String sefariaRef) {
    state = {...state, sefariaRef};
  }

  void undoSkip(String sefariaRef) {
    state = {...state}..remove(sefariaRef);
  }
}

/// All daily tasks across active curricula, filtered by skipped items.
@riverpod
Future<List<DailyTask>> allDailyTasks(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final generator = ref.watch(dailyTaskGeneratorProvider);
  final skipped = ref.watch(skippedTasksProvider);

  final activeKeys = await db.activeCurriculumDao.getActiveCurricula();
  final activeCurricula = activeKeys
      .map((key) => CurriculumId.values.where((c) => c.storageKey == key).first)
      .toList();

  return generator.generateAll(
    activeCurricula,
    DateTime.now().toUtc(),
    skippedRefs: skipped,
  );
}
