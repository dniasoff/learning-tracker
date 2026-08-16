/// Story acceptance coverage for Epic 7 — dashboard.
@Tags(['epic_7'])
library;

import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/cross_curriculum_aggregator.dart';
import 'package:test/test.dart';

void main() {
  group('Story 7 — dashboard identity', tags: ['story_7_1', 'story_7_2'], () {
    test('dashboard aggregation preserves pace and task data', () {
      final pace = PaceStatus(
        status: PaceStatusType.ahead,
        daysDelta: 2,
        delta: const DateScheduleDelta(DateDelta(2)),
        projectedCompletionDate: DateTime.utc(2026, 10, 15),
        rollingAverage: 3,
      );
      final stats = CrossCurriculumAggregator().aggregate(
        activeCurricula: const [CurriculumId.mishnayos],
        completionPercentages: const {CurriculumId.mishnayos: 0.45},
        paceStatuses: {CurriculumId.mishnayos: pace},
        todayTaskCounts: const {CurriculumId.mishnayos: 5},
        nextDueItems: const {CurriculumId.mishnayos: 'Berakhot 1.3'},
        lastCompletions: {CurriculumId.mishnayos: DateTime.utc(2026, 8, 1)},
      );
      expect(stats.curriculumSummaries.single.paceStatus, same(pace));
      expect(stats.curriculumSummaries.single.todayTaskCount, 5);
      expect(stats.totalTasksToday, 5);
    });

    test('dashboard breadcrumb trims the leading seder', () {
      expect(trimSederFromBreadcrumb('זרעים › ברכות › פרק א'), 'ברכות › פרק א');
      expect(trimSederFromBreadcrumb('ברכות'), 'ברכות');
    });
  });

  group(
    'Story 7.3 — progress charts',
    tags: ['story_7_3'],
    skip:
        'Blocked: chart/progress assertions in the original suite read Drift completion and goal DAOs; Firestore progress adapters are not wired into this acceptance construction.',
    () {
      test('placeholder for the pending Firestore progress seam', () {});
    },
  );
}
