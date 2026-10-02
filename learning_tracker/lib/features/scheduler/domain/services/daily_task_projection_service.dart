/// The planner on `LearnerState` (DNI-477, AD-49 "Planner").
///
/// The planner lays out the learner-state engine's numbers and never
/// computes one: the main track's position, current unit and
/// `schedulableRefs` up to `dailyTarget` (deadline), else `paceRate`, else
/// nothing; a calendar program's `programAssignments(date) ∪
/// programBacklog(date)`; and `reviewsDue(date)` for chazara. The engine
/// is the only implementation of order, position, targets and the review
/// schedule (AD-33, AD-35); what this file adds is task shaping — stage
/// names, track labels, calendar day labels, priorities and reasons — and
/// the FR-12a rule that a day's batch stays in one masechta except on the
/// day it finishes and the next begins.
///
/// [planCurriculumTasks] is pure. [buildPlannedTasks] plans every active
/// curriculum for one date; `plannedTasksForDateProvider` feeds it the live
/// `LearnerState`, so a planned list for any date (today, or an erev
/// locked day) is evaluated live and never persisted.
///
/// Retired here (AD-49 R4): the legacy self-paced projection and its
/// "Behind pace" accrual, the deadline-to-pace derivation, the reorder
/// amnesty, the scheduler engine's order build and due-review computation, and
/// the daily-plan snapshot of its chazara.
library;

import 'dart:math';

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/main_track_position.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/models/study_day_config.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

/// One calendar-program day's label for the leaves assigned that day: the
/// collapsed, type-aware unit name the calendar seed gives it (one daf, not
/// one amud). Presentation only.
typedef ProgramDayLabel = ({String? he, String? en});

/// What the planner needs to present one curriculum's tasks besides the
/// engine's [CurriculumState]. Nothing here is a quantity, an order or a
/// due date: those come only from the engine (AD-49).
final class CurriculumTaskPresentation {
  /// Creates the presentation inputs.
  const CurriculumTaskPresentation({
    required this.trackLabel,
    required this.stageNames,
    required this.studyDay,
    this.programDayLabels,
  });

  /// The localized track label (the curriculum's display name, Rule-7).
  final String trackLabel;

  /// Stage display names by `stage_order`. The lowest order is the learn
  /// stage new learning is shown under. Empty: the curriculum has no stages
  /// and the planner shows nothing for it.
  final Map<int, String> stageNames;

  /// Whether the planned date is a study day: on a review-only day the
  /// main track shows no new learning (reviews and calendar days still
  /// show).
  final bool studyDay;

  /// Non-null exactly when the curriculum follows a calendar program: the
  /// day label of each assigned leaf (a leaf with no label shows none).
  final Map<LeafRef, ProgramDayLabel>? programDayLabels;
}

/// One curriculum's tasks for a date: new learning (main track or calendar
/// days) and reviews, each in the engine's order.
typedef CurriculumTasks = ({List<DailyTask> learning, List<DailyTask> reviews});

