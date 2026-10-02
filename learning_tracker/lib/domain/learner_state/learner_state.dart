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
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';

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
final class ReviewDue {
  /// Creates a review item.
  const ReviewDue(this.leaf, this.stageOrder);

  /// The leaf.
  final LeafRef leaf;

  /// The review stage order.
  final int stageOrder;

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
    this.capacity,
    this.expectedNewGround = 0,
    this.shortfall = 0,
  });

  /// The sub-track ULID.
  final String subTrackId;

  /// Whether it holds its ground off the main track.
  final bool holdsGround;

  /// Whether it counts in the main-track forecast.
  final bool inForecast;

  /// Whether it shows on the home screen.
  final bool onHome;

  /// The next unlearnt leaf of its ground, if any.
  final LeafRef? position;

  /// Whether every leaf of its ground is learnt.
  final bool groundExhausted;

  /// Remaining capacity in leaves, if bounded.
  final int? capacity;

  /// Leaves of ground it is expected to cover.
  final int expectedNewGround;

  /// Leaves it is behind.
  final int shortfall;

  @override
  bool operator ==(Object other) =>
      other is SubTrackState &&
      other.subTrackId == subTrackId &&
      other.holdsGround == holdsGround &&
      other.inForecast == inForecast &&
      other.onHome == onHome &&
      other.position == position &&
      other.groundExhausted == groundExhausted &&
      other.capacity == capacity &&
      other.expectedNewGround == expectedNewGround &&
      other.shortfall == shortfall;

  @override
  int get hashCode => Object.hash(
    subTrackId,
    holdsGround,
    inForecast,
    onHome,
    position,
    groundExhausted,
    capacity,
    expectedNewGround,
    shortfall,
  );

  @override
  String toString() => 'SubTrackState($subTrackId)';
}

/// The engine's view of one curriculum.
///
/// DNI-465 provides the real implementation; DNI-466, 467 and 468 fill the
/// lock, planning and points members.
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

  /// The unit the learner is in.
  NodeEntry? get currentUnit;

  /// The next main-track leaf.
  LeafRef? get mainTrackPosition;

  /// Sub-track states by sub-track ULID.
  Map<String, SubTrackState> get subTracks;

  /// The leaves the planner may schedule.
  List<LeafRef> get schedulableRefs;

  /// Main-track leaves still to learn.
  int get mainTrackRemaining;

  /// The program's assignments on [date].
  List<LeafRef> programAssignments(CivilDate date);

  /// Program assignments before [today] still unlearnt.
  List<LeafRef> programBacklog(CivilDate today);

  /// Reviews due on [date].
  List<ReviewDue> reviewsDue(CivilDate date);

  /// Today's target in leaves, if a goal sets one.
  int? get dailyTarget;

  /// The goal pace in leaves per day, if any.
  double? get paceRate;

  /// Leaves behind the goal, if any.
  int? get shortfall;

  /// The deadline projection, if computed.
  Projection? get projection;

  /// Completed units in completion order.
  List<CompletedUnit> get completedUnits;

  /// The curriculum streak, if computed.
  CurriculumStreak? get streak;
}

/// The whole learner's state at [nowUtc] (AD-35).
final class LearnerState {
  /// Creates a state.
  LearnerState({
    required this.nowUtc,
    required Map<String, CurriculumState> curricula,
    Set<String> countedEventIds = const {},
    Set<String> earningEventIds = const {},
    Set<String> lockIgnoredEventIds = const {},
    List<RejectedRow> rejectedRows = const [],
  }) : curricula = Map.unmodifiable(curricula),
       countedEventIds = Set.unmodifiable(countedEventIds),
       earningEventIds = Set.unmodifiable(earningEventIds),
       lockIgnoredEventIds = Set.unmodifiable(lockIgnoredEventIds),
       rejectedRows = List.unmodifiable(rejectedRows);

  /// A state with no curricula.
  factory LearnerState.empty(DateTime nowUtc) =>
      LearnerState(nowUtc: nowUtc, curricula: const {});

  /// The instant the state was computed for (UTC).
  final DateTime nowUtc;

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

  /// The state of [curriculumId], or null when it has none.
  CurriculumState? operator [](String curriculumId) => curricula[curriculumId];

  @override
  String toString() =>
      'LearnerState(${nowUtc.toIso8601String()}, '
      '${curricula.length} curricula)';
}
