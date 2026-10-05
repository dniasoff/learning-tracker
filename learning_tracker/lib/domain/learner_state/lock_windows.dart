/// AD-36 lock windows (Shabbos and yom tov) and the AD-40 locked days and
/// catch-up window.
///
/// [lockWindows] is the ONLY window function: the engine's lock-ignore
/// rule, the capture gate, the lock overlay, notification suppression and
/// reminders all read it. Every civil day is a day in the learner's IANA
/// `time_zone` in force (AD-41), never the device's.
///
/// ## Window rule
///
/// A run of consecutive civil days D1..Dn on which `JewishCalendar`
/// (`inIsrael` from the settings) gives `isAssurBemelacha()` is ONE lock,
/// so yom tov chained into Shabbos stays one lock. With a location the lock
/// is `[candle-lighting(D1 − 1) − 10 min, tzeis(Dn) + 10 min]`
/// (`lock_constants.dart`). Candle-lighting is the `kosher_dart` standard
/// zman (its default offset before sea-level sunset); tzeis is the
/// `kosher_dart` default (8.5° below the horizon).
///
/// ## No location: no lock
///
/// Settings with no location produce NO lock window (product ruling
/// 2026-10-05, superseding the FR-23 Fri 12:00 → Sun 01:00 fallback):
/// nothing is refused, suppressed or lock-ignored for that span.
///
/// ## Fail-closed fallbacks (with a location, FR-23 / NFR-6)
///
/// * A zman that cannot be computed (high latitude): the hull of that
///   fixed window and whatever bound could be computed, so the window is
///   never narrower than either.
/// * A `time_zone` missing from the tz database: civil days are UTC days
///   and the window is the fixed window widened to every UTC offset
///   (`D1 − 1` 12:00 at UTC+14 → `Dn + 1` 01:00 at UTC−12).
/// * `in_israel` never set: diaspora (two-day yom tov), which locks a
///   superset of the Israel days.
///
/// ## Settings history
///
/// Each instant is judged by the settings in force at that instant: the
/// windows computed with one settings span apply only inside that span,
/// so a settings change moves only windows after the change instant.
/// Pieces that touch across a change merge into one lock.
///
/// ## Interval convention
///
/// [UtcInterval] / [LockWindow] are closed at both ends (C0 contract): an
/// event exactly at a lock bound is inside the lock (fail closed).
library;

import 'package:kosher_dart/kosher_dart.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_constants.dart';

/// A closed UTC interval `[startUtc, endUtc]`.
base class UtcInterval {
  /// Creates the interval; both ends are UTC instants.
  const UtcInterval(this.startUtc, this.endUtc);

  /// First instant inside the interval.
  final DateTime startUtc;

  /// Last instant inside the interval.
  final DateTime endUtc;

  /// Whether [t] lies in `[startUtc, endUtc]` (both ends included).
  bool contains(DateTime t) => !t.isBefore(startUtc) && !t.isAfter(endUtc);

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is UtcInterval &&
      other.startUtc == startUtc &&
      other.endUtc == endUtc;

  @override
  int get hashCode => Object.hash(runtimeType, startUtc, endUtc);

  @override
  String toString() =>
      '$runtimeType(${startUtc.toIso8601String()}, '
      '${endUtc.toIso8601String()})';
}

/// One Shabbos or yom-tov lock (AD-36): captures inside it are refused.
final class LockWindow extends UtcInterval {
  /// Creates a lock window.
  const LockWindow(super.startUtc, super.endUtc);
}

/// How far around a query the windows are searched, so a lock that is
/// already open at `fromUtc` or still open at `toUtc` keeps its true
/// bounds. The longest lock (two-day yom tov + Shabbos under the widest
/// fallback) is well under 5 days.
const Duration _searchPad = Duration(days: 7);

/// The zone-independent widening used when the zone is unknown.
const Duration _maxEastOffset = Duration(hours: 14);
const Duration _maxWestOffset = Duration(hours: 12);

/// `AstronomicalCalculator.GEOMETRIC_ZENITH` (not exported by kosher_dart):
/// the zenith of sea-level sunset.
const double _geometricZenith = 90;

