// DNI-505 (Story 3.2) T5: catch-up card availability over the canonical
// AD-36 / AD-40 functions (AC-1, AC-3, AC-4, AC-5, AC-6, EC-1).
//
// Deterministic UTC instants and learner-zone fixtures; no wall clock.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

import '../../helpers/learner_state/lock_fixtures.dart';

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d);

void main() {
  final ny = LearnerZone.of('America/New_York');

  group('AC-1 / AC-2: a regular Shabbos (Lakewood)', () {
    final h = constantHistory(lakewood);
    // 2026-10-10 is a plain Shabbos (Sukkot ended 2026-10-04).
    final lock = lockWindows(
      h,
      ny.at(_day(2026, 10, 10), hour: 12),
      ny.at(_day(2026, 10, 10), hour: 12),
    ).single;

    test('a card from L.end, on the canonical locked days and window', () {
      final sundayNoon = ny.at(_day(2026, 10, 11), hour: 12);
      final cards = catchUpCardWindowsAt(h, sundayNoon);
      expect(cards, hasLength(1));
      final card = cards.single;
      expect(card.lock, lock);
      expect(card.window, catchUpWindow(lock, h));
      expect(card.allLockedDays, lockedDays(lock, h));
      expect(card.lockedDays.map((d) => d.date), ['2026-10-10']);
      expect(card.kind, ErevKind.shabbos);
      expect(card.lastDay, '2026-10-11');
      expect(card.gap, isNull);
    });

    test('pending just after L.end and on Saturday night', () {
      expect(catchUpCardWindowsAt(h, lock.endUtc), isEmpty);
      expect(catchUpCardWindowsAt(h, lock.endUtc.add(civilTick)), hasLength(1));
      expect(
        catchUpCardWindowsAt(h, ny.at(_day(2026, 10, 10), hour: 23)),
        hasLength(1),
      );
    });

    test('none during the lock', () {
      expect(
        catchUpCardWindowsAt(h, ny.at(_day(2026, 10, 10), hour: 12)),
        isEmpty,
      );
    });

    test('gone at 00:00 Monday learner-local', () {
      final monday = ny.startOf(_day(2026, 10, 12));
      final card = catchUpCardWindowsAt(h, monday.subtract(civilTick)).single;
      expect(card.expiresAtUtc, monday);
      expect(catchUpCardWindowsAt(h, monday), isEmpty);
    });

    test('the next transition is the card expiry', () {
      expect(
        nextCatchUpTransition(h, ny.at(_day(2026, 10, 11), hour: 12)),
        ny.startOf(_day(2026, 10, 12)),
      );
    });

    test('inside the lock the next transition is just after its end', () {
      expect(
        nextCatchUpTransition(h, ny.at(_day(2026, 10, 10), hour: 12)),
        lock.endUtc.add(civilTick),
      );
    });
  });

  group('AC-3: no location means no catch-up card', () {
    final h = constantHistory(newYorkNoLocation);

    test(
      'there is no lock or catch-up card at any point on Friday/Shabbos',
      () {
        expect(
          catchUpCardWindowsAt(h, ny.at(_day(2026, 10, 9), hour: 16)),
          isEmpty,
        );
        expect(
          catchUpCardWindowsAt(h, ny.at(_day(2026, 10, 10), hour: 12)),
          isEmpty,
        );
        expect(
          catchUpCardWindowsAt(h, ny.at(_day(2026, 10, 11), hour: 12)),
          isEmpty,
        );
      },
    );
  });

  group('AC-4: diaspora yom tov chained into Shabbos vs Israel', () {
    // Pesach 7th/8th days 2027-04-22/23 (diaspora), Shabbos 2027-04-24.
    test('diaspora: one card over Thursday, Friday and Shabbos', () {
      final h = constantHistory(lakewood);
      final cards = catchUpCardWindowsAt(h, ny.at(_day(2027, 4, 25), hour: 12));
      expect(cards, hasLength(1));
      expect(cards.single.lockedDays.map((d) => d.date), [
        '2027-04-22',
        '2027-04-23',
        '2027-04-24',
      ]);
      expect(cards.single.kind, ErevKind.yomTovAndShabbos);
      expect(cards.single.lastDay, '2027-04-25');
    });

    test('Israel: one-day yom tov, so Thursday and Shabbos are two locks', () {
      final h = constantHistory(jerusalem);
      final jlm = LearnerZone.of('Asia/Jerusalem');
      final cards = catchUpCardWindowsAt(
        h,
        jlm.at(_day(2027, 4, 25), hour: 12),
      );
      expect(
        [for (final c in cards) c.lockedDays.map((d) => d.date)],
        [
          ['2027-04-22'],
          ['2027-04-24'],
        ],
      );
      expect(cards.first.kind, ErevKind.yomTov);
      expect(cards.last.kind, ErevKind.shabbos);
    });
  });

  group('AC-6: an intervening lock pauses the earlier card', () {
    final h = constantHistory(jerusalem);
    final jlm = LearnerZone.of('Asia/Jerusalem');

    test('A alone between the locks, none during B, both after B', () {
      final friday = catchUpCardWindowsAt(
        h,
        jlm.at(_day(2027, 4, 23), hour: 9),
      );
      expect(friday.map((c) => c.lockedDays.single.date), ['2027-04-22']);

      expect(
        catchUpCardWindowsAt(h, jlm.at(_day(2027, 4, 24), hour: 12)),
        isEmpty,
      );

      final sunday = catchUpCardWindowsAt(
        h,
        jlm.at(_day(2027, 4, 25), hour: 9),
      );
      expect(sunday, hasLength(2));
      final [a, b] = sunday;
      // Oldest first, each with its own window and caption.
      expect(a.lock.endUtc.isBefore(b.lock.startUtc), isTrue);
      expect(a.window, catchUpWindow(a.lock, h));
      expect(b.window, catchUpWindow(b.lock, h));
      // A's unlocked time resumes after B: it reaches the first day with
      // no locked instant (Sunday), as B's does.
      expect(a.lastDay, '2027-04-25');
      expect(b.lastDay, '2027-04-25');
      expect(a.key, isNot(b.key));
    });

    test('both are gone at 00:00 Monday', () {
      expect(catchUpCardWindowsAt(h, jlm.startOf(_day(2027, 4, 26))), isEmpty);
    });
  });

  group('AC-5: a history that yields more than three locked days', () {
    final h = constantHistory(lakewood);
    final sundayNoon = ny.at(_day(2026, 10, 11), hour: 12);

    test('keeps the three latest days, reports the gap, never throws', () {
      Set<String> five(LockWindow lock, _) => {
        '2026-10-06',
        '2026-10-07',
        '2026-10-08',
        '2026-10-09',
        '2026-10-10',
      };
      final card = catchUpCardWindowsAt(
        h,
        sundayNoon,
        lockedDaysOf: five,
      ).single;
      expect(card.lockedDays.map((d) => d.date), [
        '2026-10-08',
        '2026-10-09',
        '2026-10-10',
      ]);
      expect(card.allLockedDays, hasLength(5));
      expect(card.gap, isNotNull);
      expect(card.gap!.droppedDays, ['2026-10-06', '2026-10-07']);
      expect(CatchUpHistoryGap.reason, 'catch_up_history_gap');
    });

    test('a lock with no locked day yields no card, never an empty one', () {
      expect(
        catchUpCardWindowsAt(h, sundayNoon, lockedDaysOf: (_, _) => {}),
        isEmpty,
      );
    });
  });

  group('EC-1: learner-local days, not UTC or device days', () {
    test('a zone east of UTC: the card ends at local midnight, not UTC', () {
      final h = constantHistory(
        lockSettings(
          timeZone: 'Pacific/Auckland',
          latitude: -36.8485,
          longitude: 174.7633,
          inIsrael: false,
        ),
      );
      final nz = LearnerZone.of('Pacific/Auckland');
      // Saturday Shabbos in the configured Auckland location.
      final card = catchUpCardWindowsAt(
        h,
        nz.at(_day(2026, 10, 11), hour: 12),
      ).single;
      expect(card.lockedDays.map((d) => d.date), ['2026-10-10']);
      expect(card.lastDay, '2026-10-11');
      final monday = nz.startOf(_day(2026, 10, 12));
      // Local Monday 00:00 is still Sunday in UTC.
      expect(monday.toUtc().day, 11);
      expect(catchUpCardWindowsAt(h, monday.subtract(civilTick)), hasLength(1));
      expect(catchUpCardWindowsAt(h, monday), isEmpty);
    });

    test('across a spring-forward Sunday the card ends at EDT midnight', () {
      final h = constantHistory(newYorkLocated);
      final card = catchUpCardWindowsAt(h, DateTime.utc(2026, 3, 8, 18)).single;
      expect(card.lockedDays.map((d) => d.date), ['2026-03-07']);
      expect(card.lastDay, '2026-03-08');
      // 00:00 Monday EDT (UTC−4), not EST.
      expect(card.expiresAtUtc, DateTime.utc(2026, 3, 9, 4));
    });

    test('a move after the lock: days by the lock-start zone, expiry by the '
        'zone at L.end', () {
      final lock = lockWindows(
        constantHistory(lakewood),
        ny.at(_day(2026, 10, 10), hour: 12),
        ny.at(_day(2026, 10, 10), hour: 12),
      ).single;
      final moved = movedHistory(
        lakewood,
        lock.endUtc.add(const Duration(hours: 2)),
        jerusalem,
      );
      final card = catchUpCardWindowsAt(
        moved,
        lock.endUtc.add(const Duration(hours: 3)),
      ).single;
      expect(card.lockedDays.map((d) => d.date), ['2026-10-10']);
      expect(card.lastDay, '2026-10-11');
      expect(card.expiresAtUtc, ny.startOf(_day(2026, 10, 12)));
    });
  });
}
