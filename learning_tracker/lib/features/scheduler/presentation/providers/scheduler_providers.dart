import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/content/program_ref_resolver.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/guarded_persist.dart';
import 'package:learning_tracker/features/dashboard/data/repositories/firestore_study_day_reader_adapter.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/profile_program_repository_impl.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/tracks/tracks.dart' show activeTracksProvider;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'scheduler_providers.g.dart';

/// Dashboard-driven task section filter for Scheduler screen.
enum SchedulerTaskSection { all, today, overdue, review }

final schedulerTaskSectionProvider =
    NotifierProvider<SchedulerTaskSectionNotifier, SchedulerTaskSection>(
      SchedulerTaskSectionNotifier.new,
    );

/// Whether the scheduler screen shows tasks grouped by curriculum.
/// Kept as a provider so [SchedulerScreen] can be a pure [ConsumerWidget]
/// with no local state (W5.21).
@riverpod
class SchedulerGroupedView extends _$SchedulerGroupedView {
  @override
  bool build() => false;

  void toggle() => state = !state;
}

class SchedulerTaskSectionNotifier extends Notifier<SchedulerTaskSection> {
  @override
  SchedulerTaskSection build() => SchedulerTaskSection.all;

  void setSection(SchedulerTaskSection section) => state = section;

  void reset() => state = SchedulerTaskSection.all;
}

/// Provides the current UTC date/time. Override in tests to control time.
@riverpod
DateTime clock(Ref ref) => DateTimeFactory.nowUtc();

/// Curricula on the active profile whose goal is COARSE-paced (daf/perek/seif).
/// Drives daf-grouping of the daily list and daf labels on task cards.
@riverpod
Future<Set<CurriculumId>> coarsePacedTrackIds(Ref ref) async {
  final activeCurricula = await ref
      .watch(curriculumActivationServiceProvider)
      .getActiveCurricula();
  final goalRepository = ref.watch(goalRepositoryProvider);
  final result = <CurriculumId>{};
  for (final curriculum in activeCurricula) {
    final goals = await goalRepository.getGoals(curriculum);
    final goal = goals.firstOrNull;
    if (goal?.paceGranularity != null) result.add(curriculum);
  }
  return result;
}

/// Collapse same-(track, coarse-unit, stage) leaf tasks into ONE representative
/// (the first amud of the daf) for COARSE-paced tracks, so the daily list shows
/// one card per daf — not one per amud. Tasks on other (fine-paced) tracks pass
/// through unchanged. Pure and order-preserving.
List<DailyTask> collapseDafTasks(
  List<DailyTask> tasks, {
  required Set<CurriculumId> coarsePacedTrackIds,
  required ContentIndex index,
}) {
  final seen = <String>{};
  final out = <DailyTask>[];
  for (final t in tasks) {
    if (!coarsePacedTrackIds.contains(t.curriculumId)) {
      out.add(t);
      continue;
    }
    // AUD-core-content-06: route through ProgramRefResolver's shared
    // whitespace/transliteration normalization (FR16) instead of a bare
    // ContentIndex.lookup, so a daf whose stored ref has a stray-whitespace
    // variant still groups with its sibling amudim.
    final item = ProgramRefResolver.lookupWithVariants(
      index,
      t.contentItemSefariaRef,
    );
    final dafKey = item == null
        ? t.contentItemSefariaRef
        : coarseUnitKeyForItem(item);
    // Keep stage in the key so a daf's Learn task and its Chazara task stay
    // separate cards (only same-daf same-stage amudim collapse).
    if (seen.add('${t.curriculumId}|$dafKey|${t.stageOrder}')) out.add(t);
  }
  return out;
}

