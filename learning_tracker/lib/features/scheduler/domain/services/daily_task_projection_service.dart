/// Domain-layer daily-task projection and fresh-plan building.
///
/// Extracted from `scheduler_providers.dart` (AUD-scheduler-12):
/// [buildProjectionTasks] and [buildFreshPlan] are the ~440-line amnesty-
/// cutoff / program-vs-self-paced business logic that used to live inline in
/// `allDailyTasksProvider`'s presentation-layer file, alongside
/// `domain/projection/` (this exact feature's existing home for pure
/// scheduling logic) and `domain/services/` (its existing home for services
/// that take injected repositories/DAOs — see `study_day_toggle_service.dart`
/// for the same extraction shape, AUD-t-scheduler-02).
///
/// Neither function takes a `Ref`. Their one Riverpod dependency in the
/// provider-layer version — `curriculumLabelTextFromRef(ref, curriculum: …)`
/// for the track display label — is injected here as a plain
/// `String Function(CurriculumId) trackLabelFor` callback, matching the
/// existing DI pattern already used for `getScopedContent` and
/// `programRepository`. This is what makes the logic unit-testable without a
/// `ProviderContainer`: see
/// `test/features/scheduler/domain/services/daily_task_projection_service_test.dart`.
///
/// No behavior change: `allDailyTasksProvider` calls these exact functions
/// with a `trackLabelFor` closure that itself calls
/// `curriculumLabelTextFromRef` — the Riverpod read moves to the call site,
/// it is not removed.
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/pace_derivation.dart';
import 'package:learning_tracker/features/dashboard/data/repositories/firestore_study_day_reader_adapter.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/day_type.dart';
import 'package:learning_tracker/features/scheduler/domain/projection/projection.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/goal_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_generator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';
import 'package:learning_tracker/features/scheduler/domain/services/sefaria_ref_matcher.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/profile_program_repository.dart';
import 'package:learning_tracker/features/tracks/stages/domain/models/stage_definition.dart'
    as domain_stage;
