import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/services/cross_curriculum_aggregator.dart';

void main() {
  late CrossCurriculumAggregator aggregator;

  setUp(() {
    aggregator = CrossCurriculumAggregator();
  });

  group('CrossCurriculumAggregator', () {
    test('returns empty dashboard for no active curricula', () {
      final result = aggregator.aggregate(
        activeCurricula: [],
        completionPercentages: {},
        paceStatuses: {},
        todayTaskCounts: {},
        nextDueItems: {},
        lastCompletions: {},
      );

      expect(result.curriculumSummaries, isEmpty);
      expect(result.totalTasksToday, 0);
      expect(result.activeCurriculaCount, 0);
      expect(result.mostRecentlyActive, isNull);
    });

    test('aggregates data across multiple curricula', () {
      final now = DateTime(2026, 3, 17, 10);
      final yesterday = DateTime(2026, 3, 16, 10);

      final result = aggregator.aggregate(
        activeCurricula: [CurriculumId.mishnayos, CurriculumId.bavli],
        completionPercentages: {
          CurriculumId.mishnayos: 0.5,
          CurriculumId.bavli: 0.3,
        },
        paceStatuses: {CurriculumId.mishnayos: null, CurriculumId.bavli: null},
        todayTaskCounts: {CurriculumId.mishnayos: 3, CurriculumId.bavli: 2},
        nextDueItems: {
          CurriculumId.mishnayos: 'Berakhot 1:1',
          CurriculumId.bavli: null,
        },
        lastCompletions: {
          CurriculumId.mishnayos: now,
          CurriculumId.bavli: yesterday,
        },
      );

      expect(result.curriculumSummaries, hasLength(2));
      expect(result.totalTasksToday, 5);
      expect(result.activeCurriculaCount, 2);
    });

    test('mostRecentlyActive returns curriculum with latest completion', () {
      final now = DateTime(2026, 3, 17, 10);
      final yesterday = DateTime(2026, 3, 16, 10);

      final result = aggregator.aggregate(
        activeCurricula: [CurriculumId.mishnayos, CurriculumId.bavli],
        completionPercentages: {
          CurriculumId.mishnayos: 0.0,
          CurriculumId.bavli: 0.0,
        },
        paceStatuses: {CurriculumId.mishnayos: null, CurriculumId.bavli: null},
        todayTaskCounts: {CurriculumId.mishnayos: 0, CurriculumId.bavli: 0},
        nextDueItems: {CurriculumId.mishnayos: null, CurriculumId.bavli: null},
        lastCompletions: {
          CurriculumId.mishnayos: yesterday,
          CurriculumId.bavli: now,
        },
      );

      expect(result.mostRecentlyActive?.curriculumId, CurriculumId.bavli);
    });

    test('defaults missing map entries gracefully', () {
      final result = aggregator.aggregate(
        activeCurricula: [CurriculumId.chumash],
        completionPercentages: {},
        paceStatuses: {},
        todayTaskCounts: {},
        nextDueItems: {},
        lastCompletions: {},
      );

      expect(result.curriculumSummaries, hasLength(1));
      final summary = result.curriculumSummaries.first;
      expect(summary.completionPercentage, 0.0);
      expect(summary.paceStatus, isNull);
      expect(summary.todayTaskCount, 0);
      expect(summary.nextDueItem, isNull);
      expect(summary.lastCompletionAt, isNull);
      expect(result.totalTasksToday, 0);
    });
  });
}