/// Lays out [state]'s tasks for [date] (AD-49 "Planner"). The planner never
/// computes a quantity:
///
/// * a calendar-program curriculum shows `programBacklog(date)` (overdue
///   days) ∪ `programAssignments(date)` (today's day) less what is learnt,
///   by leaf;
/// * any other curriculum, on a study day, shows its main track: the
///   engine's position, current unit and `schedulableRefs` at the start of
///   [date] (`mainTrackAtStartOf`) up to `dailyTarget` when a deadline
///   exists, else `paceRate` (leaves per study day, rounded up to whole
///   leaves), else nothing — one masechta at a time except on the day one
///   finishes and the next begins (FR-12a, [mainTrackBatch]) — less the
///   leaves no longer schedulable now. The batch is anchored at the start
///   of the day, so it shrinks as the learner works through it and never
///   refills: once the day's batch is learnt, there is no new learning
///   until the next study day;
/// * reviews are `reviewsDue(date)` with their stage order and due date,
///   less the ones done on [date].
///
/// [corpus] is the curriculum's unscoped ContentIndex corpus, read only to
/// tell which unit a leaf is in. A curriculum the engine did not evaluate,
/// or with no stages, has no tasks.
CurriculumTasks planCurriculumTasks({
  required CurriculumId curriculum,
  required CurriculumState state,
  required Corpus? corpus,
  required CivilDate date,
  required CurriculumTaskPresentation presentation,
}) {
  if (!state.evaluated || presentation.stageNames.isEmpty) {
    return (learning: const [], reviews: const []);
  }
  final learnStage = presentation.stageNames.keys.reduce(min);
  final learnStageName = presentation.stageNames[learnStage]!;

  DailyTask learningTask(
    LeafRef leaf, {
    required DailyTaskPriority priority,
    required bool isOverdue,
    required String reason,
    ProgramDayLabel? label,
  }) => DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: leaf,
    stageOrder: learnStage,
    priority: priority,
    isOverdue: isOverdue,
    reason: reason,
    stageName: learnStageName,
    trackLabel: presentation.trackLabel,
    estimatedEffortMinutes: 5,
    unitDisplayHe: label?.he,
    unitDisplayEn: label?.en,
  );

  final learning = <DailyTask>[];
  final labels = presentation.programDayLabels;
  if (labels != null) {
    final shown = <LeafRef>{};
    for (final leaf in state.programBacklog(date)) {
      if (!shown.add(leaf)) continue;
      learning.add(
        learningTask(
          leaf,
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          reason: 'Program day pending from previous days',
          label: labels[leaf],
        ),
      );
    }
    for (final leaf in state.programAssignments(date)) {
      if (state.learntLeaves.contains(leaf) || !shown.add(leaf)) continue;
      learning.add(
        learningTask(
          leaf,
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
          reason: 'Program assignment for today',
          label: labels[leaf],
        ),
      );
    }
  } else if (presentation.studyDay) {
    final quantity = state.dailyTarget ?? state.paceRate?.ceil() ?? 0;
    final schedulableNow = state.schedulableRefs.toSet();
    for (final leaf in mainTrackBatch(
      mainTrack: state.mainTrackAtStartOf(date),
      corpus: corpus,
      quantity: quantity,
    )) {
      if (!schedulableNow.contains(leaf)) continue;
      learning.add(
        learningTask(
          leaf,
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'Due today',
        ),
      );
    }
  }

  final overdueReviews = <DailyTask>[];
  final dueReviews = <DailyTask>[];
  final day = parseCivilDay(date);
  for (final review in state.reviewsDue(date)) {
    if (review.completedOn != null) continue;
    final stageName = presentation.stageNames[review.stageOrder] ?? '';
    final dueFrom = review.dueFrom;
    final daysLate = dueFrom == null
        ? 0
        : day.difference(parseCivilDay(dueFrom)).inDays;
    final overdue = daysLate > 0;
    (overdue ? overdueReviews : dueReviews).add(
      DailyTask(
        curriculumId: curriculum,
        contentItemSefariaRef: review.leaf,
        stageOrder: review.stageOrder,
        priority: overdue
            ? DailyTaskPriority.overdueChazara
            : DailyTaskPriority.scheduledChazara,
        isOverdue: overdue,
        reason: overdue
            ? '$stageName overdue by $daysLate day(s)'
            : '$stageName due today',
        stageName: stageName,
        trackLabel: presentation.trackLabel,
      ),
    );
  }
  return (learning: learning, reviews: [...overdueReviews, ...dueReviews]);
}

/// The main-track leaves of a day's batch, at most [quantity], in engine
/// order (FR-12a): the schedulable leaves of the current unit (the unit of
/// the position when it names none); when they run out, the schedulable
/// leaves of the next unit begin — never a third. A curriculum with no
/// unit level shows the first [quantity] schedulable leaves.
///
/// Reads only the engine's [mainTrack] view (`schedulableRefs`,
/// `currentUnit` and `position`, at the start of the planned day); [corpus]
/// only says which unit a leaf is in.
List<LeafRef> mainTrackBatch({
  required MainTrackDayStart mainTrack,
  required Corpus? corpus,
  required int quantity,
}) {
  final refs = mainTrack.schedulableRefs;
  if (quantity <= 0 || refs.isEmpty) return const [];
  final position = mainTrack.position ?? refs.first;
  final unit =
      mainTrack.currentUnit ??
      (corpus == null ? null : unitOf(position, corpus));
  if (unit == null || corpus == null) return refs.take(quantity).toList();

  final unitLeaves = corpus.leavesUnder(unit).toSet();
  final batch = [
    for (final leaf in refs)
      if (unitLeaves.contains(leaf)) leaf,
  ].take(quantity).toList();
  if (batch.length == quantity) return batch;

  // The current unit finishes in this batch: the next unit begins. It is
  // the unit of the first schedulable leaf after the batch (in engine
  // order, wrapping) that is not in the current unit.
  final from = batch.isEmpty
      ? refs.indexOf(position)
      : refs.indexOf(batch.last);
  LeafRef? next;
  for (var i = 1; i <= refs.length; i++) {
    final leaf = refs[(from + i) % refs.length];
    if (!unitLeaves.contains(leaf)) {
      next = leaf;
      break;
    }
  }
  if (next == null) return batch;
  final nextUnit = unitOf(next, corpus);
  final nextLeaves = nextUnit == null
      ? {next}
      : corpus.leavesUnder(nextUnit).toSet();
  return [
    ...batch,
    ...refs.where(nextLeaves.contains).take(quantity - batch.length),
  ];
}

