/// The device lock of the lock surfaces (DNI-481): the overlay, the
/// notification suppression and the Mishna history all judge "locked now"
/// with the functions here, over `lockWindows` — the only window function
/// (AD-36). No second window calculation exists.
///
/// * The lock follows the PERSON USING THE DEVICE (product ruling
///   2026-10-05): the overlay window is the UNION of `lockWindows` over the
///   signed-in account's own learner profiles; a talmid viewed in a tutored
///   session never drives it.
/// * No location, no lock (`lockWindows`); a learner whose settings are
///   still loading or cannot be read is NOT locked and is judged again when
///   they arrive. Only settings that HAVE a location but whose zone or
///   window computation is corrupt still fail closed (NFR-6), widened to
///   every UTC offset ([widenedLockHistory]).
/// * The [SacredWindowKind] only picks the overlay's existing greeting and
///   background; it is classified from the lock's locked civil days.
library;

import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';

/// The zone id [widenedLockHistory] uses: deliberately absent from the tz
/// database, so `lockWindows` widens its fixed window to every UTC offset.
const String unresolvedLearnerZone = 'Etc/Unresolved_Learner';

/// The history a lock surface judges [history] by when its window
/// computation throws (NFR-6, only with a location): the latest settings,
/// in the unresolved zone, so the fixed window is widened to every UTC
/// offset. Null when those settings have no location (no location, no
/// lock).
LearnerSettingsHistory? widenedLockHistory(LearnerSettingsHistory history) {
  final last = history.spans.last.settings;
  if (!hasLockLocation(last)) return null;
  return LearnerSettingsHistory.constant(
    LearnerSettings(
      profileId: last.profileId,
      timeZone: unresolvedLearnerZone,
      latitude: last.latitude,
      longitude: last.longitude,
      inIsrael: last.inIsrael,
    ),
  );
}

/// How far ahead [nextLockChange] looks; every lock chain starts within it.
const Duration _lookAhead = Duration(days: 9);

/// The locks of [history] overlapping `[from, to]`; a history whose window
/// computation throws is judged by [widenedLockHistory] (none without a
/// location).
List<LockWindow> _locks(
  LearnerSettingsHistory history,
  DateTime from,
  DateTime to,
) {
  try {
    return lockWindows(history, from, to);
  } on Object {
    final widened = widenedLockHistory(history);
    return widened == null ? const [] : lockWindows(widened, from, to);
  }
}

/// The lock in force at [nowUtc] over the union of [histories], or null
/// when none of them is locked.
///
/// When several learners are locked, the lock that ends LAST is returned
/// (the overlay stays until every learner's lock has ended); its kind is
/// classified with that learner's history.
SacredWindow? sacredWindowAt(
  Iterable<LearnerSettingsHistory> histories,
  DateTime nowUtc,
) {
  final now = nowUtc.toUtc();
  (LockWindow, LearnerSettingsHistory)? best;
  for (final history in histories) {
    for (final lock in _locks(history, now, now)) {
      if (!lock.contains(now)) continue;
      if (best == null || lock.endUtc.isAfter(best.$1.endUtc)) {
        best = (lock, history);
      }
    }
  }
  if (best == null) return null;
  final (lock, history) = best;
  return SacredWindow(
    startUtc: lock.startUtc,
    endUtc: lock.endUtc,
    kind: classifyLock(lock, history),
    profileId: history.spans.last.settings.profileId,
    timeZone: history.at(lock.startUtc).timeZone,
  );
}

/// Whether any of [histories] is locked at [atUtc] (bounds inclusive).
bool isLockedAt(Iterable<LearnerSettingsHistory> histories, DateTime atUtc) =>
    sacredWindowAt(histories, atUtc) != null;

/// The first instant after [nowUtc] at which the union lock of [histories]
/// may change (a lock starts, or one microsecond after a lock ends), within
/// the next nine days; null when none does.
DateTime? nextLockChange(
  Iterable<LearnerSettingsHistory> histories,
  DateTime nowUtc,
) {
  final now = nowUtc.toUtc();
  DateTime? next;
  void consider(DateTime t) {
    if (t.isAfter(now) && (next == null || t.isBefore(next!))) next = t;
  }

  for (final history in histories) {
    for (final lock in _locks(history, now, now.add(_lookAhead))) {
      consider(lock.startUtc);
      consider(lock.endUtc.add(civilTick));
    }
  }
  return next;
}

/// The greeting kind of [lock]: Yom Kippur when it locks Yom Kippur, else
/// Shabbos & Yom Tov when it locks both, else Yom Tov or Shabbos — over
/// the lock's locked civil days (`lockedDays`, `in_israel` in force at the
/// lock's start). Shabbos when no day can be classified.
SacredWindowKind classifyLock(LockWindow lock, LearnerSettingsHistory history) {
  final inIsrael = history.at(lock.startUtc).inIsrael ?? false;
  var shabbos = false;
  var yomTov = false;
  var yomKippur = false;
  final Set<String> days;
  try {
    days = lockedDays(lock, history);
  } on Object {
    return SacredWindowKind.shabbos;
  }
  for (final day in days) {
    final calendar = JewishCalendar.fromDateTime(parseCivilDay(day))
      ..inIsrael = inIsrael;
    if (calendar.getYomTovIndex() == JewishCalendar.YOM_KIPPUR) {
      yomKippur = true;
    } else if (calendar.isYomTovAssurBemelacha()) {
      yomTov = true;
    }
    if (calendar.getDayOfWeek() == 7) shabbos = true;
  }
  if (yomKippur) return SacredWindowKind.yomKippur;
  if (shabbos && yomTov) return SacredWindowKind.shabbosYomTov;
  if (yomTov) return SacredWindowKind.yomTov;
  return SacredWindowKind.shabbos;
}
