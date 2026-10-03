// Mirror test for `lib/features/sacred_time/domain/services/sacred_lock.dart`
// (DNI-481 AC-1, AC-2, AC-5): the union device lock over lockWindows, its
// fail-closed stand-in and the greeting kind.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/sacred_time/domain/models/sacred_window.dart';
import 'package:learning_tracker/features/sacred_time/domain/services/sacred_lock.dart';

import '../../../../helpers/learner_state/lock_fixtures.dart';

const _us = Duration(microseconds: 1);

/// A history whose zmanim cannot be computed (a NaN location, which the
/// settings codec would refuse, so no real profile can hold it).
final _broken = LearnerSettingsHistory([
  SettingsSpan(
    fromUtc: null,
    settings: lockSettings(timeZone: 'America/New_York'),
  ),
  SettingsSpan(
    fromUtc: DateTime.utc(2026),
    settings: const LearnerSettings(
      profileId: '01ARZ3NDEKTSV4RRFFQ69G5FB1',
      timeZone: 'America/New_York',
      latitude: double.nan,
      longitude: double.nan,
    ),
  ),
]);

void main() {
  final lakewoodH = constantHistory(lakewood);
  final jerusalemH = constantHistory(jerusalem);
  final shabbos = DateTime.utc(2026, 9, 5, 12);
  final tuesday = DateTime.utc(2026, 9, 8, 12);

  group('failClosedSettingsHistory', () {
    test('an unknown zone with no location: the widest fixed window', () {
      final h = failClosedSettingsHistory('p');
      expect(LearnerZone.of(unresolvedLearnerZone).isKnown, isFalse);
      expect(h.at(shabbos).hasLocation, isFalse);
      expect(
        lockWindows(h, shabbos, shabbos).single,
        LockWindow(DateTime.utc(2026, 9, 3, 22), DateTime.utc(2026, 9, 6, 13)),
      );
      expect(lockWindows(h, tuesday, tuesday), isEmpty);
    });
  });

  group('sacredWindowAt (the union)', () {
    test('null when no learner is locked', () {
      expect(sacredWindowAt([lakewoodH, jerusalemH], tuesday), isNull);
      expect(sacredWindowAt(const [], shabbos), isNull);
    });

    test('any locked learner locks the device; the lock ending last wins', () {
      final lakewoodLock = lockWindows(lakewoodH, shabbos, shabbos).single;
      // Jerusalem's Shabbos ends hours before Lakewood's.
      final at = lakewoodLock.startUtc.add(const Duration(hours: 20));
      final w = sacredWindowAt([jerusalemH, lakewoodH], at)!;
      expect(w.startUtc, lakewoodLock.startUtc);
      expect(w.endUtc, lakewoodLock.endUtc);
      expect(w.kind, SacredWindowKind.shabbos);
      // Only Lakewood is still locked after Jerusalem's tzeis + 10.
      final afterJerusalem = lockWindows(
        jerusalemH,
        shabbos,
        shabbos,
      ).single.endUtc.add(_us);
      expect(sacredWindowAt([jerusalemH], afterJerusalem), isNull);
      expect(
        sacredWindowAt([jerusalemH, lakewoodH], afterJerusalem),
        isNotNull,
      );
    });

    test('both bounds are locked; a microsecond outside is not (AC-1)', () {
      final lock = lockWindows(lakewoodH, shabbos, shabbos).single;
      expect(isLockedAt([lakewoodH], lock.startUtc), isTrue);
      expect(isLockedAt([lakewoodH], lock.endUtc), isTrue);
      expect(isLockedAt([lakewoodH], lock.startUtc.subtract(_us)), isFalse);
      expect(isLockedAt([lakewoodH], lock.endUtc.add(_us)), isFalse);
    });

    test('a learner whose zmanim cannot be computed is still locked '
        '(fail closed)', () {
      // Saturday 06:00Z is inside the widest fixed window.
      expect(isLockedAt([_broken], DateTime.utc(2026, 9, 5, 6)), isTrue);
      expect(isLockedAt([_broken], tuesday), isFalse);
    });
  });

  group('nextLockChange', () {
    test('the next lock start, then one microsecond after its end', () {
      final lock = lockWindows(lakewoodH, shabbos, shabbos).single;
      expect(
        nextLockChange([lakewoodH], tuesday.subtract(const Duration(days: 5))),
        lock.startUtc,
      );
      expect(nextLockChange([lakewoodH], lock.startUtc), lock.endUtc.add(_us));
    });

    test('the earliest change over several learners', () {
      final j = lockWindows(jerusalemH, shabbos, shabbos).single;
      final l = lockWindows(lakewoodH, shabbos, shabbos).single;
      final from = DateTime.utc(2026, 9, 2);
      final next = nextLockChange([lakewoodH, jerusalemH], from)!;
      expect(next, j.startUtc.isBefore(l.startUtc) ? j.startUtc : l.startUtc);
    });
  });

  group('classifyLock (greeting kind)', () {
    SacredWindowKind kindAt(LearnerSettingsHistory h, DateTime t) =>
        classifyLock(lockWindows(h, t, t).single, h);

    test('plain Shabbos', () {
      expect(kindAt(lakewoodH, shabbos), SacredWindowKind.shabbos);
    });

    test('yom tov alone, chained into Shabbos, and Yom Kippur', () {
      // Rosh Hashana 5787: Sat 2026-09-12 + Sun 09-13 (Shabbos & Yom Tov).
      expect(
        kindAt(lakewoodH, DateTime.utc(2026, 9, 13, 12)),
        SacredWindowKind.shabbosYomTov,
      );
      // Yom Kippur 5787: Mon 2026-09-21.
      expect(
        kindAt(lakewoodH, DateTime.utc(2026, 9, 21, 12)),
        SacredWindowKind.yomKippur,
      );
      // Shavuot 5786 in Israel: Fri 2026-05-22 chained into Shabbos.
      expect(
        kindAt(jerusalemH, DateTime.utc(2026, 5, 22, 12)),
        SacredWindowKind.shabbosYomTov,
      );
      // Pesach 5786 first days (diaspora): Thu 04-02 + Fri 04-03 + Shabbos.
      expect(
        kindAt(lakewoodH, DateTime.utc(2026, 4, 2, 12)),
        SacredWindowKind.shabbosYomTov,
      );
      // Sukkot 5787 day 1 in Israel: Shabbos 09-26 only.
      expect(
        kindAt(jerusalemH, DateTime.utc(2026, 9, 26, 12)),
        SacredWindowKind.shabbosYomTov,
      );
      // A weekday yom tov alone: Pesach 7th day 5786 in Israel, Wed
      // 2026-04-08.
      expect(
        kindAt(jerusalemH, DateTime.utc(2026, 4, 8, 12)),
        SacredWindowKind.yomTov,
      );
    });
  });
}
