import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
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
