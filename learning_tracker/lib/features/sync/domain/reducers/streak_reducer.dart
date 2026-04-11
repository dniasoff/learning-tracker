import 'package:learning_tracker/core/database/user/user_database.dart';

/// Derived streak state produced by replaying a profile's streak event log.
class StreakState {
  const StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.lastCompletionDate,
  });

  final int currentStreak;
  final int longestStreak;
  final DateTime? lastCompletionDate;

  static const empty = StreakState(
    currentStreak: 0,
    longestStreak: 0,
    lastCompletionDate: null,
  );
}

/// Pure reducer: replay [events] (unsorted) and compute current state.
///
/// Rules:
///   - `completion` on a new UTC day extends or restarts the streak
///   - `completion` on the same UTC day as the last completion is a no-op
///   - gap of more than one UTC day → streak resets to 1 on the next
///     completion
///   - `day_boundary` events are a hint for future use; they don't
///     change state on their own today but the reducer tolerates them
///   - `manual_adjust` with `xpDelta`-style `eventType` isn't part of
///     the streak log — ignored if it appears
StreakState reduceStreakEvents(Iterable<StreakEvent> events) {
  final sorted = events.toList()
    ..sort((a, b) => a.eventTimestamp.compareTo(b.eventTimestamp));

  var current = 0;
  var longest = 0;
  DateTime? lastDay;

  for (final e in sorted) {
    if (e.eventType != 'completion') continue;
    final day = DateTime.utc(
      e.eventTimestamp.year,
      e.eventTimestamp.month,
      e.eventTimestamp.day,
    );

    if (lastDay == null) {
      current = 1;
    } else {
      final gap = day.difference(lastDay).inDays;
      if (gap == 0) {
        continue; // same-day completion, no streak change
      } else if (gap == 1) {
        current += 1;
      } else {
        current = 1;
      }
    }
    if (current > longest) longest = current;
    lastDay = day;
  }

  return StreakState(
    currentStreak: current,
    longestStreak: longest,
    lastCompletionDate: lastDay,
  );
}
