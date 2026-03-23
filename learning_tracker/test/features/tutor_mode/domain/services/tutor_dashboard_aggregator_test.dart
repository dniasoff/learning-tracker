import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/tutor_mode/domain/services/tutor_dashboard_aggregator.dart';

void main() {
  group('TutorDashboardData', () {
    group('filterByCurriculum', () {
      test('filters all collections by curriculum', () {
        final data = TutorDashboardData(
          activeCurricula: [CurriculumId.mishnayos, CurriculumId.bavli],
          completionHistory: [],
          chazaraQueue: [
            ChazaraQueueItem(
              curriculumId: CurriculumId.mishnayos,
              sefariaRef: 'ref_1',
              stageName: 'Chazara 1',
              urgency: ChazaraUrgency.dueToday,
              dueDate: DateTime(2026, 3, 17),
              daysOverdue: 0,
            ),
            ChazaraQueueItem(
              curriculumId: CurriculumId.bavli,
              sefariaRef: 'ref_2',
              stageName: 'Chazara 1',
              urgency: ChazaraUrgency.overdue,
              dueDate: DateTime(2026, 3, 15),
              daysOverdue: 2,
            ),
          ],
          paceInfo: {
            CurriculumId.mishnayos: const TutorPaceInfo(
              paceStatus: null,
              completionPercentage: 0.5,
              totalCompletions: 10,
            ),
          },
          dailyTasks: [
            const DailyTask(
              curriculumId: CurriculumId.mishnayos,
              contentItemSefariaRef: 'ref_1',
              stageOrder: 1,
              stageDefinitionId: 1,
              priority: DailyTaskPriority.newLearning,
              isOverdue: false,
              reason: 'New',
              stageName: 'Learn',
            ),
            const DailyTask(
              curriculumId: CurriculumId.bavli,
              contentItemSefariaRef: 'ref_2',
              stageOrder: 1,
              stageDefinitionId: 1,
              priority: DailyTaskPriority.newLearning,
              isOverdue: false,
              reason: 'New',
              stageName: 'Learn',
            ),
          ],
        );

        final filtered = data.filterByCurriculum(CurriculumId.mishnayos);

        expect(filtered.activeCurricula, hasLength(2)); // preserved
        expect(filtered.chazaraQueue, hasLength(1));
        expect(
          filtered.chazaraQueue.first.curriculumId,
          CurriculumId.mishnayos,
        );
        expect(filtered.paceInfo, hasLength(1));
        expect(filtered.dailyTasks, hasLength(1));
        expect(filtered.dailyTasks.first.curriculumId, CurriculumId.mishnayos);
      });
    });
  });

  group('ChazaraQueueItem', () {
    test('urgency enum ordering: overdue < dueToday < upcoming', () {
      expect(
        ChazaraUrgency.overdue.index,
        lessThan(ChazaraUrgency.dueToday.index),
      );
      expect(
        ChazaraUrgency.dueToday.index,
        lessThan(ChazaraUrgency.upcoming.index),
      );
    });
  });
}
