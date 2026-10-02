import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/content/program_ref_resolver.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/calendar_providers.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/guarded_persist.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/dashboard/data/repositories/firestore_study_day_reader_adapter.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/progress/presentation/providers/learner_progress_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_scope_providers.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/profile_program_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/stages/presentation/providers/stage_providers.dart';
import 'package:learning_tracker/features/tracks/tracks.dart'
    show activeTracksProvider;
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

/// The planner's task list for civil [date] (`YYYY-MM-DD`), evaluated live
/// over the active learner's current `LearnerState` (AD-49, DNI-477): new
/// learning and calendar days, then reviews, as [buildPlannedTasks] lays
/// them out. Never persisted; it recomputes whenever the learner state
/// changes. The erev planned lists of the upcoming locked days are
/// [watchPlannedDaysAfterToday] for those dates (DNI-504).
@riverpod
Future<List<DailyTask>> plannedTasksForDate(Ref ref, String date) async {
  final inputs = await _watchPlannerInputs(ref);
  final tasks = await buildPlannedTasks(
    state: inputs.state,
    corpora: inputs.corpora,
    date: date,
    activeCurricula: inputs.activeCurricula,
    activeTracks: inputs.activeTracks,
    presentationFor: (curriculum) => inputs.presentationFor(curriculum, date),
  );
  return [...tasks.learning, ...tasks.reviews];
}

/// The planner's task lists for [lockedDates], in order, laid out in
/// sequence after today's list over the active learner's live
/// `LearnerState` (DNI-504, AD-49): each date's list is
/// [plannedTasksForDate]'s for it, less what today or an earlier date
/// already holds, and its main-track batch continues after theirs instead
/// of restarting at the same position ([buildPlannedSequence]). Watches the
/// same inputs as [plannedTasksForDate], so the calling provider recomputes
/// with them.
Future<List<List<DailyTask>>> watchPlannedDaysAfterToday(
  Ref ref,
  List<String> lockedDates,
) async {
  final inputs = await _watchPlannerInputs(ref);
  final lists = await buildPlannedSequence(
    state: inputs.state,
    corpora: inputs.corpora,
    dates: [inputs.state.today, ...lockedDates],
    activeCurricula: inputs.activeCurricula,
    activeTracks: inputs.activeTracks,
    presentationFor: inputs.presentationFor,
  );
  return lists.sublist(1);
}

/// Everything the planner reads besides the date: the live state, corpora,
/// active curricula and tracks, and a per-date presentation loader.
typedef _PlannerInputs = ({
  LearnerState state,
  Map<String, Corpus> corpora,
  List<CurriculumId> activeCurricula,
  List<CurriculumTrackEntity> activeTracks,
  Future<CurriculumTaskPresentation> Function(CurriculumId, String date)
  presentationFor,
});

Future<_PlannerInputs> _watchPlannerInputs(Ref ref) async {
  // Capture every dependency synchronously (before the first await).
  final stateFuture = watchActiveLearnerState(ref);
  final corporaFuture = watchCorpora(ref);
  final calendarServiceFuture = ref.watch(
    calendarProgramServiceProvider.future,
  );
  final activeTracksFuture = ref.watch(activeTracksProvider.future);
  final activation = ref.watch(curriculumActivationServiceProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final programRepository = ref.watch(learningProgramRepositoryProvider);
  if (profileId == null) {
    throw const SchedulerNoActiveProfileException();
  }
  // Await calendarService before reading globalStageRepositoryProvider so
  // that if the calendar service is in error state (content DB not yet
  // extracted, or not overridden in tests) we fail fast here and never
  // evaluate globalStageRepositoryProvider — which transitively reaches
  // Firebase. Its value is stable per session.
  final calendarService = await calendarServiceFuture;
  final state = await stateFuture;
  if (state == null) throw const SchedulerNoActiveProfileException();
  final corpora = await corporaFuture;
  final activeTracks = await activeTracksFuture;
  final activeCurricula = await activation.getActiveCurricula();
  final stageRepository = ref.watch(globalStageRepositoryProvider);
  final studyDays = FirestoreStudyDayReaderAdapter(ref: ref);
  final programs = FirestoreProfileProgramRepositoryAdapter(ref: ref);

  return (
    state: state,
    corpora: corpora,
    activeCurricula: activeCurricula,
    activeTracks: activeTracks,
    presentationFor: (CurriculumId curriculum, String date) =>
        loadCurriculumTaskPresentation(
          curriculum: curriculum,
          date: date,
          trackLabel: curriculumLabelTextFromRef(ref, curriculum: curriculum),
          stageRepository: stageRepository,
          studyDayConfigs: studyDays.getConfigsForCurriculum,
          profileProgramRepository: programs,
          programRepository: programRepository,
          calendarService: calendarService,
          getScopedContent: (curriculumId) =>
              ref.read(scopedCurriculumContentProvider(curriculumId).future),
        ),
  );
}

/// All daily tasks across active curricula: today's [plannedTasksForDate],
/// with read-time skip handling — skipped-today refs removed, refs skipped
/// yesterday boosted — sorted by priority.
///
/// "Today" is the learner's civil date the live `LearnerState` was derived
/// for (`LearnerState.today`: AD-41, the learner's configured `time_zone`
/// per the settings history), never the device date, so the plan, its
/// reviews and its study-day decision are the engine's day.
///
/// The planner's list already excludes what is learnt or reviewed (AD-49:
/// the engine's `schedulableRefs`, `programBacklog` and `reviewsDue` say
/// so), so there is no completion filter here.
@riverpod
Future<List<DailyTask>> allDailyTasks(Ref ref) async {
  final skipped = ref.watch(skippedTasksProvider);
  final previouslySkippedFuture = ref.watch(
    previouslySkippedRefsProvider.future,
  );
  final stateFuture = watchActiveLearnerState(ref);
  final state = await stateFuture;
  if (state == null) throw const SchedulerNoActiveProfileException();
  final tasksFuture = ref.watch(
    plannedTasksForDateProvider(state.today).future,
  );
  final previouslySkipped = await previouslySkippedFuture;
  final tasks = await tasksFuture;

  final filtered = tasks
      .where((t) => !skipped.contains(t.contentItemSefariaRef))
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
