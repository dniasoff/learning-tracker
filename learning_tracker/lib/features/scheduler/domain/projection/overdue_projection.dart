/// Pure overdue projection — the `project()` function.
///
/// Architecture §4:
///   overdue   = { units scheduled before today } − { completed }
///   dueToday  = { units scheduled for today }    − { completed }
///
/// This file is the domain layer: pure Dart, no Flutter, no Riverpod,
/// no Drift, no Firebase.
library;

import 'package:learning_tracker/features/scheduler/domain/projection/overdue_types.dart';

/// Compute the overdue projection from a schedule and a completion set.
///
/// Parameters:
///   [schedule]    — the ordered list of [ScheduledUnit]s for the track,
///                   as returned by [programSchedule] or [selfPacedSchedule].
///   [completions] — the set of sefariaRefs the learner has completed (at
///                   any stage — callers filter to the relevant stage before
///                   passing this in, if needed).
///   [today]       — the reference date (UTC, midnight).
///
/// Returns a [ProjectionResult] with three disjoint sets of sefariaRefs.
/// The [review] bucket is intentionally left empty — it requires
/// stage-completion timing data computed by the scheduler engine; later
/// waves will populate it.
///
/// The function is pure: same inputs always produce the same output.
/// It does not read the clock, the DB, or any external source.
ProjectionResult project({
  required List<ScheduledUnit> schedule,
  required Set<String> completions,
  required DateTime today,
}) {
  final todayDay = _dayOnly(today);

  final overdue = <String>{};
  final dueToday = <String>{};

  for (final unit in schedule) {
    final d = _dayOnly(unit.date);
    if (d.isBefore(todayDay)) {
      // Overdue: scheduled before today and not completed.
      if (!completions.contains(unit.sefariaRef)) {
        overdue.add(unit.sefariaRef);
      }
    } else if (d == todayDay) {
      // Due today: scheduled for today and not completed.
      if (!completions.contains(unit.sefariaRef)) {
        dueToday.add(unit.sefariaRef);
      }
    }
    // Units scheduled in the future are ignored.
  }

  return ProjectionResult(
    overdue: overdue,
    dueToday: dueToday,
    review: const {},
  );
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Strips time from a DateTime, returning UTC midnight for the same date.
DateTime _dayOnly(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);
