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
///    curricula only);
/// 6. planning (DNI-467, evaluated curricula only): calendar plan
///    (`calendar_plan.dart`), reviews (`review_schedule.dart` over
///    `main_track_config_history.dart`), goal target and pace
///    (`goal_target.dart`) and projection (`projection.dart`);
/// 7. points (`earning_events.dart`, DNI-468): the profile-wide
///    `earningEventIds`, from every curriculum with a corpus.
///    Sub-track states (`sub_track_positions.dart`, DNI-493): each
///    sub-track's own position, ticked count and remaining path;
///    (`goal_target.dart`) and projection (`projection.dart`; held at
///    the lock's start while a lock is active, DNI-494);
///    sub-track states (`sub_track_positions.dart`, DNI-493): each
///    sub-track's own position, ticked count and remaining path; and the
///    AD-44 deadline forecast (`sub_track_forecast.dart` over
///    `sub_track_capacity.dart`, DNI-494): per-sub-track capacity,
///    expected new ground and shortfall feeding the FR-19 `dailyTarget`;
/// 7. points (DNI-468).
/// 7. points (`earning_events.dart`, DNI-468): the profile-wide
///    `earningEventIds`, from every curriculum with a corpus.
/// 8. report projection (`report_projection.dart`, DNI-516): lifetime and
///    per-source totals of every curriculum with a corpus, from the
///    counted events and learnt set above (AD-48).
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
import 'package:learning_tracker/domain/learner_state/earning_events.dart';
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
import 'package:learning_tracker/domain/learner_state/projection.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/review_schedule.dart';
import 'package:learning_tracker/domain/learner_state/scoped_corpus.dart';
import 'package:learning_tracker/domain/learner_state/streak.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_forecast.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_positions.dart';

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

