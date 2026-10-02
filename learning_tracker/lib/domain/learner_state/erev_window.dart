/// The erev window (Story 3.1, DNI-504): the unlocked stretch before the
/// next Shabbos / yom-tov lock in which Learn shows what is planned for the
/// locked days.
///
/// Pure: it reads only [lockWindows] and [lockedDays] (AD-36, AD-40), the
/// only window functions, so the banner's lock time is the same instant
/// the capture gate and the lock overlay use, fallbacks included (AC-6).
/// It computes no new lock and no window constant.
///
/// ## Interval (assumption A-1)
///
/// The erev window of the next lock `L` is `[00:00 learner-local on the
/// civil day L starts, L.start)`, with the civil day in the `time_zone` in
/// force at `L.start` (AD-41). The view is absent before it, and from
/// `L.start` onward (the lock overlay covers the app then, deviation #10).
/// A chained lock (yom tov into Shabbos) is one [LockWindow], so there is
/// no erev view on its inner days (AC-4).
///
/// ## Settings
///
/// The settings history decides everything: the lock `L` and its locked
/// days use the settings in force at `L.start`. A settings change recorded
/// before `L.start` (an `in_israel` change, a move) is in force at
/// `L.start`, so the planned days follow it live (AC-5).
library;

import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

/// What a locked civil day is, for its label.
enum LockedDayKind {
  /// A Shabbos that is not yom tov.
  shabbos,

  /// A yom tov that is not Shabbos (and not Yom Kippur).
  yomTov,

  /// A yom tov that falls on Shabbos.
  yomTovShabbos,

  /// Yom Kippur (on any weekday).
  yomKippur,
}

/// What the whole lock is, for the erev banner's label.
enum ErevKind {
  /// Only Shabbos.
  shabbos,

  /// Only yom tov.
  yomTov,

  /// Yom tov and Shabbos in one lock (chained, or yom tov on Shabbos).
  yomTovAndShabbos,

  /// Yom Kippur.
  yomKippur,
}

/// One locked civil day of an erev window's lock.
final class LockedDay {
  /// Creates the day.
  const LockedDay({required this.date, required this.kind});

  /// The learner-local civil date (`YYYY-MM-DD`).
  final CivilDate date;

  /// What the day is.
  final LockedDayKind kind;

  /// The weekday of [date] (`DateTime.monday` .. `DateTime.sunday`).
  int get weekday => parseCivilDay(date).weekday;

  @override
  bool operator ==(Object other) =>
      other is LockedDay && other.date == date && other.kind == kind;

  @override
  int get hashCode => Object.hash(date, kind);

  @override
  String toString() => 'LockedDay($date, ${kind.name})';
}

/// The erev view's data at one instant: the next lock, when the erev
/// window opened, and the lock's locked days in order.
final class ErevWindow {
  /// Creates the window.
  ErevWindow({
    required this.lock,
    required this.erevStartUtc,
    required this.lockStartLocal,
    required List<LockedDay> lockedDays,
  }) : lockedDays = List.unmodifiable(lockedDays);

  /// The lock `L` this erev precedes, exactly as [lockWindows] returned it.
  final LockWindow lock;

  /// 00:00 learner-local on the civil day `L` starts (assumption A-1).
  final DateTime erevStartUtc;

  /// `L.start` as the learner's wall clock reads it (zone in force at
  /// `L.start`): a display key, not an instant ([LearnerZone.wallTimeOf]).
  final DateTime lockStartLocal;

  /// The locked civil days of `L` ([lockedDays]), ascending. Empty only if
  /// the calendar names none (never for a real lock).
  final List<LockedDay> lockedDays;

  /// What the lock is, from its locked days.
  ErevKind get kind {
    final kinds = {for (final d in lockedDays) d.kind};
    if (kinds.contains(LockedDayKind.yomKippur)) return ErevKind.yomKippur;
    final shabbos =
        kinds.contains(LockedDayKind.shabbos) ||
        kinds.contains(LockedDayKind.yomTovShabbos);
    final yomTov =
        kinds.contains(LockedDayKind.yomTov) ||
        kinds.contains(LockedDayKind.yomTovShabbos);
    if (shabbos && yomTov) return ErevKind.yomTovAndShabbos;
    if (yomTov) return ErevKind.yomTov;
    return ErevKind.shabbos;
  }

