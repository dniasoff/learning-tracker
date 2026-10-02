/// Read-side projections of the engine's [LearnerState] for the progress,
/// lifetime and Browse surfaces (DNI-474, AD-35 "Reads").
///
/// Nothing here derives learner state: the learnt set, tri-state and
/// completed units come from the engine. These functions only select,
/// union (composite display curricula) and bucket what the engine already
/// derived, including its counted learn events
/// ([LearnerState.countedLearns]) for activity over time and the PRD
/// "chazara" derived count (AD-32: never stored).
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/tri_state.dart';

/// The engine's learnt leaves of [curriculumId], or none without a state.
///
/// With [subsetIds] (a composite display curriculum such as Tanach over
/// Chumash and Nach) the subsets' learnt leaves that are leaves of
/// [corpus] are added: a leaf has the same ref in every curriculum, so it
/// counts once (I-4).
Set<LeafRef> learntLeavesFor(
  LearnerState? state,
  String curriculumId, {
  Iterable<String> subsetIds = const [],
  Corpus? corpus,
}) {
  final own = state?[curriculumId]?.learntLeaves ?? const <LeafRef>{};
  if (subsetIds.isEmpty || state == null) return own;
  final leaves = corpus?.leaves.toSet();
  return {
    ...own,
    for (final subset in subsetIds)
      for (final leaf in state[subset]?.learntLeaves ?? const <LeafRef>{})
        if (leaves == null || leaves.contains(leaf)) leaf,
  };
}

/// How much of [node] is learnt: the engine's [CurriculumState.triState]
/// when [learnt] is the engine's own set, otherwise the engine's
/// [triStateOf] rule over [corpus] (composite display curricula).
TriState learntTriState(
  NodeEntry node, {
  required Corpus corpus,
  required Set<LeafRef> learnt,
}) => triStateOf(corpus.leavesUnder(node), learnt);

/// Learnt and total leaves under [node].
({int learnt, int total}) learntCount(
  NodeEntry node, {
  required Corpus corpus,
  required Set<LeafRef> learnt,
}) {
  final leaves = corpus.leavesUnder(node);
  return (learnt: leaves.where(learnt.contains).length, total: leaves.length);
}

/// The counted learn events of [curricula] (every curriculum when null), in
/// the engine's event order.
Iterable<LearningEvent> countedLearnsOf(
  LearnerState? state, {
  Set<String>? curricula,
}) {
  if (state == null) return const [];
  if (curricula == null) return state.countedLearns;
  return state.countedLearns.where((e) => curricula.contains(e.curriculumId));
}

/// The counted learning of one leaf.
final class LeafActivity {
  /// Creates the summary.
  const LeafActivity({
    required this.events,
    required this.firstAt,
    required this.firstDateState,
    required this.lastAt,
    this.trackedEvents = 0,
    this.stages = const {},
  });

  /// Counted learn events covering the leaf (a node event counts once).
  final int events;

  /// `effectiveAt` of the first counted learn.
  final DateTime firstAt;

  /// The date state of the first counted learn.
  final DateState firstDateState;

  /// `effectiveAt` of the latest counted learn.
  final DateTime lastAt;

  /// Counted learn events learnt while tracking (`dated` or `catch_up`).
  final int trackedEvents;

  /// The `stage` orders of the main-track events covering the leaf.
  final Set<int> stages;

  /// The PRD "chazara" derived count: every counted learn after the first.
  int get chazaros => events - 1;

  /// Whether the leaf was first learnt before tracking (a backfill).
  bool get firstBeforeTracking => firstDateState == DateState.beforeTracking;
}

/// Per-leaf counted learning of [corpus]'s leaves, from the counted learn
/// events of [curricula] (default: the corpus' own curriculum). Events whose
/// ref is not in [corpus] are skipped.
Map<LeafRef, LeafActivity> leafActivityOf(
  LearnerState? state,
  Corpus corpus, {
  Set<String>? curricula,
}) {
  final out = <LeafRef, _LeafAccumulator>{};
  for (final event in countedLearnsOf(
    state,
    curricula: curricula ?? {corpus.curriculumId},
  )) {
    final at = effectiveAt(event);
    for (final leaf in coveredLeaves(event, corpus)) {
      final acc = out[leaf] ??= _LeafAccumulator(at, event.dateState!);
      acc
        ..events += 1
        ..lastAt = at;
      if (event.dateState != DateState.beforeTracking) acc.trackedEvents += 1;
      if (event.stage case final stage?) acc.stages.add(stage);
    }
  }
  return {
    for (final MapEntry(:key, :value) in out.entries)
      key: LeafActivity(
        events: value.events,
        firstAt: value.firstAt,
        firstDateState: value.firstDateState,
        lastAt: value.lastAt,
        trackedEvents: value.trackedEvents,
        stages: Set.unmodifiable(value.stages),
      ),
  };
}

