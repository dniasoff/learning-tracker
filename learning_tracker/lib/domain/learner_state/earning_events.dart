/// Engine stage 7: points eligibility, `earningEventIds` (AD-50).
///
/// The engine is the only authority on which learn events earn points.
/// Writers attach a `pts_{eventId}` ledger row to every `source = main`
/// `dated`/`catch_up` learn event; the balance then counts a row only while
/// its event is in [curriculumEarningEventIds] (see `points.dart`).
///
/// An event earns when it is either:
///
/// * the **first learning** of a leaf: the earliest counted learn event of
///   any source and date state covering that leaf, by (`effectiveAt`, id),
///   and that event is `source = main` and `dated` or `catch_up`
///   ([firstLearningEarners]); a `before_tracking` node event covers every
///   leaf under its node, so it blocks earning for all of them.
///
/// Only counted events (not voided, not lock-ignored; `counted_events.dart`)
/// take part, so a void or a lock window removes an event from both the
/// ordering and the result.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';

/// Whether [event] is the kind of learn event that can earn points: a
/// `source = main` event that is `dated` or `catch_up` (AD-50, the event
/// writers attach a `pts_` row to).
bool canEarn(LearningEvent event) =>
    event.isLearn &&
    event.source == LearningEvent.sourceMain &&
    (event.dateState == DateState.dated ||
        event.dateState == DateState.catchUp);

/// The counted learn events of one curriculum that earn first-learning
/// points (AD-50, `prd-deviations` #5).
///
/// Per leaf of [corpus], only the earliest event covering it (by
/// `effectiveAt`, then id) can earn, and only when [canEarn] holds for it. A
/// sub-track or `before_tracking` (leaf or node) event that comes first
/// blocks earning for that leaf; a later main tick never earns it. An event
/// covering several new leaves earns once.
///
/// [countedLearns] are the curriculum's counted `learn` events; they are
/// ordered here, so the caller's order does not matter. Leaves are resolved
/// with `coveredLeaves` (the learnt-set rule) and are not limited to the
/// current scope, so a later scope change never moves past earning.
Set<String> firstLearningEarners(
  Iterable<LearningEvent> countedLearns,
  Corpus corpus,
) {
  final ordered = [...countedLearns]..sort(compareEventsByEffectiveAt);
  final seen = <LeafRef>{};
  final out = <String>{};
  for (final e in ordered) {
    var first = false;
    for (final leaf in coveredLeaves(e, corpus)) {
      if (seen.add(leaf)) first = true;
    }
    if (first && canEarn(e)) out.add(e.id);
  }
  return out;
}

/// The earning event ids of one curriculum (AD-50).
Set<String> curriculumEarningEventIds({
  required Iterable<LearningEvent> countedLearns,
  required Corpus corpus,
}) => firstLearningEarners(countedLearns, corpus);
