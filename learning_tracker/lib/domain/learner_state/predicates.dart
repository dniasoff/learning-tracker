/// AD-34 sub-track activity predicates, evaluated on a civil day.
///
/// The only implementation (AD-34): main-track remaining, the schedulable
/// set and the AD-44 numerator use [holdsGround]; home rows use [onHome];
/// the forecast uses [inForecast].
///
/// Dates are AD-41 civil dates (`YYYY-MM-DD`), which order correctly as
/// strings. A null `window_end` is +∞ in every predicate; only AD-44
/// capacity substitutes `target_date` for it, and that substitution is
/// inside [inForecast]'s capacity interval only.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// Whether [s] holds its ground (keeps it off the main track) on [today]:
/// `!ended_at && today ≤ window_end`.
///
/// True for a future-start sub-track: its ground leaves the main track as
/// soon as it is created (AD-34, prd-deviations #4).
bool holdsGround(SubTrack s, CivilDate today) =>
    !s.isEnded && _onOrBefore(today, s.windowEnd);

/// Whether [s] shows on the home screen on [today]:
/// `!ended_at && window_start ≤ today ≤ window_end`.
bool onHome(SubTrack s, CivilDate today) =>
    !s.isEnded &&
    s.windowStart.compareTo(today) <= 0 &&
    _onOrBefore(today, s.windowEnd);

/// Whether [s] counts in the main-track forecast on [today], given the
/// curriculum [deadline]: `holdsGround && capacity interval non-empty`.
///
/// The AD-44 capacity interval is
/// `[max(today, window_start), min(window_end, target_date)]`. Here an open
/// `window_end` uses [deadline]; with no deadline as well the end is +∞
/// and the interval is non-empty.
bool inForecast(SubTrack s, CivilDate today, {required CivilDate? deadline}) {
  if (!holdsGround(s, today)) return false;
  final start = today.compareTo(s.windowStart) >= 0 ? today : s.windowStart;
  final end = _minDate(s.windowEnd, deadline);
  return _onOrBefore(start, end);
}

/// `a ≤ b`, where a null [b] is +∞.
bool _onOrBefore(CivilDate a, CivilDate? b) => b == null || a.compareTo(b) <= 0;

/// The earlier of [a] and [b], where null is +∞.
CivilDate? _minDate(CivilDate? a, CivilDate? b) {
  if (a == null) return b;
  if (b == null) return a;
  return a.compareTo(b) <= 0 ? a : b;
}
