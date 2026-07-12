/// `StreakReducer` — pure function that turns a sequence of
/// [StreakLogEvent]s into the derived state `(currentStreak, maxStreak)`.
///
/// Rules (Story 25.16 + D16 — LOCAL day boundaries, matching the rest of the
/// app: `LocalDayClock`, the scheduler, and the streak-calendar feed which all
/// bucket by local day via `DateUtils.extractLocalDate`):
///
///   * Only `completion` events count.
///   * Each distinct LOCAL day with at least one completion is a "day".
///   * Two consecutive LOCAL days extend the run.
///   * Any gap of more than one LOCAL day resets the run to 1 on the
///     next completion.
///   * `currentStreak` reflects today's run: if `today` is more than
///     one LOCAL day past the most-recent completion the run has lapsed
///     and `currentStreak` is `0` (max survives).
library;

import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/gamification/streak/streak_log_event.dart';

class StreakState {
  const StreakState({
    required this.currentStreak,
    required this.maxStreak,
    required this.lastCompletionDayLocal,
  });

  final int currentStreak;
  final int maxStreak;

  /// Local-day midnight of the most-recent completion (null when there are
  /// no completions). D16: this is a LOCAL date, not UTC — it matches the
  /// calendar feed's `DateUtils.extractLocalDate`.
  final DateTime? lastCompletionDayLocal;

  static const empty = StreakState(
    currentStreak: 0,
    maxStreak: 0,
    lastCompletionDayLocal: null,
  );
}

class StreakReducer {
  const StreakReducer();

  /// Reduce [events] into a [StreakState] relative to [today].
  ///
  /// [dayOf] maps a timestamp to its day bucket and defaults to
  /// [DateUtils.extractLocalDate] (LOCAL day). It is injectable so tests can
  /// pin a fixed UTC offset deterministically without depending on the host
  /// machine's timezone (the D16 regression contrasts local vs UTC bucketing).
  StreakState reduce(
    Iterable<StreakLogEvent> events, {
    required DateTime today,
    DateTime Function(DateTime)? dayOf,
  }) {
    final toDay = dayOf ?? DateUtils.extractLocalDate;
    final todayDay = toDay(today);

    final days = <DateTime>{};
    for (final e in events) {
      if (e.eventType != 'completion') continue;
      days.add(toDay(e.eventTimestamp));
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
    final gapToToday = todayDay.difference(lastDay).inDays;
    // Run is "alive" iff the last completion is today or yesterday.
    final current = gapToToday <= 1 ? run : 0;

    return StreakState(
      currentStreak: current,
      maxStreak: maxRun,
      lastCompletionDayLocal: lastDay,
    );
  }
}