@riverpod
SchedulerEngine schedulerEngine(Ref ref) {
  // Use scope-aware content: returns scoped content if scopes are set,
  // otherwise returns full curriculum content.
  Future<List<ContentItem>> getScopedContent(CurriculumId curriculumId) async {
    return ref.read(scopedCurriculumContentProvider(curriculumId).future);
  }

  return SchedulerEngine(
    contentRepository: SchedulerContentRepositoryImpl(
      getContent: getScopedContent,
    ),
    completionRepository: SchedulerFirestoreCompletionRepositoryAdapter(
      ref: ref,
    ),
    stageRepository: SchedulerStageRepositoryImpl(
      stageRepository: ref.watch(globalStageRepositoryProvider),
    ),
    // F2-parallel fix: the custom-order WRITER moved to Firestore
    // (`learningOrderRepositoryProvider` → `FirestoreLearningOrderRepositoryAdapter`),
    // so the scheduler's reader must resolve the same document tree instead
    // of the now-frozen Drift `learning_order` table — see
    // `SchedulerFirestoreLearningOrderRepositoryAdapter`'s class doc comment
    // for the full defect and the not-ready-read decision.
    learningOrderRepository: SchedulerFirestoreLearningOrderRepositoryAdapter(
      ref: ref,
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
  required String trackLabel,
  DateTime? goalDeadline,
}) async {
  final engine = ref.watch(schedulerEngineProvider);
  final config = ScheduleConfig(
    curriculumId: curriculumId,
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
  /// The in-flight (or settled) [_loadFromPrefs] load kicked off by [build].
  /// Captured so tests can await it deterministically instead of guessing a
  /// fixed delay — see [debugReadyForTest].
  Future<void>? _loadFuture;

  @override
  Set<String> build() {
    _loadFuture = _loadFromPrefs();
    return {};
  }

  /// Resolves once the initial prefs load kicked off by [build] has
  /// settled — i.e. [state] reflects persisted data (or the empty/reset
  /// default) rather than the transient `{}` [build] returns synchronously.
  ///
  /// Tests await this instead of a fixed `Future.delayed` guess to
  /// synchronize with the async `_loadFromPrefs()` call (AUD-t-scheduler-03,
  /// TQ-6: hermetic tests never rely on wall-clock timing).
  @visibleForTesting
  Future<void> get debugReadyForTest => _loadFuture ?? Future<void>.value();

  Future<void> _loadFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // SM-4: the provider may have been disposed (e.g. the user navigated
      // off the Scheduler screen) while the await above was in flight —
      // return early instead of touching `ref`/`state` on an unmounted Ref
      // (AUD-scheduler-10).
      if (!ref.mounted) return;
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
        // SM-4: three more awaits happened since the guard above — re-check
        // before this second `state = ...` touch.
        if (!ref.mounted) return;
        state = {};
      }
    } catch (e, st) {
      AppLogger.instance.error(
        event: 'Failed to load skipped tasks',
        exception: e,
        stackTrace: st,
      );
    }
  }

  Future<void> skip(String sefariaRef) async {
    final previous = state;
    state = {...state, sefariaRef};
    // AUD-core-preferences-04 (EH-2): guard the write so a failure logs +
    // rolls back state instead of leaving the skip silently unpersisted
    // (the dismissed task would reappear next launch with no explanation).
    await guardedPersist(
      event: 'skipped_tasks_skip_persist_failed',
      write: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_skippedRefsKey, state.toList());
      },
      onFailure: () => state = previous,
    );
  }

  Future<void> undoSkip(String sefariaRef) async {
    final previous = state;
    state = {...state}..remove(sefariaRef);
    // AUD-core-preferences-04 (EH-2): see [skip].
    await guardedPersist(
      event: 'skipped_tasks_undo_skip_persist_failed',
      write: () async {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setStringList(_skippedRefsKey, state.toList());
      },
      onFailure: () => state = previous,
    );
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
  final now = ref.watch(clockProvider);

  // Rule-7 (no track types): all tracks are implicitly personal now, so the
  // `trackType == personal` filter was a no-op that could wrongly drop rows.
  // Use every completion for the rolling-average daily counts.
  final completionRepository = SchedulerFirestoreCompletionRepositoryAdapter(
    ref: ref,
  );
  final allCompletions = await completionRepository.getCompletions(
    curriculumId,
  );

  // Build daily completion counts for rolling average
  final dailyCounts = <DateTime, int>{};
  for (final c in allCompletions) {
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
      completedItems: allCompletions.length,
      dailyCompletionCounts: dailyCounts,
      today: now,
    );
  }

  if (goalDeadline == null) return null;

  return PaceCalculator.calculate(
    goalStartDate: goalStartDate,
    goalDeadline: goalDeadline,
    totalItems: totalItems,
    completedItems: allCompletions.length,
    dailyCompletionCounts: dailyCounts,
    today: now,
  );
}

