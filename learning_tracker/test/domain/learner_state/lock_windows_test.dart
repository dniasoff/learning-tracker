// Mirror test for `lib/domain/learner_state/lock_windows.dart`
// (C0 DNI-524 AC-6; DNI-466 AC-2, AC-3, AC-5 and the edge rows).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_constants.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

import '../../helpers/learner_state/lock_fixtures.dart';

const _us = Duration(microseconds: 1);

/// kosher_dart truncates its zmanim to whole seconds.
void _near(DateTime actual, DateTime expected) {
  expect(
    actual.difference(expected).inMilliseconds.abs(),
    lessThanOrEqualTo(1000),
    reason: 'actual $actual, expected $expected',
  );
}

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d);

LockWindow _single(LearnerSettingsHistory h, DateTime from, [DateTime? to]) =>
    lockWindows(h, from, to ?? from).single;

/// The fixed fail-closed window over locked days [first]..[last].
(DateTime, DateTime) _fixed(String zoneId, DateTime first, DateTime last) {
  final zone = LearnerZone.of(zoneId);
  final after = addCivilDays(last, 1);
  final one = zone.at(after, hour: 1);
  final late = zone.at(after, hour: 2).subtract(const Duration(hours: 1));
  return (
    zone.at(addCivilDays(first, -1), hour: 12),
    late.isAfter(one) ? late : one,
  );
}

