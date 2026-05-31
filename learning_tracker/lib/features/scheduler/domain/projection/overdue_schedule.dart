/// Pure schedule generators for the overdue projection.
///
/// These functions produce the list of [ScheduledUnit]s that a track expects
/// to have been covered by a given date.  They are pure: no I/O, no DB
/// access, no clock reads.  Every input is an explicit parameter.
///
/// Architecture references:
///   §4  — "overdue is a pure projection"
///   §5.1 — Schedule: program tracks and self-paced tracks
///   §10.1 — sefariaRef stability
///   §10.3 — self-paced needs an explicit pace
library;

import 'package:learning_tracker/features/scheduler/domain/projection/overdue_types.dart';

// ---------------------------------------------------------------------------
// Program-track schedule
// ---------------------------------------------------------------------------

/// Returns the ordered list of [ScheduledUnit]s spanning [anchor, today]
/// inclusive for a program-calendar track.
///
/// Each entry pairs a calendar date with the calendar unit for that date.
/// The caller supplies [calendarEntries] — a list of `(date, sefariaRef)`
/// pairs already fetched from the calendar engine; this function does not
/// perform I/O.
///
/// Convention (O2):
///   • The schedule is [anchor, today] inclusive.
///   • The LAST entry in the returned list is "today's unit".
///   • Every earlier entry is an overdue unit.
///   • A program anchored N days before today with no completions yields
///     N overdue units + 1 today unit.
///
/// Parameters:
///   [anchor] — the tracking start date (UTC, midnight). Units from this
///     date onward are included.
///   [calendarEntries] — ordered list of `(date, sefariaRef)` covering at
///     least [anchor, today].  Entries outside [anchor, today] are silently
///     ignored.
///   [today] — the reference date (UTC, midnight).
List<ScheduledUnit> programSchedule({
  required DateTime anchor,
  required List<(DateTime date, String sefariaRef)> calendarEntries,
  required DateTime today,
}) {
  final anchorDay = _dayOnly(anchor);
  final todayDay = _dayOnly(today);

  final result = <ScheduledUnit>[];
  for (final (date, ref) in calendarEntries) {
    final d = _dayOnly(date);
    if (d.isBefore(anchorDay)) continue;
    if (d.isAfter(todayDay)) continue;
    result.add(ScheduledUnit(date: d, sefariaRef: ref));
  }

  // Sort ascending so today is last (matches O2 convention).
  result.sort((a, b) => a.date.compareTo(b.date));
  return result;
}

// ---------------------------------------------------------------------------
// Self-paced schedule
// ---------------------------------------------------------------------------

/// Returns the list of [ScheduledUnit]s for a self-paced track.
///
/// Formula (§5.1):
///   `expected_position(date) = pace × elapsed_study_days(anchor, date)`
///
/// The schedule assigns `pace` new refs per study day, walking forward
/// through [orderedRefs] from position 0 at [anchor].  Each study day
/// adds [pace] units to the expected position.  The schedule only includes
/// dates that are study days per [studyDayPattern].
///
/// Parameters:
///   [anchor]          — the date on which the track started (UTC, midnight).
///   [pace]            — the explicit pace (units per study day, integer ≥ 1).
///                       MUST NOT be null — [MissingPaceError] is thrown if
///                       it is null (architecture §10.3).
///   [studyDayPattern] — which weekdays are study days.
///   [orderedRefs]     — the stable ordered list of curriculum leaf refs
///                       (sefariaRef strings, never numeric indices — §10.1).
///   [today]           — the reference date (UTC, midnight).
///
/// Returns a flat list of [ScheduledUnit]s, one per (date, ref) pair, in
/// chronological order.  Each study day in [anchor, today] contributes
/// exactly [pace] units (clamped to the available refs).
///
/// Throws [MissingPaceError] when [pace] is null.
/// [paceWindowStudyDays] is the denominator of the pace: [pace] units accrue
/// per [paceWindowStudyDays] study days. The default (1) preserves the legacy
/// "[pace] units every study day" behaviour for per-day paces. A weekly pace
/// passes the week's study-day count (e.g. 7), so `pace=1, window=7` schedules
/// exactly one ref per 7 study days instead of one per study day (B2 — a
/// sub-weekly pace must NOT be inflated to 1/study-day).
List<ScheduledUnit> selfPacedSchedule({
  required DateTime anchor,
  required int? pace,
  int paceWindowStudyDays = 1,
  required StudyDayPattern studyDayPattern,
  required List<String> orderedRefs,
  required DateTime today,
}) {
  if (pace == null) throw MissingPaceError();
  if (pace <= 0) {
    throw ArgumentError.value(pace, 'pace', 'Pace must be a positive integer.');
  }
  final window = paceWindowStudyDays < 1 ? 1 : paceWindowStudyDays;

  final anchorDay = _dayOnly(anchor);
  final todayDay = _dayOnly(today);

  if (todayDay.isBefore(anchorDay)) return const [];
  if (orderedRefs.isEmpty) return const [];

  final result = <ScheduledUnit>[];
  var refIndex = 0;
  var cursor = anchorDay;
  // Exact integer accumulation: [pace] units accrue per [window] study days.
  // window=1 → [pace] refs every study day (legacy); window=N → [pace] refs
  // every N study days. Integer math avoids the float error a fractional
  // per-study-day rate would introduce (e.g. 1/7 × 7 = 0.9999…).
  var accumulator = 0;

  while (!cursor.isAfter(todayDay)) {
    if (studyDayPattern.isStudyDay(cursor.weekday)) {
      accumulator += pace;
      final assignCount = accumulator ~/ window;
      accumulator -= assignCount * window;
      for (var i = 0; i < assignCount && refIndex < orderedRefs.length; i++) {
        result.add(
          ScheduledUnit(date: cursor, sefariaRef: orderedRefs[refIndex]),
        );
        refIndex++;
      }
      if (refIndex >= orderedRefs.length) break; // All refs scheduled.
    }
    cursor = cursor.add(const Duration(days: 1));
  }

  return result;
}

// ---------------------------------------------------------------------------
// Elapsed study day counter (used by O7 formula verification)
// ---------------------------------------------------------------------------

/// Counts the number of study days in the half-open interval [anchor, today).
///
/// "Elapsed" means strictly before [today] — this is used to compute how
/// many units the learner is expected to have finished before today starts.
///
/// Both [anchor] and [today] are normalised to UTC midnight before counting.
int elapsedStudyDays({
  required DateTime anchor,
  required DateTime today,
  required StudyDayPattern studyDayPattern,
}) {
  final anchorDay = _dayOnly(anchor);
  final todayDay = _dayOnly(today);

  var count = 0;
  var cursor = anchorDay;
  while (cursor.isBefore(todayDay)) {
    if (studyDayPattern.isStudyDay(cursor.weekday)) count++;
    cursor = cursor.add(const Duration(days: 1));
  }
  return count;
}

// ---------------------------------------------------------------------------
// Private helpers
// ---------------------------------------------------------------------------

/// Strips time from a DateTime, returning UTC midnight for the same date.
DateTime _dayOnly(DateTime dt) => DateTime.utc(dt.year, dt.month, dt.day);