/// Repository that snapshots today's plan to DB so completions don't
/// trigger regeneration.
@riverpod
DailyPlanRepository dailyPlanRepository(Ref ref) {
  return DailyPlanRepository();
}

/// All daily tasks across active curricula.
///
/// The projection (pure overdue/today computation from synced inputs) is
/// authoritative.  Every self-paced track is required by the setup UI to
/// carry an explicit pace; the projection's API enforces it
/// (`MissingPaceError`).
///
/// daily_plans is used as a write-through cache for chazara tasks produced
/// by the engine (review items that require stage-completion timing data the
/// pure projection does not compute).  The overdue/today buckets are NEVER
/// read from daily_plans.isOverdue — they come solely from the projection.
///
/// Skipped-task filtering and previously-skipped priority boosting are
/// applied at read time.
/// Thrown by [allDailyTasksProvider] when there is no active profile.
///
/// The daily task list is achievement-shaped (D-E): an empty list would
/// read as "nothing scheduled today", indistinguishable from a learner
/// with a genuinely empty plan. There is no legitimate "no active profile"
/// empty state to fabricate here — every dependency this provider reads is
/// scoped to the active profile.
class SchedulerNoActiveProfileException implements Exception {
  const SchedulerNoActiveProfileException();

  @override
  String toString() =>
      'SchedulerNoActiveProfileException: allDailyTasks was read with no '
      'active profile — the daily task list is scoped to the active '
      'profile and there is nothing to compute without one.';
}

