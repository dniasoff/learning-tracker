import 'dart:async';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/services/calendar_program_registry.dart';
import 'package:learning_tracker/core/services/calendar_program_service.dart';
import 'package:learning_tracker/core/services/learning_program_service.dart';
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
  final calendarService = ref.watch(calendarProgramServiceProvider);
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
      calendarService: calendarService,
      getScopedContent: (curriculumId) =>
          ref.read(scopedCurriculumContentProvider(curriculumId).future),
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
  final snapshotMissingProgramAssignments =
      await _snapshotMissingProgramAssignments(
        db: db,
        tasks: tasks,
        profileId: profileId,
        now: now,
        activeCurriculumKeys: activeCurriculumKeys,
        calendarService: calendarService,
        getScopedContent: (curriculumId) =>
            ref.read(scopedCurriculumContentProvider(curriculumId).future),
      );

  final effectiveTasks =
      (snapshotMissingActiveCurriculum || snapshotMissingProgramAssignments)
      ? await planRepo.rebuildPlan(
          profileId: profileId,
          now: now,
          buildPlan: () => _buildFreshPlan(
            db: db,
            generator: generator,
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

Future<bool> _snapshotMissingProgramAssignments({
  required UserDatabase db,
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

    final enrollment = await db.profileProgramDao.getProgramForProfileAndCurriculum(
      profileId,
      curriculum.storageKey,
    );
    final programId = enrollment?.programId;
    if (programId == null) continue;
    final program = LearningProgramRepository.instance.getProgramById(programId);
    final apiKey = program?.apiProgramKey;
    if (program == null || apiKey == null || apiKey.isEmpty) continue;

    final programKey =
        CalendarProgramRegistry.byId(apiKey)?.id ??
        CalendarProgramRegistry.byApiKey(apiKey)?.id ??
        CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;
    if (programKey == null) continue;

    final entry = await calendarService.getEntry(programKey, now);
    final todayRef = entry?.todayRef.trim();
    if (todayRef == null || todayRef.isEmpty) continue;

    final contentItems = await getScopedContent(curriculum);
    final expectedRefs = _resolvedOrFallbackProgramRefs(
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
  final expectedNormalized = expectedRefs.map(_normalizeRef).toSet();
  final actualNormalized = tasks
      .where((t) => t.trackId == trackId)
      .map((t) => _normalizeRef(t.contentItemSefariaRef))
      .toSet();
  return expectedNormalized.every(actualNormalized.contains);
}

/// Runs the scheduler across all active curricula to produce a fresh plan.
/// Called only when no snapshot exists for the current local day.
Future<List<DailyTask>> _buildFreshPlan({
  required UserDatabase db,
  required DailyTaskGenerator generator,
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

  final generated = await generator.generateAll(
    activeCurricula,
    now,
    goalDeadlines: goalDeadlines,
    pacePerDayMap: pacePerDayMap,
    isStudyDayMap: isStudyDayMap,
    studyDaysPerWeekMap: studyDaysPerWeekMap,
    trackIds: trackIds,
    trackLabels: trackLabels,
  );

  final overridden = await _applyProgramCalendarOverrides(
    db: db,
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

Future<List<DailyTask>> _applyProgramCalendarOverrides({
  required UserDatabase db,
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

    final entry = await calendarService.getEntry(programKey, now);
    final todayRef = entry?.todayRef;
    if (todayRef == null || todayRef.trim().isEmpty) continue;

    final contentItems = await getScopedContent(curriculum);
    final refsForToday = _resolvedOrFallbackProgramRefs(
      todayRef: todayRef,
      contentItems: contentItems,
    );
    if (refsForToday.isEmpty) continue;

    final stages = await db.stageDao.getStagesByTrack(trackId);
    if (stages.isEmpty) continue;
    final firstStage =
        (stages.toList()..sort((a, b) => a.stageOrder.compareTo(b.stageOrder)))
            .first;

    result.removeWhere(
      (t) =>
          t.curriculumId == curriculum &&
          t.trackId == trackId &&
          t.priority == DailyTaskPriority.newLearning,
    );

    result.addAll(
      refsForToday.map((ref) {
        return DailyTask(
          curriculumId: curriculum,
          contentItemSefariaRef: ref,
          stageOrder: firstStage.stageOrder,
          stageDefinitionId: firstStage.id,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'Program assignment for today',
          stageName: firstStage.stageName,
          trackId: trackId,
          trackLabel: trackLabels[curriculum] ?? TrackType.personal.storageKey,
          estimatedEffortMinutes: 5,
        );
      }),
    );
  }

  return result;
}

Set<String> _resolveProgramTodayRefs(
  String todayRef,
  List<ContentItem> contentItems,
) {
  final leafRefs = contentItems
      .where((item) => item.isLeaf)
      .map((item) => item.sefariaRef)
      .whereType<String>()
      .toList();
  if (leafRefs.isEmpty) return const {};

  final normalizedLeaf = <String, String>{
    for (final ref in leafRefs) _normalizeRef(ref): ref,
  };

  final candidates = <String>{
    ..._refVariants(todayRef),
    ..._expandSimpleRange(todayRef),
    ..._expandDafLikeRange(todayRef),
    for (final variant in _refVariants(todayRef)) ..._expandSimpleRange(variant),
    for (final variant in _refVariants(todayRef)) ..._expandDafLikeRange(variant),
  };

  final matches = <String>{};
  for (final candidate in candidates) {
    final resolved = normalizedLeaf[_normalizeRef(candidate)];
    if (resolved != null) {
      matches.add(resolved);
    }
  }

  if (matches.isNotEmpty) return matches;

  // Fallback: calendar entry may point at a non-leaf unit (e.g. full daf),
  // while track content is leaf-only (e.g. amud a/b). Expand to leaf children.
  for (final candidate in candidates) {
    final expanded = _resolveLeafRefsFromContainer(candidate, contentItems);
    if (expanded.isNotEmpty) {
      matches.addAll(expanded);
      continue;
    }

    final indexed = _resolveIndexedUnitRefs(candidate, contentItems);
    if (indexed.isNotEmpty) {
      matches.addAll(indexed);
    }
  }
  return matches;
}

Set<String> _resolvedOrFallbackProgramRefs({
  required String todayRef,
  required List<ContentItem> contentItems,
}) {
  final resolved = _resolveProgramTodayRefs(todayRef, contentItems);
  if (resolved.isNotEmpty) return resolved;

  final fallback = _displayProgramRef(todayRef);
  if (fallback.isEmpty) return const {};
  return {fallback};
}

String _displayProgramRef(String ref) {
  return ref
      .replaceAll('_', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Set<String> _refVariants(String ref) {
  final trimmed = ref.replaceAll('–', '-').trim();
  if (trimmed.isEmpty) return const {};

  final variants = <String>{trimmed};
  final lower = trimmed.toLowerCase();

  // Common transliteration variants seen in calendar feeds vs content trees.
  final aliasMap = <String, String>{
    'midos': 'middot',
    'mishnayos': 'mishnah',
    'mishna ': 'mishnah ',
  };
  var replacedLower = lower;
  aliasMap.forEach((from, to) {
    replacedLower = replacedLower.replaceAll(from, to);
  });
  if (replacedLower != lower) {
    variants.add(_matchOriginalCasing(trimmed, replacedLower));
  }

  if (lower.startsWith('mishnah ')) {
    variants.add(trimmed.substring('mishnah '.length).trim());
  } else {
    variants.add('Mishnah $trimmed');
  }

  if (lower.startsWith('jerusalem talmud ')) {
    variants.add(trimmed.substring('jerusalem talmud '.length).trim());
  } else {
    variants.add('Jerusalem Talmud $trimmed');
  }

  return variants.where((v) => v.trim().isNotEmpty).map((v) => v.trim()).toSet();
}

String _matchOriginalCasing(String original, String lowerValue) {
  if (original == original.toUpperCase()) return lowerValue.toUpperCase();
  if (original == original.toLowerCase()) return lowerValue;
  return lowerValue
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => part[0].toUpperCase() + part.substring(1))
      .join(' ');
}

String _normalizeRef(String ref) {
  return ref
      .toLowerCase()
      .replaceAll('_', ' ')
      .replaceAll(':', '.')
      .replaceAll(RegExp(r'[^a-z0-9.\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

Set<String> _expandSimpleRange(String ref) {
  final normalized = ref.replaceAll('–', '-').trim();
  final match = RegExp(
    r'^(.*?)(\d+)[\.:](\d+)\s*-\s*(\d+)$',
  ).firstMatch(normalized);
  if (match == null) return const {};

  final base = match.group(1)?.trim() ?? '';
  final chapter = int.tryParse(match.group(2) ?? '');
  final from = int.tryParse(match.group(3) ?? '');
  final to = int.tryParse(match.group(4) ?? '');
  if (chapter == null || from == null || to == null || to < from)
    return const {};

  final expanded = <String>{};
  for (var section = from; section <= to; section++) {
    expanded.add('$base $chapter.$section'.trim());
    expanded.add('$base $chapter:$section'.trim());
  }
  return expanded;
}

Set<String> _expandDafLikeRange(String ref) {
  final normalized = ref.replaceAll('–', '-').trim();
  final match = RegExp(
    r'^(.*?)(\d+)([ab])?\s*-\s*(\d+)([ab])?$',
    caseSensitive: false,
  ).firstMatch(normalized);
  if (match == null) return const {};

  final base = match.group(1)?.trim() ?? '';
  final fromPage = int.tryParse(match.group(2) ?? '');
  final fromSide = (match.group(3) ?? '').toLowerCase();
  final toPage = int.tryParse(match.group(4) ?? '');
  final toSide = (match.group(5) ?? '').toLowerCase();
  if (fromPage == null || toPage == null || toPage < fromPage) return const {};

  final expanded = <String>{};
  for (var page = fromPage; page <= toPage; page++) {
    if (fromSide.isNotEmpty || toSide.isNotEmpty) {
      expanded.add('$base ${page}a'.trim());
      expanded.add('$base ${page}b'.trim());
      continue;
    }
    expanded.add('$base $page'.trim());
  }

  // If specific boundary sides are provided, trim out impossible endpoints.
  if (fromSide == 'b') {
    expanded.remove('$base ${fromPage}a'.trim());
  }
  if (toSide == 'a') {
    expanded.remove('$base ${toPage}b'.trim());
  }
  return expanded;
}

Set<String> _resolveLeafRefsFromContainer(
  String candidate,
  List<ContentItem> contentItems,
) {
  final normalizedCandidate = _normalizeRef(candidate);
  if (normalizedCandidate.isEmpty) return const {};

  final exactContainer = contentItems.firstWhere(
    (item) => _normalizeRef(item.sefariaRef) == normalizedCandidate,
    orElse: () => const ContentItem(
      curriculumId: '',
      level1: '',
      displayNameHe: '',
      displayNameEn: '',
      sefariaRef: '',
      sortOrder: 0,
      isLeaf: true,
    ),
  );

  if (exactContainer.sefariaRef.isNotEmpty && !exactContainer.isLeaf) {
    return _leafChildrenForContainer(exactContainer, contentItems);
  }

  final fuzzyContainer = _findFuzzyContainerMatch(candidate, contentItems);
  if (fuzzyContainer == null) return const {};
  return _leafChildrenForContainer(fuzzyContainer, contentItems);
}

Set<String> _resolveIndexedUnitRefs(
  String candidate,
  List<ContentItem> contentItems,
) {
  final parsed = _parseRefTail(candidate);
  if (parsed == null) return const {};

  final rawTitle = parsed.$1.trim();
  final address = parsed.$2.trim().toLowerCase();
  final index = int.tryParse(address);
  if (index == null || index <= 0) return const {};

  // Yerushalmi cycle entries are often "Jerusalem Talmud <masechta> <ordinal>"
  // where ordinal indexes through units, not chapter number.
  if (!_normalizeRef(rawTitle).startsWith('jerusalem talmud ')) return const {};

  final topContainer = contentItems.firstWhere(
    (item) => !item.isLeaf && _normalizeRef(item.sefariaRef) == _normalizeRef(rawTitle),
    orElse: () => const ContentItem(
      curriculumId: '',
      level1: '',
      displayNameHe: '',
      displayNameEn: '',
      sefariaRef: '',
      sortOrder: 0,
      isLeaf: true,
    ),
  );
  if (topContainer.sefariaRef.isEmpty) return const {};

  final leaves = _leafChildrenForContainer(topContainer, contentItems).toList()
    ..sort((a, b) {
      final aOrder = contentItems
          .firstWhere((i) => i.sefariaRef == a, orElse: () => const ContentItem(
                curriculumId: '',
                level1: '',
                displayNameHe: '',
                displayNameEn: '',
                sefariaRef: '',
                sortOrder: 0,
                isLeaf: true,
              ))
          .sortOrder;
      final bOrder = contentItems
          .firstWhere((i) => i.sefariaRef == b, orElse: () => const ContentItem(
                curriculumId: '',
                level1: '',
                displayNameHe: '',
                displayNameEn: '',
                sefariaRef: '',
                sortOrder: 0,
                isLeaf: true,
              ))
          .sortOrder;
      return aOrder.compareTo(bOrder);
    });
  if (leaves.isEmpty || index > leaves.length) return const {};

  return {leaves[index - 1]};
}

Set<String> _leafChildrenForContainer(
  ContentItem container,
  List<ContentItem> contentItems,
) {
  final leaves = contentItems.where((item) {
    if (!item.isLeaf) return false;
    if (item.level1 != container.level1) return false;
    if (container.level2 != null && item.level2 != container.level2) return false;
    if (container.level3 != null && item.level3 != container.level3) return false;
    if (container.level4 != null && item.level4 != container.level4) return false;
    return true;
  }).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  return leaves.map((leaf) => leaf.sefariaRef).toSet();
}

ContentItem? _findFuzzyContainerMatch(
  String candidate,
  List<ContentItem> contentItems,
) {
  final parsed = _parseRefTail(candidate);
  if (parsed == null) return null;
  final title = parsed.$1;
  final address = parsed.$2;
  if (title.isEmpty || address.isEmpty) return null;

  final normalizedTitle = _normalizeTitle(title);
  final possibleContainers = contentItems.where((item) => !item.isLeaf).toList();
  ContentItem? best;
  var bestScore = -1;

  for (final item in possibleContainers) {
    final parsedItem = _parseRefTail(item.sefariaRef);
    if (parsedItem == null) continue;
    final itemAddress = parsedItem.$2;
    if (itemAddress != address) continue;

    final itemTitleNorm = _normalizeTitle(parsedItem.$1);
    final score = _titleSimilarityScore(normalizedTitle, itemTitleNorm);
    if (score > bestScore) {
      bestScore = score;
      best = item;
    }
  }

  return bestScore >= 2 ? best : null;
}

(String, String)? _parseRefTail(String ref) {
  final normalized = ref.replaceAll('_', ' ').trim();
  final match = RegExp(r'^(.*?)(\d+[a-z]?)$').firstMatch(normalized);
  if (match == null) return null;
  return ((match.group(1) ?? '').trim(), (match.group(2) ?? '').trim());
}

String _normalizeTitle(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z\s]'), '')
      .replaceAll(RegExp(r'\b(the|talmud|mishnah|jerusalem)\b'), '')
      .replaceAll('baba', 'bava')
      .replaceAll('succah', 'sukkah')
      .replaceAll('megilah', 'megillah')
      .replaceAll('hullin', 'chullin')
      .replaceAll('beitzah', 'beitza')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

int _titleSimilarityScore(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0;
  if (a == b) return 10;
  if (a.contains(b) || b.contains(a)) return 6;

  final aWords = a.split(' ').where((w) => w.isNotEmpty).toSet();
  final bWords = b.split(' ').where((w) => w.isNotEmpty).toSet();
  final overlap = aWords.intersection(bWords).length;
  return overlap;
}
