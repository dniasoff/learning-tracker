/// The pure learner-state engine (AD-35):
/// `const LearnerStateEngine().run(LearnerStateInputs(...)) → LearnerState`.
///
/// The engine is an ordered pipeline of pure stage functions, one file per
/// stage, and [DerivedCurriculumState] is composed of per-stage records:
///
/// 0. lock filter (`lock_filter.dart`, DNI-466): events inside a lock
///    window are lock-ignored before anything else is derived;
/// 1. counted events (`counted_events.dart`);
/// 2. learnt set and scope (DNI-465);
/// 3. tri-state and main-track position (DNI-465; order and held ground
///    by DNI-467);
/// 4. completed units (DNI-465);
/// 5. streak (`streak.dart`, DNI-466: per curriculum, evaluated
///    curricula only); planning and points (DNI-467, 468).
///
/// No I/O, clock read or global state: every input is in
/// [LearnerStateInputs], and identical inputs give equal outputs.
library;

import 'package:learning_tracker/domain/learner_state/calendar_plan.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/completed_units.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/derived_curriculum_state.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/goal_target.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/main_track_config_history.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/main_track_position.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ordered_leaves.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/review_schedule.dart';
import 'package:learning_tracker/domain/learner_state/scoped_corpus.dart';
import 'package:learning_tracker/domain/learner_state/streak.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// One calendar program assignment: [node] is assigned on [date].
final class CalendarAssignment {
  /// Creates an assignment.
  const CalendarAssignment(this.date, this.node);

  /// The civil date.
  final CivilDate date;

  /// The assigned node.
  final NodeEntry node;

  @override
  bool operator ==(Object other) =>
      other is CalendarAssignment && other.date == date && other.node == node;

  @override
  int get hashCode => Object.hash(date, node);

  @override
  String toString() => 'CalendarAssignment($date, $node)';
}

/// The complete inputs of one engine run (AD-35 "Complete inputs").
final class LearnerStateInputs {
  /// Creates the inputs.
  const LearnerStateInputs({
    required this.events,
    required this.subTracks,
    required this.mainTrackIntent,
    required this.goals,
    required this.intentHistory,
    required this.settingsHistory,
    required this.calendars,
    required this.corpora,
    required this.nowUtc,
  });

  /// Every learning event (complete).
  final List<LearningEvent> events;

  /// Every sub-track, live and tombstoned.
  final List<SubTrack> subTracks;

  /// Main-track intent by curriculum id.
  final Map<String, MainTrackIntent> mainTrackIntent;

  /// Goals by curriculum id.
  final Map<String, CurriculumGoals> goals;

  /// The governed intent change history (AD-37).
  final List<ChangeLogEntry> intentHistory;

  /// The learnerSettings slice of [intentHistory], reconstructed.
  final LearnerSettingsHistory settingsHistory;

  /// Calendar program assignments by `program_id`.
  final Map<String, List<CalendarAssignment>> calendars;

  /// Unscoped corpora by curriculum id.
  final Map<String, Corpus> corpora;

  /// The instant to evaluate at (UTC).
  final DateTime nowUtc;
}

/// How far before `nowUtc` locks are computed: enough for every catch-up
/// window that can still be open (AD-40 streak pending days).
const Duration _streakLookBack = Duration(days: 21);

/// The pure learner-state engine.
final class LearnerStateEngine {
  /// The engine has no state.
  const LearnerStateEngine();

  /// Folds [inputs] into a [LearnerState].
  ///
  /// Every curriculum named by a corpus, a main-track intent or a `learn`
  /// event gets a [CurriculumState]. Only a curriculum whose
  /// `curriculum_tracks` doc is `active` with no `ended_at` (and whose
  /// corpus is present) is `evaluated` and gets position and plan; events
  /// of every curriculum still count for the learnt set and siyum (AD-35).
  LearnerState run(LearnerStateInputs inputs) {
    final locks = engineLockWindows(
      inputs.settingsHistory,
      inputs.events,
      inputs.nowUtc,
      lookBack: _streakLookBack,
    );
    final counted = countEvents(
      inputs.events,
      isLockIgnored: lockIgnoreHook(locks),
    );
    final learnsByCurriculum = <String, List<LearningEvent>>{};
    for (final e in counted.learns) {
      (learnsByCurriculum[e.curriculumId!] ??= []).add(e);
    }
    final curricula = <String>{
      ...inputs.corpora.keys,
      ...inputs.mainTrackIntent.keys,
      ...learnsByCurriculum.keys,
    }.toList()..sort();
    return LearnerState(
      nowUtc: inputs.nowUtc,
      curricula: {
        for (final c in curricula)
          c: _curriculum(c, inputs, learnsByCurriculum[c] ?? const [], locks),
      },
      countedEventIds: counted.countedIds,
      lockIgnoredEventIds: counted.lockIgnoredIds,
    );
  }

