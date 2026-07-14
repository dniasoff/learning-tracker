import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart'
    show Completion;
import 'package:learning_tracker/features/dashboard/domain/services/parent_dashboard_aggregator.dart';

void main() {
  group('ParentDashboardAggregator', () {
    group('computeEngagement (static)', () {
      test('returns zero metrics for empty completions', () {
        final now = DateTime(2026, 3, 17, 12); // Tuesday
        final result = ParentDashboardAggregator.computeEngagement([], now);

        expect(result.daysActiveThisWeek, 0);
        expect(result.averageDailyCompletions, 0.0);
      });

      test('counts active days this week correctly', () {
        final now = DateTime(2026, 3, 17, 12); // Tuesday
        // Week starts Monday March 16
        final completions = [
          _makeCompletion(DateTime(2026, 3, 16, 10)), // Monday
          _makeCompletion(DateTime(2026, 3, 16, 14)), // Monday (same day)
          _makeCompletion(DateTime(2026, 3, 17, 8)), // Tuesday
        ];

        final result = ParentDashboardAggregator.computeEngagement(
          completions,
          now,
        );

        expect(result.daysActiveThisWeek, 2); // Mon + Tue
      });

      test('calculates average daily completions over last 7 days', () {
        final now = DateTime(2026, 3, 17, 12);
        // 7 completions in last 7 days => avg 1.0
        final completions = List.generate(
          7,
          (i) => _makeCompletion(now.subtract(Duration(days: i, hours: 1))),
        );

        final result = ParentDashboardAggregator.computeEngagement(
          completions,
          now,
        );

        expect(result.averageDailyCompletions, 1.0);
      });
    });
  });
}

Completion _makeCompletion(DateTime completedAt) {
  return Completion(
    id: 0,
    profileId: 0,
    curriculumId: 'mishnayos',
    sefariaRef: 'ref_1',
    stageId: 1,
    trackType: 'personal',
    trackId: 1,
    completedAt: completedAt,
    points: 10,
    derivedFromEvents: false,
  );
}
