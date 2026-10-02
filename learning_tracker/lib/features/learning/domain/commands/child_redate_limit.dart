/// The FR-4 child re-date limit (AD-40).
///
/// A child session (parent PIN locked) may re-date an event only to a
/// locked day L-day, and only while `nowUtc` is inside `catchUpWindow(L)`
/// of the lock that locked that day. Outside it the child may only remove
/// (void). A parent has no such limit.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

/// Whether a child may re-date an event to [learnedOn] at [nowUtc].
///
/// The locked day being corrected is [learnedOn]: it must be in
/// `lockedDays(L)` of a lock L that ended before [nowUtc] (searched back
/// [catchUpReach], which always reaches the lock a catch-up window
/// follows), and [nowUtc] must be inside `catchUpWindow(L)`. A null
/// [learnedOn] (`before_tracking`) is never a locked day.
bool childMayRedate({
  required CivilDate? learnedOn,
  required LearnerSettingsHistory settingsHistory,
  required DateTime nowUtc,
}) {
  if (learnedOn == null) return false;
  final now = nowUtc.toUtc();
  final locks = lockWindows(settingsHistory, now.subtract(catchUpReach), now);
  for (final lock in locks.reversed) {
    if (!lock.endUtc.isBefore(now)) continue;
    if (!lockedDays(lock, settingsHistory).contains(learnedOn)) continue;
    return catchUpWindow(lock, settingsHistory).contains(now);
  }
  return false;
}
