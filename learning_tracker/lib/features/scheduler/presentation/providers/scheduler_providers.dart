import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/learning/completion_writer_providers.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/stages/presentation/providers/stage_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'scheduler_providers.g.dart';

/// True when the goal's [paceGranularity] (e.g. 'perek', 'daf', 'siman')
/// names a level above the curriculum's leaf, so pace is interpreted in
/// coarse units. When false (leaf mode or no unit set) pace counts leaves.
bool _isCoarseLearningUnit(CurriculumId curriculum, String? paceGranularity) {
  if (paceGranularity == null) return false;
  final leafEn = CurriculumLabels.leaf(curriculum).en.toLowerCase();
  return paceGranularity.toLowerCase() != leafEn;
}

/// Dashboard-driven task section filter for Scheduler screen.
enum SchedulerTaskSection { all, today, overdue, review }

final schedulerTaskSectionProvider =
    NotifierProvider<SchedulerTaskSectionNotifier, SchedulerTaskSection>(
      SchedulerTaskSectionNotifier.new,
    );

class SchedulerTaskSectionNotifier extends Notifier<SchedulerTaskSection> {
  @override
  SchedulerTaskSection build() => SchedulerTaskSection.all;

  void setSection(SchedulerTaskSection section) => state = section;

  void reset() => state = SchedulerTaskSection.all;
}

