/// The engine's real [CurriculumState] (DNI-465), composed of per-stage
/// sub-records so later engine stories extend it without touching the
/// stages that are already done.
///
/// | Stage | Record | Owner |
/// | --- | --- | --- |
/// | learnt set, scope, tri-state | [LearntRecord] | DNI-465 |
/// | main-track position | [MainTrackRecord] | DNI-465 (DNI-467 adds order and held ground) |
/// | completed units | [completedUnits] | DNI-465 |
/// | plan: calendar, reviews, goal target, pace, projection | [PlanRecord] | DNI-467 (sub-track states: DNI-493/494) |
/// | streak | [streak] | DNI-466 |
library;

import 'package:learning_tracker/domain/learner_state/calendar_plan.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/review_schedule.dart';
import 'package:learning_tracker/domain/learner_state/tri_state.dart';

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _setEquals<T>(Set<T> a, Set<T> b) =>
    identical(a, b) || (a.length == b.length && a.containsAll(b));

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final MapEntry(:key, :value) in a.entries) {
    if (!b.containsKey(key) || b[key] != value) return false;
  }
  return true;
}

/// The learnt-set stage of one curriculum (AD-31, AD-32, AD-42).
final class LearntRecord {
  /// Creates the record.
  LearntRecord({
    required this.corpus,
    required List<LeafRef> scopedLeaves,
    required Set<LeafRef> learntLeaves,
  }) : scopedLeaves = List.unmodifiable(scopedLeaves),
       _scoped = Set.unmodifiable(scopedLeaves),
       learntLeaves = Set.unmodifiable(learntLeaves);

  /// A curriculum without a corpus: nothing can be resolved, so nothing is
  /// learnt (unknown refs never become learnt).
  LearntRecord.none()
    : corpus = null,
      scopedLeaves = const [],
      _scoped = const {},
      learntLeaves = const {};

  /// The unscoped ContentIndex corpus, or null when none was supplied.
  final Corpus? corpus;

  /// The learner's corpus, `ContentIndex ∩ curriculum_scope`, in
  /// ContentIndex order.
  final List<LeafRef> scopedLeaves;

  final Set<LeafRef> _scoped;

  /// Leaves of [scopedLeaves] with at least one counted `learn` event.
  final Set<LeafRef> learntLeaves;

  /// Whether [leaf] is in the learner's corpus.
  bool inScope(LeafRef leaf) => _scoped.contains(leaf);

  @override
  bool operator ==(Object other) =>
      other is LearntRecord &&
      identical(other.corpus, corpus) &&
      _listEquals(other.scopedLeaves, scopedLeaves) &&
      _setEquals(other.learntLeaves, learntLeaves);

  @override
  int get hashCode => Object.hash(
    identityHashCode(corpus),
    Object.hashAll(scopedLeaves),
    Object.hashAllUnordered(learntLeaves),
  );
}

/// The main-track stage of one curriculum (AD-33). Empty for a curriculum
/// that is not evaluated.
final class MainTrackRecord {
  /// Creates the record.
  MainTrackRecord({
    required List<LeafRef> schedulableRefs,
    this.currentUnit,
    this.position,
  }) : schedulableRefs = List.unmodifiable(schedulableRefs);

  /// No position, nothing schedulable.
  const MainTrackRecord.none()
    : schedulableRefs = const [],
      currentUnit = null,
      position = null;

  /// The leaves the planner may schedule, in AD-33 order.
  final List<LeafRef> schedulableRefs;

  /// The FR-12a unit the learner is in, while it has a schedulable leaf.
  final NodeEntry? currentUnit;

  /// The next main-track leaf.
  final LeafRef? position;

  @override
  bool operator ==(Object other) =>
      other is MainTrackRecord &&
      _listEquals(other.schedulableRefs, schedulableRefs) &&
      other.currentUnit == currentUnit &&
      other.position == position;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(schedulableRefs), currentUnit, position);
}

/// The planning stage of one curriculum (DNI-467). Empty for a curriculum
/// that is not evaluated.
final class PlanRecord {
  /// Creates the record.
  PlanRecord({
    this.subTracks = const {},
    this.calendar,
    this.reviews,
    this.dailyTarget,
    this.paceRate,
    this.shortfall,
    this.projection,
    Set<CurriculumValidationError> validationErrors = const {},
  }) : validationErrors = Set.unmodifiable(validationErrors);

  /// No plan.
  const PlanRecord.none()
    : subTracks = const {},
      calendar = null,
      reviews = null,
      dailyTarget = null,
      paceRate = null,
      shortfall = null,
      projection = null,
      validationErrors = const {};

