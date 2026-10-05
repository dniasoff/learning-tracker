/// The device lock of the lock surfaces (DNI-481): the overlay, the
/// notification suppression and the Mishna history all judge "locked now"
/// with the functions here, over `lockWindows` — the only window function
/// (AD-36). No second window calculation exists.
///
/// * The overlay window is the UNION of `lockWindows` over every learner
///   whose lock drives the device (every learner profile of the signed-in
///   account, plus the talmid of an active tutored session).
/// * A learner whose settings cannot be read (still loading, or an error)
///   is judged with [failClosedSettingsHistory]: the no-location fixed
///   window in the device's zone (the unknown-zone widening only when the
///   device zone is unknown too), never "unlocked".
/// * The [SacredWindowKind] only picks the overlay's existing greeting and
///   background; it is classified from the lock's locked civil days.
library;

import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';

/// The zone id [failClosedSettingsHistory] uses: deliberately absent from
/// the tz database, so `lockWindows` widens its fixed window to every UTC
/// offset.
const String unresolvedLearnerZone = 'Etc/Unresolved_Learner';

/// The settings history a lock surface judges a learner by while that
/// learner's real settings cannot be read (AD-36 fail closed, NFR-6): no
/// location (the FR-23 Fri 12:00 → Sun 01:00 learner-local fallback and
/// its yom tov equivalent) and diaspora yom tov (a superset of the Israel
/// days), never "unlocked".
///
/// The zone is [deviceZone] — the device's IANA zone, the same zone a
/// profile is seeded with on creation (AD-37) — when it resolves in the tz
/// database, so the lock follows the real local Shabbos / Yom Tov times.
/// Only when no usable device zone is known is the zone unresolved, which
/// widens the fixed window to every UTC offset. (Hotfix ruling, see
/// `decisions-for-user.md`: settings that are merely unavailable must not
/// lock a London learner from Thursday night to Sunday afternoon.)
LearnerSettingsHistory failClosedSettingsHistory(
  String profileId, {
  String? deviceZone,
}) => LearnerSettingsHistory.constant(
  LearnerSettings(
    profileId: profileId,
    timeZone: deviceZone != null && LearnerZone.of(deviceZone).isKnown
        ? deviceZone
        : unresolvedLearnerZone,
  ),
);

/// How far ahead [nextLockChange] looks; every lock chain starts within it.
const Duration _lookAhead = Duration(days: 9);

/// The locks of [history] overlapping `[from, to]`; a history whose window
/// computation throws is judged by [failClosedSettingsHistory].
List<LockWindow> _locks(
  LearnerSettingsHistory history,
  DateTime from,
  DateTime to,
) {
  try {
    return lockWindows(history, from, to);
  } on Object {
    final profileId = history.spans.last.settings.profileId;
    return lockWindows(failClosedSettingsHistory(profileId), from, to);
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
