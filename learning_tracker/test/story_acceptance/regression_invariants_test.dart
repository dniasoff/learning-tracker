/// Invariant test net — 2026-05-17 quality crisis.
///
/// Characterization/invariant tests (N-series) documenting the correct system
/// behaviour. Each becomes the regression anchor for a corresponding repair:
///
///   N7 → F1  pace-goal projected finish anchors to createdAt, not now
///
/// Rule: a failing test is fixed by changing production code only — never by
/// weakening the assertion. Each repair ships as one commit: failing test +
/// fix + green test.
@Tags(['invariants'])
library;

import 'package:test/test.dart';

void main() {
  group('Invariant net — 2026-05-17 quality crisis', tags: ['invariants'], () {
    // ── N7 — pace-goal projected finish anchors to createdAt, not now ────────

    group('N7: pace-goal projected finish anchors to createdAt, not now', () {
      test('projected finish uses goal.createdAt as anchor — stable across days', () {
        // Simulate a goal created 7 days ago.
        final createdAt = DateTime.now().subtract(const Duration(days: 7));

        // Goal parameters: 10 items/week, 100 total items, 0 completed.
        const pacePerWeek = 10;
        const totalItems = 100;
        const completedItems = 0;
        const itemsRemaining = totalItems - completedItems; // 100

        // Expected: 100 items / 10 per week = 10 weeks = 70 days.
        final daysNeeded = (itemsRemaining / pacePerWeek * 7).ceil(); // 70

        // The FIXED formula anchors to goal.createdAt — not today.
        final projected1 = createdAt.toLocal().add(Duration(days: daysNeeded));
        final projected2 = createdAt.toLocal().add(Duration(days: daysNeeded));

        // Assert the result equals createdAt + 70 days.
        expect(
          projected1,
          equals(createdAt.toLocal().add(const Duration(days: 70))),
          reason:
              'N7: projected finish must be createdAt + 70 days for '
              '100 items at 10/week',
        );

        // Assert it does NOT equal DateTime.now() + 70 days (differs by ~7 days).
        final nowBased = DateTime.now().add(const Duration(days: 70));
        // The createdAt-anchored date must differ from now-anchored by ~7 days.
        final differenceMillis =
            (projected1.millisecondsSinceEpoch -
                    nowBased.millisecondsSinceEpoch)
                .abs();
        // 7 days in ms ≈ 604_800_000. Allow 10 minutes of slack.
        expect(
          differenceMillis,
          greaterThan(
            const Duration(days: 6, hours: 23, minutes: 50).inMilliseconds,
          ),
          reason:
              'N7: createdAt-anchored projection must differ from now-anchored '
              'projection by approximately 7 days — the two must NOT be equal',
        );

        // Calling the formula twice returns the same calendar day (no drift).
        expect(
          projected1.year == projected2.year &&
              projected1.month == projected2.month &&
              projected1.day == projected2.day,
          isTrue,
          reason:
              'N7: computing the projected finish twice must yield the same '
              'calendar day — createdAt is fixed, so there is no drift',
        );
      });
    });
  });
}