/// The lock windows that overlap `[fromUtc, toUtc]` (AD-36), ascending.
///
/// Each instant is judged by the settings in force at it (see the library
/// doc). A lock that is open at `fromUtc` or still open at `toUtc` is
/// returned with its TRUE bounds, never clipped to the query, so
/// [lockedDays] and [catchUpWindow] can use it.
List<LockWindow> lockWindows(
  LearnerSettingsHistory settingsHistory,
  DateTime fromUtc,
  DateTime toUtc,
) {
  final from = fromUtc.toUtc();
  final to = toUtc.toUtc();
  if (to.isBefore(from)) return const [];
  final lo = from.subtract(_searchPad);
  final hi = to.add(_searchPad);
  final spans = settingsHistory.spans;
  final pieces = <(DateTime, DateTime)>[];
  for (var i = 0; i < spans.length; i++) {
    // The first span also covers every instant before its `fromUtc`
    // (LearnerSettingsHistory.at).
    final spanFrom = i == 0 ? null : spans[i].fromUtc;
    final spanTo = i + 1 < spans.length ? spans[i + 1].fromUtc : null;
    final a = spanFrom == null || spanFrom.isBefore(lo) ? lo : spanFrom;
    final b = spanTo == null || spanTo.isAfter(hi)
        ? hi
        : spanTo.subtract(civilTick);
    if (b.isBefore(a)) continue;
    for (final (start, end) in _windowsFor(spans[i].settings, a, b)) {
      final s = start.isBefore(a) ? a : start;
      final e = end.isAfter(b) ? b : end;
      if (!e.isBefore(s)) pieces.add((s, e));
    }
  }
  pieces.sort((x, y) => x.$1.compareTo(y.$1));
  final merged = <(DateTime, DateTime)>[];
  for (final piece in pieces) {
    if (merged.isNotEmpty && !piece.$1.isAfter(merged.last.$2.add(civilTick))) {
      final last = merged.removeLast();
      merged.add((last.$1, piece.$2.isAfter(last.$2) ? piece.$2 : last.$2));
    } else {
      merged.add(piece);
    }
  }
  return [
    for (final (start, end) in merged)
      if (!end.isBefore(from) && !start.isAfter(to)) LockWindow(start, end),
  ];
}

/// The civil days [lock] locks (AD-40): the learner-local dates D, in the
/// zone in force at `lock.startUtc`, from the day after the lock starts
/// through the day it ends, for which `JewishCalendar` (with `in_israel`
/// in force at `lock.startUtc`) gives `isAssurBemelacha()`. The day the
/// lock starts on is never a locked day.
Set<CivilDate> lockedDays(
  LockWindow lock,
  LearnerSettingsHistory settingsHistory,
) {
  final settings = settingsHistory.at(lock.startUtc);
  final zone = LearnerZone.of(settings.timeZone);
  final inIsrael = _inIsrael(settings);
  final last = zone.dayOf(lock.endUtc);
  return {
    for (
      var d = addCivilDays(zone.dayOf(lock.startUtc), 1);
      !d.isAfter(last);
      d = addCivilDays(d, 1)
    )
      if (_isAssur(d, inIsrael)) formatCivilDay(d),
  };
}

/// The AD-40 catch-up window that follows [lock]: from just after
/// `lock.endUtc` to the end of the first civil day after `lock.endUtc`
/// that contains no locked instant (days in the zone in force at
/// `lock.endUtc`).
///
/// The result is one interval; any later lock it spans (yom tov, a free
/// Friday, then Shabbos) is not catch-up time, and the engine never sees
/// an event inside a lock, so callers check lock membership separately
/// (as `streakDay` does).
UtcInterval catchUpWindow(
  LockWindow lock,
  LearnerSettingsHistory settingsHistory,
) {
  final zone = LearnerZone.of(settingsHistory.at(lock.endUtc).timeZone);
  final start = lock.endUtc.add(civilTick);
  final later = [
    for (final w in lockWindows(
      settingsHistory,
      start,
      start.add(const Duration(days: 21)),
    ))
      if (w.startUtc.isAfter(lock.endUtc)) w,
  ];
  var day = addCivilDays(zone.dayOf(lock.endUtc), 1);
  var dayEnd = zone.startOf(addCivilDays(day, 1)).subtract(civilTick);
  // A lock chain never covers 14 consecutive civil days.
  for (var i = 0; i < 14; i++) {
    final dayStart = zone.startOf(day);
    dayEnd = zone.startOf(addCivilDays(day, 1)).subtract(civilTick);
    final touched = later.any(
      (w) => !w.endUtc.isBefore(dayStart) && !w.startUtc.isAfter(dayEnd),
    );
    if (!touched) break;
    day = addCivilDays(day, 1);
  }
  return UtcInterval(start, dayEnd);
}

/// Whether [settings] carry a location; only then can they lock (product
/// ruling 2026-10-05: no location, no Sacred Time lock).
bool hasLockLocation(LearnerSettings settings) =>
    settings.latitude != null && settings.longitude != null;

bool _inIsrael(LearnerSettings settings) => settings.inIsrael ?? false;

bool _isAssur(DateTime day, bool inIsrael) =>
    (JewishCalendar.fromDateTime(day)..inIsrael = inIsrael).isAssurBemelacha();

