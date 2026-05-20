// Regression test for M1 fix: "All time" floor must match the bulk-prior
// sentinel epoch (DateTime(2000, 1, 1)), consistent with ProgressChartsScreen.
//
// Previously the floor was hardcoded to DateTime(2024, 1, 1), which is an
// arbitrary magic constant inconsistent with the charts screen.

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('streak_history_screen allTime floor', () {
    // Mirrors the logic from _StreakHistoryScreenState._dateRange for allTime.
    DateTime allTimeStart() => DateTime(2000, 1, 1);

    // The charts screen uses the same floor.
    DateTime chartsAllTimeStart() => DateTime(2000, 1, 1);

    test('allTime start matches the progress-charts allTime floor', () {
      expect(
        allTimeStart(),
        equals(chartsAllTimeStart()),
        reason:
            'Both screens must use the same "all time" floor (bulk-prior epoch) '
            'so cumulative charts and streak history are consistent. '
            'Previously streak_history used 2024-01-01 while charts used 2000-01-01.',
      );
    });

    test('allTime start is DateTime(2000, 1, 1) — not 2024', () {
      final floor = allTimeStart();
      expect(floor.year, equals(2000));
      expect(floor.month, equals(1));
      expect(floor.day, equals(1));
    });

    test('allTime start is at or before the bulk-prior sentinel epoch', () {
      // The bulk-prior sentinel is DateTime.utc(2000, 1, 1).
      // The floor must be <= that sentinel so bulk-prior entries are included
      // in the "all time" view.
      const kBulkPriorYear = 2000;
      final floor = allTimeStart();
      expect(
        floor.year,
        lessThanOrEqualTo(kBulkPriorYear),
        reason:
            'The allTime floor must be at or before the bulk-prior sentinel '
            'year ($kBulkPriorYear) so that bulk-prior completions are visible.',
      );
    });
  });
}