final class _LeafAccumulator {
  _LeafAccumulator(this.firstAt, this.firstDateState) : lastAt = firstAt;

  final DateTime firstAt;
  final DateState firstDateState;
  DateTime lastAt;
  int events = 0;
  int trackedEvents = 0;
  final Set<int> stages = {};
}

/// The local calendar day an event was learnt on: its `learned_on` civil
/// date as a local midnight. Null for `before_tracking` (no day).
DateTime? learnedOnDay(LearningEvent event) {
  final day = event.learnedOn;
  if (day == null) return null;
  final parts = day.split('-');
  if (parts.length != 3) return null;
  return DateTime(
    int.parse(parts[0]),
    int.parse(parts[1]),
    int.parse(parts[2]),
  );
}

/// Counted learning on one day.
final class DayActivity {
  /// Creates an empty day.
  DayActivity();

  /// Counted learn events learnt on the day.
  int events = 0;

  /// Events that learnt at least one leaf for the first time (limud).
  int limudim = 0;

  /// Events on leaves already learnt before them (PRD chazara).
  int chazaros = 0;

  /// Leaves learnt for the first time that day.
  int newLeaves = 0;
}

/// Counted learning per local day (dated and catch_up events, by
/// `learned_on`), for [curricula] (every curriculum when null).
///
/// An event is a limud when it learns a leaf for the first time, else a
/// chazara; `before_tracking` events have no day but still make later
/// learning of their leaves a chazara. [corpusFor] resolves node events;
/// without a corpus an event counts for its own ref.
Map<DateTime, DayActivity> dailyActivityOf(
  LearnerState? state, {
  Set<String>? curricula,
  Corpus? Function(String curriculumId)? corpusFor,
}) {
  final seen = <String>{};
  final out = <DateTime, DayActivity>{};
  for (final event in countedLearnsOf(state, curricula: curricula)) {
    final corpus = corpusFor?.call(event.curriculumId!);
    final leaves = corpus == null
        ? [if (event.level == null) ?event.ref]
        : coveredLeaves(event, corpus);
    var fresh = 0;
    for (final leaf in leaves) {
      if (seen.add('${event.curriculumId}|$leaf')) fresh++;
    }
    final day = learnedOnDay(event);
    if (day == null) continue;
    final bucket = out[day] ??= DayActivity();
    bucket
      ..events += 1
      ..newLeaves += fresh;
    if (fresh > 0) {
      bucket.limudim += 1;
    } else {
      bucket.chazaros += 1;
    }
  }
  return out;
}

/// The latest `effectiveAt` of a counted learn of [curricula], or null.
DateTime? lastLearntAt(LearnerState? state, {Set<String>? curricula}) {
  DateTime? latest;
  for (final event in countedLearnsOf(state, curricula: curricula)) {
    final at = effectiveAt(event);
    if (latest == null || at.isAfter(latest)) latest = at;
  }
  return latest;
}

/// The PRD "chazara" derived count over [curricula] (every curriculum when
/// null): counted learn events that learn no leaf for the first time. With
/// [trackedOnly], only `dated` and `catch_up` events are counted (a
/// before-tracking mark still makes later learning a repeat).
int chazaraCount(
  LearnerState? state, {
  Set<String>? curricula,
  Corpus? Function(String curriculumId)? corpusFor,
  bool trackedOnly = false,
}) {
  final seen = <String>{};
  var count = 0;
  for (final event in countedLearnsOf(state, curricula: curricula)) {
    final corpus = corpusFor?.call(event.curriculumId!);
    final leaves = corpus == null
        ? [if (event.level == null) ?event.ref]
        : coveredLeaves(event, corpus);
    var fresh = false;
    for (final leaf in leaves) {
      if (seen.add('${event.curriculumId}|$leaf')) fresh = true;
    }
    if (fresh) continue;
    if (trackedOnly && event.dateState == DateState.beforeTracking) continue;
    count++;
  }
  return count;
}
