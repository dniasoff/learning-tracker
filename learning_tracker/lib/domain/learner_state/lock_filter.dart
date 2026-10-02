/// Engine stage 0: the AD-36 lock-ignore rule ("enforced again by
/// derivation").
///
/// An event whose `effectiveAt` falls inside a lock window computed with
/// the settings in force at that instant is lock-ignored: the counted-event
/// stage drops it before the learnt set, progress, position, streak,
/// siyum and points are derived, and the engine reports its id in
/// `LearnerState.lockIgnoredEventIds` so history can label it "kept, not
/// counted — recorded during Shabbos/Yom Tov". Undo is never offered for
/// it (AD-36).
library;

import 'package:learning_tracker/domain/learner_state/counted_events.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

/// The lock windows one engine run needs: every lock that overlaps an
/// event's `effectiveAt` or the span from [lookBack] before [nowUtc] to
/// [nowUtc] (the streak reads recent locks), ascending and disjoint.
List<LockWindow> engineLockWindows(
  LearnerSettingsHistory settingsHistory,
  Iterable<LearningEvent> events,
  DateTime nowUtc, {
  Duration lookBack = Duration.zero,
}) {
  var lo = nowUtc.toUtc().subtract(lookBack);
  var hi = nowUtc.toUtc();
  for (final e in events) {
    final t = effectiveAt(e);
    if (t.isBefore(lo)) lo = t;
    if (t.isAfter(hi)) hi = t;
  }
  return lockWindows(settingsHistory, lo, hi);
}

/// Whether [t] lies inside one of [locks] (ascending and disjoint, as
/// [lockWindows] returns them). Bounds are inside (closed intervals).
bool insideLock(List<LockWindow> locks, DateTime t) {
  var lo = 0;
  var hi = locks.length - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    final lock = locks[mid];
    if (t.isBefore(lock.startUtc)) {
      hi = mid - 1;
    } else if (t.isAfter(lock.endUtc)) {
      lo = mid + 1;
    } else {
      return true;
    }
  }
  return false;
}

/// The [LockIgnoreHook] for [locks]: an event is ignored iff its
/// `effectiveAt` is inside a lock (either kind: a lock-ignored `void`
/// cancels nothing).
LockIgnoreHook lockIgnoreHook(List<LockWindow> locks) {
  if (locks.isEmpty) return noLockIgnored;
  return (event) => insideLock(locks, effectiveAt(event));
}
