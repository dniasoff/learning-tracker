import 'dart:async';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
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
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'scheduler_providers.g.dart';

/// Provides the current UTC date/time. Override in tests to control time.
@riverpod
DateTime clock(Ref ref) => DateTime.now().toUtc();

@riverpod
SchedulerEngine schedulerEngine(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);

  // Use scope-aware content: returns scoped content if scopes are set,
  // otherwise returns full curriculum content.
  Future<List<ContentItem>> getScopedContent(CurriculumId curriculumId) async {
    return ref.read(scopedCurriculumContentProvider(curriculumId).future);
  }

  return SchedulerEngine(
    contentRepository: SchedulerContentRepositoryImpl(
      getContent: getScopedContent,
    ),
    completionRepository: SchedulerCompletionRepositoryImpl(
      completionDao: db.completionDao,
      stageDao: db.stageDao,
      profileId: profileId,
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
  required int trackId,
  required String trackLabel,
  DateTime? goalDeadline,
}) async {
  final engine = ref.watch(schedulerEngineProvider);
  final config = ScheduleConfig(
    curriculumId: curriculumId,
    trackId: trackId,
    trackLabel: trackLabel,
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
    unawaited(_loadFromPrefs());
    return {};
  }

  Future<void> _loadFromPrefs() async {
    try {
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
    } catch (e, st) {
      AppLogger.instance.error('Failed to load skipped tasks', e, st);
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
/// Supports both deadline-based and pace-based goals.
@riverpod
Future<PaceStatus?> paceStatus(
  Ref ref, {
  required CurriculumId curriculumId,
  required DateTime goalStartDate,
  DateTime? goalDeadline,
  required int totalItems,
  String goalType = 'deadline',
  double? pacePerDay,
}) async {
  final db = ref.watch(userDatabaseProvider);
  final now = ref.watch(clockProvider);

  final profileId = ref.watch(activeProfileIdProvider);

  // Get personal-track completions only
  final allCompletions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculumId.storageKey, profileId);
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

  if (goalType == 'pace' && pacePerDay != null) {
    return PaceCalculator.calculateForPaceGoal(
      targetPacePerDay: pacePerDay,
      totalItems: totalItems,
      completedItems: personalCompletions.length,
      dailyCompletionCounts: dailyCounts,
      today: now,
    );
  }

  if (goalDeadline == null) return null;

  return PaceCalculator.calculate(
    goalStartDate: goalStartDate,
    goalDeadline: goalDeadline,
    totalItems: totalItems,
    completedItems: personalCompletions.length,
    dailyCompletionCounts: dailyCounts,
    today: now,
  );
}

/// Repository that snapshots today's plan to DB so completions don't
/// trigger regeneration.
@riverpod
DailyPlanRepository dailyPlanRepository(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  return DailyPlanRepository(db);
}

/// All daily tasks across active curricula.
///
/// The raw plan is snapshotted to the `daily_plans` table on the first
/// read of each local day and served back verbatim on subsequent reads.
/// Completions do **not** regenerate the plan — today's list is a
/// contract. Skipped-task filtering and previously-skipped priority
/// boosting are applied at read time.
@riverpod
Future<List<DailyTask>> allDailyTasks(Ref ref) async {
  final db = ref.watch(userDatabaseProvider);
  final generator = ref.watch(dailyTaskGeneratorProvider);
  final planRepo = ref.watch(dailyPlanRepositoryProvider);
  final skipped = ref.watch(skippedTasksProvider);
  final previouslySkipped = await ref.watch(
    previouslySkippedRefsProvider.future,
  );
  final profileId = ref.watch(activeProfileIdProvider);
  final now = ref.watch(clockProvider);

  final tasks = await planRepo.getOrSnapshotPlan(
    profileId: profileId,
    now: now,
    buildPlan: () => _buildFreshPlan(
      db: db,
      generator: generator,
      profileId: profileId,
      now: now,
    ),
  );

  // Guard against stale/empty daily snapshots:
  // if active curricula changed after the first snapshot of the day,
  // today's plan may miss entire curricula until tomorrow.
  final activeCurriculumKeys = await db.activeCurriculumDao
      .getActiveCurriculaByProfile(profileId);
  final snapshotCurriculumKeys = tasks
      .map((t) => t.curriculumId.storageKey)
      .toSet();
  final snapshotMissingActiveCurriculum =
      activeCurriculumKeys.isNotEmpty &&
      activeCurriculumKeys.any((key) => !snapshotCurriculumKeys.contains(key));

  final effectiveTasks = snapshotMissingActiveCurriculum
      ? await planRepo.rebuildPlan(
          profileId: profileId,
          now: now,
          buildPlan: () => _buildFreshPlan(
            db: db,
            generator: generator,
            profileId: profileId,
            now: now,
          ),
        )
      : tasks;

  // Hide tasks already completed today (or earlier) while preserving the
  // frozen daily snapshot contract. We do not regenerate rows, we only
  // filter resolved items at read time.
  final completions = await db.completionDao.getCompletionsByProfile(profileId);
  bool isTaskCompleted(DailyTask task) {
    return completions.any((c) {
      if (c.sefariaRef != task.contentItemSefariaRef) return false;
      if (task.trackId != 0 && c.trackId != task.trackId) return false;
      return c.stageId == task.stageDefinitionId ||
          c.stageId == task.stageOrder;
    });
  }

  // Apply read-time filters: skipped-today removed, previously-skipped boosted.
  final filtered = effectiveTasks
      .where(
        (t) =>
            !skipped.contains(t.contentItemSefariaRef) && !isTaskCompleted(t),
      )
      .toList();

  if (previouslySkipped.isEmpty) {
    filtered.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    return filtered;
  }

  return filtered.map((task) {
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

/// Runs the scheduler across all active curricula to produce a fresh plan.
/// Called only when no snapshot exists for the current local day.
Future<List<DailyTask>> _buildFreshPlan({
  required UserDatabase db,
  required DailyTaskGenerator generator,
  required int profileId,
  required DateTime now,
}) async {
  final activeKeys = await db.activeCurriculumDao.getActiveCurriculaByProfile(
    profileId,
  );
  final activeCurricula = <CurriculumId>[
    for (final key in activeKeys)
      ...CurriculumId.values.where((c) => c.storageKey == key).take(1),
  ];

  // Resolve one active track per curriculum for this profile.
  // Prefer personal track when present (current v1 default).
  final activeTracks = await db.trackDao.getActiveTracksForProfile(profileId);
  final trackIds = <CurriculumId, int>{};
  final trackLabels = <CurriculumId, String>{};
  for (final curriculum in activeCurricula) {
    final tracksForCurriculum = activeTracks
        .where((t) => t.curriculumId == curriculum.storageKey)
        .toList();
    if (tracksForCurriculum.isEmpty) continue;
    final preferred = tracksForCurriculum.firstWhere(
      (t) => t.trackType == TrackType.personal.storageKey,
      orElse: () => tracksForCurriculum.first,
    );
    trackIds[curriculum] = preferred.id;
    trackLabels[curriculum] = preferred.trackType;
  }

  final goalDeadlines = <CurriculumId, DateTime>{};
  final pacePerDayMap = <CurriculumId, double>{};
  for (final curriculum in activeCurricula) {
    final trackId = trackIds[curriculum];
    if (trackId != null) {
      final goal = await db.goalDao.getGoalByTrack(trackId);
      if (goal != null) {
        if (goal.goalType == 'pace' &&
            goal.paceValue != null &&
            goal.paceUnit != null) {
          final dailyRate = PaceCalculator.paceToDaily(
            goal.paceValue!,
            goal.paceUnit!,
          );
          final existing = pacePerDayMap[curriculum];
          if (existing == null || dailyRate > existing) {
            pacePerDayMap[curriculum] = dailyRate;
          }
        } else if (goal.targetDate != null) {
          final existing = goalDeadlines[curriculum];
          if (existing == null || goal.targetDate!.isBefore(existing)) {
            goalDeadlines[curriculum] = goal.targetDate!;
          }
        }
        continue;
      }
    }

    // Fallback for legacy rows lacking explicit track linkage.
    final goals = await db.goalDao.getGoalsByCurriculumAndProfile(
      curriculum.storageKey,
      profileId,
    );
    for (final goal in goals) {
      if (goal.goalType == 'pace' &&
          goal.paceValue != null &&
          goal.paceUnit != null) {
        final dailyRate = PaceCalculator.paceToDaily(
          goal.paceValue!,
          goal.paceUnit!,
        );
        final existing = pacePerDayMap[curriculum];
        if (existing == null || dailyRate > existing) {
          pacePerDayMap[curriculum] = dailyRate;
        }
      } else if (goal.targetDate != null) {
        final existing = goalDeadlines[curriculum];
        if (existing == null || goal.targetDate!.isBefore(existing)) {
          goalDeadlines[curriculum] = goal.targetDate!;
        }
      }
    }
  }

  final isStudyDayMap = <CurriculumId, bool>{};
  final studyDaysPerWeekMap = <CurriculumId, int>{};
  for (final curriculum in activeCurricula) {
    final trackId = trackIds[curriculum];
    if (trackId != null) {
      isStudyDayMap[curriculum] = await db.studyDayConfigDao.isStudyDayForTrack(
        trackId: trackId,
        dayOfWeek: now.weekday,
      );
      studyDaysPerWeekMap[curriculum] = await db.studyDayConfigDao
          .getStudyDaysPerWeekForTrack(trackId: trackId);
    } else {
      isStudyDayMap[curriculum] = await db.studyDayConfigDao.isStudyDay(
        profileId: profileId,
        curriculumId: curriculum.storageKey,
        dayOfWeek: now.weekday,
      );
      studyDaysPerWeekMap[curriculum] = await db.studyDayConfigDao
          .getStudyDaysPerWeek(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
          );
    }
  }

  return generator.generateAll(
    activeCurricula,
    now,
    goalDeadlines: goalDeadlines,
    pacePerDayMap: pacePerDayMap,
    isStudyDayMap: isStudyDayMap,
    studyDaysPerWeekMap: studyDaysPerWeekMap,
    trackIds: trackIds,
    trackLabels: trackLabels,
  );
}
