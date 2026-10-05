// Mirror test for `lib/domain/learner_state/erev_window.dart`
// (DNI-504 T1: AC-1, AC-4, AC-5, AC-6 and the civil-date / time-zone edges).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';

import '../../helpers/learner_state/lock_fixtures.dart';

const _us = Duration(microseconds: 1);

/// The UTC instant of [hour]:[minute] on [y]-[m]-[d] in [zoneId].
DateTime _local(
  String zoneId,
  int y,
  int m,
  int d, [
  int hour = 0,
  int minute = 0,
]) => LearnerZone.of(
  zoneId,
).at(DateTime.utc(y, m, d), hour: hour, minute: minute);

/// The one lock that contains [instant].
LockWindow _lockAt(LearnerSettingsHistory h, DateTime instant) =>
    lockWindows(h, instant, instant).single;

void main() {
  const ny = 'America/New_York';
  const jlm = 'Asia/Jerusalem';

  group('AC-1 interval: 00:00 on the lock day until just before L.start', () {
    final h = constantHistory(lakewood);
    // A plain Shabbos: Friday 2026-10-09, Shabbos 2026-10-10.
    final lock = _lockAt(h, _local(ny, 2026, 10, 9, 22));
    final erevStart = _local(ny, 2026, 10, 9);

    test('absent before 00:00 learner-local on the lock day', () {
      expect(erevWindowAt(h, erevStart.subtract(_us)), isNull);
      expect(erevWindowAt(h, _local(ny, 2026, 10, 8, 12)), isNull);
    });

    test('present from 00:00 through the instant before L.start', () {
      for (final t in [
        erevStart,
        _local(ny, 2026, 10, 9, 9),
        lock.startUtc.subtract(_us),
      ]) {
        final w = erevWindowAt(h, t);
        expect(w, isNotNull, reason: '$t');
        expect(w!.lock, lock);
        expect(w.erevStartUtc, erevStart);
      }
    });

    test('absent at L.start and inside the lock', () {
      expect(erevWindowAt(h, lock.startUtc), isNull);
      expect(erevWindowAt(h, _local(ny, 2026, 10, 10, 12)), isNull);
      expect(erevWindowAt(h, lock.endUtc), isNull);
    });

    test('a plain Shabbos has one locked day and the Shabbos kind', () {
      final w = erevWindowAt(h, _local(ny, 2026, 10, 9, 9))!;
      expect(w.lockedDays, [
        const LockedDay(date: '2026-10-10', kind: LockedDayKind.shabbos),
      ]);
      expect(w.kind, ErevKind.shabbos);
    });

    test('the lock start time is the learner wall clock of L.start', () {
      final w = erevWindowAt(h, _local(ny, 2026, 10, 9, 9))!;
      expect(w.lockStartLocal, LearnerZone.of(ny).wallTimeOf(lock.startUtc));
      // Candle-lighting in Lakewood in October is early evening.
      expect(w.lockStartLocal.hour, inInclusiveRange(17, 18));
      expect(w.lockStartLocal.day, 9);
    });
  });

  group('AC-4 diaspora yom tov Thursday and Friday chained into Shabbos', () {
    // Pesach 2027: Thursday 04-22 and Friday 04-23 are yom tov in the
    // diaspora, followed by Shabbos 04-24.
    final h = constantHistory(lakewood);

    test('Wednesday shows Thursday, Friday and Shabbos in order', () {
      final w = erevWindowAt(h, _local(ny, 2027, 4, 21, 12))!;
      expect(
        [for (final d in w.lockedDays) d.date],
        ['2027-04-22', '2027-04-23', '2027-04-24'],
      );
      expect(
        [for (final d in w.lockedDays) d.kind],
        [LockedDayKind.yomTov, LockedDayKind.yomTov, LockedDayKind.shabbos],
      );
      expect(w.kind, ErevKind.yomTovAndShabbos);
      expect(w.lockedDays.map((d) => d.weekday), [
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
      ]);
    });

    test('there is no erev view on Thursday or Friday', () {
      for (final t in [
        _local(ny, 2027, 4, 22),
        _local(ny, 2027, 4, 22, 12),
        _local(ny, 2027, 4, 23),
        _local(ny, 2027, 4, 23, 12),
      ]) {
        expect(erevWindowAt(h, t), isNull, reason: '$t');
      }
    });
  });

  group('AC-5 Israel one-day yom tov', () {
    final h = constantHistory(jerusalem);

    test('Wednesday shows only Thursday; Friday has its own erev', () {
      final wed = erevWindowAt(h, _local(jlm, 2027, 4, 21, 12))!;
      expect(wed.lockedDays, [
        const LockedDay(date: '2027-04-22', kind: LockedDayKind.yomTov),
      ]);
      expect(wed.kind, ErevKind.yomTov);

      expect(erevWindowAt(h, _local(jlm, 2027, 4, 22, 12)), isNull);

      final fri = erevWindowAt(h, _local(jlm, 2027, 4, 23, 10))!;
      expect(fri.lockedDays, [
        const LockedDay(date: '2027-04-24', kind: LockedDayKind.shabbos),
      ]);
      expect(fri.erevStartUtc, _local(jlm, 2027, 4, 23));
    });

    test('an in_israel change before L.start changes the days live', () {
      final now = _local(ny, 2027, 4, 21, 12);
      final diaspora = constantHistory(lakewood);
      final moved = movedHistory(
        lakewood,
        _local(ny, 2027, 4, 21, 11),
        lockSettings(latitude: 40.0821, longitude: -74.2097, inIsrael: true),
      );
      expect(erevWindowAt(diaspora, now)!.lockedDays, hasLength(3));
      final w = erevWindowAt(moved, now)!;
      expect([for (final d in w.lockedDays) d.date], ['2027-04-22']);
      // The lock itself is the one lockWindows gives under the settings in
      // force at its start (the gate and overlay read the same value).
      expect(w.lock, _lockAt(moved, w.lock.startUtc));
    });
  });

  group('AC-6 no location: there is no erev or lock window', () {
    final h = constantHistory(newYorkNoLocation);

    test('the Friday erev banner is absent', () {
      expect(erevWindowAt(h, _local(ny, 2026, 10, 9, 9)), isNull);
    });

    test('Friday afternoon and Shabbos remain open', () {
      for (final at in [
        _local(ny, 2026, 10, 9, 16),
        _local(ny, 2026, 10, 10, 12),
      ]) {
        expect(erevWindowAt(h, at), isNull);
        expect(const LockWindowCaptureGate().check(h, at), const GateOpen());
      }
    });
  });

  group('Edge: civil dates and time zones', () {
    test(
      'DST: the erev start is local midnight on both sides of fall-back',
      () {
        final h = constantHistory(lakewood);
        // EDT on Friday 2026-10-30, EST on Friday 2026-11-06.
        expect(
          erevWindowAt(h, _local(ny, 2026, 10, 30, 8))!.erevStartUtc,
          DateTime.utc(2026, 10, 30, 4),
        );
        expect(
          erevWindowAt(h, _local(ny, 2026, 11, 6, 8))!.erevStartUtc,
          DateTime.utc(2026, 11, 6, 5),
        );
      },
    );

    test('a time_zone change before L.start uses the new zone', () {
      final moved = movedHistory(
        lakewood,
        DateTime.utc(2026, 10, 1),
        jerusalem,
      );
      final w = erevWindowAt(moved, _local(jlm, 2026, 10, 9, 8))!;
      expect(w.erevStartUtc, _local(jlm, 2026, 10, 9));
      expect(w.lockStartLocal, LearnerZone.of(jlm).wallTimeOf(w.lock.startUtc));
      // 06:00 Jerusalem is still Thursday night in New York: before the
      // move the erev would not have opened yet; after it, it has.
      expect(erevWindowAt(moved, _local(jlm, 2026, 10, 9, 0, 30)), isNotNull);
      expect(
        erevWindowAt(
          constantHistory(lakewood),
          _local(jlm, 2026, 10, 9, 0, 30),
        ),
        isNull,
      );
    });

    test('two profiles keep their own settings', () {
      final now = _local(jlm, 2027, 4, 21, 12);
      final a = erevWindowAt(constantHistory(jerusalem), now)!;
      final b = erevWindowAt(constantHistory(lakewood), now)!;
      expect(a.lockedDays, hasLength(1));
      expect(b.lockedDays, hasLength(3));
      expect(a.lock, isNot(b.lock));
    });

    test('Yom Kippur is its own kind', () {
      // Yom Kippur 5787: Monday 2026-09-21.
      final w = erevWindowAt(
        constantHistory(lakewood),
        _local(ny, 2026, 9, 20, 9),
      )!;
      expect(w.lockedDays, [
        const LockedDay(date: '2026-09-21', kind: LockedDayKind.yomKippur),
      ]);
      expect(w.kind, ErevKind.yomKippur);
    });
  });

  group('nextErevTransition', () {
    final h = constantHistory(lakewood);
    final lock = _lockAt(h, _local(ny, 2026, 10, 9, 22));

    test('before the erev window it is the erev start', () {
      expect(
        nextErevTransition(h, _local(ny, 2026, 10, 8, 12)),
        _local(ny, 2026, 10, 9),
      );
    });

    test('inside the erev window it is L.start', () {
      expect(nextErevTransition(h, _local(ny, 2026, 10, 9, 9)), lock.startUtc);
    });

    test('inside a lock there is none', () {
      expect(nextErevTransition(h, _local(ny, 2026, 10, 10, 12)), isNull);
    });
  });
}