void main() {
  final start = DateTime.utc(2026, 9, 4, 16);
  final end = DateTime.utc(2026, 9, 5, 17);

  group('UtcInterval / LockWindow (C0)', () {
    test('UtcInterval.contains is closed at both ends', () {
      final i = UtcInterval(start, end);
      expect(i.contains(start), isTrue);
      expect(i.contains(end), isTrue);
      expect(i.contains(start.add(const Duration(hours: 3))), isTrue);
      expect(i.contains(start.subtract(_us)), isFalse);
      expect(i.contains(end.add(_us)), isFalse);
    });

    test('LockWindow is a UtcInterval with the same semantics', () {
      final lock = LockWindow(start, end);
      expect(lock, isA<UtcInterval>());
      expect(lock.contains(start), isTrue);
      expect(lock.contains(end.add(_us)), isFalse);
    });

    test('value equality distinguishes a lock from a plain interval', () {
      expect(LockWindow(start, end), LockWindow(start, end));
      expect(LockWindow(start, end).hashCode, LockWindow(start, end).hashCode);
      expect(LockWindow(start, end), isNot(UtcInterval(start, end)));
      expect(UtcInterval(start, end), UtcInterval(start, end));
    });
  });

  group('AC-2: lockWindows', () {
    final lakewoodH = constantHistory(lakewood);
    final jerusalemH = constantHistory(jerusalem);

    test('a Shabbos lock is [candle-lighting − 10 min, tzeis + 10 min]', () {
      final lock = _single(lakewoodH, DateTime.utc(2026, 3, 28, 12));
      _near(
        lock.startUtc,
        kosherCandleLighting(
          40.0821,
          -74.2097,
          _day(2026, 3, 27),
        )!.subtract(lockStartBeforeCandleLighting),
      );
      _near(
        lock.endUtc,
        kosherTzeis(
          40.0821,
          -74.2097,
          _day(2026, 3, 28),
        )!.add(lockEndAfterTzeis),
      );
      expect(lockedDays(lock, lakewoodH), {'2026-03-28'});
    });

    test('civil days are iterated in the learner zone', () {
      // Auckland: the Friday-evening lock opens on Friday morning UTC.
      final auckland = constantHistory(
        lockSettings(
          timeZone: 'Pacific/Auckland',
          latitude: -36.85,
          longitude: 174.76,
          inIsrael: false,
        ),
      );
      final lock = _single(auckland, DateTime.utc(2026, 9, 5));
      expect(civilDate(lock.startUtc, auckland), '2026-09-04');
      expect(lock.startUtc.isBefore(DateTime.utc(2026, 9, 4, 12)), isTrue);
      _near(
        lock.startUtc,
        kosherCandleLighting(
          -36.85,
          174.76,
          _day(2026, 9, 4),
        )!.subtract(lockStartBeforeCandleLighting),
      );
      expect(lockedDays(lock, auckland), {'2026-09-05'});
    });

    test('in_israel decides one- vs two-day yom tov (Pesach 5786)', () {
      final from = DateTime.utc(2026, 3, 31);
      final to = DateTime.utc(2026, 4, 5, 12);
      final diaspora = lockWindows(lakewoodH, from, to);
      expect(diaspora, hasLength(1));
      expect(lockedDays(diaspora.single, lakewoodH), {
        '2026-04-02',
        '2026-04-03',
        '2026-04-04',
      });

      final israel = lockWindows(jerusalemH, from, to);
      expect(israel, hasLength(2));
      expect(lockedDays(israel[0], jerusalemH), {'2026-04-02'});
      expect(lockedDays(israel[1], jerusalemH), {'2026-04-04'});

      // The flag, not the location, decides.
      final jerusalemDiaspora = constantHistory(
        lockSettings(
          timeZone: 'Asia/Jerusalem',
          latitude: 31.778,
          longitude: 35.235,
          inIsrael: false,
        ),
      );
      final chained = lockWindows(jerusalemDiaspora, from, to);
      expect(chained, hasLength(1));
      expect(lockedDays(chained.single, jerusalemDiaspora), hasLength(3));
    });

    test('in_israel never set locks the diaspora days (fail closed)', () {
      final unset = constantHistory(
        lockSettings(
          timeZone: 'Asia/Jerusalem',
          latitude: 31.778,
          longitude: 35.235,
        ),
      );
      final locks = lockWindows(
        unset,
        DateTime.utc(2026, 3, 31),
        DateTime.utc(2026, 4, 5, 12),
      );
      expect(locks, hasLength(1));
      expect(lockedDays(locks.single, unset), hasLength(3));
    });

    test('a move mid-range changes only windows after the change', () {
      final move = DateTime.utc(2026, 3, 30);
      final history = movedHistory(lakewood, move, jerusalem);
      final from = DateTime.utc(2026, 3, 25);
      final to = DateTime.utc(2026, 4, 12);
      final moved = lockWindows(history, from, to);
      final ny = lockWindows(lakewoodH, from, to);
      final jlm = lockWindows(jerusalemH, from, to);
      expect(moved.first, ny.first);
      expect(moved.skip(1).toList(), [
        for (final w in jlm)
          if (w.startUtc.isAfter(move)) w,
      ]);
    });

    test('a change inside a lock judges each instant by its settings', () {
      // Jerusalem's Shabbos ends about 7 hours before Lakewood's.
      final nyLock = _single(lakewoodH, DateTime.utc(2026, 3, 28, 12));
      final jlmLock = _single(jerusalemH, DateTime.utc(2026, 3, 28, 12));
      final change = DateTime.utc(2026, 3, 28, 12);
      final lock = _single(
        movedHistory(lakewood, change, jerusalem),
        DateTime.utc(2026, 3, 28, 12),
      );
      expect(lock, LockWindow(nyLock.startUtc, jlmLock.endUtc));

      // A change exactly at a bound resolves to the new settings there.
      final atBound = movedHistory(lakewood, jlmLock.endUtc, jerusalem);
      final bounded = _single(atBound, DateTime.utc(2026, 3, 28, 12));
      expect(bounded.endUtc, jlmLock.endUtc);
      expect(
        lockWindows(
          atBound,
          jlmLock.endUtc.add(_us),
          nyLock.endUtc,
        ).where((w) => w.startUtc.isBefore(DateTime.utc(2026, 3, 29))),
        isEmpty,
      );
    });

    test('a lock open at fromUtc or past toUtc keeps its true bounds', () {
      final full = _single(lakewoodH, DateTime.utc(2026, 3, 28, 12));
      expect(_single(lakewoodH, full.startUtc), full);
      expect(_single(lakewoodH, full.endUtc), full);
      expect(
        _single(
          lakewoodH,
          full.startUtc.subtract(const Duration(days: 1)),
          full.startUtc.add(const Duration(minutes: 1)),
        ),
        full,
      );
      expect(
        lockWindows(lakewoodH, full.endUtc.add(_us), DateTime.utc(2026, 3, 30)),
        isEmpty,
      );
      expect(lockWindows(lakewoodH, full.endUtc, full.startUtc), isEmpty);
    });
  });

  group('AC-3: fail-closed fallbacks', () {
    // Product ruling 2026-10-05 (supersedes the FR-23 no-location fixed
    // window): no location, no lock. The fall-back-night and "fixed window
    // holds the computed one" cases pinned that retired fallback.
    test('no location: no lock at any time (Friday afternoon, Shabbos, '
        'yom tov), in any zone', () {
      for (final settings in [
        newYorkNoLocation,
        lockSettings(timeZone: 'Europe/London'),
        lockSettings(timeZone: 'Asia/Jerusalem', inIsrael: true),
        lockSettings(timeZone: 'Mars/Olympus_Mons'),
      ]) {
        final h = constantHistory(settings);
        expect(
          lockWindows(h, DateTime.utc(2026), DateTime.utc(2026, 12, 31)),
          isEmpty,
          reason: settings.timeZone,
        );
      }
    });

    test('a move from no location to a location locks only after the '
        'move', () {
      final h = movedHistory(
        newYorkNoLocation,
        DateTime.utc(2026, 9, 1),
        lakewood,
      );
      final windows = lockWindows(
        h,
        DateTime.utc(2026, 8, 1),
        DateTime.utc(2026, 9, 30),
      );
      expect(windows, isNotEmpty);
      expect(
        windows.every((w) => w.startUtc.isAfter(DateTime.utc(2026, 9, 1))),
        isTrue,
      );
    });

    test('high latitude: an uncomputable zman gives the fixed window', () {
      final tromso = lockSettings(
        timeZone: 'Europe/Oslo',
        latitude: 69.65,
        longitude: 18.96,
      );
      final h = constantHistory(tromso);
      // Midnight sun: no sunset, no tzeis.
      final june = _single(h, DateTime.utc(2026, 6, 20, 12));
      final (juneStart, juneEnd) = _fixed(
        'Europe/Oslo',
        _day(2026, 6, 20),
        _day(2026, 6, 20),
      );
      expect(june, LockWindow(juneStart, juneEnd));
      // Polar night: the sun never sets because it never rises.
      final december = _single(h, DateTime.utc(2026, 12, 19, 12));
      final (decStart, decEnd) = _fixed(
        'Europe/Oslo',
        _day(2026, 12, 19),
        _day(2026, 12, 19),
      );
      expect(december, LockWindow(decStart, decEnd));
    });

    test('no input yields a window narrower than the computed window', () {
      final from = DateTime.utc(2026);
      final to = DateTime.utc(2026, 12, 31);
      for (final (zone, lng) in const [
        ('Europe/London', -0.1),
        ('America/New_York', -74.0),
      ]) {
        for (var lat = -65; lat <= 75; lat += 5) {
          final settings = lockSettings(
            timeZone: zone,
            latitude: lat.toDouble(),
            longitude: lng,
            inIsrael: false,
          );
          final h = constantHistory(settings);
          for (final lock in lockWindows(h, from, to)) {
            final days = lockedDays(lock, h).map(parseCivilDay).toList()
              ..sort();
            final first = days.first;
            final last = days.last;
            final candle = kosherCandleLighting(
              lat.toDouble(),
              lng,
              addCivilDays(first, -1),
            );
            final tzeis = kosherTzeis(lat.toDouble(), lng, last);
            final reason = '$zone $lat $lock';
            if (candle != null && tzeis != null) {
              final s = candle.subtract(lockStartBeforeCandleLighting);
              final e = tzeis.add(lockEndAfterTzeis);
              expect(
                lock.startUtc.difference(s).inMilliseconds,
                lessThanOrEqualTo(1000),
                reason: reason,
              );
              expect(
                e.difference(lock.endUtc).inMilliseconds,
                lessThanOrEqualTo(1000),
                reason: reason,
              );
            } else {
              final (s, e) = _fixed(zone, first, last);
              expect(lock.startUtc.isAfter(s), isFalse, reason: reason);
              expect(lock.endUtc.isBefore(e), isFalse, reason: reason);
            }
          }
        }
      }
    });

    test('a location with an unknown zone widens the fixed window to '
        'every UTC offset (NFR-6 kept where a location is set)', () {
      final unknown = constantHistory(
        lockSettings(
          timeZone: 'Mars/Olympus_Mons',
          latitude: 40.0821,
          longitude: -74.2097,
        ),
      );
      final lock = _single(unknown, DateTime.utc(2026, 9, 5, 12));
      expect(
        lock,
        LockWindow(DateTime.utc(2026, 9, 3, 22), DateTime.utc(2026, 9, 6, 13)),
      );
      for (final known in [
        constantHistory(lakewood),
        constantHistory(
          lockSettings(
            timeZone: 'Pacific/Kiritimati',
            latitude: 1.87,
            longitude: -157.4,
          ),
        ),
        constantHistory(
          lockSettings(
            timeZone: 'Pacific/Pago_Pago',
            latitude: -14.27,
            longitude: -170.7,
          ),
        ),
        constantHistory(jerusalem),
      ]) {
        // 06:00Z Saturday is inside every one of these locks.
        final w = _single(known, DateTime.utc(2026, 9, 5, 6));
        expect(lock.startUtc.isAfter(w.startUtc), isFalse, reason: '$w');
        expect(lock.endUtc.isBefore(w.endUtc), isFalse, reason: '$w');
      }
    });
  });

  group('AC-5: lockedDays and catchUpWindow', () {
    final lakewoodH = constantHistory(lakewood);

    test('two-day yom tov into Shabbos is one lock with 3 locked days', () {
      final lock = _single(lakewoodH, DateTime.utc(2026, 4, 3, 12));
      expect(lockedDays(lock, lakewoodH), {
        '2026-04-02',
        '2026-04-03',
        '2026-04-04',
      });
      // The erev the lock starts on is never a locked day.
      expect(civilDate(lock.startUtc, lakewoodH), '2026-04-01');
    });

    test('lockedDays reads the zone and in_israel in force at L.start', () {
      final lock = _single(lakewoodH, DateTime.utc(2026, 3, 28, 12));
      // From an hour into the lock the learner is at UTC+14, where the
      // lock's end falls on Sunday: reading L.end's settings would give no
      // locked day at all.
      final h = movedHistory(
        lakewood,
        lock.startUtc.add(const Duration(hours: 1)),
        lockSettings(timeZone: 'Pacific/Kiritimati', inIsrael: true),
      );
      expect(lockedDays(lock, h), {'2026-03-28'});
    });

    test('catch-up runs to the end of the first unlocked civil day', () {
      final lock = _single(lakewoodH, DateTime.utc(2026, 3, 28, 12));
      final window = catchUpWindow(lock, lakewoodH);
      expect(window.startUtc, lock.endUtc.add(_us));
      // End of Sunday 2026-03-29, EDT.
      expect(window.endUtc, DateTime.utc(2026, 3, 30, 4).subtract(_us));
      expect(window.contains(lock.endUtc), isFalse);
    });

    test('catch-up pauses through a later lock (yom tov, Friday, Shabbos)', () {
      final yomTov = _single(lakewoodH, DateTime.utc(2026, 4, 8, 12));
      expect(lockedDays(yomTov, lakewoodH), {'2026-04-08', '2026-04-09'});
      final window = catchUpWindow(yomTov, lakewoodH);
      // Friday holds the Shabbos lock's start, Saturday is locked: the
      // first lock-free day is Sunday 2026-04-12.
      expect(window.endUtc, DateTime.utc(2026, 4, 13, 4).subtract(_us));
      final shabbos = _single(lakewoodH, DateTime.utc(2026, 4, 11, 12));
      expect(window.contains(shabbos.startUtc), isTrue);
      expect(window.contains(shabbos.endUtc), isTrue);
    });

    test('catch-up day ends follow DST (spring-forward Sunday)', () {
      final lock = _single(lakewoodH, DateTime.utc(2026, 3, 7, 12));
      final window = catchUpWindow(lock, lakewoodH);
      // Sunday 2026-03-08 is 23 hours long and ends at 04:00Z (EDT).
      expect(window.endUtc, DateTime.utc(2026, 3, 9, 4).subtract(_us));
      // Saturday 23:30 EST is still Saturday for the learner.
      expect(
        civilDate(DateTime.utc(2026, 3, 8, 4, 30), lakewoodH),
        '2026-03-07',
      );
    });

    test('catch-up days are the learner civil days (Jerusalem)', () {
      final h = constantHistory(jerusalem);
      final lock = _single(h, DateTime.utc(2026, 3, 28, 12));
      // End of Sunday 2026-03-29 in Jerusalem (IDT, UTC+3).
      expect(
        catchUpWindow(lock, h).endUtc,
        DateTime.utc(2026, 3, 29, 21).subtract(_us),
      );
    });
  });

  group('DNI-504 AC-4/AC-6: the erev view reads these windows', () {
    test('diaspora yom tov Thu+Fri chained into Shabbos is ONE lock', () {
      final h = constantHistory(lakewood);
      final wed = LearnerZone.of(
        'America/New_York',
      ).at(_day(2027, 4, 21), hour: 12);
      final windows = lockWindows(h, wed, wed.add(const Duration(days: 4)));
      expect(windows, hasLength(1));
      expect(lockedDays(windows.single, h), {
        '2027-04-22',
        '2027-04-23',
        '2027-04-24',
      });
    });

    test('Israel: the same week is two locks with a free Friday', () {
      final h = constantHistory(jerusalem);
      final wed = LearnerZone.of(
        'Asia/Jerusalem',
      ).at(_day(2027, 4, 21), hour: 12);
      final windows = lockWindows(h, wed, wed.add(const Duration(days: 4)));
      expect(windows, hasLength(2));
      expect(lockedDays(windows.first, h), {'2027-04-22'});
      expect(lockedDays(windows.last, h), {'2027-04-24'});
    });

    test('no location: no erev window, a plain Shabbos does not lock', () {
      final h = constantHistory(newYorkNoLocation);
      final zone = LearnerZone.of('America/New_York');
      final friday = zone.at(_day(2026, 10, 9), hour: 9);
      expect(
        lockWindows(h, friday, friday.add(const Duration(days: 1))),
        isEmpty,
      );
    });
  });

  // DNI-481 (1.19) consumes lockWindows for the overlay, notifications and
  // the capture gate (ruling B4(d): T1 is consume-only). These pin the
  // boundary and calendar cases the 1.19 acceptance table names that the
  // DNI-466 groups above do not already cover.
  group('DNI-481: lock surfaces consumer cases', () {
    test('no location: Sukkot on Shabbos does not lock, in Israel or the '
        'diaspora', () {
      final at = DateTime.utc(2026, 9, 26, 12);
      for (final inIsrael in [true, false]) {
        final h = constantHistory(
          lockSettings(timeZone: 'Asia/Jerusalem', inIsrael: inIsrael),
        );
        expect(lockWindows(h, at, at), isEmpty, reason: '$inIsrael');
      }
    });

    test('exact bounds: one microsecond either side of a lock is outside, '
        'both bounds are inside', () {
      final h = constantHistory(lakewood);
      final lock = _single(h, DateTime.utc(2026, 9, 5, 12));
      expect(lockWindows(h, lock.startUtc, lock.startUtc), [lock]);
      expect(lockWindows(h, lock.endUtc, lock.endUtc), [lock]);
      final before = lock.startUtc.subtract(_us);
      final after = lock.endUtc.add(_us);
      expect(
        lockWindows(h, before, before).where((w) => w.contains(before)),
        isEmpty,
      );
      expect(
        lockWindows(h, after, after).where((w) => w.contains(after)),
        isEmpty,
      );
    });
  });
}
