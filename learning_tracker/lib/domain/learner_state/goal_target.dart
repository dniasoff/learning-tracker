/// Engine stage 6c: the goal-driven daily target and pace (AD-43, AD-44).
///
/// The engine reads only the fixed-id goal docs: `goals/{c}_deadline` for
/// the forecast and `goals/{c}_pace` for `paceRate`. `target_percent` is
/// retired (a deadline always covers the whole AD-42 corpus) and is not an
/// input. Calendar-program curricula take their target from the calendar
/// instead (`calendar_plan.dart`).
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

/// `pace_unit` storage value of a weekly pace.
const perWeekPaceUnit = 'per_week';

/// The live deadline goal of [goals], or null when absent or ended.
DeadlineGoal? liveDeadline(CurriculumGoals? goals) {
  final deadline = goals?.deadline;
  return deadline == null || deadline.endedAt != null ? null : deadline;
}

/// The live pace goal of [goals], or null when absent or ended.
PaceGoal? livePace(CurriculumGoals? goals) {
  final pace = goals?.pace;
  return pace == null || pace.endedAt != null ? null : pace;
}

/// AD-44 `dailyTarget`:
/// `max(0, ceil(numerator ÷ studyDaysToDeadline))`, or `max(0, numerator)`
/// when the divisor is 0 (a deadline today on a non-study day, or past).
///
/// `studyDaysToDeadline` counts the dates in `[today, target_date]` whose
/// weekday is a study day in [studyDays]. A target is never negative
/// (B13 default 5, DNI-494).
///
/// [numerator] is `mainTrackRemaining − Σ expectedNewGround(s) +
/// Σ shortfall(s)` over the curriculum's `holdsGround` sub-tracks; the
/// engine passes the main track's remaining at the start of [today]
/// (`mainTrackAtStartOf(today)`, the no-sub-track case; DNI-477), since the
/// divisor counts [today] too, and DNI-494 adds the sub-track terms.
int deadlineDailyTarget({
  required int numerator,
  required DeadlineGoal deadline,
  required StudyDays studyDays,
  required CivilDate today,
}) {
  final divisor = studyDays.countStudyDays(today, deadline.targetDate);
  if (divisor == 0) return numerator < 0 ? 0 : numerator;
  final target = (numerator / divisor).ceil();
  return target < 0 ? 0 : target;
}

/// `paceRate` in leaves per study day, from the pace goal (AD-43).
///
/// * `pace_value` units of `pace_granularity` per `pace_unit`.
/// * A granularity naming a ContentIndex level converts at the average
///   number of in-scope leaves per node of that level (Mishnayos `perek` ≈
///   leaves per perek); a granularity that names no level of [corpus] (or
///   the leaf level) counts leaves.
/// * `per_week` spreads the weekly amount over the week's study days (all
///   seven by default; one when every day is review-only, matching the
///   AD-44 zero-divisor rule); any other unit is per study day.
double paceRateOf({
  required PaceGoal pace,
  required Corpus corpus,
  required bool Function(LeafRef leaf) inScope,
  required StudyDays studyDays,
}) {
  final perUnit = _leavesPerUnit(corpus, pace.paceGranularity, inScope);
  final amount = pace.paceValue.toDouble() * perUnit;
  if (pace.paceUnit != perWeekPaceUnit) return amount;
  final days = studyDays.studyWeekdays.length;
  return amount / (days == 0 ? 1 : days);
}

double _leavesPerUnit(
  Corpus corpus,
  String level,
  bool Function(LeafRef leaf) inScope,
) {
  var nodes = 0;
  var leaves = 0;
  void walk(NodeEntry node) {
    if (node.level == level) {
      final n = corpus.leavesUnder(node).where(inScope).length;
      if (n > 0) {
        nodes++;
        leaves += n;
      }
      return;
    }
    corpus.childrenOf(node).forEach(walk);
  }

  corpus.roots.forEach(walk);
  return nodes == 0 ? 1 : leaves / nodes;
}
