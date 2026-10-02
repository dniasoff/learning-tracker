// Story 2.10 (DNI-501) T4: the main-track Up to… requests built from the
// unchanged today list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/main_track_up_to_action.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/pump_app.dart';

DailyTask _task(
  CurriculumId c,
  String ref,
  DailyTaskPriority p, {
  int stage = 1,
  String label = 'Track',
}) => DailyTask(
  curriculumId: c,
  contentItemSefariaRef: ref,
  stageOrder: stage,
  priority: p,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: label,
);

void main() {
  test('one request per curriculum, led by its new-learning tasks in task '
      'order (overdue new learning included); reviews and program items '
      'are not leads', () {
    final requests = mainTrackUpToRequests([
      _task(CurriculumId.mishnayos, 'm2', DailyTaskPriority.overdueNewLearning),
      _task(
        CurriculumId.bavli,
        'b1',
        DailyTaskPriority.newLearning,
        label: 'Bavli',
      ),
      _task(CurriculumId.mishnayos, 'm3', DailyTaskPriority.newLearning),
      _task(
        CurriculumId.mishnayos,
        'r1',
        DailyTaskPriority.scheduledChazara,
        stage: 2,
      ),
      _task(CurriculumId.mishnayos, 'p1', DailyTaskPriority.todayProgram),
    ]);
    expect([for (final r in requests) r.curriculumId], ['mishnayos', 'bavli']);
    expect(requests.first.leadRefs, ['m2', 'm3']);
    expect(requests.first.stage, 1);
    expect(requests.last.name, 'Bavli');
  });

  testWidgets('absent when today has no new-learning task', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          ...learnerStateOverrides(scope: c0Scope()),
          allDailyTasksProvider.overrideWith(
            (ref) async => [
              _task(
                CurriculumId.mishnayos,
                'r1',
                DailyTaskPriority.scheduledChazara,
                stage: 2,
              ),
            ],
          ),
        ],
        child: const Scaffold(body: MainTrackUpToActions()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Up to…'), findsNothing);
  });

  testWidgets('one labelled action per curriculum when several have new '
      'learning', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        overrides: [
          ...learnerStateOverrides(scope: c0Scope()),
          allDailyTasksProvider.overrideWith(
            (ref) async => [
              _task(
                CurriculumId.mishnayos,
                'm1',
                DailyTaskPriority.newLearning,
                label: 'Mishnayos',
              ),
              _task(
                CurriculumId.bavli,
                'b1',
                DailyTaskPriority.newLearning,
                label: 'Bavli',
              ),
            ],
          ),
        ],
        child: const Scaffold(body: MainTrackUpToActions()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Mishnayos · up to…'), findsOneWidget);
    expect(find.text('Bavli · up to…'), findsOneWidget);
  });
}
