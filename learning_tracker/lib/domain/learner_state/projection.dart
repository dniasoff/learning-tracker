/// Engine stage 6d: the finish projection (AD-35 "Projection").
///
/// Velocity is the count of distinct leaves newly learnt per civil day
/// (`learned_on`), from `dated` and `catch_up` events, excluding chazara
/// (a `stage` above the first) and before-tracking. It is taken over the
/// trailing 28 days; with 14–27 days of tracked history over all of it;
/// under 14 days no projection is made. There is no pace reset: no input
/// restarts the window.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learnt_set.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

/// The fewest days of tracked history a projection needs.
const projectionMinHistoryDays = 14;

/// The trailing velocity window, in days.
const projectionWindowDays = 28;

/// The civil day each leaf was newly learnt, for the velocity.
///
/// A leaf is newly learnt on the earliest `learned_on` of its counted
/// `dated`/`catch_up` events that are not chazara (`stage` ≤
/// [firstStage]; a free tick or a sub-track event has no stage and counts).
/// A leaf covered by any counted `before_tracking` event was known before
/// tracking and is never newly learnt. Only leaves in the learner's corpus
/// ([inScope]) count.
Map<LeafRef, CivilDate> newlyLearntOn({
  required List<LearningEvent> countedLearns,
  required Corpus corpus,
  required bool Function(LeafRef leaf) inScope,
  required int? firstStage,
}) {
  final known = <LeafRef>{};
  final firstDay = <LeafRef, CivilDate>{};
  for (final e in countedLearns) {
    if (e.dateState == DateState.beforeTracking) {
      known.addAll(coveredLeaves(e, corpus));
      continue;
    }
    final day = e.learnedOn;
    final stage = e.stage;
    if (day == null ||
        (e.dateState != DateState.dated && e.dateState != DateState.catchUp) ||
        (stage != null && firstStage != null && stage > firstStage)) {
      continue;
    }
    for (final leaf in coveredLeaves(e, corpus)) {
      if (!inScope(leaf)) continue;
      final current = firstDay[leaf];
      if (current == null || day.compareTo(current) < 0) firstDay[leaf] = day;
    }
  }
  firstDay.removeWhere((leaf, _) => known.contains(leaf));
  return firstDay;
}

/// The projection of one curriculum on [today].
///
/// * Tracked history runs from [historyStart] (the `tracking_start_date`,
///   else the earliest `learned_on` of the curriculum's `dated`/`catch_up`
///   events) through [today]. Under [projectionMinHistoryDays] days (or
///   with no history) the status is [ProjectionStatus.tooEarly] with no
///   velocity.
/// * `velocityPerDay` = newly learnt leaves dated in the window ÷ window
///   days, the window being the trailing [projectionWindowDays] days, or
///   all history when shorter.
/// * `projectedFinish` = `today + ⌈remaining ÷ velocity⌉` days (DNI-494
///   AC-6), computed in integers as `⌈remaining × windowDays ÷ learnt⌉`
///   so no floating-point error moves the date; [today] when nothing
///   remains; null at zero velocity.
/// * During a lock the engine passes the civil day of the lock's start as
///   [today] (see [projectionDay]), so status and projection hold still
///   until the lock ends.
/// * Status: [ProjectionStatus.noDeadline] without a live [deadline];
///   otherwise [ProjectionStatus.onTrack] when the finish is on or before
///   `target_date`, else [ProjectionStatus.behindPace].
Projection deriveProjection({
  required Map<LeafRef, CivilDate> newlyLearnt,
  required CivilDate? historyStart,
  required CivilDate today,
  required int remaining,
  required DeadlineGoal? deadline,
}) {
  final start = historyStart;
  if (start == null) return const Projection(status: ProjectionStatus.tooEarly);
  final history = _days(start, today);
  if (history < projectionMinHistoryDays) {
    return const Projection(status: ProjectionStatus.tooEarly);
  }
  final windowStart = history >= projectionWindowDays
      ? shiftCivilDate(today, 1 - projectionWindowDays)
      : start;
  final windowDays = _days(windowStart, today);
  var learnt = 0;
  for (final day in newlyLearnt.values) {
    if (day.compareTo(windowStart) >= 0 && day.compareTo(today) <= 0) {
      learnt++;
    }
  }
  final velocity = learnt / windowDays;
  final CivilDate? finish;
  if (remaining <= 0) {
    finish = today;
  } else if (learnt == 0) {
    finish = null;
  } else {
    // ⌈remaining ÷ (learnt ÷ windowDays)⌉ in integers.
    final days = (remaining * windowDays + learnt - 1) ~/ learnt;
    finish = shiftCivilDate(today, days);
  }
  final ProjectionStatus status;
  if (deadline == null) {
    status = ProjectionStatus.noDeadline;
  } else if (finish != null && finish.compareTo(deadline.targetDate) <= 0) {
    status = ProjectionStatus.onTrack;
  } else {
    status = ProjectionStatus.behindPace;
  }
  return Projection(
    status: status,
    velocityPerDay: velocity,
    projectedFinish: finish,
  );
}

/// The civil day the projection is evaluated on at [nowUtc] (AD-35,
/// NFR-9, FR-23): while [nowUtc] is inside one of [locks], the civil day
/// of that lock's start, so status and projection stay as they were when
/// the lock began; otherwise `civilDate(nowUtc)`. After the lock ends the
/// next run evaluates on its own day again. [locks] are the engine run's
/// [lockWindows] (ascending, disjoint, true bounds).
CivilDate projectionDay({
  required List<LockWindow> locks,
  required DateTime nowUtc,
  required LearnerSettingsHistory settingsHistory,
}) {
  final lock = lockAt(locks, nowUtc);
  return civilDate(lock?.startUtc ?? nowUtc, settingsHistory);
}

/// The start of tracked history: [trackingStartDate], else the earliest
/// `learned_on` of [countedLearns]' `dated`/`catch_up` events, else null.
CivilDate? trackedHistoryStart(
  CivilDate? trackingStartDate,
  List<LearningEvent> countedLearns,
) {
  if (trackingStartDate != null) return trackingStartDate;
  CivilDate? earliest;
  for (final e in countedLearns) {
    final day = e.learnedOn;
    if (day == null ||
        (e.dateState != DateState.dated && e.dateState != DateState.catchUp)) {
      continue;
    }
    if (earliest == null || day.compareTo(earliest) < 0) earliest = day;
  }
  return earliest;
}

/// `days([a, b]) = b − a + 1` if `a ≤ b`, else 0 (AD-44).
int _days(CivilDate a, CivilDate b) {
  final diff = parseCivilDay(b).difference(parseCivilDay(a)).inDays;
  return diff < 0 ? 0 : diff + 1;
}
