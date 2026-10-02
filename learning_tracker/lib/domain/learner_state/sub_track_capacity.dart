/// AD-44 sub-track capacity arithmetic (DNI-494): the pure helpers the
/// engine's deadline forecast (`sub_track_forecast.dart`) uses.
///
/// All intervals are inclusive AD-41 civil dates. Capacity is counted in
/// the curriculum's ContentIndex leaf units (`rate_per_week` is in those
/// units, prd-deviations #12), never in a Mishnayos-specific unit.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// The `windowLengthDays` of an ongoing sub-track (AD-44).
const ongoingWindowLengthDays = 365;

/// Absorbs binary floating-point error before flooring, so a product that
/// is mathematically an integer (`10 × 39 × 334 ÷ 334`) floors to itself.
const double _floorTolerance = 1e-9;

/// AD-44 `days([a, b])`: `b − a + 1` if `a ≤ b`, else 0.
int civilDays(CivilDate a, CivilDate b) {
  final diff = parseCivilDay(b).difference(parseCivilDay(a)).inDays;
  return diff < 0 ? 0 : diff + 1;
}

/// The AD-44 capacity interval of [s] on [today] against the deadline
/// [targetDate]: `[max(today, window_start), min(window_end, target_date)]`,
/// an open `window_end` using [targetDate]. May be empty (start after end).
({CivilDate start, CivilDate end}) capacityInterval(
  SubTrack s, {
  required CivilDate today,
  required CivilDate targetDate,
}) {
  final start = today.compareTo(s.windowStart) >= 0 ? today : s.windowStart;
  final windowEnd = s.windowEnd;
  final end = windowEnd == null || targetDate.compareTo(windowEnd) <= 0
      ? targetDate
      : windowEnd;
  return (start: start, end: end);
}

/// AD-44 `windowLengthDays`: `days([window_start, window_end])` for a
/// school-year sub-track, [ongoingWindowLengthDays] for an ongoing one.
///
/// A school-year sub-track always has a `window_end` (AD-52 validation);
/// should one arrive without it, or with a reversed window, it is prorated
/// as ongoing rather than dividing by zero.
int windowLengthDays(SubTrack s) {
  final windowEnd = s.windowEnd;
  if (s.type != SubTrackType.schoolYear || windowEnd == null) {
    return ongoingWindowLengthDays;
  }
  final days = civilDays(s.windowStart, windowEnd);
  return days == 0 ? ongoingWindowLengthDays : days;
}

/// AD-44 `activeWeeksLeft = weeks_per_year × days(interval) ÷
/// windowLengthDays` over [capacityInterval]; 0 when it is empty.
double activeWeeksLeft(
  SubTrack s, {
  required CivilDate today,
  required CivilDate targetDate,
}) {
  final interval = capacityInterval(s, today: today, targetDate: targetDate);
  final days = civilDays(interval.start, interval.end);
  return s.weeksPerYear * days / windowLengthDays(s);
}

/// AD-44 `capacity = floor(rate_per_week × activeWeeksLeft)`, in leaf
/// units; 0 when the capacity interval is empty (or the product is
/// negative).
///
/// The product is formed as `rate × weeks × days ÷ windowLengthDays` with
/// one division, then floored: the FR-19 fixture
/// `floor(10 × 39 × 304 ÷ 334)` is 354.
int subTrackCapacity(
  SubTrack s, {
  required CivilDate today,
  required CivilDate targetDate,
}) {
  final interval = capacityInterval(s, today: today, targetDate: targetDate);
  final days = civilDays(interval.start, interval.end);
  if (days == 0) return 0;
  final raw = s.ratePerWeek * s.weeksPerYear * days / windowLengthDays(s);
  final capacity = (raw + _floorTolerance).floor();
  return capacity < 0 ? 0 : capacity;
}
