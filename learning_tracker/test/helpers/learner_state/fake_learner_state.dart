/// A settable [CurriculumState] and a [LearnerState] builder for tests
/// written against the C0 (DNI-524) contract.
///
/// The fakes are not the spec (C0 contract-change protocol, rule 4): the
/// owner story's tests are. If the real engine diverges from what a fake
/// does, the owner story updates the fake in the same commit.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';

/// The fixed instant [fakeLearnerState] uses when none is given (TQ-6: no
/// wall clock in tests).
final fakeLearnerStateNow = DateTime.utc(2026, 9, 1, 12);

/// A [CurriculumState] whose every member is a constructor parameter with
/// an empty or zero default.
///
/// Date-keyed queries read a `Map<CivilDate, List<...>>` (missing date →
/// empty); [triState] reads [triStates] (missing node → [TriState.empty]).
/// [distinctLearnt] defaults to `learntLeaves.length`. [evaluated]
/// defaults to true, because a fake standing in for an engine run is an
/// evaluated curriculum; pass false to model a corpus that is not ready.
final class FakeCurriculumState implements CurriculumState {
  /// Creates the fake.
  FakeCurriculumState({
    this.curriculumId = '',
    this.evaluated = true,
    this.learntLeaves = const {},
    int? distinctLearnt,
    this.triStates = const {},
    this.currentUnit,
    this.mainTrackPosition,
    this.subTracks = const {},
    this.schedulableRefs = const [],
    this.mainTrackRemaining = 0,
    this.assignments = const {},
    this.backlog = const {},
    this.reviews = const {},
    this.dailyTarget,
    this.paceRate,
    this.shortfall,
    this.projection,
    this.completedUnits = const [],
    this.streak,
  }) : distinctLearnt = distinctLearnt ?? learntLeaves.length;

  @override
  final String curriculumId;

  @override
  final bool evaluated;

  @override
  final Set<LeafRef> learntLeaves;

  @override
  final int distinctLearnt;

  /// [triState] answers, by node.
  final Map<NodeEntry, TriState> triStates;

  @override
  final NodeEntry? currentUnit;

  @override
  final LeafRef? mainTrackPosition;

  @override
  final Map<String, SubTrackState> subTracks;

  @override
  final List<LeafRef> schedulableRefs;

  @override
  final int mainTrackRemaining;

  /// [programAssignments] answers, by date.
  final Map<CivilDate, List<LeafRef>> assignments;

  /// [programBacklog] answers, by `today`.
  final Map<CivilDate, List<LeafRef>> backlog;

  /// [reviewsDue] answers, by date.
  final Map<CivilDate, List<ReviewDue>> reviews;

  @override
  final int? dailyTarget;

  @override
  final double? paceRate;

  @override
  final int? shortfall;

  @override
  final Projection? projection;

  @override
  final List<CompletedUnit> completedUnits;

  @override
  final CurriculumStreak? streak;

  @override
  TriState triState(NodeEntry node) => triStates[node] ?? TriState.empty;

  @override
  List<LeafRef> programAssignments(CivilDate date) =>
      assignments[date] ?? const [];

  @override
  List<LeafRef> programBacklog(CivilDate today) => backlog[today] ?? const [];

  @override
  List<ReviewDue> reviewsDue(CivilDate date) => reviews[date] ?? const [];
}

/// A [LearnerState] with empty defaults at [fakeLearnerStateNow].
LearnerState fakeLearnerState({
  Map<String, CurriculumState> curricula = const {},
  Set<String> countedEventIds = const {},
  Set<String> earningEventIds = const {},
  Set<String> lockIgnoredEventIds = const {},
  List<RejectedRow> rejectedRows = const [],
  DateTime? nowUtc,
}) => LearnerState(
  nowUtc: nowUtc ?? fakeLearnerStateNow,
  curricula: curricula,
  countedEventIds: countedEventIds,
  earningEventIds: earningEventIds,
  lockIgnoredEventIds: lockIgnoredEventIds,
  rejectedRows: rejectedRows,
);
