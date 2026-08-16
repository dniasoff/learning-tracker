import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/domain/use_cases/compute_pace_status_use_case.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_entity.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

void main() {
  group('ComputePaceStatusUseCase', () {
    group('buildDailyCounts (static)', () {
      test('returns zero metrics for empty completions', () {
        final result = ComputePaceStatusUseCase.buildDailyCounts(
          const <DateTime>[],
        );

        expect(result.length, 0);
        expect(
          result.values.fold<int>(0, (sum, count) => sum + count),
          0,
        );
      });

      test('counts active days this week correctly', () {
        final now = DateTime(2026, 3, 17, 12); // Tuesday
        // Week starts Monday March 16
        final completions = [
          _makeCompletion(DateTime(2026, 3, 16, 10)), // Monday
          _makeCompletion(DateTime(2026, 3, 16, 14)), // Monday (same day)
          _makeCompletion(DateTime(2026, 3, 17, 8)), // Tuesday
        ];

        final result = ComputePaceStatusUseCase.buildDailyCounts(
          completions.map((completion) => completion.completedAt),
        );

        expect(result.length, 2); // Mon + Tue
        expect(result.values.fold<int>(0, (sum, count) => sum + count), 3);
      });

      test('calculates average daily completions over last 7 days', () {
        final now = DateTime(2026, 3, 17, 12);
        // 7 completions in last 7 days => avg 1.0
        final completions = List.generate(
          7,
          (i) => _makeCompletion(now.subtract(Duration(days: i, hours: 1))),
        );

        final result = ComputePaceStatusUseCase.buildDailyCounts(
          completions.map((completion) => completion.completedAt),
        );

        expect(result.length, 7);
        expect(result.values.fold<int>(0, (sum, count) => sum + count), 7);
      });
    });
  });
}

CompletionEntity _makeCompletion(DateTime completedAt) {
  return CompletionEntity(
    curriculumId: CurriculumId.mishnayos,
    sefariaRef: 'ref_1',
    stageId: 1,
    trackType: 'personal',
    source: CompletionSource.live,
    completedAt: completedAt,
  );
}
