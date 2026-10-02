// Mirror test for `lib/domain/learner_state/points.dart`: the C0 (DNI-524)
// value types plus DNI-468 (Story 1.6) AC-4 (filtered, clamped balance and
// lifetime) and AC-5 (achievement crossing and latch).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';

/// A `pts_{eventId}` row of [amount] points.
PointsLedgerRow _pts(String eventId, int amount) => PointsLedgerRow(
  id: 'pts_$eventId',
  amount: amount,
  eventId: eventId,
  entryKind: 'completion',
);

/// A non-event row of [kind].
PointsLedgerRow _row(String id, int amount, String kind) =>
    PointsLedgerRow(id: id, amount: amount, entryKind: kind);

void main() {
  test('value types compare by value', () {
    expect(
      const PointsLedgerRow(id: 'pts_a', amount: 5, eventId: 'a'),
      const PointsLedgerRow(id: 'pts_a', amount: 5, eventId: 'a'),
    );
    expect(
      const PointsLedgerRow(id: 'pts_a', amount: 5),
      isNot(const PointsLedgerRow(id: 'pts_a', amount: 5, eventId: 'a')),
    );
    expect(
      const PointsLedgerRow(id: 'x', amount: 5, entryKind: 'parent_add'),
      isNot(const PointsLedgerRow(id: 'x', amount: 5)),
    );
    expect(
      const PointsTotals(balance: 3, lifetimeEarned: 9),
      const PointsTotals(balance: 3, lifetimeEarned: 9),
    );
    expect(
      const AchievementThreshold(id: 'x', points: 100),
      const AchievementThreshold(id: 'x', points: 100),
    );
  });

  group('AC-4: pointsTotals', () {
    test('counts earning pts_ rows and every non-event row', () {
      final rows = [
        _pts('a', 10),
        _pts('b', 5),
        _pts('ineligible', 7),
        _pts('orphan', 9),
        _row('add', 4, 'parent_add'),
        _row('spend', -6, 'redemption_debit'),
        _row('refund', 2, 'redemption_refund'),
        _row('deduct', -1, 'parent_deduct'),
        _row('legacy', 3, 'completion'),
      ];
      // 'ineligible' is an event the engine does not count as earning;
      // 'orphan' names no event at all. Neither counts.
      expect(
        pointsTotals(rows, {'a', 'b'}),
        // balance: 10 + 5 + 4 - 6 + 2 - 1 + 3; lifetime: 10 + 5 + 4 + 3.
        const PointsTotals(balance: 17, lifetimeEarned: 22),
      );
    });

    test('voiding an earning event lowers balance and lifetime', () {
      final rows = [_pts('a', 10), _pts('b', 5), _row('spend', -3, 'x')];
      final before = pointsTotals(rows, {'a', 'b'});
      final after = pointsTotals(rows, {'a'});
      expect(before, const PointsTotals(balance: 12, lifetimeEarned: 15));
      expect(after, const PointsTotals(balance: 7, lifetimeEarned: 10));
    });

    test('clamps both sums to [0, 1 << 30]', () {
      expect(
        pointsTotals(
          [_pts('a', 4), _row('spend', -10, 'redemption_debit')],
          {'a'},
        ),
        const PointsTotals(balance: 0, lifetimeEarned: 4),
      );
      expect(
        pointsTotals(
          [
            _pts('a', pointsTotalMax),
            _row('add', pointsTotalMax, 'parent_add'),
          ],
          {'a'},
        ),
        const PointsTotals(
          balance: pointsTotalMax,
          lifetimeEarned: pointsTotalMax,
        ),
      );
      expect(pointsTotalMax, 1 << 30);
    });

    test('a non-event row without a lifetime kind counts toward the '
        'balance only', () {
      expect(
        pointsTotals(const [PointsLedgerRow(id: 'x', amount: 5)], const {}),
        const PointsTotals(balance: 5, lifetimeEarned: 0),
      );
    });

    test('a repeated ledger id counts once', () {
      expect(
        pointsTotals([_pts('a', 10), _pts('a', 10)], {'a'}),
        const PointsTotals(balance: 10, lifetimeEarned: 10),
      );
    });

    test('no rows give zero totals', () {
      expect(
        pointsTotals(const [], const {'a'}),
        const PointsTotals(balance: 0, lifetimeEarned: 0),
      );
    });
  });

  group('AC-5: achievements', () {
    const thresholds = [
      AchievementThreshold(id: 'bronze', points: 10),
      AchievementThreshold(id: 'silver', points: 50),
      AchievementThreshold(id: 'gold', points: 100),
    ];

    PointsTotals lifetime(int points) =>
        PointsTotals(balance: 0, lifetimeEarned: points);

    test('returns crossed ids that are not yet unlocked', () {
      // Below every threshold.
      expect(
        newlyCrossedAchievements(lifetime(9), thresholds, const {}),
        isEmpty,
      );
      expect(newlyCrossedAchievements(lifetime(10), thresholds, const {}), {
        'bronze',
      });
      expect(newlyCrossedAchievements(lifetime(60), thresholds, {'bronze'}), {
        'silver',
      });
      expect(
        newlyCrossedAchievements(lifetime(100), thresholds, {
          'bronze',
          'silver',
          'gold',
        }),
        isEmpty,
      );
    });

    test('crossing is judged on lifetime earned, not the balance', () {
      expect(
        newlyCrossedAchievements(
          const PointsTotals(balance: 200, lifetimeEarned: 20),
          thresholds,
          const {},
        ),
        {'bronze'},
      );
    });

    test('an unlocked id stays unlocked after the totals drop (latch)', () {
      // A void took lifetime from 60 to 5: nothing is newly crossed and
      // nothing is taken back.
      expect(
        newlyCrossedAchievements(lifetime(5), thresholds, {'bronze', 'silver'}),
        isEmpty,
      );
      expect(
        unlockedAchievementIds(lifetime(5), thresholds, {'bronze', 'silver'}),
        {'bronze', 'silver'},
      );
      expect(unlockedAchievementIds(lifetime(100), thresholds, {'silver'}), {
        'bronze',
        'silver',
        'gold',
      });
    });
  });
}
