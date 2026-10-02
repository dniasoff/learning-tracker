// Mirror test for `lib/domain/learner_state/points.dart` (C0, DNI-524).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';

import '../../helpers/learner_state/c0_stub_matcher.dart';

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
      const PointsTotals(balance: 3, lifetimeEarned: 9),
      const PointsTotals(balance: 3, lifetimeEarned: 9),
    );
    expect(
      const AchievementThreshold(id: 'x', points: 100),
      const AchievementThreshold(id: 'x', points: 100),
    );
  });

  group('rule functions are C0 stubs owned by DNI-468', () {
    test('pointsTotals', () {
      expect(
        () => pointsTotals(const [], const {}),
        throwsC0Stub('DNI-468', 'pointsTotals'),
      );
    });

    test('newlyCrossedAchievements', () {
      expect(
        () => newlyCrossedAchievements(
          const PointsTotals(balance: 0, lifetimeEarned: 0),
          const [],
          const {},
        ),
        throwsC0Stub('DNI-468', 'newlyCrossedAchievements'),
      );
    });
  });
}