  /// Sub-track states by sub-track ULID.
  final Map<String, SubTrackState> subTracks;

  /// The calendar plan, for a calendar-program curriculum only.
  final CalendarPlan? calendar;

  /// The AD-32 review schedule.
  final ReviewSchedule? reviews;

  /// Today's target in leaves.
  final int? dailyTarget;

  /// The goal pace in leaves per study day.
  final double? paceRate;

  /// Leaves behind the goal.
  final int? shortfall;

  /// The deadline projection.
  final Projection? projection;

  /// Invalid intent found while planning.
  final Set<CurriculumValidationError> validationErrors;

  @override
  bool operator ==(Object other) =>
      other is PlanRecord &&
      _mapEquals(other.subTracks, subTracks) &&
      other.calendar == calendar &&
      other.reviews == reviews &&
      other.dailyTarget == dailyTarget &&
      other.paceRate == paceRate &&
      other.shortfall == shortfall &&
      other.projection == projection &&
      _setEquals(other.validationErrors, validationErrors);

  @override
  int get hashCode => Object.hash(
    subTracks.length,
    calendar,
    reviews,
    dailyTarget,
    paceRate,
    shortfall,
    projection,
    Object.hashAllUnordered(validationErrors),
  );
}

/// The engine's [CurriculumState] for one curriculum.
final class DerivedCurriculumState implements CurriculumState {
  /// Creates the state from its stage records.
  DerivedCurriculumState({
    required this.curriculumId,
    required this.evaluated,
    required this.learnt,
    this.mainTrack = const MainTrackRecord.none(),
    List<CompletedUnit> completedUnits = const [],
    this.plan = const PlanRecord.none(),
    this.streak,
  }) : completedUnits = List.unmodifiable(completedUnits);

  @override
  final String curriculumId;

  @override
  final bool evaluated;

  /// The learnt-set stage.
  final LearntRecord learnt;

  /// The main-track stage.
  final MainTrackRecord mainTrack;

  /// The planning stage (DNI-467).
  final PlanRecord plan;

  @override
  final List<CompletedUnit> completedUnits;

  @override
  final CurriculumStreak? streak;

  @override
  Set<LeafRef> get learntLeaves => learnt.learntLeaves;

  @override
  int get distinctLearnt => learnt.learntLeaves.length;

  @override
  TriState triState(NodeEntry node) {
    final corpus = learnt.corpus;
    if (corpus == null) return TriState.empty;
    return triStateOf(
      corpus.leavesUnder(node).where(learnt.inScope),
      learnt.learntLeaves,
    );
  }

  @override
  NodeEntry? get currentUnit => mainTrack.currentUnit;

  @override
  LeafRef? get mainTrackPosition => mainTrack.position;

  @override
  List<LeafRef> get schedulableRefs => mainTrack.schedulableRefs;

  @override
  int get mainTrackRemaining => mainTrack.schedulableRefs.length;

  @override
  Map<String, SubTrackState> get subTracks => plan.subTracks;

  @override
  List<LeafRef> programAssignments(CivilDate date) =>
      plan.calendar?.assignments(date) ?? const [];

  @override
  List<LeafRef> programBacklog(CivilDate today) =>
      plan.calendar?.backlog(today) ?? const [];

  @override
  List<ReviewDue> reviewsDue(CivilDate date) =>
      plan.reviews?.dueOn(date) ?? const [];

  @override
  int? get dailyTarget => plan.dailyTarget;

  @override
  double? get paceRate => plan.paceRate;

  @override
  int? get shortfall => plan.shortfall;

  @override
  Projection? get projection => plan.projection;

  @override
  Set<CurriculumValidationError> get validationErrors => plan.validationErrors;

  @override
  bool operator ==(Object other) =>
      other is DerivedCurriculumState &&
      other.curriculumId == curriculumId &&
      other.evaluated == evaluated &&
      other.learnt == learnt &&
      other.mainTrack == mainTrack &&
      _listEquals(other.completedUnits, completedUnits) &&
      other.plan == plan &&
      other.streak == streak;

  @override
  int get hashCode => Object.hash(
    curriculumId,
    evaluated,
    learnt,
    mainTrack,
    Object.hashAll(completedUnits),
    plan,
    streak,
  );

  @override
  String toString() =>
      'DerivedCurriculumState($curriculumId, evaluated: $evaluated, '
      'learnt: $distinctLearnt)';
}
