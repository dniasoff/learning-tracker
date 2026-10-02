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
/// * a **scheduled review**: per (leaf, stage above the first), the earliest
///   counted `source = main` `dated`/`catch_up` event carrying that stage
///   whose pair is in `reviewsDue` on the event's earning date
///   ([reviewEarners]). The review schedule computes every step under the
///   stage and study-day settings in force at the time (AD-35), so changing
///   the settings later never changes past earning.
///
/// Only counted events (not voided, not lock-ignored; `counted_events.dart`)
/// take part, so a void or a lock window removes an event from both the
/// ordering and the result.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/review_schedule.dart';

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

/// The first stage order in force at an instant, or null with no stage.
typedef FirstStageAt = int? Function(DateTime instantUtc);

/// The civil date a review event is judged on (AD-50 "reviewsDue(civilDate(
/// effectiveAt(e)))").
///
/// A `dated` event is judged on `civilDate(effectiveAt(e))`. A `catch_up`
/// event is judged on its `learned_on`, the locked day it catches up and
/// counts on (AD-40); judged on its recording day, the review it completes
/// would already be closed and a caught-up review could never earn.
CivilDate reviewEarningDate(
  LearningEvent event,
  LearnerSettingsHistory settingsHistory,
) {
  final learnedOn = event.learnedOn;
  if (event.dateState == DateState.catchUp && learnedOn != null) {
    return learnedOn;
  }
  return civilDate(effectiveAt(event), settingsHistory);
}

/// The counted learn events of one curriculum that earn review points
/// (AD-50).
///
/// Per (leaf, stage) with stage above the first stage order in force at
/// the event ([firstStageAt]), the earliest counted [canEarn] leaf event
/// carrying that stage earns when (leaf, stage) is in
/// `reviews.dueOn(reviewEarningDate(e))`. An attempt that is not due does
/// not use up the pair: a later due attempt can still earn it. Once a pair
/// has earned, its repeats never do.
Set<String> reviewEarners({
  required Iterable<LearningEvent> countedLearns,
  required Corpus corpus,
  required ReviewSchedule reviews,
  required FirstStageAt firstStageAt,
  required LearnerSettingsHistory settingsHistory,
}) {
  final ordered = [...countedLearns]..sort(compareEventsByEffectiveAt);
  final dueByDate = <CivilDate, Set<ReviewDue>>{};
  final earned = <ReviewDue>{};
  final out = <String>{};
  for (final e in ordered) {
    final stage = e.stage;
    final ref = e.ref;
    if (!canEarn(e) || stage == null || ref == null || e.level != null) {
      continue;
    }
    final node = corpus.nodeForRef(ref);
    if (node == null || !corpus.isLeaf(node)) continue;
    final first = firstStageAt(effectiveAt(e));
    if (first == null || stage <= first) continue;
    final pair = ReviewDue(ref, stage);
    if (earned.contains(pair)) continue;
    final date = reviewEarningDate(e, settingsHistory);
    final due = dueByDate.putIfAbsent(date, () => reviews.dueOn(date).toSet());
    if (due.contains(pair)) {
      earned.add(pair);
      out.add(e.id);
    }
  }
  return out;
}

/// The earning event ids of one curriculum (AD-50): first-learning earners
/// plus, when the curriculum has a review schedule, review earners.
Set<String> curriculumEarningEventIds({
  required Iterable<LearningEvent> countedLearns,
  required Corpus corpus,
  required LearnerSettingsHistory settingsHistory,
  ReviewSchedule? reviews,
  FirstStageAt? firstStageAt,
}) => {
  ...firstLearningEarners(countedLearns, corpus),
  if (reviews != null && firstStageAt != null)
    ...reviewEarners(
      countedLearns: countedLearns,
      corpus: corpus,
      reviews: reviews,
      firstStageAt: firstStageAt,
      settingsHistory: settingsHistory,
    ),
};
