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

/// How long before a `catch_up` event the lock it catches up can have
/// ended: a catch-up window ends within 16 civil days of its lock's end
/// (`catchUpWindow` skips at most 14 lock-touched days), so 21 days
/// always reaches the preceding lock.
const Duration catchUpReach = Duration(days: 21);

/// The lock windows one engine run needs, ascending and disjoint: every
/// lock that overlaps an event's `effectiveAt`, the [catchUpReach] before
/// a `catch_up` learn (so `streakDay` finds the earlier lock it catches
/// up, however old the event), or the span from [lookBack] before
/// [nowUtc] to [nowUtc] (the streak reads recent locks).
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
    final from = e.isLearn && e.dateState == DateState.catchUp
        ? t.subtract(catchUpReach)
        : t;
    if (from.isBefore(lo)) lo = from;
    if (t.isAfter(hi)) hi = t;
  }
  return lockWindows(settingsHistory, lo, hi);
}

/// The sorted, disjoint union of lock windows computed from multiple
/// settings histories. Each source window still comes from [lockWindows].
List<LockWindow> mergeLockWindows(Iterable<LockWindow> windows) {
  final sorted = windows.toList()
    ..sort((a, b) => a.startUtc.compareTo(b.startUtc));
  if (sorted.isEmpty) return const [];
  final merged = <LockWindow>[sorted.first];
  for (final next in sorted.skip(1)) {
    final last = merged.last;
    if (!next.startUtc.isAfter(last.endUtc)) {
      merged[merged.length - 1] = LockWindow(
        last.startUtc,
        next.endUtc.isAfter(last.endUtc) ? next.endUtc : last.endUtc,
      );
    } else {
      merged.add(next);
    }
  }
  return List.unmodifiable(merged);
}

/// Whether [t] lies inside one of [locks] (ascending and disjoint, as
/// [lockWindows] returns them). Bounds are inside (closed intervals).
bool insideLock(List<LockWindow> locks, DateTime t) => lockAt(locks, t) != null;

/// The lock of [locks] (ascending and disjoint, as [lockWindows] returns
/// them) that contains [t], or null. Bounds are inside (closed intervals).
/// A lookup over the windows [lockWindows] computed, not a second window
/// function (AD-36).
LockWindow? lockAt(List<LockWindow> locks, DateTime t) {
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
      return lock;
    }
  }
  return null;
}

/// The [LockIgnoreHook] for [locks]: an event is ignored iff its
/// `effectiveAt` is inside a lock (either kind: a lock-ignored `void`
/// cancels nothing).
LockIgnoreHook lockIgnoreHook(List<LockWindow> locks) {
  if (locks.isEmpty) return noLockIgnored;
  return (event) => insideLock(locks, effectiveAt(event));
}