@riverpod
Future<List<DailyTask>> allDailyTasks(Ref ref) async {
  ref.watch<int>(completionCommittedProvider);
  final generator = ref.watch(dailyTaskGeneratorProvider);
  final planRepo = ref.watch(dailyPlanRepositoryProvider);
  // Capture future synchronously (before first await) to satisfy the
  // "all ref reads before first await" rule; await below after all deps.
  final calendarServiceFuture = ref.watch(
    calendarProgramServiceProvider.future,
  );
  final skipped = ref.watch(skippedTasksProvider);
  final previouslySkipped = await ref.watch(
    previouslySkippedRefsProvider.future,
  );
  // Await calendarService before reading globalStageRepositoryProvider so
  // that if the calendar service is in error state (content DB not yet
  // extracted, or not overridden in tests) we fail fast here and never
  // evaluate globalStageRepositoryProvider — which transitively reaches
  // syncWriteFacadeProvider → authStateProvider → Firebase.  Deferring
  // this read past an await is intentional: we accept no reactive
  // re-run on stageRepository changes (its value is stable per session).
  final calendarService = await calendarServiceFuture;

  final profileId = ref.watch(activeProfileIdProvider);
  if (profileId == null) {
    throw const SchedulerNoActiveProfileException();
  }
  final now = ref.watch(clockProvider);

  final engine = ref.watch(schedulerEngineProvider);
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final activeCurricula = await ref
      .watch(curriculumActivationServiceProvider)
      .getActiveCurricula();
  final activeTracks = await ref.watch(activeTracksProvider.future);
  final completionRepository = SchedulerFirestoreCompletionRepositoryAdapter(
    ref: ref,
  );
  final profileProgramRepository = FirestoreProfileProgramRepositoryAdapter(
    ref: ref,
  );
  final goalRepository = ref.watch(goalRepositoryProvider);
  final studyDayReader = FirestoreStudyDayReaderAdapter(ref: ref);

  // ── Step 1: derive overdue/today via the pure projection ─────────────────
  //
  // The projection is the authoritative source of truth for the overdue and
  // today buckets (architecture §4).  It is re-derived on demand from
  // synced inputs and is never persisted as a flag.
  // AUD-scheduler-12: buildProjectionTasks/buildFreshPlan take no Ref — their
  // one Riverpod dependency (the track display label) is injected as a plain
  // callback, matching getScopedContent/programRepository below.
  String trackLabelFor(CurriculumId curriculum) =>
      curriculumLabelTextFromRef(ref, curriculum: curriculum);

  final projectionTasks = await buildProjectionTasks(
    trackLabelFor: trackLabelFor,
    activeCurricula: activeCurricula,
    activeTracks: activeTracks,
    completionRepository: completionRepository,
    profileProgramRepository: profileProgramRepository,
    goalRepository: goalRepository,
    studyDayReader: studyDayReader,
    stageRepository: stageRepository,
    engine: engine,
    now: now,
    calendarService: calendarService,
    getScopedContent: (curriculumId) =>
        ref.read(scopedCurriculumContentProvider(curriculumId).future),
    programRepository: ref.read(learningProgramRepositoryProvider),
  );

  // ── Step 2: engine-generated chazara/review tasks ─────────────────────
  //
  // The pure projection leaves review empty (it requires stage-completion
  // timing).  Continue generating those via the engine's snapshot path and
  // merge them with the projection output.  The snapshot is still used as
  // a cache so chazara items are not recomputed on every read within a day.
  final planResult = await planRepo.getOrSnapshotPlan(
    profileId: profileId,
    now: now,
    buildPlan: () => buildFreshPlan(
      trackLabelFor: trackLabelFor,
      activeCurricula: activeCurricula,
      activeTracks: activeTracks,
      goalRepository: goalRepository,
      profileProgramRepository: profileProgramRepository,
      studyDayReader: studyDayReader,
      stageRepository: stageRepository,
      generator: generator,
      engine: engine,
      now: now,
      calendarService: calendarService,
      getScopedContent: (curriculumId) =>
          ref.read(scopedCurriculumContentProvider(curriculumId).future),
      programRepository: ref.read(learningProgramRepositoryProvider),
    ),
  );

  // Extract only the chazara/review tasks from the snapshot — the
  // overdue/today tasks from the snapshot are discarded; the projection
  // owns those buckets.
  final chazaraTasks = planResult.tasks
      .where(
        (t) =>
            t.priority == DailyTaskPriority.overdueChazara ||
            t.priority == DailyTaskPriority.scheduledChazara,
      )
      .toList();

  // Merge: projection tasks (overdue + today) + chazara from engine.
  final effectiveTasks = [...projectionTasks, ...chazaraTasks];

  // ── Step 3: completion filtering ─────────────────────────────────────────
  final taskCurricula = effectiveTasks.map((t) => t.curriculumId).toSet();
  final completionsByCurriculum = <CurriculumId, List<SchedulerCompletion>>{
    for (final curriculum in taskCurricula)
      curriculum: await completionRepository.getCompletions(curriculum),
  };
  bool isTaskCompleted(DailyTask task) {
    final completions = completionsByCurriculum[task.curriculumId] ?? const [];
    return completions.any((c) {
      if (c.sefariaRef != task.contentItemSefariaRef) return false;
      // Sentinel completions (bulk-prior mark, completedAt = 2000-01-01) are
      // not genuine study sessions. They must NOT filter today's new-learning
      // tasks — the user still needs to study these items. (F5)
      if (c.completedAt.millisecondsSinceEpoch ==
          SchedulerEngine.kBulkPriorSentinelMs)
        return false;
      return c.stageOrder == task.stageOrder;
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

/// Overdue task count for a single curriculum.
///
/// Reads from [allDailyTasksProvider] and filters by [curriculumId] +
/// [isOverdue].  Used by the reorder-confirm dialog to show the user how many
/// overdue items would be amnestied (architecture §10.1 / reorder-amnesty).
@riverpod
Future<int> overdueCountForCurriculum(
  Ref ref,
  CurriculumId curriculumId,
) async {
  final tasks = await ref.watch(allDailyTasksProvider.future);
  return tasks
      .where((t) => t.curriculumId == curriculumId && t.isOverdue)
      .length;
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
  required CurriculumId curriculumId,
  required TrackTaskCategory category,
}) async {
  final all = await ref.watch(allDailyTasksProvider.future);
  final forTrack = all.where((t) => t.curriculumId == curriculumId);

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
