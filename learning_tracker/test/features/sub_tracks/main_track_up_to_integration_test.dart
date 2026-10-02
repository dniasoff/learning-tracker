// Story 2.10 (DNI-501) AC-5 integration: Up to… on the main-track today
// list, through the real LearningCommands and engine.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/main_track_up_to_action.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/pump_app.dart';
import 'helpers/capture_harness.dart';
import 'helpers/up_to_fixtures.dart';

/// Tuesday 2026-09-01 08:00Z.
final _morning = engineAt(480);

DailyTask _task(
  String ref, {
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  int stage = 1,
}) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: ref,
  stageOrder: stage,
  priority: priority,
  isOverdue: false,
  reason: 'test',
  stageName: stage == 1 ? 'Learn' : 'Chazara',
  trackLabel: 'Mishnayos',
);

final _tasks = [
  _task('Mishnah Berakhot 1:1'),
  _task('Mishnah Berakhot 1:2'),
  _task(
    'Mishnah Peah 1:2',
    priority: DailyTaskPriority.scheduledChazara,
    stage: 2,
  ),
];

class _Tutored extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: 'talmid',
    ownerUid: 'owner',
    grantId: 'grant',
    permissions: TutorPermissions(),
    tutorOwnProfileId: 'tutor-own',
  );
}

Future<(CaptureRig, List<int>)> _pump(
  WidgetTester tester, {
  bool tutored = false,
}) async {
  final rig = CaptureRig(now: _morning);
  addTearDown(rig.dispose);
  final builds = [0];
  useSurface(tester, phoneSize);
  await tester.pumpWidget(
    pumpApp(
      overrides: [
        ...rig.overrides(),
        allDailyTasksProvider.overrideWith((ref) async {
          builds[0]++;
          return _tasks;
        }),
        if (tutored)
          activeTutoredProfileSelectionProvider.overrideWith(_Tutored.new),
      ],
      child: const Scaffold(body: Center(child: MainTrackUpToActions())),
    ),
  );
  await tester.pumpAndSettle();
  return (rig, builds);
}

void main() {
  test('one request per curriculum with new-learning tasks; review tasks '
      'are not leads', () {
    final requests = mainTrackUpToRequests(_tasks);
    expect(requests, hasLength(1));
    expect(requests.single.leadRefs, [
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
    ]);
    expect(requests.single.stage, 1);
    expect(mainTrackUpToRequests([_tasks.last]), isEmpty);
  });

  testWidgets('records only the included planned leaves as main, dated, '
      'first-stage events with paired pts_ entries; the task set is not '
      'regenerated; the streak follows AD-40', (tester) async {
    final (rig, builds) = await _pump(tester);
    expect(builds.single, 1);
    await tester.tap(find.byKey(const Key('mainTrackUpTo-mishnayos')));
    await tester.pumpAndSettle();
    expect(find.text('Mishnayos · up to…'), findsOneWidget);
    // schedulableRefs from the main position, led by today's new learning.
    final y1 = tester.getTopLeft(find.text('Berakhot 1:1')).dy;
    final y2 = tester.getTopLeft(find.text('Berakhot 1:2')).dy;
    final y3 = tester.getTopLeft(find.text('Berakhot 1:3')).dy;
    expect(y1 < y2 && y2 < y3, isTrue);

    await tester.tap(find.text('Berakhot 1:3'));
    await tester.pump();
    await tester.tap(find.byKey(const Key('upToRowTick-1')));
    await tester.pump();
    expect(find.text('Record 2 mishnayos'), findsOneWidget);
    await tester.tap(find.byKey(const Key('upToRecord')));
    await tester.pumpAndSettle();

    final learns = rig.written;
    expect(
      [for (final e in learns) e.ref],
      ['Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:3'],
    );
    for (final e in learns) {
      expect(e.source, LearningEvent.sourceMain);
      expect(e.dateState, DateState.dated);
      expect(e.learnedOn, '2026-09-01');
      expect(e.stage, 1);
    }
    for (final chunk in rig.port.chunks) {
      expect(
        {for (final a in chunk.awards) a.eventId},
        {for (final e in chunk.events) e.id},
        reason: 'each pts_ entry in the same chunk as its event (AD-50)',
      );
    }
    expect(builds.single, 1, reason: 'task generation untouched');

    final main = rig.state.curricula[engineCurriculum]!;
    expect(main.streak?.current, 1);
    expect(main.streak?.lastDay, '2026-09-01');
    expect(main.learntLeaves, {'Mishnah Berakhot 1:1', 'Mishnah Berakhot 1:3'});

    // The skipped leaf leads the next picker.
    await tester.tap(find.byKey(const Key('mainTrackUpTo-mishnayos')));
    await tester.pumpAndSettle();
    expect(find.text('Berakhot 1:1'), findsNothing);
    expect(find.text('Berakhot 1:3'), findsNothing);
    expect(find.text('Berakhot 1:2'), findsOneWidget);
  });

  testWidgets('absent in a tutored session', (tester) async {
    await _pump(tester, tutored: true);
    expect(find.byKey(const Key('mainTrackUpTo-mishnayos')), findsNothing);
  });
}
