/// AD-41 learner time zone: civil-day arithmetic in the learner's IANA
/// `time_zone`, never the device offset.
///
/// A civil day is carried internally as the UTC midnight [DateTime] of its
/// `YYYY-MM-DD` (a pure date key, not an instant). [LearnerZone] turns
/// instants into civil days and civil wall-clock times back into instants.
///
/// The tz database is the `timezone` package's embedded `latest_all` data
/// (pure Dart, no I/O). It is loaded once on first use if no one has loaded
/// it yet; an already-initialised database is never reloaded, so the app's
/// `tz.local` (set by the notification initialiser) is left alone.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// One microsecond: the resolution of [DateTime] and of the closed
/// [UtcInterval]-style bounds built from civil days.
const Duration civilTick = Duration(microseconds: 1);

/// A learner's IANA zone, resolved against the tz database.
///
/// An id that is not in the database (a well-formed but unknown name) is
/// [isKnown] `false`; such a zone computes civil days in UTC, and the lock
/// rules use a zone-independent fail-closed window instead (AD-36, story
/// assumption "invalid IANA zone").
final class LearnerZone {
  LearnerZone._(this.id, this._location);

  /// Resolves [ianaId].
  factory LearnerZone.of(String ianaId) =>
      LearnerZone._(ianaId, _lookup(ianaId));

  static tz.Location? _lookup(String id) {
    if (id == 'UTC') return tz.UTC;
    if (!tz.timeZoneDatabase.isInitialized) tzdata.initializeTimeZones();
    try {
      return tz.getLocation(id);
    } on tz.LocationNotFoundException {
      return null;
    }
  }

  /// The IANA id as stored on the profile.
  final String id;

  final tz.Location? _location;

  /// Whether [id] names a zone in the tz database.
  bool get isKnown => _location != null;

  /// The civil day (UTC-midnight date key) of [instantUtc] in this zone.
  DateTime dayOf(DateTime instantUtc) {
    final location = _location;
    final local = location == null
        ? instantUtc.toUtc()
        : tz.TZDateTime.from(instantUtc.toUtc(), location);
    return DateTime.utc(local.year, local.month, local.day);
  }

  /// The UTC instant of wall-clock [hour]:[minute] on civil [day] in this
  /// zone. A wall time inside a DST gap resolves as the `timezone` package
  /// resolves it (forward across the gap).
  DateTime at(DateTime day, {int hour = 0, int minute = 0}) {
    final location = _location;
    if (location == null) {
      return DateTime.utc(day.year, day.month, day.day, hour, minute);
    }
    final local = tz.TZDateTime(
      location,
      day.year,
      day.month,
      day.day,
      hour,
      minute,
    );
    return DateTime.fromMicrosecondsSinceEpoch(
      local.microsecondsSinceEpoch,
      isUtc: true,
    );
  }

  /// The first instant of civil [day] (local midnight).
  DateTime startOf(DateTime day) => at(day);

  /// The wall-clock reading of [instantUtc] in this zone, as a UTC-flagged
  /// [DateTime] whose fields are the local year..microsecond (a display
  /// key, not an instant; DNI-504). An unknown zone reads UTC.
  DateTime wallTimeOf(DateTime instantUtc) {
    final location = _location;
    final local = location == null
        ? instantUtc.toUtc()
        : tz.TZDateTime.from(instantUtc.toUtc(), location);
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
      local.millisecond,
      local.microsecond,
    );
  }

  @override
  String toString() => 'LearnerZone($id${isKnown ? '' : ', unknown'})';
}

/// [day] plus [days] civil days.
DateTime addCivilDays(DateTime day, int days) =>
    DateTime.utc(day.year, day.month, day.day + days);

/// The `YYYY-MM-DD` form of civil [day].
CivilDate formatCivilDay(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// The civil-day key of [date] (`YYYY-MM-DD`, validated by the caller).
DateTime parseCivilDay(CivilDate date) => DateTime.utc(
  int.parse(date.substring(0, 4)),
  int.parse(date.substring(5, 7)),
  int.parse(date.substring(8, 10)),
);