/// Provides the current UTC date/time. Override in tests to control time.
@riverpod
DateTime clock(Ref ref) => DateTimeFactory.nowUtc();

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
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
  final generator = ref.watch(dailyTaskGeneratorProvider);
  final planRepo = ref.watch(dailyPlanRepositoryProvider);
  final calendarService = ref.watch(calendarProgramServiceProvider);
  final skipped = ref.watch(skippedTasksProvider);
  final previouslySkipped = await ref.watch(
    previouslySkippedRefsProvider.future,
  );
  final profileId = ref.watch(activeProfileIdProvider);
  final now = ref.watch(clockProvider);

  final engine = ref.watch(schedulerEngineProvider);
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final planResult = await planRepo.getOrSnapshotPlan(
    profileId: profileId,
    now: now,
    buildPlan: () => _buildFreshPlan(
      db: db,
      stageRepository: stageRepository,
      generator: generator,
      engine: engine,
      planRepo: planRepo,
      profileId: profileId,
      now: now,
      calendarService: calendarService,
      getScopedContent: (curriculumId) =>
          ref.read(scopedCurriculumContentProvider(curriculumId).future),
    ),
  );
  final tasks = planResult.tasks;

  // Guard against stale/empty daily snapshots:
  // if active curricula changed after the first snapshot of the day,
  // today's plan may miss entire curricula until tomorrow.
  //
  // Performance: skip this guard when the plan was already snapshotted
  // before this provider call (e.g. completion-triggered re-evaluations).
  // The guard is only meaningful immediately after the plan is first built,
  // not on every subsequent read.
  final activeCurriculumKeys = await db.activeCurriculumDao
      .getActiveCurriculaByProfile(profileId);
  final snapshotCurriculumKeys = tasks
      .map((t) => t.curriculumId.storageKey)
      .toSet();
  final snapshotMissingActiveCurriculum =
      activeCurriculumKeys.isNotEmpty &&
      activeCurriculumKeys.any((key) => !snapshotCurriculumKeys.contains(key));
  final snapshotMissingProgramAssignments = planResult.isNew
      ? await _snapshotMissingProgramAssignments(
          db: db,
          stageRepository: stageRepository,
          tasks: tasks,
          profileId: profileId,
          now: now,
          activeCurriculumKeys: activeCurriculumKeys,
          calendarService: calendarService,
          getScopedContent: (curriculumId) =>
              ref.read(scopedCurriculumContentProvider(curriculumId).future),
        )
      : false;

  final effectiveTasks =
      (snapshotMissingActiveCurriculum || snapshotMissingProgramAssignments)
      ? await planRepo.rebuildPlan(
          profileId: profileId,
          now: now,
          buildPlan: () => _buildFreshPlan(
            db: db,
            stageRepository: stageRepository,
            generator: generator,
            engine: engine,
            planRepo: planRepo,
            profileId: profileId,
            now: now,
            calendarService: calendarService,
            getScopedContent: (curriculumId) =>
                ref.read(scopedCurriculumContentProvider(curriculumId).future),
          ),
        )
      : tasks;

  // Hide tasks already completed today (or earlier) while preserving the
  // frozen daily snapshot contract. We do not regenerate rows, we only
  // filter resolved items at read time.
  final taskRefs = effectiveTasks.map((t) => t.contentItemSefariaRef).toSet();
  final completions = taskRefs.isEmpty
      ? const <Completion>[]
      : await db.completionDao.getCompletionsByProfileForSefariaRefs(
          profileId,
          taskRefs,
        );
  bool isTaskCompleted(DailyTask task) {
    return completions.any((c) {
      if (c.sefariaRef != task.contentItemSefariaRef) return false;
      if (task.trackId != 0 && c.trackId != task.trackId) return false;
      // Sentinel completions (bulk-prior mark, completedAt = 2000-01-01) are
      // not genuine study sessions. They must NOT filter today's new-learning
      // tasks — the user still needs to study these items. (F5)
      if (c.completedAt.millisecondsSinceEpoch ==
          SchedulerEngine.kBulkPriorSentinelMs)
        return false;
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

Future<bool> _snapshotMissingProgramAssignments({
  required UserDatabase db,
  required StageDefinitionRepository stageRepository,
  required List<DailyTask> tasks,
  required int profileId,
  required DateTime now,
  required List<String> activeCurriculumKeys,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
}) async {
  if (activeCurriculumKeys.isEmpty) return false;

  final activeCurricula = <CurriculumId>[
    for (final key in activeCurriculumKeys)
      ...CurriculumId.values.where((c) => c.storageKey == key).take(1),
  ];
  if (activeCurricula.isEmpty) return false;

  final activeTracks = await db.trackDao.getActiveTracksForProfile(profileId);
  final trackIdsByCurriculum = <CurriculumId, int>{};
  for (final curriculum in activeCurricula) {
    final tracksForCurriculum = activeTracks
        .where((t) => t.curriculumId == curriculum.storageKey)
        .toList();
    if (tracksForCurriculum.isEmpty) continue;
    final preferred = tracksForCurriculum.firstWhere(
      (t) => t.trackType == TrackType.personal.storageKey,
      orElse: () => tracksForCurriculum.first,
    );
    trackIdsByCurriculum[curriculum] = preferred.id;
  }

  for (final curriculum in activeCurricula) {
    final trackId = trackIdsByCurriculum[curriculum];
    if (trackId == null) continue;

    final enrollment = await db.profileProgramDao
        .getProgramForProfileAndCurriculum(profileId, curriculum.storageKey);
    final programId = enrollment?.programId;
    if (programId == null) continue;
    final program = LearningProgramRepository.instance.getProgramById(
      programId,
    );
    final apiKey = program?.apiProgramKey;
    if (program == null || apiKey == null || apiKey.isEmpty) continue;

    final programKey =
        CalendarProgramRegistry.byId(apiKey)?.id ??
        CalendarProgramRegistry.byApiKey(apiKey)?.id ??
        CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;
    if (programKey == null) continue;

    final todayLocal = DateUtils.extractLocalDate(now);
    final entry = await calendarService.getEntry(programKey, todayLocal);
    final todayRef = entry?.todayRef.trim();
    if (todayRef == null || todayRef.isEmpty) continue;

    final contentItems = await getScopedContent(curriculum);
    final expectedRefs = resolvedOrFallbackProgramRefs(
      todayRef: todayRef,
      contentItems: contentItems,
    );
    if (expectedRefs.isEmpty) continue;

    final found = _programAssignmentPresentInTasks(
      tasks: tasks,
      trackId: trackId,
      expectedRefs: expectedRefs,
    );
    if (!found) {
      return true;
    }
  }

  return false;
}

bool _programAssignmentPresentInTasks({
  required List<DailyTask> tasks,
  required int trackId,
  required Set<String> expectedRefs,
}) {
  if (expectedRefs.isEmpty) return true;
  final expectedNormalized = expectedRefs.map(normalizeRef).toSet();
  final actualNormalized = tasks
      .where((t) => t.trackId == trackId)
      .map((t) => normalizeRef(t.contentItemSefariaRef))
      .toSet();
  return expectedNormalized.every(actualNormalized.contains);
}

/// Runs the scheduler across all active curricula to produce a fresh plan.
/// Called only when no snapshot exists for the current local day.
Future<List<DailyTask>> _buildFreshPlan({
  required UserDatabase db,
  required StageDefinitionRepository stageRepository,
  required DailyTaskGenerator generator,
  required SchedulerEngine engine,
  required DailyPlanRepository planRepo,
  required int profileId,
  required DateTime now,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
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
  final trackStartedAtMap = <CurriculumId, DateTime>{};
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
    trackStartedAtMap[curriculum] = preferred.activatedAt;
  }

  final goalDeadlines = <CurriculumId, DateTime>{};
  final pacePerDayMap = <CurriculumId, double>{};
  final paceGranularityMap = <CurriculumId, String>{};
  for (final curriculum in activeCurricula) {
    final trackId = trackIds[curriculum];
    if (trackId != null) {
      final goal = await db.goalDao.getGoalByTrack(trackId);
      if (goal != null) {
        if (goal.goalType == 'pace' &&
            goal.paceValue != null &&
            goal.pacePeriod != null) {
          final dailyRate = PaceCalculator.paceToDaily(
            goal.paceValue!,
            goal.pacePeriod!,
          );
          final existing = pacePerDayMap[curriculum];
          if (existing == null || dailyRate > existing) {
            pacePerDayMap[curriculum] = dailyRate;
            if (goal.paceGranularity != null) {
              paceGranularityMap[curriculum] = goal.paceGranularity!;
            } else {
              paceGranularityMap.remove(curriculum);
            }
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
          goal.pacePeriod != null) {
        final dailyRate = PaceCalculator.paceToDaily(
          goal.paceValue!,
          goal.pacePeriod!,
        );
        final existing = pacePerDayMap[curriculum];
        if (existing == null || dailyRate > existing) {
          pacePerDayMap[curriculum] = dailyRate;
          if (goal.paceGranularity != null) {
            paceGranularityMap[curriculum] = goal.paceGranularity!;
          } else {
            paceGranularityMap.remove(curriculum);
          }
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
  final localWeekday = now.toLocal().weekday;
  for (final curriculum in activeCurricula) {
    final trackId = trackIds[curriculum];
    if (trackId != null) {
      isStudyDayMap[curriculum] = await db.studyDayConfigDao.isStudyDayForTrack(
        trackId: trackId,
        dayOfWeek: localWeekday,
      );
      studyDaysPerWeekMap[curriculum] = await db.studyDayConfigDao
          .getStudyDaysPerWeekForTrack(trackId: trackId);
    } else {
      isStudyDayMap[curriculum] = await db.studyDayConfigDao.isStudyDay(
        profileId: profileId,
        curriculumId: curriculum.storageKey,
        dayOfWeek: localWeekday,
      );
      studyDaysPerWeekMap[curriculum] = await db.studyDayConfigDao
          .getStudyDaysPerWeek(
            profileId: profileId,
            curriculumId: curriculum.storageKey,
          );
    }
  }

  // Exact study-day count from today through deadline (per track pattern).
  final studyDaysInDeadlineWindowMap = <CurriculumId, int>{};
  for (final curriculum in activeCurricula) {
    if (pacePerDayMap.containsKey(curriculum)) continue;
    final deadline = goalDeadlines[curriculum];
    final trackId = trackIds[curriculum];
    if (deadline == null || trackId == null) continue;
    final start = _localDateOnly(now);
    final end = _localDateOnly(deadline);
    final n = await db.studyDayConfigDao
        .countStudyDaysInInclusiveDateRangeForTrack(
          trackId: trackId,
          startInclusive: start,
          endInclusive: end,
        );
    if (n > 0) {
      studyDaysInDeadlineWindowMap[curriculum] = n;
    }
  }

  // For every track with a known activatedAt, back-fill synthetic snapshots
  // for elapsed *study days* that have no existing snapshot row.  The engine
  // uses priorlyShownRefs to surface uncompleted prior items as overdue today.
  //
  // F6 fix: back-fill now runs for tracks regardless of whether they have a
  // pace-based goal.  Non-pace tracks use `defaultNewItemsPerDay` (5) as the
  // effective pace so the snapshot path fires and overdue items appear after
  // elapsed study days.  Back-fill is restricted to study days only —
  // non-study elapsed days are skipped.
  final priorlyShownRefsMap = <CurriculumId, Set<String>>{};
  // Tracks that don't have a pace goal but have activatedAt: we synthesise
  // a pacePerDay for the engine snapshot path (overdue computation only).
  final effectivePaceOverrideMap = <CurriculumId, double>{};
  final todayLocal = _localDateOnly(now);
  for (final curriculum in activeCurricula) {
    final trackId = trackIds[curriculum];
    final startedAt = trackStartedAtMap[curriculum];
    if (trackId == null || startedAt == null) continue;

    final orderedItems = await engine.getOrderedLeafItems(curriculum);
    final stages = await stageRepository.getStagesByTrack(trackId);
    if (stages.isEmpty || orderedItems.isEmpty) continue;
    final firstStage = stages.reduce(
      (domain_stage.StageDefinition a, domain_stage.StageDefinition b) =>
          a.stageOrder < b.stageOrder ? a : b,
    );

    final pace = pacePerDayMap[curriculum];
    final hasPaceGoal = pace != null;

    if (hasPaceGoal) {
      // Existing pace-goal path: respect coarse-unit grouping and use the
      // configured pace.  Back-fill is study-day-aware.
      final paceCeil = pace.ceil();
      if (paceCeil <= 0) continue;

      // Fetch study day weekdays for this track.
      final studyConfigs = await db.studyDayConfigDao.getConfigsByTrack(
        trackId,
      );
      final studyWeekdays = studyConfigs.isEmpty
          ? {1, 2, 3, 4, 5, 6, 7}
          : {
              for (final c in studyConfigs)
                if (c.dayType == 'study') c.dayOfWeek,
            };

      // Slot a day's worth of refs by either coarse unit (when the goal's
      // paceGranularity names a level above the leaf, e.g. 'perek' for
      // Mishnayos or 'daf' for Bavli) or single leaves.
      final paceGranularity = paceGranularityMap[curriculum];
      final isCoarse = _isCoarseLearningUnit(curriculum, paceGranularity);
      final daySlots = <List<String>>[];
      if (isCoarse) {
        final byKey = <String, List<String>>{};
        final keyOrder = <String>[];
        for (final item in orderedItems) {
          final key = item.coarseUnitKey ?? item.sefariaRef;
          final list = byKey.putIfAbsent(key, () {
            keyOrder.add(key);
            return <String>[];
          });
          list.add(item.sefariaRef);
        }
        for (final key in keyOrder) {
          daySlots.add(byKey[key]!);
        }
      } else {
        for (final item in orderedItems) {
          daySlots.add([item.sefariaRef]);
        }
      }

      // Study-day ordinal counter — incremented only for study days so the
      // position assignment skips non-study days.
      var studyDayOrdinal = 0;
      await planRepo.backfillMissingSnapshots(
        profileId: profileId,
        trackId: trackId,
        activatedAt: startedAt,
        currentDate: now,
        buildSnapshotForDay: ({required dayIndex, required planDate}) async {
          // Skip non-study days.
          if (!studyWeekdays.contains(planDate.weekday)) {
            return const <DailyTask>[];
          }

          final start = studyDayOrdinal * paceCeil;
          studyDayOrdinal++;

          if (start >= daySlots.length) return const <DailyTask>[];
          final end = (start + paceCeil).clamp(0, daySlots.length);
          final refs = daySlots.sublist(start, end).expand((g) => g).toList();
          return refs
              .map(
                (ref) => DailyTask(
                  curriculumId: curriculum,
                  contentItemSefariaRef: ref,
                  stageOrder: firstStage.stageOrder,
                  stageDefinitionId: firstStage.id,
                  priority: DailyTaskPriority.newLearning,
                  isOverdue: true,
                  reason: 'Backfilled (app not run)',
                  stageName: firstStage.stageName,
                  trackId: trackId,
                  trackLabel: trackLabels[curriculum] ?? '',
                  estimatedEffortMinutes: 5,
                ),
              )
              .toList();
        },
      );
    } else {
      // Non-pace-goal path (F6 fix): back-fill elapsed study days using a
      // default pace so overdue items appear when study days were missed.
      const kDefaultBackfillPace = 5;

      final studyConfigs = await db.studyDayConfigDao.getConfigsByTrack(
        trackId,
      );
      final studyWeekdays = studyConfigs.isEmpty
          ? const <int>{1, 2, 3, 4, 5, 6, 7}
          : {
              for (final c in studyConfigs)
                if (c.dayType == 'study') c.dayOfWeek,
            };

      final orderedRefs = orderedItems.map((i) => i.sefariaRef).toList();

      await planRepo.backfillStudyDaySnapshots(
        profileId: profileId,
        trackId: trackId,
        curriculumId: curriculum,
        activatedAt: startedAt,
        currentDate: now,
        pace: kDefaultBackfillPace,
        studyWeekdays: studyWeekdays,
        orderedRefs: orderedRefs,
        firstStageOrder: firstStage.stageOrder,
        firstStageDefinitionId: firstStage.id,
        firstStageName: firstStage.stageName,
        trackLabel: trackLabels[curriculum] ?? '',
      );

      // Record the effective pace override so the engine uses the snapshot
      // path (which handles priorlyShownRefs) for overdue computation.
      effectivePaceOverrideMap[curriculum] = kDefaultBackfillPace.toDouble();
    }

    priorlyShownRefsMap[curriculum] = await db.dailyPlanDao
        .getPriorlyShownRefsForTrack(trackId: trackId, excludeDate: todayLocal);
  }

  // Merge the explicit pace-goal map with effective-pace overrides for
  // non-pace tracks that were back-filled (F6 fix).  The engine snapshot
  // path requires pacePerDay != null to fire; effectivePaceOverrideMap
  // supplies a default value so overdue items surface for those tracks.
  final mergedPacePerDayMap = {
    ...effectivePaceOverrideMap,
    ...pacePerDayMap, // explicit goals take precedence
  };

  final generated = await generator.generateAll(
    activeCurricula,
    now,
    goalDeadlines: goalDeadlines,
    pacePerDayMap: mergedPacePerDayMap,
    isStudyDayMap: isStudyDayMap,
    studyDaysPerWeekMap: studyDaysPerWeekMap,
    studyDaysInDeadlineWindowMap: studyDaysInDeadlineWindowMap,
    trackIds: trackIds,
    trackLabels: trackLabels,
    trackStartedAtMap: trackStartedAtMap,
    priorlyShownRefsMap: priorlyShownRefsMap,
    paceGranularityMap: paceGranularityMap,
  );

  final overridden = await _applyProgramCalendarOverrides(
    db: db,
    stageRepository: stageRepository,
    generated: generated,
    profileId: profileId,
    now: now,
    activeCurricula: activeCurricula,
    trackIds: trackIds,
    trackLabels: trackLabels,
    calendarService: calendarService,
    getScopedContent: getScopedContent,
  );
  overridden.sort((a, b) => a.priority.index.compareTo(b.priority.index));
  return overridden;
}

/// Returns the ordered list of calendar entries spanning [anchor, today]
/// inclusive for a program-calendar track.
///
/// The last entry in the list is today's unit (priority `todayProgram`);
/// every earlier entry represents an overdue unit (`overdueProgram`).
///
/// This is a pure function of its inputs — no DB access — and is the
/// single source of truth for "which calendar units belong in the
/// schedule".  It is package-visible so that the characterisation test
/// (O2 in `test/scheduler/overdue_projection_test.dart`) can exercise it
/// directly.
///
/// Invariant (O2 convention):
///   A program anchored N days before today with no completions →
///   N entries before the last one (overdue) + 1 last entry (today).
Future<List<CalendarProgramEntry>> programCalendarSchedule({
  required String programKey,
  required DateTime anchor,
  required DateTime today,
  required CalendarProgramService calendarService,
}) async {
  // [anchor, today] inclusive — getEntriesForRange is inclusive on both ends.
  final entries = await calendarService.getEntriesForRange(
    programKey,
    anchor,
    today,
  );
  if (entries.isNotEmpty) return entries;

  // Calendar engine returned nothing for the range — fall back to just today.
  final todayEntry = await calendarService.getEntry(programKey, today);
  return todayEntry != null ? [todayEntry] : const [];
}

Future<List<DailyTask>> _applyProgramCalendarOverrides({
  required UserDatabase db,
  required StageDefinitionRepository stageRepository,
  required List<DailyTask> generated,
  required int profileId,
  required DateTime now,
  required List<CurriculumId> activeCurricula,
  required Map<CurriculumId, int> trackIds,
  required Map<CurriculumId, String> trackLabels,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
}) async {
  final result = List<DailyTask>.from(generated);

  for (final curriculum in activeCurricula) {
    final trackId = trackIds[curriculum];
    if (trackId == null) continue;

    final enrollment = await db.profileProgramDao
        .getProgramForProfileAndCurriculum(profileId, curriculum.storageKey);
    if (enrollment == null) continue;

    final program = LearningProgramRepository.instance.getProgramById(
      enrollment.programId,
    );
    final apiKey = program?.apiProgramKey;
    if (program == null || apiKey == null || apiKey.isEmpty) continue;

    final programKey =
        CalendarProgramRegistry.byId(apiKey)?.id ??
        CalendarProgramRegistry.byApiKey(apiKey)?.id ??
        CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;
    if (programKey == null) continue;

    final contentItems = await getScopedContent(curriculum);
    final stages = await stageRepository.getStagesByTrack(trackId);
    if (stages.isEmpty) continue;
    final firstStage =
        (stages.toList()..sort(
              (
                domain_stage.StageDefinition a,
                domain_stage.StageDefinition b,
              ) => a.stageOrder.compareTo(b.stageOrder),
            ))
            .first;

    final todayDate = DateUtils.extractLocalDate(now);
    final DateTime configuredStartDate;
    if (enrollment.trackingStartDate == null) {
      configuredStartDate = todayDate;
    } else {
      final anchorUtc = enrollment.trackingStartDate!;
      // Ignore corrupt / default-epoch anchors that would span the whole cycle.
      if (anchorUtc.isBefore(DateTime.utc(2020, 1, 1))) {
        configuredStartDate = todayDate;
      } else {
        configuredStartDate = DateUtils.extractLocalDate(anchorUtc);
      }
    }
    result.removeWhere(
      (t) =>
          t.curriculumId == curriculum &&
          t.trackId == trackId &&
          (t.priority == DailyTaskPriority.newLearning ||
              t.priority == DailyTaskPriority.overdueProgram ||
              t.priority == DailyTaskPriority.todayProgram),
    );

    // Future anchors defer cycle tasks until the selected day.
    // This treats skipped-forward days as baseline, without writing fake
    // completion rows (which would distort streak/points/awards).
    if (configuredStartDate.isAfter(todayDate)) {
      continue;
    }

    // Walk the calendar from [anchor, today] inclusive.
    // tracking_start_ref is NOT consulted as "today's unit" — the calendar
    // engine is the source of truth.  The stored ref may still be written
    // by other code (e.g. re-anchor / setup flow) and is left intact in the
    // DB; we simply stop using it here to derive the schedule.
    final entries = await programCalendarSchedule(
      programKey: programKey,
      anchor: configuredStartDate,
      today: todayDate,
      calendarService: calendarService,
    );

    if (entries.isEmpty) continue;

    for (var i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final refsForEntry = resolvedOrFallbackProgramRefs(
        todayRef: entry.todayRef,
        contentItems: contentItems,
      );
      if (refsForEntry.isEmpty) continue;
      final isTodayUnit = i == entries.length - 1;
      final priority = isTodayUnit
          ? DailyTaskPriority.todayProgram
          : DailyTaskPriority.overdueProgram;
      final reason = isTodayUnit
          ? 'Program assignment for today'
          : 'Program day pending from previous days';
      result.addAll(
        refsForEntry.map((ref) {
          return DailyTask(
            curriculumId: curriculum,
            contentItemSefariaRef: ref,
            stageOrder: firstStage.stageOrder,
            stageDefinitionId: firstStage.id,
            priority: priority,
            isOverdue: !isTodayUnit,
            reason: reason,
            stageName: firstStage.stageName,
            trackId: trackId,
            trackLabel:
                trackLabels[curriculum] ?? TrackType.personal.storageKey,
            estimatedEffortMinutes: 5,
          );
        }),
      );
    }
  }

  return result;
}

/// Calendar date in the user's local timezone (time stripped).
DateTime _localDateOnly(DateTime utc) {
  final l = utc.toLocal();
  return DateTime(l.year, l.month, l.day);
}

// ─────────────────────────────────────────────────────────────────────────────
// TrackTaskCategory — task bucket selector for firstTaskInTrackForCategory
// ─────────────────────────────────────────────────────────────────────────────

/// Selector that identifies which bucket of the track's task queue to inspect.
///
/// Used by [firstTaskInTrackForCategoryProvider] and consumed by
/// [NextTaskBreadcrumb] when the user taps a stat box on a [TrackCard].
///
///   [review]    — chazara / repetition tasks (overdueChazara, scheduledChazara)
///   [dueToday]  — new-learning and on-time program tasks
///   [overdue]   — missed program days (non-review overdue)
enum TrackTaskCategory { review, dueToday, overdue }

/// Returns the first [DailyTask] for [trackId] that falls in [category],
/// or null when the bucket is empty.
///
/// Sourced from [allDailyTasksProvider] so it shares the frozen daily snapshot
/// and benefits from the same skip-filtering logic.
@riverpod
Future<DailyTask?> firstTaskInTrackForCategory(
  Ref ref, {
  required int trackId,
  required TrackTaskCategory category,
}) async {
  final all = await ref.watch(allDailyTasksProvider.future);
  final forTrack = all.where((t) => t.trackId == trackId);

  bool isReview(DailyTask t) =>
      t.priority == DailyTaskPriority.overdueChazara ||
      t.priority == DailyTaskPriority.scheduledChazara;

  final Iterable<DailyTask> bucket;
  switch (category) {
    case TrackTaskCategory.review:
      bucket = forTrack.where(isReview);
    case TrackTaskCategory.dueToday:
      bucket = forTrack.where((t) => !isReview(t) && !t.isOverdue);
    case TrackTaskCategory.overdue:
      bucket = forTrack.where((t) => !isReview(t) && t.isOverdue);
  }

  return bucket.isEmpty ? null : bucket.first;
}
