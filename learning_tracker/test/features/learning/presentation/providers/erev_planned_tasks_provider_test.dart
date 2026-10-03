// DNI-504 AC-1 / AC-2 / AC-4: the erev providers' wiring. The window and
// the planned days read the commands' clock and the learner's settings
// history, and pass the locked dates to the shared planner in order. The
// planner's own sequencing over a real LearnerState is covered by
// test/features/learning/domain/erev_planned_tasks_provider_test.dart.
@Tags(['learning'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

import '../../../../helpers/learner_state/lock_fixtures.dart';

DateTime _ny(int y, int m, int d, int hour) =>
    LearnerZone.of('America/New_York').at(DateTime.utc(y, m, d), hour: hour);

DailyTask _task(String ref) => DailyTask(
  curriculumId: CurriculumId.mishnayos,
  contentItemSefariaRef: ref,
  stageOrder: 1,
  priority: DailyTaskPriority.newLearning,
  isOverdue: false,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Mishnayos',
);

ProviderContainer _container({
  required DateTime now,
  LearnerSettingsHistory? history,
  List<List<String>>? requested,
  List<List<DailyTask>> lists = const [],
}) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      erevSettingsHistoryProvider.overrideWith((ref) async => history),
      learningCommandClockProvider.overrideWithValue(() => now),
      erevSequencePlannerProvider.overrideWithValue((ref, dates) async {
        requested?.add(dates);
        return lists;
      }),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('no learner: no window and no planned days', () async {
    final c = _container(now: _ny(2026, 10, 9, 9));
    final sub = c.listen(erevPlannedDaysProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(erevWindowProvider.future), isNull);
    expect(await c.read(erevPlannedDaysProvider.future), isNull);
  });

  test('outside the erev window the planner is not asked', () async {
    final requested = <List<String>>[];
    final c = _container(
      now: _ny(2026, 10, 8, 9), // Thursday
      history: constantHistory(lakewood),
      requested: requested,
    );
    final sub = c.listen(erevPlannedDaysProvider, (_, _) {});
    addTearDown(sub.close);
    expect(await c.read(erevPlannedDaysProvider.future), isNull);
    expect(requested, isEmpty);
  });

  test('inside it, the planner gets the locked dates in order and each '
      'list lands on its day', () async {
    final requested = <List<String>>[];
    final c = _container(
      now: _ny(2027, 4, 21, 12), // Wednesday before yom tov + Shabbos
      history: constantHistory(lakewood),
      requested: requested,
      lists: [
        [_task('Mishnah Peah 1:1')],
        [_task('Mishnah Peah 1:2')],
      ],
    );
    final sub = c.listen(erevPlannedDaysProvider, (_, _) {});
    addTearDown(sub.close);
    final days = (await c.read(erevPlannedDaysProvider.future))!;
    expect(requested.single, ['2027-04-22', '2027-04-23', '2027-04-24']);
    expect([for (final d in days) d.day.date], requested.single);
    expect(days[0].tasks.single.contentItemSefariaRef, 'Mishnah Peah 1:1');
    expect(days[1].tasks.single.contentItemSefariaRef, 'Mishnah Peah 1:2');
    // A day the planner returned nothing for is empty, not missing.
    expect(days[2].tasks, isEmpty);
  });

  test('a planner failure is the planned region\'s error only', () async {
    final c = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        erevSettingsHistoryProvider.overrideWith(
          (ref) async => constantHistory(lakewood),
        ),
        learningCommandClockProvider.overrideWithValue(
          () => _ny(2026, 10, 9, 9),
        ),
        erevSequencePlannerProvider.overrideWithValue(
          (ref, dates) async => throw StateError('planner down'),
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(erevPlannedDaysProvider, (_, _) {});
    addTearDown(sub.close);
    await expectLater(
      c.read(erevPlannedDaysProvider.future),
      throwsA(isA<StateError>()),
    );
    expect(await c.read(erevWindowProvider.future), isNotNull);
  });
}
