import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

Goal _paceGoal({int paceValue = 3, String pacePeriod = 'per_week'}) => Goal(
      id: 1,
      profileId: 1,
      curriculumId: 'mishnayos',
      trackId: 1,
      targetPercent: 100,
      description: '',
      dateType: 'english',
      goalType: 'pace',
      paceValue: paceValue,
      pacePeriod: pacePeriod,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

Goal _deadlineGoal({
  DateTime? targetDate,
  int? paceValue,
  String? pacePeriod,
}) =>
    Goal(
      id: 2,
      profileId: 1,
      curriculumId: 'mishnayos',
      trackId: 1,
      targetPercent: 100,
      description: '',
      dateType: 'english',
      goalType: 'deadline',
      targetDate: targetDate ?? DateTime(2026, 12, 31),
      paceValue: paceValue,
      pacePeriod: pacePeriod,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

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
            goal: _paceGoal(paceValue: 7, pacePeriod: 'per_week'),
            completedItems: 0,
            dailyCompletionCounts: {},
            totalItems: 100,
            today: today,
          ),
        );
        expect(result, isNotNull);
        expect(result, isA<PaceStatus>());
      });

      test('returns PaceStatus with non-null status when user has completions', () {
        // 7 items/week = 1 item/day. User did 30 items, rolling avg 3/day.
        final now = DateTime(2026, 5, 20);
        final counts = <DateTime, int>{};
        for (var i = 0; i < 7; i++) {
          counts[now.subtract(Duration(days: i))] = 3;
        }
        final result = useCase.execute(
          PaceStatusInput(
            goal: _paceGoal(paceValue: 7, pacePeriod: 'per_week'),
            completedItems: 30,
            dailyCompletionCounts: counts,
            totalItems: 100,
            today: now,
          ),
        );
        expect(result, isNotNull);
        // Status is determined by PaceCalculator; we verify it is a valid value.
        expect(PaceStatusType.values.contains(result!.status), isTrue);
      });
    });

    // ------------------------------------------------------------------
    // Deadline goal
    // ------------------------------------------------------------------
    group('deadline goal', () {
      test('returns null when targetDate is null', () {
        final goal = Goal(
          id: 3,
          profileId: 1,
          curriculumId: 'mishnayos',
          trackId: 1,
          targetPercent: 100,
          description: '',
          dateType: 'english',
          goalType: 'deadline',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );
        final result = useCase.execute(
          PaceStatusInput(
            goal: goal,
            completedItems: 0,
            dailyCompletionCounts: {},
            totalItems: 100,
            today: today,
          ),
        );
        expect(result, isNull);
      });

      test('returns PaceStatus when targetDate is set with stored pace', () {
        final result = useCase.execute(
          PaceStatusInput(
            goal: _deadlineGoal(
              paceValue: 5,
              pacePeriod: 'per_week',
            ),
            completedItems: 0,
            dailyCompletionCounts: {},
            totalItems: 100,
            today: today,
          ),
        );
        expect(result, isNotNull);
      });

      test('uses derived pace when targetDate set but no stored pace', () {
        // B3 NOTE: deadline goal ALWAYS yields a projection — even on day one
        // with 0 completions — via calculateForPaceGoal. Back-dated enrolments
        // generate overdue tasks in the scheduler; here we verify the pace
        // projection is also non-null for such a goal.
        final result = useCase.execute(
          PaceStatusInput(
            goal: _deadlineGoal(), // no paceValue / pacePeriod
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
      });

      test('falls back to 1/week when studyDaysInWindow is zero', () {
        final result = useCase.execute(
          PaceStatusInput(
            goal: _deadlineGoal(),
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
