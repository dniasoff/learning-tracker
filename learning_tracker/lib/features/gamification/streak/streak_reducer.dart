/// `StreakReducer` — pure function that turns a sequence of
/// [StreakEvent]s into the derived state `(currentStreak, maxStreak)`.
///
/// Rules (Story 25.16, UTC boundaries only — no local-timezone math):
///
///   * Only `completion` events count.
///   * Each distinct UTC day with at least one completion is a "day".
///   * Two consecutive UTC days extend the run.
///   * Any gap of more than one UTC day resets the run to 1 on the
///     next completion.
///   * `currentStreak` reflects today's run: if `today` is more than
///     one UTC day past the most-recent completion the run has lapsed
///     and `currentStreak` is `0` (max survives).
library;

import 'package:learning_tracker/features/gamification/streak/streak_event.dart';

class StreakState {
  const StreakState({
    required this.currentStreak,
    required this.maxStreak,
    required this.lastCompletionDayUtc,
  });

  final int currentStreak;
  final int maxStreak;
  final DateTime? lastCompletionDayUtc;

  static const empty = StreakState(
    currentStreak: 0,
    maxStreak: 0,
    lastCompletionDayUtc: null,
  );
}

class StreakReducer {
  const StreakReducer();

  StreakState reduce(Iterable<StreakEvent> events, {required DateTime today}) {
    final todayUtc = _utcDay(today);

    final days = <DateTime>{};
    for (final e in events) {
      if (e.eventType != 'completion') continue;
      days.add(_utcDay(e.eventTimestamp));
    }
    if (days.isEmpty) return StreakState.empty;

    final ordered = days.toList()..sort();

    var maxRun = 1;
    var run = 1;
    for (var i = 1; i < ordered.length; i++) {
      final gap = ordered[i].difference(ordered[i - 1]).inDays;
      if (gap == 1) {
        run += 1;
      } else {
        run = 1;
      }
      if (run > maxRun) maxRun = run;
    }

    final lastDay = ordered.last;
    final gapToToday = todayUtc.difference(lastDay).inDays;
    // Run is "alive" iff the last completion is today or yesterday.
    final current = gapToToday <= 1 ? run : 0;

    return StreakState(
      currentStreak: current,
      maxStreak: maxRun,
      lastCompletionDayUtc: lastDay,
    );
  }

  static DateTime _utcDay(DateTime t) {
    final utc = t.isUtc ? t : t.toUtc();
    return DateTime.utc(utc.year, utc.month, utc.day);
  }
}