import 'package:learning_tracker/features/tracks/stages/domain/repositories/stage_definition_repository.dart';

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
Future<List<DailyTask>> buildProjectionTasks({
  required String Function(CurriculumId) trackLabelFor,
  required List<CurriculumId> activeCurricula,
  required List<CurriculumTrackEntity> activeTracks,
  required SchedulerCompletionRepository completionRepository,
  required ProfileProgramRepository profileProgramRepository,
  required GoalRepository goalRepository,
  required FirestoreStudyDayReaderAdapter studyDayReader,
  required StageDefinitionRepository stageRepository,
  required SchedulerEngine engine,
  required DateTime now,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
  required LearningProgramRepository programRepository,
}) async {
  final trackLabels = <CurriculumId, String>{};
  final trackStartedAtMap = <CurriculumId, DateTime>{};
  // §10.1 / reorder-amnesty: the projection filters out overdue items whose
  // scheduled date is strictly before the most-recent reorder timestamp.
  // Null lastReorderAt (rows created before this column was added) is treated
  // as epoch 0 — no historic tasks are amnestied.
  final trackLastReorderAtMap = <CurriculumId, DateTime>{};
  final tracksByCurriculum = <CurriculumId, CurriculumTrackEntity>{
    for (final t in activeTracks) t.curriculumId: t,
  };
  for (final curriculum in activeCurricula) {
    final preferred = tracksByCurriculum[curriculum];
    if (preferred == null) continue;
    // Rule-7 (no track types): the track label is the curriculum's localized
    // display name (never an internal track storage key like "personal").
    trackLabels[curriculum] = trackLabelFor(curriculum);
    trackStartedAtMap[curriculum] = preferred.activatedAt;
    trackLastReorderAtMap[curriculum] =
        preferred.lastReorderAt ?? DateTime.fromMillisecondsSinceEpoch(0);
  }

  final todayDate = LocalDayUtils.extractLocalDate(now);
  final result = <DailyTask>[];

  for (final curriculum in activeCurricula) {
    if (!tracksByCurriculum.containsKey(curriculum)) continue;

    final stages = await stageRepository.getStagesForCurriculum(curriculum);
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
    // Every Firestore completion's stageId is a stage_order value by
    // construction (SchedulerFirestoreCompletionRepositoryAdapter's class
    // doc comment) — no legacy stage_definitions.id format to disambiguate,
    // unlike the retired Drift dual-format comparison this replaces.
    final allCompletions = await completionRepository.getCompletions(
      curriculum,
    );
    final completionRefs = allCompletions
        .where((c) => c.stageOrder == firstStage.stageOrder)
        .map((c) => c.sefariaRef)
        .toSet();

    // ── Program track path ────────────────────────────────────────────────
    final enrollment = await profileProgramRepository.getProgram(curriculum);

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
              // still owes that day's work. See [amnestyDayCutoffUtc] for the
              // full rationale.
              final rawAmnestyCutoff = amnestyDayCutoffUtc(progLastReorderAt);
              // Back-date fix: clamp the cutoff to the anchor so a
              // freshly-enrolled program track's intended back-date window
              // survives. See [clampAmnestyCutoffToAnchor] for the full
              // rationale.
              final progAmnestyCutoff = clampAmnestyCutoffToAnchor(
                rawAmnestyCutoff,
                anchor,
              );
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
                      priority: DailyTaskPriority.overdueProgram,
                      isOverdue: true,
                      reason: 'Program day pending from previous days',
                      stageName: firstStage.stageName,
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
                      priority: DailyTaskPriority.todayProgram,
                      isOverdue: false,
                      reason: 'Program assignment for today',
                      stageName: firstStage.stageName,
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
    final goals = await goalRepository.getGoals(curriculum);
    final goal = goals.firstOrNull;
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
        final studyDaysInWindow = await studyDayReader
            .countStudyDaysInInclusiveDateRange(
              curriculumId: curriculum,
              startInclusive: startLocal,
              endInclusive: endLocal,
            );
        final studyDaysPerWeek = await studyDayReader.studyDaysPerWeek(
          curriculum,
        );
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
    final studyConfigs = await studyDayReader.getConfigsForCurriculum(
      curriculum,
    );
    final studyWeekdays = <int>{
      for (final c in studyConfigs)
        if (c.dayType == DayType.study) c.dayOfWeek,
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
              c.stageOrder == firstStage.stageOrder &&
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
    final amnestyCutoff = amnestyDayCutoffUtc(lastReorderAt);
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
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
          reason: 'Behind pace',
          stageName: firstStage.stageName,
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
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
          reason: 'Due today',
          stageName: firstStage.stageName,
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
///
/// AUD-scheduler-12: extracted from `scheduler_providers.dart`'s
/// `_buildFreshPlan`. The `DailyPlanRepository planRepo` parameter the
/// provider-layer version carried was dead — never read in the body — and
/// is dropped here rather than relocated: keeping it would force this
/// domain-layer file to import a `data/repositories/` concretion purely to
/// satisfy an unused parameter, undermining the layering this extraction
/// exists to fix.
Future<List<DailyTask>> buildFreshPlan({
  required String Function(CurriculumId) trackLabelFor,
  required List<CurriculumId> activeCurricula,
  required List<CurriculumTrackEntity> activeTracks,
  required GoalRepository goalRepository,
  required ProfileProgramRepository profileProgramRepository,
  required FirestoreStudyDayReaderAdapter studyDayReader,
  required StageDefinitionRepository stageRepository,
  required DailyTaskGenerator generator,
  required SchedulerEngine engine,
  required DateTime now,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
  required LearningProgramRepository programRepository,
}) async {
  // Resolve one active track per curriculum for this profile.
  final tracksByCurriculum = <CurriculumId, CurriculumTrackEntity>{
    for (final t in activeTracks) t.curriculumId: t,
  };
  final trackLabels = <CurriculumId, String>{};
  final trackStartedAtMap = <CurriculumId, DateTime>{};
  for (final curriculum in activeCurricula) {
    final preferred = tracksByCurriculum[curriculum];
    if (preferred == null) continue;
    // Rule-7 (no track types): the track label is the curriculum's localized
    // display name (never an internal track storage key like "personal").
    trackLabels[curriculum] = trackLabelFor(curriculum);
    trackStartedAtMap[curriculum] = preferred.activatedAt;
  }

  final goalDeadlines = <CurriculumId, DateTime>{};
  final pacePerDayMap = <CurriculumId, double>{};
  final paceGranularityMap = <CurriculumId, String>{};
  for (final curriculum in activeCurricula) {
    final goals = await goalRepository.getGoals(curriculum);
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
            paceGranularityMap[curriculum] = goal.paceGranularity!.storageKey;
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
    // "No config" defaults to "study every day" — same convention
    // buildProjectionTasks' StudyDayPattern uses (an empty weekday set means
    // every day is a study day; a non-empty config set with zero 'study'
    // entries means the user marked every day review-only).
    final configs = await studyDayReader.getConfigsForCurriculum(curriculum);
    final studyWeekdays = <int>{
      for (final c in configs)
        if (c.dayType == DayType.study) c.dayOfWeek,
    };
    isStudyDayMap[curriculum] = configs.isEmpty
        ? true
        : studyWeekdays.contains(localWeekday);
    studyDaysPerWeekMap[curriculum] = studyWeekdays.isEmpty
        ? 7
        : studyWeekdays.length;
  }

  // Exact study-day count from today through deadline (per track pattern).
  final studyDaysInDeadlineWindowMap = <CurriculumId, int>{};
  for (final curriculum in activeCurricula) {
    if (pacePerDayMap.containsKey(curriculum)) continue;
    final deadline = goalDeadlines[curriculum];
    if (deadline == null) continue;
    final start = LocalDayUtils.extractLocalDate(now);
    final end = LocalDayUtils.extractLocalDate(deadline);
    final n = await studyDayReader.countStudyDaysInInclusiveDateRange(
      curriculumId: curriculum,
      startInclusive: start,
      endInclusive: end,
    );
    if (n > 0) {
      studyDaysInDeadlineWindowMap[curriculum] = n;
    }
  }

  // buildFreshPlan now generates chazara/review tasks only — overdue and
  // today are owned by the pure projection (buildProjectionTasks / project).
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
    trackLabels: trackLabels,
    trackStartedAtMap: trackStartedAtMap,
    priorlyShownRefsMap: const {},
    paceGranularityMap: paceGranularityMap,
  );

  final overridden = await _applyProgramCalendarOverrides(
    stageRepository: stageRepository,
    profileProgramRepository: profileProgramRepository,
    generated: generated,
    now: now,
    activeCurricula: activeCurricula,
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
  // so that buildProjectionTasks classifies it correctly (dueToday, not
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
  required StageDefinitionRepository stageRepository,
  required ProfileProgramRepository profileProgramRepository,
  required List<DailyTask> generated,
  required DateTime now,
  required List<CurriculumId> activeCurricula,
  required Map<CurriculumId, String> trackLabels,
  required CalendarProgramService calendarService,
  required Future<List<ContentItem>> Function(CurriculumId) getScopedContent,
  required LearningProgramRepository programRepository,
}) async {
  final result = List<DailyTask>.from(generated);

  for (final curriculum in activeCurricula) {
    if (!trackLabels.containsKey(curriculum)) continue;

    final enrollment = await profileProgramRepository.getProgram(curriculum);
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
    final stages = await stageRepository.getStagesForCurriculum(curriculum);
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
            priority: priority,
            isOverdue: !isTodayUnit,
            reason: reason,
            stageName: firstStage.stageName,
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