  /// One curriculum. [learns] are its counted `learn` events, in event
  /// order.
  DerivedCurriculumState _curriculum(
    String curriculumId,
    LearnerStateInputs inputs,
    List<LearningEvent> learns,
    List<LockWindow> locks,
  ) {
    final corpus = inputs.corpora[curriculumId];
    final intent = inputs.mainTrackIntent[curriculumId];
    final evaluated = corpus != null && intent != null && intent.isEvaluated;
    if (corpus == null) {
      return DerivedCurriculumState(
        curriculumId: curriculumId,
        evaluated: false,
        learnt: LearntRecord.none(),
      );
    }
    final live = _liveDocs(intent);
    final firstStage = firstStageOrder(live?.stages ?? const [], learns);
    final scoped = scopedLeaves(corpus, live?.scope);
    final scopedSet = scoped.toSet();
    final learnt = LearntRecord(
      corpus: corpus,
      scopedLeaves: scoped,
      learntLeaves: learntLeaves(learns, corpus, scopedSet.contains),
    );
    final mainTrack = evaluated
        ? _mainTrack(
            curriculumId,
            inputs,
            intent,
            corpus,
            learnt,
            learns,
            firstStage,
          )
        : const MainTrackRecord.none();
    return DerivedCurriculumState(
      curriculumId: curriculumId,
      evaluated: evaluated,
      learnt: learnt,
      mainTrack: mainTrack,
      completedUnits: completedUnits(
        corpus: corpus,
        inScope: learnt.inScope,
        countedLearns: learns,
        firstStage: firstStage,
      ),
      plan: evaluated
          ? _plan(
              curriculumId,
              inputs,
              intent,
              corpus,
              learnt,
              learns,
              firstStage,
              mainTrack,
            )
          : const PlanRecord.none(),
      streak: evaluated
          ? curriculumStreak(
              learns,
              settingsHistory: inputs.settingsHistory,
              locks: locks,
              nowUtc: inputs.nowUtc,
            )
          : null,
    );
  }

  /// The AD-33 main-track stage of an evaluated curriculum.
  MainTrackRecord _mainTrack(
    String curriculumId,
    LearnerStateInputs inputs,
    MainTrackIntent intent,
    Corpus corpus,
    LearntRecord learnt,
    List<LearningEvent> learns,
    int? firstStage,
  ) {
    // `O` (AD-33): the only order function, restricted to the learner's
    // corpus. It ignores ended order docs itself.
    final order = [
      for (final leaf in orderedLeaves(corpus, intent.order))
        if (learnt.inScope(leaf)) leaf,
    ];
    final program = intent.program;
    return deriveMainTrack(
      corpus: corpus,
      order: order,
      learnt: learnt.learntLeaves,
      countedLearns: learns,
      heldGround: _heldGround(curriculumId, inputs, corpus),
      start: program?.endedAt == null ? program?.trackingStartRef : null,
      startAt: trackingStartAt(inputs.intentHistory, curriculumId),
      firstStage: firstStage,
    );
  }

  /// The planning stage of an evaluated curriculum (DNI-467).
  ///
  /// A calendar-program curriculum plans from its calendar: assignments,
  /// backlog, and `dailyTarget` / shortfall = assigned through today minus
  /// learnt. AD-44 is not computed for it.
  PlanRecord _plan(
    String curriculumId,
    LearnerStateInputs inputs,
    MainTrackIntent intent,
    Corpus corpus,
    LearntRecord learnt,
    List<LearningEvent> learns,
    int? firstStage,
    MainTrackRecord mainTrack,
  ) {
    final today = civilDate(inputs.nowUtc, inputs.settingsHistory);
    final configHistory = MainTrackConfigHistory.build(
      curriculumId: curriculumId,
      intent: intent,
      intentHistory: inputs.intentHistory,
    );
    final reviews = deriveReviewSchedule(
      countedLearns: learns,
      corpus: corpus,
      inScope: learnt.inScope,
      configHistory: configHistory,
      settingsHistory: inputs.settingsHistory,
      fallbackFirstStage: firstStage,
    );
    final errors = <CurriculumValidationError>{};
    final calendar = deriveCalendarPlan(
      curriculumId: curriculumId,
      intent: intent,
      calendars: inputs.calendars,
      corpus: corpus,
      inScope: learnt.inScope,
      learnt: learnt.learntLeaves,
      intentHistory: inputs.intentHistory,
      settingsHistory: inputs.settingsHistory,
      errors: errors,
    );
    if (calendar != null) {
      return PlanRecord(
        calendar: calendar,
        reviews: reviews,
        dailyTarget: calendar.dailyTarget(today),
        shortfall: calendar.amnestyFrom == null
            ? null
            : calendar.backlog(today).length,
        validationErrors: errors,
      );
    }
    // AD-43/AD-44: a deadline gives `dailyTarget`, a pace gives `paceRate`
    // (it also feeds FR-20 with a deadline); neither gives nulls. The
    // numerator is the no-sub-track case (DNI-494 adds the sub-track
    // terms).
    final goals = inputs.goals[curriculumId];
    final deadline = liveDeadline(goals);
    final pace = livePace(goals);
    final studyDays = configHistory.current.studyDays;
    return PlanRecord(
      reviews: reviews,
      dailyTarget: deadline == null
          ? null
          : deadlineDailyTarget(
              numerator: mainTrack.schedulableRefs.length,
              deadline: deadline,
              studyDays: studyDays,
              today: today,
            ),
      paceRate: pace == null
          ? null
          : paceRateOf(
              pace: pace,
              corpus: corpus,
              inScope: learnt.inScope,
              studyDays: studyDays,
            ),
      validationErrors: errors,
    );
  }

  /// The ground of [curriculumId]'s `holdsGround` sub-tracks (AD-34), which
  /// leaves the main track. A leaf held by several sub-tracks is excluded
  /// once (a set).
  Set<LeafRef> _heldGround(
    String curriculumId,
    LearnerStateInputs inputs,
    Corpus corpus,
  ) {
    final subTracks = [
      for (final s in inputs.subTracks)
        if (s.curriculumId == curriculumId) s,
    ];
    if (subTracks.isEmpty) return const {};
    final today = civilDate(inputs.nowUtc, inputs.settingsHistory);
    return {
      for (final s in subTracks)
        if (holdsGround(s, today)) ...expandGround(s.ground, corpus),
    };
  }

  /// [intent] while its track is not ended, else null: while the track has
  /// `ended_at`, its other governed docs read as ended too (AD-38).
  MainTrackIntent? _liveDocs(MainTrackIntent? intent) =>
      intent != null && intent.track.endedAt == null ? intent : null;
}
