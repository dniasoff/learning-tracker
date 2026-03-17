import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/content_browsing/presentation/providers/content_providers.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'scheduler_providers.g.dart';

/// Provides the current UTC date/time. Override in tests to control time.
@riverpod
DateTime clock(Ref ref) => DateTime.now().toUtc();

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
    currentDate: ref.watch(clockProvider),
  );
  return engine.generateDailyTasks(config);
}

/// Storage key constants for skipped-task persistence.
const _skippedDateKey = 'skipped_tasks_date';
const _skippedRefsKey = 'skipped_tasks_refs';
const _previouslySkippedRefsKey = 'skipped_tasks_previous_refs';

/// Holds the set of sefaria refs skipped (dismissed) today.
///
/// Persisted via SharedPreferences. Resets automatically when the date
/// changes. Previously-skipped refs are tracked so they can receive a
/// priority boost (see [previouslySkippedRefsProvider]).
@riverpod
class SkippedTasks extends _$SkippedTasks {
  @override
  Set<String> build() {
    _loadFromPrefs();
    return {};
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final today = ref.read(clockProvider);
    final todayStr =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final storedDate = prefs.getString(_skippedDateKey);

    if (storedDate == todayStr) {
      final refs = prefs.getStringList(_skippedRefsKey) ?? [];
      state = refs.toSet();
    } else {
      // Date changed — archive yesterday's skips, clear today's
      final yesterdayRefs = prefs.getStringList(_skippedRefsKey) ?? [];
      await prefs.setStringList(_previouslySkippedRefsKey, yesterdayRefs);
      await prefs.setString(_skippedDateKey, todayStr);
      await prefs.setStringList(_skippedRefsKey, []);
      state = {};
    }
  }

  Future<void> skip(String sefariaRef) async {
    state = {...state, sefariaRef};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_skippedRefsKey, state.toList());
  }

  Future<void> undoSkip(String sefariaRef) async {
    state = {...state}..remove(sefariaRef);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_skippedRefsKey, state.toList());
  }
}

/// Refs that were skipped yesterday. Used for priority boost logic.
@riverpod
Future<Set<String>> previouslySkippedRefs(Ref ref) async {
  final prefs = await SharedPreferences.getInstance();
  final refs = prefs.getStringList(_previouslySkippedRefsKey) ?? [];
  return refs.toSet();
}

/// Pace status for a curriculum goal.
///
/// Calculates pace using personal-track completions only and a rolling
/// 7-day average for projected completion.
@riverpod
Future<PaceStatus?> paceStatus(
  Ref ref, {
  required CurriculumId curriculumId,
  required DateTime goalStartDate,
  required DateTime goalDeadline,
  required int totalItems,
}) async {
  final db = ref.watch(appDatabaseProvider);
  final now = ref.watch(clockProvider);

  // Get personal-track completions only
  final allCompletions = await db.completionDao.getCompletionsByCurriculum(
    curriculumId.storageKey,
  );
  final personalCompletions = allCompletions
      .where((c) => c.trackType == TrackType.personal.storageKey)
      .toList();

  // Build daily completion counts for rolling average
  final dailyCounts = <DateTime, int>{};
  for (final c in personalCompletions) {
    final date = DateTime.utc(
      c.completedAt.year,
      c.completedAt.month,
      c.completedAt.day,
    );
    dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
  }

  return PaceCalculator.calculate(
    goalStartDate: goalStartDate,
    goalDeadline: goalDeadline,
    totalItems: totalItems,
    completedItems: personalCompletions.length,
    dailyCompletionCounts: dailyCounts,
    today: now,
  );
}

/// All daily tasks across active curricula, filtered by skipped items.
///
/// Previously-skipped tasks receive an `overdueChazara`-level priority
/// boost so they appear near the top of the list.
@riverpod
Future<List<DailyTask>> allDailyTasks(Ref ref) async {
  final db = ref.watch(appDatabaseProvider);
  final generator = ref.watch(dailyTaskGeneratorProvider);
  final skipped = ref.watch(skippedTasksProvider);
  final previouslySkipped = await ref.watch(
    previouslySkippedRefsProvider.future,
  );

  final activeKeys = await db.activeCurriculumDao.getActiveCurricula();
  final activeCurricula = activeKeys
      .map((key) => CurriculumId.values.where((c) => c.storageKey == key).first)
      .toList();

  // Look up earliest goal deadline per curriculum for pacing.
  final goalDeadlines = <CurriculumId, DateTime>{};
  for (final curriculum in activeCurricula) {
    final goals = await db.goalDao.getGoalsByCurriculum(curriculum.storageKey);
    for (final goal in goals) {
      if (goal.targetDate != null) {
        final existing = goalDeadlines[curriculum];
        if (existing == null || goal.targetDate!.isBefore(existing)) {
          goalDeadlines[curriculum] = goal.targetDate!;
        }
      }
    }
  }

  final tasks = await generator.generateAll(
    activeCurricula,
    ref.watch(clockProvider),
    skippedRefs: skipped,
    goalDeadlines: goalDeadlines,
  );

  // Priority boost: previously-skipped tasks get overdueChazara priority
  if (previouslySkipped.isEmpty) return tasks;

  return tasks.map((task) {
    if (previouslySkipped.contains(task.contentItemSefariaRef) &&
        task.priority != DailyTaskPriority.overdueChazara) {
      return task.copyWith(
        priority: DailyTaskPriority.overdueChazara,
        reason: '${task.reason} (previously skipped)',
      );
    }
    return task;
  }).toList()..sort((a, b) => a.priority.index.compareTo(b.priority.index));
}
