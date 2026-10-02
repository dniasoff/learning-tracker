/// The learner-state engine's output (AD-35).
///
/// `LearnerStateEngine.run` (`learner_state_engine.dart`) folds the
/// complete inputs into one [LearnerState]; every learner number on every
/// surface reads it. C0 (DNI-524) fixes the shape. DNI-465 provides the
/// real [CurriculumState] implementation and DNI-466, 467 and 468 extend it.
/// Everything under `lib/domain/**` stays pure Dart:
/// `tool/check_dependency_direction.dart` enforces it.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';

/// How much of a node is learnt.
enum TriState {
  /// No leaf under the node is learnt.
  empty,

  /// Some, but not all, leaves are learnt.
  partial,

  /// Every leaf is learnt.
  complete,
}

/// A unit (siyum level) learnt to completion one or more times.
final class CompletedUnit {
  /// Creates a completed unit.
  const CompletedUnit({
    required this.unit,
    required this.completionNumber,
    required this.firstCompletedAt,
  });

  /// The unit node.
  final NodeEntry unit;

  /// How many times it is complete (k).
  final int completionNumber;

  /// k → the `effectiveAt` of the k-th completion; always holds key 1.
  final Map<int, DateTime> firstCompletedAt;

  @override
  bool operator ==(Object other) {
    if (other is! CompletedUnit ||
        other.unit != unit ||
        other.completionNumber != completionNumber ||
        other.firstCompletedAt.length != firstCompletedAt.length) {
      return false;
    }
    for (final MapEntry(:key, :value) in firstCompletedAt.entries) {
      if (other.firstCompletedAt[key] != value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    unit,
    completionNumber,
    Object.hashAllUnordered(
      firstCompletedAt.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );

  @override
  String toString() => 'CompletedUnit($unit, x$completionNumber)';
}

/// A leaf due for review at stage [stageOrder].
///
/// A review is identified by `(leaf, stageOrder)`: equality and hash read
/// only those two. [dueFrom] and [completedOn] describe the review on the
/// date it was queried for (DNI-477, additive to the C0 contract) so the
/// planner takes the due date from `reviewsDue(date)` and never schedules
/// a review itself (AD-49).
final class ReviewDue {
  /// Creates a review item.
  const ReviewDue(this.leaf, this.stageOrder, {this.dueFrom, this.completedOn});

  /// The leaf.
  final LeafRef leaf;

  /// The review stage order.
  final int stageOrder;

  /// The first civil date the review was due. Earlier than the queried
  /// date only for an overdue delay review (it stays due until done); the
  /// queried date for a weekly or rolling review. Null when the source did
  /// not say.
  final CivilDate? dueFrom;

  /// The civil date the review was done, when it was done on the queried
  /// date (a review done on a date still counts as due that day); null
  /// while it is still to do.
  final CivilDate? completedOn;

  @override
  bool operator ==(Object other) =>
      other is ReviewDue &&
      other.leaf == leaf &&
      other.stageOrder == stageOrder;

  @override
  int get hashCode => Object.hash(leaf, stageOrder);

  @override
  String toString() => 'ReviewDue($leaf, $stageOrder)';
}

/// The per-curriculum streak (AD-40).
final class CurriculumStreak {
  /// Creates a streak value.
  const CurriculumStreak({
    required this.current,
    required this.best,
    this.lastDay,
  });

  /// Current run of streak days.
  final int current;

  /// Longest run ever.
  final int best;

  /// The last streak day, if any.
  final CivilDate? lastDay;

  @override
  bool operator ==(Object other) =>
      other is CurriculumStreak &&
      other.current == current &&
      other.best == best &&
      other.lastDay == lastDay;

  @override
  int get hashCode => Object.hash(current, best, lastDay);

  @override
  String toString() => 'CurriculumStreak($current, best $best)';
}

/// Where the learner stands against the deadline.
enum ProjectionStatus {
  /// Not enough history to project.
  tooEarly,

  /// On track to finish by the deadline.
  onTrack,

  /// Behind the pace the deadline needs.
  behindPace,

  /// No deadline goal.
  noDeadline,
}

/// The finish projection of one curriculum.
final class Projection {
  /// Creates a projection.
  const Projection({
    required this.status,
    this.velocityPerDay,
    this.projectedFinish,
  });

  /// The status.
  final ProjectionStatus status;

  /// Observed leaves per day, if known.
  final double? velocityPerDay;

  /// Projected finish day, if known.
  final CivilDate? projectedFinish;

  @override
  bool operator ==(Object other) =>
      other is Projection &&
      other.status == status &&
      other.velocityPerDay == velocityPerDay &&
      other.projectedFinish == projectedFinish;

  @override
  int get hashCode => Object.hash(status, velocityPerDay, projectedFinish);

  @override
  String toString() => 'Projection(${status.name})';
}

/// The engine's view of one sub-track (AD-34).
final class SubTrackState {
  /// Creates a sub-track state.
  const SubTrackState({
    required this.subTrackId,
    required this.holdsGround,
    required this.inForecast,
    required this.onHome,
    this.position,
    this.groundExhausted = false,
    this.ticked = 0,
    this.remainingPath = const [],
    this.capacity,
    this.expectedNewGround = 0,
    this.shortfall = 0,
    this.shortfallLeaves = const [],
    this.windowEnd,
    this.lastShortfallNode,
  });

  /// The sub-track ULID.
  final String subTrackId;

  /// Whether it holds its ground off the main track.
  final bool holdsGround;

  /// Whether it counts in the main-track forecast.
  final bool inForecast;

  /// Whether it shows on the home screen.
  final bool onHome;

  /// Its position (AD-33): the first leaf of `expandGround(ground)` with
  /// no counted `learn` event whose `source` is this sub-track; null when
  /// every ground leaf is ticked in it, or it has no ground. Events from
  /// other sources never move it (FR-13).
  final LeafRef? position;

  /// Whether it has ground and every ground leaf is ticked in it (no
  /// [position]); a groundless sub-track is not exhausted.
  final bool groundExhausted;

  /// The distinct ground leaves with a counted `learn` event from this
  /// sub-track (DNI-493).
  final int ticked;

  /// `expandGround(ground)` from [position] to the end, learnt or not;
  /// empty with no [position] (DNI-493). The AD-44 `path` is this list
  /// restricted to the learner's scoped corpus (AD-42).
  final List<LeafRef> remainingPath;

  /// AD-44 capacity in leaves: `floor(rate_per_week × activeWeeksLeft)`
  /// up to the deadline, 0 when the capacity interval is empty. Null when
  /// not computed: no live deadline, a calendar-program curriculum, or a
  /// sub-track that does not hold ground (DNI-494).
  final int? capacity;

  /// `max(0, capacity − |path|)`, `path` being [remainingPath] in the
  /// learner's scoped corpus: capacity left over for ground
  /// not entered yet, credited against the main track (FR-19). 0 when
  /// [capacity] is null.
  final int expectedNewGround;

  /// The leaves of the scoped `path` this sub-track will not reach by the
  /// deadline and that come back to the main track: unlearnt, at `path`
  /// indices `≥ capacity`, not reached within capacity by another holder, each
  /// counted under one sub-track only (DNI-494). Its sum over the
  /// curriculum's sub-tracks is the FR-19 shortfall term. 0 when
  /// [capacity] is null.
  final int shortfall;

  /// The [shortfall] leaves, in [remainingPath] order (DNI-494, FR-21):
  /// exactly the leaves this sub-track adds to the FR-19 numerator, so
  /// `shortfallLeaves.length == shortfall`. Empty when not computed.
  final List<LeafRef> shortfallLeaves;

  /// The sub-track's `window_end` (AD-41 civil date, inclusive); null for
  /// an open ongoing window. FR-21 copy names it.
  final CivilDate? windowEnd;

  /// The last entry of the sub-track's `ground` (list order, as entered)
  /// that contains one of [shortfallLeaves]; null with no shortfall. FR-21
  /// copy names it ("…won't finish <node> by <windowEnd>").
  final NodeEntry? lastShortfallNode;

  @override
  bool operator ==(Object other) =>
      other is SubTrackState &&
      other.subTrackId == subTrackId &&
      other.holdsGround == holdsGround &&
      other.inForecast == inForecast &&
      other.onHome == onHome &&
      other.position == position &&
      other.groundExhausted == groundExhausted &&
      other.ticked == ticked &&
      _sameLeaves(other.remainingPath, remainingPath) &&
      other.capacity == capacity &&
      other.expectedNewGround == expectedNewGround &&
      other.shortfall == shortfall &&
      _sameLeaves(other.shortfallLeaves, shortfallLeaves) &&
      other.windowEnd == windowEnd &&
      other.lastShortfallNode == lastShortfallNode;

  @override
  int get hashCode => Object.hash(
    subTrackId,
    holdsGround,
    inForecast,
    onHome,
    position,
    groundExhausted,
    ticked,
    Object.hashAll(remainingPath),
    capacity,
    expectedNewGround,
    shortfall,
    Object.hashAll(shortfallLeaves),
    windowEnd,
    lastShortfallNode,
  );

  @override
  String toString() => 'SubTrackState($subTrackId)';
}

bool _sameLeaves(List<LeafRef> a, List<LeafRef> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The main track as it stood at the start of one civil day (DNI-477,
/// additive to the C0 contract): the AD-33 [schedulableRefs], FR-12a
/// [currentUnit] and [position] derived from only the learning recorded as
/// learnt before that day. A leaf learnt on the day is still in it, so a
/// day's main-track batch laid out from it does not refill as the learner
/// works through it (AD-49 planner).
final class MainTrackDayStart {
  /// Creates the view.
  MainTrackDayStart({
    required List<LeafRef> schedulableRefs,
    this.currentUnit,
    this.position,
  }) : schedulableRefs = List.unmodifiable(schedulableRefs);

  /// The leaves the planner could schedule at the start of the day, in
  /// AD-33 order.
  final List<LeafRef> schedulableRefs;

  /// The FR-12a unit the learner was in at the start of the day.
  final NodeEntry? currentUnit;

  /// The next main-track leaf at the start of the day.
  final LeafRef? position;

  @override
  bool operator ==(Object other) {
    if (other is! MainTrackDayStart ||
        other.currentUnit != currentUnit ||
        other.position != position ||
        other.schedulableRefs.length != schedulableRefs.length) {
      return false;
    }
    for (var i = 0; i < schedulableRefs.length; i++) {
      if (other.schedulableRefs[i] != schedulableRefs[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(schedulableRefs), currentUnit, position);

  @override
  String toString() =>
      'MainTrackDayStart($position, ${schedulableRefs.length} schedulable)';
}

/// An invalid intent the engine found while deriving one curriculum's plan.
/// The engine never substitutes a default for it; the affected outputs
/// stay empty or null and the error is reported here.
enum CurriculumValidationError {
  /// A calendar-program curriculum has no `tracking_start_date` (AD-35):
  /// `programBacklog` and the calendar `dailyTarget` are not derived.
  missingTrackingStartDate,
}

/// The engine's view of one curriculum.
///
/// DNI-465 provides the real implementation; DNI-466, 467 and 468 fill the
/// lock, planning and points members. Planning members are derived only
/// for an evaluated curriculum; otherwise they are empty or null.
abstract interface class CurriculumState {
  /// The curriculum.
  String get curriculumId;

  /// Whether the engine evaluated this curriculum (its corpus was ready).
  bool get evaluated;

  /// Every learnt leaf.
  Set<LeafRef> get learntLeaves;

  /// `learntLeaves.length`.
  int get distinctLearnt;

  /// How much of [node] is learnt.
  TriState triState(NodeEntry node);

  /// The FR-12a unit (Mishnayos: masechta) the learner is in: the unit of
  /// the later of the latest counted main-track capture and
  /// `tracking_start_ref`, only while it still has a schedulable leaf
  /// (AD-33).
  NodeEntry? get currentUnit;

  /// The next main-track leaf: the first schedulable leaf of [currentUnit],
  /// else the first of [schedulableRefs] (AD-33).
  LeafRef? get mainTrackPosition;

  /// Sub-track states by sub-track ULID.
  Map<String, SubTrackState> get subTracks;

  /// The leaves the planner may schedule (AD-33): the leaves of
  /// `O = orderedLeaves(corpus, mainTrackOrder)` within the learner's
  /// corpus that have no counted learn event and are not in the ground of
  /// any `holdsGround` sub-track, ordered as the leaves at or after
  /// `tracking_start_ref`, then the leaves before it.
  List<LeafRef> get schedulableRefs;

  /// `schedulableRefs.length`.
  int get mainTrackRemaining;

  /// The main track at the start of civil [date] (DNI-477, additive to the
  /// C0 contract): [schedulableRefs], [currentUnit] and
  /// [mainTrackPosition] derived as above from only the counted `learn`
  /// events whose `learned_on` is before [date] (undated before-tracking
  /// events are earlier), under the current order, scope, held ground and
  /// tracking start. A leaf learnt on [date] is still schedulable in it.
  ///
  /// The planner lays out [date]'s main-track batch from it, so learning a
  /// leaf on [date] never pulls the next leaf into that day's batch. On a
  /// date after every `learned_on` it is the live main track. Empty for a
  /// curriculum that is not evaluated.
  MainTrackDayStart mainTrackAtStartOf(CivilDate date);

  /// Calendar-program curricula only: the leaves assigned on [date], each
  /// assigned node expanded by `expandGround` within the learner's corpus
  /// (learnt leaves included). Empty for any other curriculum.
  List<LeafRef> programAssignments(CivilDate date);

  /// Calendar-program curricula only: the leaves assigned before [today]
  /// and on or after `amnestyFrom` with no counted learn event, in date
  /// order. Empty when `tracking_start_date` is missing (see
  /// [validationErrors]).
  List<LeafRef> programBacklog(CivilDate today);

  /// The (leaf, `stage_order`) reviews due on [date] from AD-32 cycles,
  /// each step under the stages and study days in force at the event that
  /// completed the previous step. An overdue delay review stays due until
  /// done; a review done on [date] was due on [date]. The only review
  /// scheduler (AD-35).
  List<ReviewDue> reviewsDue(CivilDate date);

  /// Today's target in leaves. Calendar program: assigned through today
  /// minus learnt. Otherwise, with a live `goals/{c}_deadline`:
  /// `max(0, ceil(numerator ÷ studyDaysToDeadline))`, or
  /// `max(0, numerator)` when no study day is left (AD-44, B13). The
  /// numerator is `mainTrackRemaining − Σ expectedNewGround +
  /// Σ shortfall` over the `holdsGround` sub-tracks (DNI-494), where the
  /// main-track remaining is measured at the start of today (DNI-477).
  /// Null with no deadline.
  int? get dailyTarget;

  /// Leaves per study day from a live `goals/{c}_pace` doc (AD-43); null
  /// without one and on a calendar-program curriculum.
  double? get paceRate;

  /// Leaves behind: the calendar backlog size on a calendar-program
  /// curriculum; otherwise, with a live deadline, the FR-19 sub-track
  /// shortfall term (each leaf once; the sum of [SubTrackState.shortfall],
  /// DNI-494). Null when not derived (no deadline).
  int? get shortfall;

  /// The finish projection of an evaluated curriculum (AD-35): velocity =
  /// distinct leaves newly learnt per `learned_on` day from dated/catch_up
  /// non-chazara events over the trailing 28 days (all history at 14–27
  /// days); [ProjectionStatus.tooEarly] under 14 days. Projected finish =
  /// today + ⌈remaining corpus ÷ velocity⌉; on track iff it is on or
  /// before `target_date`. While a lock is active, the projection as
  /// evaluated on the lock's start day, re-evaluated after the lock ends
  /// (NFR-9, FR-23; DNI-494). Null when not evaluated.
  Projection? get projection;

  /// Completed units in completion order.
  List<CompletedUnit> get completedUnits;

  /// The curriculum streak, if computed.
  CurriculumStreak? get streak;

  /// Invalid intent found while planning (DNI-467); empty when valid.
  Set<CurriculumValidationError> get validationErrors;

  /// The report projection (AD-48, FR-31, FR-32; DNI-516): lifetime and
  /// per-source totals for every curriculum with a corpus, retired ones
  /// included. The only input of any report total, count or velocity.
  ReportProjection get report;
}

/// The whole learner's state at [nowUtc] (AD-35).
final class LearnerState {
  /// Creates a state.
  LearnerState({
    required this.nowUtc,
    CivilDate? today,
    required Map<String, CurriculumState> curricula,
    Set<String> countedEventIds = const {},
    Set<String> earningEventIds = const {},
    Set<String> lockIgnoredEventIds = const {},
    List<RejectedRow> rejectedRows = const [],
    List<LearningEvent> countedLearns = const [],
  }) : today = today ?? formatCivilDay(nowUtc.toUtc()),
       curricula = Map.unmodifiable(curricula),
       countedLearns = List.unmodifiable(countedLearns),
       countedEventIds = Set.unmodifiable(countedEventIds),
       earningEventIds = Set.unmodifiable(earningEventIds),
       lockIgnoredEventIds = Set.unmodifiable(lockIgnoredEventIds),
       rejectedRows = List.unmodifiable(rejectedRows);

  /// A state with no curricula.
  factory LearnerState.empty(DateTime nowUtc) =>
      LearnerState(nowUtc: nowUtc, curricula: const {});

  /// The instant the state was computed for (UTC).
  final DateTime nowUtc;

  /// The learner's civil date at [nowUtc] (AD-41: `civilDate(nowUtc)` in
  /// the `time_zone` in force per the settings history, never the device
  /// offset): the `today` every date-keyed output was derived for
  /// (DNI-477, additive to the C0 contract). Surfaces that ask for
  /// "today's" plan read it instead of the device date. A state built
  /// without one (tests, [LearnerState.empty]) uses the UTC date of
  /// [nowUtc].
  final CivilDate today;

  /// Curriculum states by curriculum id.
  final Map<String, CurriculumState> curricula;

  /// Learn events that count (not voided, not lock-ignored).
  final Set<String> countedEventIds;

  /// Learn events that earn points (AD-50).
  final Set<String> earningEventIds;

  /// Events recorded inside a lock window and ignored (AD-36).
  final Set<String> lockIgnoredEventIds;

  /// Rows the complete reads could not decode; surfaced, never dropped.
  final List<RejectedRow> rejectedRows;

  /// The counted `learn` events of every curriculum (not voided, not
  /// lock-ignored), in the engine's event order (`effectiveAt`, then id):
  /// the `[countedEventIds]` events themselves.
  ///
  /// Surfaces that show activity over time (charts, the PRD "chazara"
  /// derived count, per-leaf provenance) bucket these instead of reading
  /// `learning_events` (AD-35 "Reads"; DNI-474, additive to the C0
  /// contract).
  final List<LearningEvent> countedLearns;

  /// The state of [curriculumId], or null when it has none.
  CurriculumState? operator [](String curriculumId) => curricula[curriculumId];

  @override
  String toString() =>
      'LearnerState(${nowUtc.toIso8601String()}, $today, '
      '${curricula.length} curricula)';
}
