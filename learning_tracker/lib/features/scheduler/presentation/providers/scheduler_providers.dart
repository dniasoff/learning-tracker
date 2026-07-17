import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/content/program_ref_resolver.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/pace_derivation.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_writer_providers.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_completion_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_content_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_learning_order_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/scheduler_stage_repository_impl.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
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

/// Track ids on the active profile whose goal is COARSE-paced (daf/perek/seif).
/// Drives daf-grouping of the daily list and daf labels on task cards.
@riverpod
Future<Set<int>> coarsePacedTrackIds(Ref ref) async {
  final profileId = ref.watch(activeProfileIdProvider);
  final goals = await ref
      .watch(userDatabaseProvider)
      .goalDao
      .getGoalsByProfile(profileId);
  return {
    for (final g in goals)
      if (PaceGranularity.fromStorageKey(g.paceGranularity) != null) g.trackId,
  };
}

/// Collapse same-(track, coarse-unit, stage) leaf tasks into ONE representative
/// (the first amud of the daf) for COARSE-paced tracks, so the daily list shows
/// one card per daf — not one per amud. Tasks on other (fine-paced) tracks pass
/// through unchanged. Pure and order-preserving.
List<DailyTask> collapseDafTasks(
  List<DailyTask> tasks, {
  required Set<int> coarsePacedTrackIds,
  required ContentIndex index,
}) {
  final seen = <String>{};
  final out = <DailyTask>[];
  for (final t in tasks) {
    if (!coarsePacedTrackIds.contains(t.trackId)) {
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
    if (seen.add('${t.trackId}|$dafKey|${t.stageOrder}')) out.add(t);
  }
  return out;
}

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
      profileId: profileId,
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
      AppLogger.instance.error(
        event: 'Failed to load skipped tasks',
        exception: e,
        stackTrace: st,
      );
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

  // Rule-7 (no track types): all tracks are implicitly personal now, so the
  // `trackType == personal` filter was a no-op that could wrongly drop rows.
  // Use every completion for the rolling-average daily counts.
  final allCompletions = await db.completionDao
      .getCompletionsByCurriculumAndProfile(curriculumId.storageKey, profileId);

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
  final db = ref.watch(userDatabaseProvider);
  return DailyPlanRepository(db);
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
@riverpod
Future<List<DailyTask>> allDailyTasks(Ref ref) async {
  ref.watch<int>(completionCommittedProvider);
  final db = ref.watch(userDatabaseProvider);
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
  final now = ref.watch(clockProvider);

  final engine = ref.watch(schedulerEngineProvider);
  final stageRepository = ref.watch(globalStageRepositoryProvider);

  // ── Step 1: derive overdue/today via the pure projection ─────────────────
  //
  // The projection is the authoritative source of truth for the overdue and
  // today buckets (architecture §4).  It is re-derived on demand from
  // synced inputs and is never persisted as a flag.
  final projectionTasks = await _buildProjectionTasks(
    ref: ref,
    db: db,
    stageRepository: stageRepository,
    engine: engine,
    profileId: profileId,
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
    buildPlan: () => _buildFreshPlan(
      ref: ref,
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

/// Returns the day-level amnesty cutoff for [lastReorderAt]: midnight of
/// the device-local date on which the reorder occurred, encoded as pseudo-UTC
/// midnight (the same encoding [ScheduledUnit.date] uses).
///
/// Schedule entries are dated to UTC midnight of the unit's local day, while
/// `lastReorderAt` is a real instant (e.g. activation at 15:00 UTC).  A naive
/// `scheduledDate.isBefore(lastReorderAt)` would treat same-day schedule
/// entries as "before" the reorder and amnesty them — wiping today's overdue
/// for a track activated yesterday.  The amnesty rule (§10.1) is "items
/// scheduled on days strictly before the day of the reorder", so we normalize
/// to midnight of the device-local date here.
DateTime _amnestyDayCutoffUtc(DateTime lastReorderAt) {
  final local = lastReorderAt.toLocal();
  return DateTime.utc(local.year, local.month, local.day);
}

/// Derives the overdue and dueToday task lists from the pure projection.
///
/// This is the authoritative source of truth for the overdue/today buckets
/// (architecture §4).  It reads only synced inputs (profile_programs,
/// curriculum_tracks, completions, study_day_config) and never persists
/// any result.
///
/// Every self-paced track is required by the setup UI to carry an explicit
/// pace; the projection enforces it via [MissingPaceError]
/// (architecture §10.3).
Future<List<DailyTask>> _buildProjectionTasks({
  required Ref ref,
  required UserDatabase db,
  required StageDefinitionRepository stageRepository,
  required SchedulerEngine engine,
  required int profileId,
  required DateTime now,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
  required LearningProgramRepository programRepository,
}) async {
  final activeKeys = await db.activeCurriculumDao.getActiveCurriculaByProfile(
    profileId,
  );
  final activeCurricula = <CurriculumId>[
    for (final key in activeKeys)
      ...CurriculumId.values.where((c) => c.storageKey == key).take(1),
  ];

  final activeTracks = await db.trackDao.getActiveTracksForProfile(profileId);
  final trackIds = <CurriculumId, int>{};
  final trackLabels = <CurriculumId, String>{};
  final trackStartedAtMap = <CurriculumId, DateTime>{};
  // §10.1 / reorder-amnesty: the projection filters out overdue items whose
  // scheduled date is strictly before the most-recent reorder timestamp.
  // Null lastReorderAt (rows created before this column was added) is treated
  // as epoch 0 — no historic tasks are amnestied.
  final trackLastReorderAtMap = <CurriculumId, DateTime>{};
  for (final curriculum in activeCurricula) {
    final tracksForCurriculum = activeTracks
        .where((t) => t.curriculumId == curriculum.storageKey)
        .toList();
    if (tracksForCurriculum.isEmpty) continue;
    // W3.22: trackType dropped — one track per curriculum per profile.
    final preferred = tracksForCurriculum.first;
    trackIds[curriculum] = preferred.id;
    // Rule-7 (no track types): the track label is the curriculum's localized
    // display name (never an internal track storage key like "personal").
    trackLabels[curriculum] = curriculumLabelTextFromRef(
      ref,
      curriculum: curriculum,
    );
    trackStartedAtMap[curriculum] = preferred.activatedAt;
    trackLastReorderAtMap[curriculum] =
        preferred.lastReorderAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  final todayDate = LocalDayUtils.extractLocalDate(now);
  final result = <DailyTask>[];

  for (final curriculum in activeCurricula) {
    final trackId = trackIds[curriculum];
    if (trackId == null) continue;

    final stages = await stageRepository.getStagesByTrack(trackId);
    if (stages.isEmpty) continue;
    final firstStage = stages.reduce(
      (domain_stage.StageDefinition a, domain_stage.StageDefinition b) =>
          a.stageOrder < b.stageOrder ? a : b,
    );

    // ── Fetch all completions for this track ─────────────────────────────
    // F-H4: filter to first-stage completions only.  A chazara-stage
    // completion for ref X must NOT mask an unlearned ref X in the
    // projection's overdue set; only a first-stage (learn) completion counts.
    //
    // The OR accepts both stage-reference formats live in the codebase: the
    // legacy completion path writes stage_definitions.id (autoincrement FK)
    // and the newer path writes stageOrder (1, 2, 3…). Completion rows are
    // already scoped to this curriculum + profile, so cross-curriculum
    // contamination is excluded. A narrow edge remains within a curriculum
    // if stage_definitions.id coincidentally equals another stage's
    // stageOrder — flagged for a future migration to a single canonical
    // stage reference.
    final allCompletions = await db.completionDao
        .getCompletionsByCurriculumAndProfile(curriculum.storageKey, profileId);
    final completionRefs = allCompletions
        .where(
          (c) =>
              c.stageId == firstStage.id || c.stageId == firstStage.stageOrder,
        )
        .map((c) => c.sefariaRef)
        .toSet();

    // ── Program track path ────────────────────────────────────────────────
    final enrollment = await db.profileProgramDao
        .getProgramForProfileAndCurriculum(profileId, curriculum.storageKey);

    if (enrollment != null) {
      final program = programRepository.getProgramById(enrollment.programId);
      final apiKey = program?.apiProgramKey;
      if (program != null && apiKey != null && apiKey.isNotEmpty) {
        final programKey =
            CalendarProgramRegistry.byId(apiKey)?.id ??
            CalendarProgramRegistry.byApiKey(apiKey)?.id ??
            CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;

        if (programKey != null) {
          // Resolve the anchor date from the enrollment.
          final DateTime anchor;
          if (enrollment.trackingStartDate == null) {
            anchor = todayDate;
          } else {
            final anchorUtc = enrollment.trackingStartDate!;
            if (anchorUtc.isBefore(DateTime.utc(2020, 1, 1))) {
              anchor = todayDate;
            } else {
              anchor = LocalDayUtils.extractLocalDate(anchorUtc);
            }
          }

          // Future anchors: no tasks yet.
          if (!anchor.isAfter(todayDate)) {
            final entries = await programCalendarSchedule(
              programKey: programKey,
              anchor: anchor,
              today: todayDate,
              calendarService: calendarService,
            );

            if (entries.isNotEmpty) {
              final contentItems = await getScopedContent(curriculum);
              // Build calendarEntries in the format programSchedule() expects.
              // F-H2: use the entry's own date field instead of a sequential
              // cursor walk.  For weekly programs the DB has one row per week
              // (not per day), so the cursor walk mis-dates every entry after
              // the first.  entry.date is populated from the DB's date_key
              // column by LocalCalendarEngine and reflects the true calendar
              // date, regardless of cadence.
              final calendarEntries = <(DateTime, String)>[];
              // Index each day's English ref → seed-sourced day-level labels.
              // The projection emits English refs (e.g. "Chullin 25"); this
              // lets us re-attach the collapsed, type-aware unit name
              // (todayRefHe / displayNameEn) to the generated DailyTask so the
              // dashboard card renders one daf, not one amud breadcrumb.
              final dayLabelByRef = <String, ({String? he, String? en})>{};
              for (final entry in entries) {
                final entryDate = entry.date;
                assert(
                  entryDate != null,
                  'CalendarProgramEntry.date must be populated by '
                  'LocalCalendarEngine; got null for ref ${entry.todayRef}',
                );
                if (entryDate == null) continue;
                calendarEntries.add((entryDate, entry.todayRef));
                dayLabelByRef[entry.todayRef] = (
                  he: entry.todayRefHe.isEmpty ? null : entry.todayRefHe,
                  en: entry.todayRef.isEmpty
                      ? null
                      : displayProgramRef(entry.todayRef),
                );
              }

              final schedule = programSchedule(
                anchor: anchor,
                calendarEntries: calendarEntries,
                today: todayDate,
              );

              final projection = project(
                schedule: schedule,
                completions: completionRefs,
                today: todayDate,
              );

              // Reorder-amnesty filter: build ref→scheduledDate index.
              final progLastReorderAt =
                  trackLastReorderAtMap[curriculum] ??
                  DateTime.fromMillisecondsSinceEpoch(0);
              // Day-level cutoff: midnight of the device-local date on which
              // the reorder happened, encoded as pseudo-UTC midnight (the same
              // encoding schedule entries use). Without this, a mid-day
              // lastReorderAt (e.g. track activation at 15:00 UTC) is wrongly
              // treated as "after" same-day schedule entries (00:00 UTC), and
              // those entries get silently amnestied even though the user
              // still owes that day's work.
              final rawAmnestyCutoff = _amnestyDayCutoffUtc(progLastReorderAt);
              // Back-date fix: a freshly-enrolled program track has
              // lastReorderAt == creation day (today) while its anchor
              // (trackingStartDate) is in the past. The raw cutoff would then
              // amnesty the ENTIRE intended back-date window — every
              // back-dated daf scheduled before today gets silently stripped,
              // so a track started "4 days behind" shows no overdue. Programs
              // are calendar-anchored (never user-reordered), so clamp the
              // cutoff to the anchor: overdue on/after trackingStartDate is
              // never amnestied, while a genuine re-anchor (anchor == today)
              // still yields no spurious overdue.
              final progAmnestyCutoff = rawAmnestyCutoff.isAfter(anchor)
                  ? anchor
                  : rawAmnestyCutoff;
              final progScheduleIndex = <String, DateTime>{
                for (final unit in schedule) unit.sefariaRef: unit.date,
              };

              // Map projection refs to DailyTask objects.
              for (final ref in projection.overdue) {
                // Amnesty: skip overdue items scheduled on a day strictly
                // before the day of the last reorder.
                final scheduledDate = progScheduleIndex[ref];
                if (scheduledDate != null &&
                    scheduledDate.isBefore(progAmnestyCutoff)) {
                  continue;
                }
                final dayLabel = dayLabelByRef[ref];
                final taskRefs = resolvedOrFallbackProgramRefs(
                  todayRef: ref,
                  contentItems: contentItems,
                );
                for (final taskRef in taskRefs.isEmpty ? [ref] : taskRefs) {
                  result.add(
                    DailyTask(
                      curriculumId: curriculum,
                      contentItemSefariaRef: taskRef,
                      stageOrder: firstStage.stageOrder,
                      stageDefinitionId: firstStage.id,
                      priority: DailyTaskPriority.overdueProgram,
                      isOverdue: true,
                      reason: 'Program day pending from previous days',
                      stageName: firstStage.stageName,
                      trackId: trackId,
                      trackLabel: trackLabels[curriculum] ?? '',
                      estimatedEffortMinutes: 5,
                      unitDisplayHe: dayLabel?.he,
                      unitDisplayEn: dayLabel?.en,
                    ),
                  );
                }
              }

              for (final ref in projection.dueToday) {
                final dayLabel = dayLabelByRef[ref];
                final taskRefs = resolvedOrFallbackProgramRefs(
                  todayRef: ref,
                  contentItems: contentItems,
                );
                for (final taskRef in taskRefs.isEmpty ? [ref] : taskRefs) {
                  result.add(
                    DailyTask(
                      curriculumId: curriculum,
                      contentItemSefariaRef: taskRef,
                      stageOrder: firstStage.stageOrder,
                      stageDefinitionId: firstStage.id,
                      priority: DailyTaskPriority.todayProgram,
                      isOverdue: false,
                      reason: 'Program assignment for today',
                      stageName: firstStage.stageName,
                      trackId: trackId,
                      trackLabel: trackLabels[curriculum] ?? '',
                      estimatedEffortMinutes: 5,
                      unitDisplayHe: dayLabel?.he,
                      unitDisplayEn: dayLabel?.en,
                    ),
                  );
                }
              }
            }
          }
          continue; // program track handled — skip the self-paced path.
        }
      }
    }

    // ── Self-paced track path ─────────────────────────────────────────────
    final startedAt = trackStartedAtMap[curriculum];
    if (startedAt == null) continue;

    // Fetch the goal. Prefer an explicit pace; fall back to deriving one from
    // the deadline + scope + study-day density so a deadline-only goal still
    // emits today's tasks instead of being skipped. Older deadline goals
    // (written before F-M2 saved an explicit pace) and anything else where
    // pace fields are null but a target date exists land in the fallback.
    final goal = await db.goalDao.getGoalByTrack(trackId);
    if (goal == null) continue;

    // Fetch ordered curriculum refs via the engine (which respects the
    // content repository and scoped overrides — the same path used by the
    // snapshot builder).
    final orderedItems = await engine.getOrderedLeafItems(curriculum);
    final orderedRefs = orderedItems.map((i) => i.sefariaRef).toList();

    var paceValue = goal.paceValue;
    var pacePeriod = goal.pacePeriod;
    if ((paceValue == null || pacePeriod == null) &&
        goal.goalType == 'deadline' &&
        goal.targetDate != null) {
      // Use the injected clock (todayDate), not the wall clock: this
      // function's "today" must track clockProvider so it stays hermetic
      // under test (TQ-6) — reading DateTimeFactory.nowLocal() directly
      // silently drifted from the test-overridden clock and made deadline
      // derivation skip (and the track go silently unscheduled) once real
      // wall-clock time advanced past a test's fixed target date.
      final startLocal = todayDate;
      final endLocal = LocalDayUtils.extractLocalDate(
        goal.targetDate!.toLocal(),
      );
      if (!endLocal.isBefore(startLocal)) {
        final studyDaysInWindow = await db.studyDayConfigDao
            .countStudyDaysInInclusiveDateRangeForTrack(
              trackId: trackId,
              startInclusive: startLocal,
              endInclusive: endLocal,
            );
        final studyDaysPerWeek = await db.studyDayConfigDao
            .getStudyDaysPerWeekForTrack(trackId: trackId);
        final derived = derivePaceFromDeadline(
          totalScopeItems: orderedItems.length,
          studyDaysInWindow: studyDaysInWindow,
          studyDaysPerWeek: studyDaysPerWeek,
        );
        paceValue = derived.paceValue;
        pacePeriod = derived.pacePeriod;
      }
    }
    if (paceValue == null || pacePeriod == null) continue;

    // Fetch study-day pattern.
    //
    // Disambiguate "no config" (default = study every day) from "config exists
    // but ZERO study days" (every day toggled to review). The projection's
    // StudyDayPattern treats an EMPTY weekday set as "study every day", so
    // passing {} for an all-review config would collapse to all-study and
    // schedule brand-new learning on days the user explicitly marked
    // review-only — disagreeing with isStudyDayForTrack (which correctly
    // reports those days are NOT study days). When rows exist but none are
    // 'study', skip new-learning scheduling entirely for this track.
    final studyConfigs = await db.studyDayConfigDao.getConfigsByTrack(trackId);
    final studyWeekdays = <int>{
      for (final c in studyConfigs)
        if (c.dayType == 'study') c.dayOfWeek,
    };
    if (studyConfigs.isNotEmpty && studyWeekdays.isEmpty) {
      // Genuine zero-study-day pattern: the user marked every day review-only.
      // Schedule no new learning (no overdue, no due-today) for this track.
      continue;
    }
    final pattern = StudyDayPattern(studyWeekdays);

    // B2: a weekly pace = paceValue units per WEEK, spread across that week's
    // study days — NOT 1 unit per study day. Pass the window so
    // selfPacedSchedule accrues paceValue units per studyDaysPerWeek study days.
    // (paceToDaily(per_week)=paceValue/7 was previously ceil'd to 1, inflating
    // any sub-8 weekly pace to ~1/study-day and flooding the overdue queue.)
    final studyDaysPerWeek = studyWeekdays.isEmpty ? 7 : studyWeekdays.length;
    final paceWindowStudyDays = pacePeriod == 'per_week' ? studyDaysPerWeek : 1;

    final anchor = LocalDayUtils.extractLocalDate(startedAt);

    // Items completed strictly before the track's anchor date are "prior
    // completions" — e.g. bulk Mark-Prior-Completions rows, which carry a
    // placeholder completedAt (Jan 1 2000). They must NOT consume schedule
    // slots: selfPacedSchedule walks orderedRefs from index 0, so a track
    // created today with N prior completions would schedule N already-done
    // refs for today, project() would strip them, and the queue would show
    // nothing due for the next N / pace study days (the Mishnayot
    // ghost-track bug). Walk the schedule over only the refs NOT yet
    // completed before the anchor, so the first genuinely-unlearned ref lands
    // on the anchor day. Completions made ON OR AFTER the anchor stay in the
    // schedule and are handled by project() as normal on-pace progress.
    // NOTE: using isBefore (not !isAfter) so that same-day completions (when
    // the track was started and tasks completed on the same calendar day)
    // remain in the schedule and are correctly counted as done by project().
    final priorCompletionRefs = allCompletions
        .where(
          (c) =>
              (c.stageId == firstStage.id ||
                  c.stageId == firstStage.stageOrder) &&
              LocalDayUtils.extractLocalDate(c.completedAt).isBefore(anchor),
        )
        .map((c) => c.sefariaRef)
        .toSet();
    final scheduleRefs = priorCompletionRefs.isEmpty
        ? orderedRefs
        : orderedRefs.where((r) => !priorCompletionRefs.contains(r)).toList();

    final schedule = selfPacedSchedule(
      anchor: anchor,
      pace: paceValue,
      paceWindowStudyDays: paceWindowStudyDays,
      studyDayPattern: pattern,
      orderedRefs: scheduleRefs,
      today: todayDate,
    );

    final projection = project(
      schedule: schedule,
      completions: completionRefs,
      today: todayDate,
    );

    // Reorder-amnesty filter (§10.1): build a ref→scheduledDate index so we
    // can drop overdue items whose scheduled date is on a day strictly before
    // the day of the track's lastReorderAt.  Items scheduled on the same
    // device-local day as the reorder are never amnestied — the user still
    // owes that day's work regardless of any mid-day reorder.
    final lastReorderAt =
        trackLastReorderAtMap[curriculum] ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final amnestyCutoff = _amnestyDayCutoffUtc(lastReorderAt);
    final scheduleIndex = <String, DateTime>{
      for (final unit in schedule) unit.sefariaRef: unit.date,
    };

    for (final ref in projection.overdue) {
      final scheduledDate = scheduleIndex[ref];
      // Amnesty: skip overdue items whose scheduled date is on a day strictly
      // before the day of the most recent reorder.  Items with no schedule
      // entry (shouldn't happen) are kept to avoid silently dropping tasks.
      if (scheduledDate != null && scheduledDate.isBefore(amnestyCutoff)) {
        continue;
      }
      result.add(
        DailyTask(
          curriculumId: curriculum,
          contentItemSefariaRef: ref,
          stageOrder: firstStage.stageOrder,
          stageDefinitionId: firstStage.id,
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          reason: 'Behind pace',
          stageName: firstStage.stageName,
          trackId: trackId,
          trackLabel: trackLabels[curriculum] ?? '',
          estimatedEffortMinutes: 5,
        ),
      );
    }

    for (final ref in projection.dueToday) {
      result.add(
        DailyTask(
          curriculumId: curriculum,
          contentItemSefariaRef: ref,
          stageOrder: firstStage.stageOrder,
          stageDefinitionId: firstStage.id,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'Due today',
          stageName: firstStage.stageName,
          trackId: trackId,
          trackLabel: trackLabels[curriculum] ?? '',
          estimatedEffortMinutes: 5,
        ),
      );
    }
  }

  return result;
}

/// Runs the scheduler across all active curricula to produce a fresh plan.
/// Called only when no snapshot exists for the current local day.
Future<List<DailyTask>> _buildFreshPlan({
  required Ref ref,
  required UserDatabase db,
  required StageDefinitionRepository stageRepository,
  required DailyTaskGenerator generator,
  required SchedulerEngine engine,
  required DailyPlanRepository planRepo,
  required int profileId,
  required DateTime now,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
  required LearningProgramRepository programRepository,
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
    // W3.22: trackType dropped — one track per curriculum per profile.
    final preferred = tracksForCurriculum.first;
    trackIds[curriculum] = preferred.id;
    // Rule-7 (no track types): the track label is the curriculum's localized
    // display name (never an internal track storage key like "personal").
    trackLabels[curriculum] = curriculumLabelTextFromRef(
      ref,
      curriculum: curriculum,
    );
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

  // _buildFreshPlan now generates chazara/review tasks only — overdue and
  // today are owned by the pure projection (_buildProjectionTasks / project).
  // The backfill machinery (backfillMissingSnapshots / backfillStudyDaySnapshots
  // / kDefaultBackfillPace / effectivePaceOverrideMap) has been deleted:
  // the schedule function spans missed days intrinsically (architecture §11 step 4).
  final generated = await generator.generateAll(
    activeCurricula,
    now,
    goalDeadlines: goalDeadlines,
    pacePerDayMap: pacePerDayMap,
    isStudyDayMap: isStudyDayMap,
    studyDaysPerWeekMap: studyDaysPerWeekMap,
    studyDaysInDeadlineWindowMap: studyDaysInDeadlineWindowMap,
    trackIds: trackIds,
    trackLabels: trackLabels,
    trackStartedAtMap: trackStartedAtMap,
    priorlyShownRefsMap: const {},
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
    programRepository: programRepository,
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
  // F-M1: ensure the fallback entry's date field is populated with `today`
  // so that _buildProjectionTasks classifies it correctly (dueToday, not
  // overdue) when building calendarEntries from entry.date.
  final todayEntry = await calendarService.getEntry(programKey, today);
  if (todayEntry == null) return const [];
  // If the engine already populated date, use it directly; otherwise stamp
  // today explicitly so the projection path never sees a null date.
  final entryWithDate = todayEntry.date != null
      ? todayEntry
      : CalendarProgramEntry(
          programId: todayEntry.programId,
          displayNameEn: todayEntry.displayNameEn,
          displayNameHe: todayEntry.displayNameHe,
          todayRef: todayEntry.todayRef,
          todayRefHe: todayEntry.todayRefHe,
          apiSource: todayEntry.apiSource,
          date: today,
        );
  return [entryWithDate];
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
  required LearningProgramRepository programRepository,
}) async {
  final result = List<DailyTask>.from(generated);

  for (final curriculum in activeCurricula) {
    final trackId = trackIds[curriculum];
    if (trackId == null) continue;

    final enrollment = await db.profileProgramDao
        .getProgramForProfileAndCurriculum(profileId, curriculum.storageKey);
    if (enrollment == null) continue;

    final program = programRepository.getProgramById(enrollment.programId);
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

    final todayDate = LocalDayUtils.extractLocalDate(now);
    final DateTime configuredStartDate;
    if (enrollment.trackingStartDate == null) {
      configuredStartDate = todayDate;
    } else {
      final anchorUtc = enrollment.trackingStartDate!;
      // Ignore corrupt / default-epoch anchors that would span the whole cycle.
      if (anchorUtc.isBefore(DateTime.utc(2020, 1, 1))) {
        configuredStartDate = todayDate;
      } else {
        configuredStartDate = LocalDayUtils.extractLocalDate(anchorUtc);
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

    // Diagnostic (back-date overdue investigation): surface the persisted
    // anchor + the resolved schedule so a "starting N days behind is ignored"
    // report is answerable from Send Diagnostic Logs. entries.length-1 is the
    // expected overdue count; if it's 0 the anchor wasn't back-dated (offset
    // not persisted) or the calendar range returned only today.
    AppLogger.instance.info(
      event: 'program_calendar_override',
      fields: {
        'curriculum': curriculum.storageKey,
        'trackId': trackId,
        'tracking_start_date':
            enrollment.trackingStartDate?.toIso8601String() ?? 'null',
        'tracking_start_ref': enrollment.trackingStartRef ?? 'null',
        'configured_start': configuredStartDate.toIso8601String(),
        'today': todayDate.toIso8601String(),
        'entries': entries.length,
      },
    );

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
      final unitDisplayHe = entry.todayRefHe.isEmpty ? null : entry.todayRefHe;
      final unitDisplayEn = entry.todayRef.isEmpty
          ? null
          : displayProgramRef(entry.todayRef);
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
            trackLabel: trackLabels[curriculum] ?? '',
            estimatedEffortMinutes: 5,
            unitDisplayHe: unitDisplayHe,
            unitDisplayEn: unitDisplayEn,
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