/// The AD-35 velocity inputs of one evaluated curriculum.
typedef _VelocityInputs = ({
  Map<LeafRef, CivilDate> newlyLearnt,
  CivilDate? historyStart,
  CivilDate today,
});

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
    final states = <String, CurriculumState>{};
    final earning = <String>{};
    for (final c in curricula) {
      final (state, earners) = _curriculum(
        c,
        inputs,
        learnsByCurriculum[c] ?? const [],
        locks,
      );
      states[c] = state;
      earning.addAll(earners);
    }
    return LearnerState(
      nowUtc: inputs.nowUtc,
      today: civilDate(inputs.nowUtc, inputs.settingsHistory),
      curricula: states,
      countedEventIds: counted.countedIds,
      earningEventIds: earning,
      lockIgnoredEventIds: counted.lockIgnoredIds,
      countedLearns: counted.learns,
    );
  }

  /// One curriculum and its earning event ids (stage 7). [learns] are its
  /// counted `learn` events, in event order.
  (DerivedCurriculumState, Set<String>) _curriculum(
    String curriculumId,
    LearnerStateInputs inputs,
    List<LearningEvent> learns,
    List<LockWindow> locks,
  ) {
    final corpus = inputs.corpora[curriculumId];
    final intent = inputs.mainTrackIntent[curriculumId];
    final evaluated = corpus != null && intent != null && intent.isEvaluated;
    if (corpus == null) {
      // Without a corpus no event resolves to a leaf: nothing is learnt
      // and nothing earns.
      return (
        DerivedCurriculumState(
          curriculumId: curriculumId,
          evaluated: false,
          learnt: LearntRecord.none(),
        ),
        const <String>{},
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
    // The AD-35 velocity inputs, shared by the projection (stage 6) and
    // the report velocities (stage 8) so both read one rule.
    final velocity = evaluated
        ? _velocityInputs(
            inputs,
            intent,
            corpus,
            learnt,
            learns,
            firstStage,
            locks,
          )
        : null;
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
    // The AD-35 review schedule over the reconstructed config history. It
    // is built for every curriculum with a main track, evaluated or not,
    // so ending or pausing a track never takes back past review earning.
    final configHistory = intent == null
        ? null
        : MainTrackConfigHistory.build(
            curriculumId: curriculumId,
            intent: intent,
            intentHistory: inputs.intentHistory,
          );
    final reviews = configHistory == null
        ? null
        : deriveReviewSchedule(
            countedLearns: learns,
            corpus: corpus,
            inScope: learnt.inScope,
            configHistory: configHistory,
            settingsHistory: inputs.settingsHistory,
            fallbackFirstStage: firstStage,
          );
    final earners = curriculumEarningEventIds(
      countedLearns: learns,
      corpus: corpus,
      settingsHistory: inputs.settingsHistory,
      reviews: reviews,
      firstStageAt: configHistory == null
          ? null
          : (t) => configHistory.at(t).firstStageOrder ?? firstStage,
    );
    final plan = evaluated
        ? _plan(
            curriculumId,
            inputs,
            intent,
            corpus,
            learnt,
            learns,
            firstStage,
            mainTrack,
            configHistory!,
            reviews!,
            velocity!,
          )
        : const PlanRecord.none();
    final state = DerivedCurriculumState(
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
      plan: plan,
      streak: evaluated
          ? curriculumStreak(
              learns,
              settingsHistory: inputs.settingsHistory,
              locks: locks,
              nowUtc: inputs.nowUtc,
            )
          : null,
      report: deriveReportProjection(
        curriculumId: curriculumId,
        countedLearns: learns,
        corpus: corpus,
        inScope: learnt.inScope,
        learntLeaves: learnt.learntLeaves,
        subTracks: [
          for (final s in inputs.subTracks)
            if (s.curriculumId == curriculumId) s,
        ],
        civilDayOf: (instant) => civilDate(instant, inputs.settingsHistory),
        velocity: velocity == null
            ? null
            : ReportVelocityBasis(
                newlyLearnt: velocity.newlyLearnt,
                trackingStart: velocity.historyStart,
                today: velocity.today,
                firstStage: firstStage,
                projection: plan.projection,
                calendarProgram: plan.calendar != null,
              ),
      ),
    );
    return (state, earners);
  }

  /// The AD-35 velocity inputs of an evaluated curriculum: the day each
  /// leaf was newly learnt, the start of tracked history and the
  /// projection day (held at a lock's start during a lock; NFR-9, FR-23).
  _VelocityInputs _velocityInputs(
    LearnerStateInputs inputs,
    MainTrackIntent intent,
    Corpus corpus,
    LearntRecord learnt,
    List<LearningEvent> learns,
    int? firstStage,
    List<LockWindow> locks,
  ) {
    final program = intent.program;
    return (
      newlyLearnt: newlyLearntOn(
        countedLearns: learns,
        corpus: corpus,
        inScope: learnt.inScope,
        firstStage: firstStage,
      ),
      historyStart: trackedHistoryStart(
        program?.endedAt == null ? program?.trackingStartDate : null,
        learns,
      ),
      today: projectionDay(
        locks: locks,
        nowUtc: inputs.nowUtc,
        settingsHistory: inputs.settingsHistory,
      ),
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
    final heldGround = _heldGround(curriculumId, inputs, corpus);
    final start = program?.endedAt == null ? program?.trackingStartRef : null;
    final startAt = trackingStartAt(inputs.intentHistory, curriculumId);
    MainTrackRecord derive(Set<LeafRef> learntSet, List<LearningEvent> ls) =>
        deriveMainTrack(
          corpus: corpus,
          order: order,
          learnt: learntSet,
          countedLearns: ls,
          heldGround: heldGround,
          start: start,
          startAt: startAt,
          firstStage: firstStage,
        );
    final live = derive(learnt.learntLeaves, learns);
    // DNI-477: the main track at the start of a civil date is the same
    // derivation over only the learning dated before it (an undated
    // before-tracking event is earlier than any date).
    return live.withStartOf((date) {
      final before = [
        for (final e in learns)
          if (e.learnedOn == null || e.learnedOn!.compareTo(date) < 0) e,
      ];
      if (before.length == learns.length) return live;
      return derive(learntLeaves(before, corpus, learnt.inScope), before);
    });
  }

  /// The planning stage of an evaluated curriculum (DNI-467). [reviews]
  /// is its review schedule over [configHistory], shared with stage 7.
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
    MainTrackConfigHistory configHistory,
    ReviewSchedule reviews,
    _VelocityInputs velocity,
  ) {
    final today = civilDate(inputs.nowUtc, inputs.settingsHistory);
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
    final goals = inputs.goals[curriculumId];
    final deadline = calendar == null ? liveDeadline(goals) : null;
    // DNI-493: each sub-track's own position, ticked count and remaining
    // path; evaluated curricula only (AD-35).
    final subTracks = subTrackStates(
      subTracks: inputs.subTracks,
      corpus: corpus,
      countedLearns: learns,
      today: today,
      deadline: deadline?.targetDate,
    );
    final projection = deriveProjection(
      newlyLearnt: velocity.newlyLearnt,
      historyStart: velocity.historyStart,
      // NFR-9/FR-23: during a lock, as evaluated at the lock's start.
      today: velocity.today,
      remaining: learnt.scopedLeaves.length - learnt.learntLeaves.length,
      deadline: deadline,
    );
    if (calendar != null) {
      return PlanRecord(
        subTracks: subTracks,
        calendar: calendar,
        reviews: reviews,
        projection: projection,
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
    // terms), taken at the start of today: `studyDaysToDeadline` counts
    // today, so the leaves learnt today still count against today's
    // target and it does not shrink as they are learnt (DNI-477).
    // AD-43/AD-44: a deadline gives `dailyTarget` from the FR-19
    // numerator over the `holdsGround` sub-tracks (DNI-494), a pace gives
    // `paceRate` (it also feeds FR-20 with a deadline); neither gives
    // nulls. With no deadline no capacity or shortfall is computed and no
    // sub-track rate affects any value.
    final pace = livePace(goals);
    final studyDays = configHistory.current.studyDays;
    DeadlineForecast? forecast;
    int? dailyTarget;
    if (deadline != null) {
      forecast = deriveDeadlineForecast(
        subTracks: [
          for (final s in inputs.subTracks)
            if (s.curriculumId == curriculumId) s,
        ],
        states: subTracks,
        corpus: corpus,
        isLearnt: learnt.learntLeaves.contains,
        inScope: learnt.inScope,
        mainTrackRemaining: mainTrack.atStartOf(today).schedulableRefs.length,
        today: today,
        targetDate: deadline.targetDate,
      );
      dailyTarget = deadlineDailyTarget(
        numerator: forecast.numerator,
        deadline: deadline,
        studyDays: studyDays,
        today: today,
      );
    }
    return PlanRecord(
      subTracks: forecast == null
          ? subTracks
          : withForecast(subTracks, forecast),
      reviews: reviews,
      dailyTarget: dailyTarget,
      shortfall: forecast?.shortfall,
      paceRate: pace == null
          ? null
          : paceRateOf(
              pace: pace,
              corpus: corpus,
              inScope: learnt.inScope,
              studyDays: studyDays,
            ),
      projection: projection,
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
