/// Branch coverage for scheduler provider consumers.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

DailyTask _task({
  required CurriculumId curriculum,
  required String ref,
  required DailyTaskPriority priority,
  required bool overdue,
}) => DailyTask(
  curriculumId: curriculum,
  contentItemSefariaRef: ref,
  stageOrder: 1,
  priority: priority,
  isOverdue: overdue,
  reason: 'branch',
  stageName: 'Learn',
  trackLabel: curriculum.storageKey,
);

void main() {
  test(
    'allDailyTasks branch preserves both active curricula and priority order',
    () async {
      final container = ProviderContainer(
        overrides: [
          allDailyTasksProvider.overrideWith(
            (ref) async => [
              _task(
                curriculum: CurriculumId.mishnayos,
                ref: 'mish-overdue',
                priority: DailyTaskPriority.overdueProgram,
                overdue: true,
              ),
              _task(
                curriculum: CurriculumId.bavli,
                ref: 'bavli-today',
                priority: DailyTaskPriority.newLearning,
                overdue: false,
              ),
            ],
          ),
        ],
      );
      addTearDown(container.dispose);

      final tasks = await container.read(allDailyTasksProvider.future);
      expect(tasks, hasLength(2));
      expect(tasks.map((task) => task.curriculumId).toSet(), {
        CurriculumId.mishnayos,
        CurriculumId.bavli,
      });
      expect(tasks.first.priority, DailyTaskPriority.overdueProgram);
      expect(tasks.last.priority, DailyTaskPriority.newLearning);
    },
  );

  test(
    'allDailyTasks error branch remains an error, not a fabricated empty plan',
    () async {
      final container = ProviderContainer(
        retry: (_, __) => null,
        overrides: [
          allDailyTasksProvider.overrideWith(
            (ref) =>
                Future<List<DailyTask>>.error(StateError('provider failed')),
          ),
        ],
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(allDailyTasksProvider.future),
        throwsA(isA<StateError>()),
      );
    },
  );
}
