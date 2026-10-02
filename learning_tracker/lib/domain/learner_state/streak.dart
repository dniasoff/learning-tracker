/// AD-40 streak: the civil day a learning event counts for, and the
/// per-curriculum streak built from those days.
///
/// The streak is per curriculum; `LearnerState` has no profile-wide
/// streak (deviation #13). Only counted `source = main` learn events of
/// the curriculum feed it, each on its [streakDay]:
///
/// * `dated` counts on `learned_on` iff `learned_on` is the civil date of
///   `effectiveAt(e)` — a backdated tick never repairs a streak;
/// * `catch_up` counts on `learned_on` iff `learned_on` is a locked day of
///   a lock L that ended before `effectiveAt(e)` and `effectiveAt(e)` is in
///   `catchUpWindow(L)` (outside any lock);
/// * `before_tracking`, sub-track sources and `void` events never count.
///
/// These functions live only here (`streak_events` is retired, R6).
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

/// The civil day [e] counts for in its curriculum's streak, or null when it
/// counts for none (AD-40; reads `effectiveAt`).
///
/// [locks] are the lock windows around the event, ascending and disjoint
/// as [lockWindows] returns them. The lock a `catch_up` event catches up
/// is the earlier lock (one that ended before the event) whose
/// [lockedDays] contain `learned_on`: with yom tov, a free Friday, then
/// Shabbos, a Sunday catch-up for the yom tov day still counts, because
/// that lock's window pauses through Shabbos. An event inside a lock never
/// counts (it is lock-ignored).
CivilDate? streakDay(
  LearningEvent e, {
  required LearnerSettingsHistory settingsHistory,
  required List<LockWindow> locks,
}) {
  if (!e.isLearn || e.source != LearningEvent.sourceMain) return null;
  final day = e.learnedOn;
  if (day == null) return null;
  final t = effectiveAt(e);
  if (insideLock(locks, t)) return null;
  switch (e.dateState) {
    case DateState.dated:
      return civilDate(t, settingsHistory) == day ? day : null;
    case DateState.catchUp:
      // A lock can only lock `day` if it overlaps that date in some zone
      // (UTC−12 … UTC+14): a cheap filter before the calendar checks.
      final dayKey = parseCivilDay(day);
      final near = dayKey.subtract(const Duration(days: 1));
      final far = dayKey.add(const Duration(days: 2));
      for (final lock in locks) {
        if (!lock.endUtc.isBefore(t)) break;
        if (lock.endUtc.isBefore(near) || lock.startUtc.isAfter(far)) {
          continue;
        }
        if (lockedDays(lock, settingsHistory).contains(day) &&
            catchUpWindow(lock, settingsHistory).contains(t)) {
          return day;
        }
      }
      return null;
    case DateState.beforeTracking:
    case null:
      return null;
  }
}

/// The per-curriculum streak (AD-40) of one curriculum's counted learn
/// events [countedLearns], evaluated at [nowUtc].
///
/// * A streak day is any [streakDay] of the events; duplicates, copies and
///   corrections of one day count once.
/// * `current` runs back from today. Today not (yet) learnt does not break
///   it, and neither does a locked day whose catch-up is still pending (it
///   is in a lock now, or [nowUtc] is inside its catch-up window); any
///   other missing day ends it.
/// * `best` is the longest run of consecutive streak days, and never less
///   than `current`.
/// * `lastDay` is the latest streak day.
///
/// [locks] must cover every event and the last weeks before [nowUtc]
/// (`engineLockWindows` with a look-back).
CurriculumStreak curriculumStreak(
  Iterable<LearningEvent> countedLearns, {
  required LearnerSettingsHistory settingsHistory,
  required List<LockWindow> locks,
  required DateTime nowUtc,
}) {
  final days = <DateTime>{
    for (final e in countedLearns)
      if (streakDay(e, settingsHistory: settingsHistory, locks: locks)
          case final day?)
        parseCivilDay(day),
  };
  if (days.isEmpty) return const CurriculumStreak(current: 0, best: 0);
  final sorted = days.toList()..sort();

  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in sorted) {
    run = previous != null && addCivilDays(previous, 1) == day ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }

  final pending = _pendingLockedDays(settingsHistory, locks, nowUtc);
  final today = parseCivilDay(civilDate(nowUtc, settingsHistory));
  var current = 0;
  var day = today;
  final earliest = sorted.first;
  while (!day.isBefore(earliest)) {
    if (days.contains(day)) {
      current++;
    } else if (day != today && !pending.contains(day)) {
      break;
    }
    day = addCivilDays(day, -1);
  }

  return CurriculumStreak(
    current: current,
    best: current > best ? current : best,
    lastDay: formatCivilDay(sorted.last),
  );
}

/// Locked days whose catch-up is still open at [nowUtc]: the days of a
/// lock [nowUtc] is inside, and of a lock whose catch-up window holds
/// [nowUtc].
Set<DateTime> _pendingLockedDays(
  LearnerSettingsHistory settingsHistory,
  List<LockWindow> locks,
  DateTime nowUtc,
) => {
  for (final lock in locks)
    if (!lock.startUtc.isAfter(nowUtc) &&
        (lock.contains(nowUtc) ||
            catchUpWindow(lock, settingsHistory).contains(nowUtc)))
      ...lockedDays(lock, settingsHistory).map(parseCivilDay),
};