/// Every active curriculum's tasks for [date] from the live [state]
/// (AD-49): new learning and calendar days in [CurriculumTasks.learning],
/// reviews in [CurriculumTasks.reviews], curricula in [activeCurricula]
/// order. Only curricula with an active track are planned; the erev
/// planned list of an upcoming locked day is this list for that date.
Future<CurriculumTasks> buildPlannedTasks({
  required LearnerState state,
  required Map<String, Corpus> corpora,
  required CivilDate date,
  required List<CurriculumId> activeCurricula,
  required List<CurriculumTrackEntity> activeTracks,
  required Future<CurriculumTaskPresentation> Function(CurriculumId)
  presentationFor,
}) async {
  final tracked = {for (final t in activeTracks) t.curriculumId};
  final learning = <DailyTask>[];
  final reviews = <DailyTask>[];
  for (final curriculum in activeCurricula) {
    if (!tracked.contains(curriculum)) continue;
    final curriculumState = state[curriculum.storageKey];
    if (curriculumState == null || !curriculumState.evaluated) continue;
    final tasks = planCurriculumTasks(
      curriculum: curriculum,
      state: curriculumState,
      corpus: corpora[curriculum.storageKey],
      date: date,
      presentation: await presentationFor(curriculum),
    );
    learning.addAll(tasks.learning);
    reviews.addAll(tasks.reviews);
  }
  return (learning: learning, reviews: reviews);
}

/// Loads [curriculum]'s [CurriculumTaskPresentation] for [date]: stage
/// names, whether [date] is a study day (no study-day config means every
/// day is one), and — for a calendar-program enrollment — the day label of
/// each assigned leaf.
Future<CurriculumTaskPresentation> loadCurriculumTaskPresentation({
  required CurriculumId curriculum,
  required CivilDate date,
  required String trackLabel,
  required StageDefinitionRepository stageRepository,
  required Future<List<StudyDayConfigEntry>> Function(CurriculumId)
  studyDayConfigs,
  required ProfileProgramRepository profileProgramRepository,
  required LearningProgramRepository programRepository,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
}) async {
  final stages = await stageRepository.getStagesForCurriculum(curriculum);
  final configs = await studyDayConfigs(curriculum);
  final weekday = parseCivilDay(date).weekday;
  return CurriculumTaskPresentation(
    trackLabel: trackLabel,
    stageNames: {for (final s in stages) s.stageOrder: s.stageName},
    studyDay:
        configs.isEmpty ||
        configs.any(
          (c) => c.dayType == DayType.study && c.dayOfWeek == weekday,
        ),
    programDayLabels: await programDayLabels(
      curriculum: curriculum,
      date: date,
      profileProgramRepository: profileProgramRepository,
      programRepository: programRepository,
      calendarService: calendarService,
      getScopedContent: getScopedContent,
    ),
  );
}

/// The day label of each leaf a calendar program assigned to [curriculum]
/// from its tracking start through [date], or null when the curriculum
/// follows no calendar program. Labels only: which leaves are due comes
/// from the engine's `programAssignments` / `programBacklog`.
Future<Map<LeafRef, ProgramDayLabel>?> programDayLabels({
  required CurriculumId curriculum,
  required CivilDate date,
  required ProfileProgramRepository profileProgramRepository,
  required LearningProgramRepository programRepository,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
}) async {
  final enrollment = await profileProgramRepository.getProgram(curriculum);
  if (enrollment == null) return null;
  final apiKey = programRepository
      .getProgramById(enrollment.programId)
      ?.apiProgramKey;
  if (apiKey == null || apiKey.isEmpty) return null;
  final programKey =
      CalendarProgramRegistry.byId(apiKey)?.id ??
      CalendarProgramRegistry.byApiKey(apiKey)?.id ??
      CalendarProgramRegistry.byHebcalCategory(apiKey)?.id;
  if (programKey == null) return null;

  final civil = parseCivilDay(date);
  final day = DateTime(civil.year, civil.month, civil.day);
  final start = enrollment.trackingStartDate;
  // A missing, corrupt or default-epoch start labels only [date].
  final anchor = start == null || start.isBefore(DateTime.utc(2020))
      ? day
      : LocalDayUtils.extractLocalDate(start);
  if (anchor.isAfter(day)) return const {};

  final entries = await programCalendarSchedule(
    programKey: programKey,
    anchor: anchor,
    today: day,
    calendarService: calendarService,
  );
  if (entries.isEmpty) return const {};
  final content = await getScopedContent(curriculum);
  final labels = <LeafRef, ProgramDayLabel>{};
  for (final entry in entries) {
    final label = (
      he: entry.todayRefHe.isEmpty ? null : entry.todayRefHe,
      en: entry.todayRef.isEmpty ? null : displayProgramRef(entry.todayRef),
    );
    for (final leaf in resolvedOrFallbackProgramRefs(
      todayRef: entry.todayRef,
      contentItems: content,
    )) {
      labels[leaf] = label;
    }
  }
  return labels;
}

/// The calendar entries of [programKey] over `[anchor, today]` inclusive,
/// falling back to today's entry alone when the range has none. Used only
/// to label calendar-program tasks ([programDayLabels]); which leaves are
/// due is the engine's.
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

  // Calendar engine returned nothing for the range — fall back to just today,
  // with its date field populated (F-M1).
  final todayEntry = await calendarService.getEntry(programKey, today);
  if (todayEntry == null) return const [];
  // If the engine already populated date, use it directly; otherwise stamp
  // today explicitly so a caller never sees a null date.
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
