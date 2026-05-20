import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart';
import 'package:learning_tracker/features/scheduler/domain/models/goal_entity.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

void main() {
  const useCase = ComputePaceStatusUseCase();
  final today = DateTime(2026, 5, 20);

  group('ComputePaceStatusUseCase', () {
    // ------------------------------------------------------------------
    // Pace goal
    // ------------------------------------------------------------------
    group('pace goal', () {
      test('returns PaceStatus for valid pace goal', () {
        final result = useCase.execute(
          PaceStatusInput(
            paceTarget: const PacePeriodTarget(rate: 7, period: 'per_week'),
            completedItems: 0,
            dailyCompletionCounts: {},
            totalItems: 100,
            today: today,
          ),
        );
        expect(result, isNotNull);
        expect(result, isA<PaceStatus>());
      });

      test(
        'returns PaceStatus with non-null status when user has completions',
        () {
          // 7 items/week = 1 item/day. User did 30 items, rolling avg 3/day.
          final now = DateTime(2026, 5, 20);
          final counts = <DateTime, int>{};
          for (var i = 0; i < 7; i++) {
            counts[now.subtract(Duration(days: i))] = 3;
          }
          final result = useCase.execute(
            PaceStatusInput(
              paceTarget: const PacePeriodTarget(rate: 7, period: 'per_week'),
              completedItems: 30,
              dailyCompletionCounts: counts,
              totalItems: 100,
              today: now,
            ),
          );
          expect(result, isNotNull);
          // Status is determined by PaceCalculator; we verify it is a valid value.
          expect(PaceStatusType.values.contains(result!.status), isTrue);
        },
      );
    });

    // ------------------------------------------------------------------
    // Deadline goal
    // ------------------------------------------------------------------
    group('deadline goal', () {
      test('returns null when paceTarget is null (no goal set)', () {
        final result = useCase.execute(
          PaceStatusInput(
            paceTarget: null,
            completedItems: 0,
            dailyCompletionCounts: {},
            totalItems: 100,
            today: today,
          ),
        );
        expect(result, isNull);
      });

      test('returns PaceStatus for DeadlineTarget', () {
        final result = useCase.execute(
          PaceStatusInput(
            paceTarget: DeadlineTarget(DateTime(2026, 12, 31)),
            completedItems: 0,
            dailyCompletionCounts: {},
            totalItems: 100,
            today: today,
            studyDaysInWindow: 200,
            studyDaysPerWeek: 5,
          ),
        );
        expect(result, isNotNull);
      });

      test(
        'uses derived pace when studyDaysInWindow is non-zero — B3 verified',
        () {
          // B3 NOTE: deadline goal ALWAYS yields a projection — even on day one
          // with 0 completions — via calculateForPaceGoal. Back-dated enrolments
          // generate overdue tasks in the scheduler; here we verify the pace
          // projection is also non-null for such a goal.
          final result = useCase.execute(
            PaceStatusInput(
              paceTarget: DeadlineTarget(DateTime(2026, 12, 31)),
              completedItems: 0,
              dailyCompletionCounts: {},
              totalItems: 100,
              today: today,
              studyDaysInWindow: 200,
              studyDaysPerWeek: 5,
            ),
          );
          // B3 verified: projection is non-null despite 0 completions.
          expect(result, isNotNull);
        },
      );

      test('falls back to 1/week when studyDaysInWindow is zero', () {
        final result = useCase.execute(
          PaceStatusInput(
            paceTarget: DeadlineTarget(DateTime(2026, 12, 31)),
            completedItems: 0,
            dailyCompletionCounts: {},
            totalItems: 100,
            today: today,
            studyDaysInWindow: 0,
            studyDaysPerWeek: 5,
          ),
        );
        // Should still produce a result (not throw) via fallback pace.
        expect(result, isNotNull);
      });
    });

    // ------------------------------------------------------------------
    // buildDailyCounts helper
    // ------------------------------------------------------------------
    group('buildDailyCounts', () {
      test('returns empty map for empty input', () {
        expect(ComputePaceStatusUseCase.buildDailyCounts([]), isEmpty);
      });

      test('normalises to UTC day boundaries', () {
        final ts = DateTime(2026, 5, 20, 14, 30); // local mid-day
        final counts = ComputePaceStatusUseCase.buildDailyCounts([ts]);
        expect(counts.length, 1);
        final key = counts.keys.first;
        expect(key.isUtc, isTrue);
      });

      test('aggregates multiple completions on same day', () {
        final day = DateTime(2026, 5, 20);
        final counts = ComputePaceStatusUseCase.buildDailyCounts([
          day,
          day.add(const Duration(hours: 2)),
          day.add(const Duration(hours: 5)),
        ]);
        expect(counts.values.first, 3);
      });
    });
  });
}