/// The windows computed with [settings] that may touch `[a, b]`.
Iterable<(DateTime, DateTime)> _windowsFor(
  LearnerSettings settings,
  DateTime a,
  DateTime b,
) sync* {
  // No location, no lock (product ruling 2026-10-05, supersedes the FR-23
  // no-location fallback): Sacred Time is not active until a location is
  // set.
  if (!hasLockLocation(settings)) return;
  final zone = LearnerZone.of(settings.timeZone);
  final inIsrael = _inIsrael(settings);
  // A lock over days D1..Dn lies inside civil days D1 − 2 .. Dn + 1 (the
  // unknown-zone window is the widest), so runs meeting this range are the
  // only candidates.
  final first = addCivilDays(zone.dayOf(a), -2);
  final last = addCivilDays(zone.dayOf(b), 2);
  var d = first;
  // Back up to the start of a run already in progress.
  while (_isAssur(d, inIsrael)) {
    d = addCivilDays(d, -1);
  }
  while (!d.isAfter(last)) {
    if (!_isAssur(d, inIsrael)) {
      d = addCivilDays(d, 1);
      continue;
    }
    final runStart = d;
    var runEnd = d;
    while (_isAssur(addCivilDays(runEnd, 1), inIsrael)) {
      runEnd = addCivilDays(runEnd, 1);
    }
    final window = _window(settings, zone, runStart, runEnd);
    if (!window.$2.isBefore(a) && !window.$1.isAfter(b)) yield window;
    d = addCivilDays(runEnd, 1);
  }
}

/// The lock over the locked run [firstDay]..[lastDay].
(DateTime, DateTime) _window(
  LearnerSettings settings,
  LearnerZone zone,
  DateTime firstDay,
  DateTime lastDay,
) {
  final erev = addCivilDays(firstDay, -1);
  final after = addCivilDays(lastDay, 1);
  if (!zone.isKnown) {
    return (
      DateTime.utc(
        erev.year,
        erev.month,
        erev.day,
        12,
      ).subtract(_maxEastOffset),
      DateTime.utc(after.year, after.month, after.day, 1).add(_maxWestOffset),
    );
  }
  final fixedStart = zone.at(erev, hour: 12);
  // On a fall-back night 01:00 happens twice; take the later one (one hour
  // before 02:00) so the fixed window never ends early.
  final firstOne = zone.at(after, hour: 1);
  final lateOne = zone.at(after, hour: 2).subtract(const Duration(hours: 1));
  final fixedEnd = lateOne.isAfter(firstOne) ? lateOne : firstOne;
  final latitude = settings.latitude;
  final longitude = settings.longitude;
  if (latitude == null || longitude == null) return (fixedStart, fixedEnd);

  final start = _candleLighting(
    latitude,
    longitude,
    erev,
  )?.subtract(lockStartBeforeCandleLighting);
  final end = _tzeis(latitude, longitude, lastDay)?.add(lockEndAfterTzeis);
  if (start != null && end != null && start.isBefore(end)) {
    return (start, end);
  }
  final s = start != null && start.isBefore(fixedStart) ? start : fixedStart;
  final e = end != null && end.isAfter(fixedEnd) ? end : fixedEnd;
  return (s, e);
}

/// Candle-lighting on civil [day] at the location: the kosher_dart
/// standard offset before sea-level sunset, or null when the sun does not
/// set.
DateTime? _candleLighting(double latitude, double longitude, DateTime day) {
  final calendar = _calendar(latitude, longitude, day);
  final sunset = _instant(
    day,
    calendar.getUTCSeaLevelSunset(_geometricZenith),
    longitude,
  );
  if (sunset == null) return null;
  final offsetMinutes = calendar.getCandleLightingOffset();
  return sunset.subtract(
    Duration(
      microseconds: (offsetMinutes * Duration.microsecondsPerMinute).round(),
    ),
  );
}

/// Tzeis (8.5°, the kosher_dart default) on civil [day] at the location,
/// or null when the sun never gets that low.
DateTime? _tzeis(double latitude, double longitude, DateTime day) {
  final calendar = _calendar(latitude, longitude, day);
  return _instant(
    day,
    calendar.getUTCSunset(ZmanimCalendar.ZENITH_8_POINT_5),
    longitude,
  );
}

ZmanimCalendar _calendar(double latitude, double longitude, DateTime day) {
  // A UTC date keeps kosher_dart's antimeridian adjustment off the device
  // offset; only the date's year/month/day is read.
  final date = DateTime.utc(day.year, day.month, day.day);
  final geo = GeoLocation.setLocation('learner', latitude, longitude, date);
  return ZmanimCalendar.intGeolocation(geo)..setCalendar(date);
}

/// The UTC instant of an evening zman [utcHours] (hours after UTC midnight
/// as kosher_dart returns them, NaN when uncomputable) on civil [day] at
/// [longitude]. A zman whose UTC hour wraps past midnight is moved to the
/// right UTC day by the local solar time, as kosher_dart itself does.
DateTime? _instant(DateTime day, double utcHours, double longitude) {
  if (utcHours.isNaN || utcHours.isInfinite) return null;
  var instant = DateTime.utc(day.year, day.month, day.day).add(
    Duration(microseconds: (utcHours * Duration.microsecondsPerHour).round()),
  );
  final solarHours = utcHours + longitude / 15;
  if (solarHours < 6) {
    instant = instant.add(const Duration(days: 1));
  } else if (solarHours >= 30) {
    instant = instant.subtract(const Duration(days: 1));
  }
  return instant;
}