  @override
  bool operator ==(Object other) {
    if (other is! ErevWindow ||
        other.lock != lock ||
        other.erevStartUtc != erevStartUtc ||
        other.lockStartLocal != lockStartLocal ||
        other.lockedDays.length != lockedDays.length) {
      return false;
    }
    for (var i = 0; i < lockedDays.length; i++) {
      if (other.lockedDays[i] != lockedDays[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    lock,
    erevStartUtc,
    lockStartLocal,
    Object.hashAll(lockedDays),
  );

  @override
  String toString() =>
      'ErevWindow($lock, erev from ${erevStartUtc.toIso8601String()}, '
      '$lockedDays)';
}

/// How far ahead the next lock is searched. Locks are at most a week
/// apart, so a week and a day always reaches the next one.
const Duration _lookAhead = Duration(days: 8);

/// The next lock that starts after [nowUtc], or null when [nowUtc] is
/// inside a lock or none starts within the look-ahead.
LockWindow? _nextLock(LearnerSettingsHistory history, DateTime nowUtc) {
  final now = nowUtc.toUtc();
  for (final window in lockWindows(history, now, now.add(_lookAhead))) {
    if (window.contains(now)) return null;
    if (window.startUtc.isAfter(now)) return window;
  }
  return null;
}

/// 00:00 learner-local on the civil day [lock] starts.
DateTime _erevStart(LockWindow lock, LearnerSettingsHistory history) {
  final zone = LearnerZone.of(history.at(lock.startUtc).timeZone);
  return zone.startOf(zone.dayOf(lock.startUtc));
}

/// The erev window in force at [nowUtc], or null outside it: before
/// 00:00 learner-local on the day the next lock starts, inside a lock, and
/// from the lock's start onward (AC-1, AC-4).
///
/// Throws whatever [lockWindows] throws; callers fail closed (no erev
/// view; the gate and overlay decide the lock themselves).
ErevWindow? erevWindowAt(LearnerSettingsHistory history, DateTime nowUtc) {
  final now = nowUtc.toUtc();
  final lock = _nextLock(history, now);
  if (lock == null) return null;
  final erevStart = _erevStart(lock, history);
  if (now.isBefore(erevStart)) return null;
  final settings = history.at(lock.startUtc);
  final zone = LearnerZone.of(settings.timeZone);
  final inIsrael = settings.inIsrael ?? false;
  final days = lockedDays(lock, history).toList()..sort();
  return ErevWindow(
    lock: lock,
    erevStartUtc: erevStart,
    lockStartLocal: zone.wallTimeOf(lock.startUtc),
    lockedDays: [
      for (final d in days) LockedDay(date: d, kind: _kindOf(d, inIsrael)),
    ],
  );
}

/// The next instant after [nowUtc] at which [erevWindowAt] may change:
/// the next lock's start while in its erev window, the erev start before
/// it, and null when no lock starts within the look-ahead or [nowUtc] is
/// inside a lock (the lock's end is the overlay's business; callers
/// re-check periodically).
DateTime? nextErevTransition(LearnerSettingsHistory history, DateTime nowUtc) {
  final now = nowUtc.toUtc();
  final lock = _nextLock(history, now);
  if (lock == null) return null;
  final erevStart = _erevStart(lock, history);
  return now.isBefore(erevStart) ? erevStart : lock.startUtc;
}

LockedDayKind _kindOf(CivilDate date, bool inIsrael) {
  final day = parseCivilDay(date);
  final calendar = JewishCalendar.fromDateTime(day)..inIsrael = inIsrael;
  if (calendar.getYomTovIndex() == JewishCalendar.YOM_KIPPUR) {
    return LockedDayKind.yomKippur;
  }
  final shabbos = day.weekday == DateTime.saturday;
  final yomTov = calendar.isYomTovAssurBemelacha();
  if (shabbos && yomTov) return LockedDayKind.yomTovShabbos;
  if (yomTov) return LockedDayKind.yomTov;
  return LockedDayKind.shabbos;
}
