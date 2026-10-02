/// Provider-level scheduler coverage using direct Riverpod override seams.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

class _GatedSkippedTasksStore extends InMemorySharedPreferencesStore {
  _GatedSkippedTasksStore(super.data) : super.withData();

  final Completer<void> _gate = Completer<void>();

  void openGate() {
    if (!_gate.isCompleted) _gate.complete();
  }

  @override
  Future<Map<String, Object>> getAll() async {
    await _gate.future;
    return super.getAll();
  }
}

DailyTask _task({
  CurriculumId curriculum = CurriculumId.mishnayos,
  required String ref,
  required DailyTaskPriority priority,
  required bool isOverdue,
}) => DailyTask(
  curriculumId: curriculum,
  contentItemSefariaRef: ref,
  stageOrder: 1,
  priority: priority,
  isOverdue: isOverdue,
  reason: 'test',
  stageName: 'Learn',
  trackLabel: 'Test',
);

ProviderContainer _withTasks(List<DailyTask> tasks) => ProviderContainer(
  overrides: [allDailyTasksProvider.overrideWith((ref) async => tasks)],
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'SkippedTasks loads, skips, and undoes refs through preferences',
    () async {
      final container = ProviderContainer(
        overrides: [
          clockProvider.overrideWith((ref) => DateTime.utc(2026, 4, 20)),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(skippedTasksProvider.notifier);
      await notifier.debugReadyForTest;

      await notifier.skip('Mishnah 1');
      expect(container.read(skippedTasksProvider), {'Mishnah 1'});
      await notifier.undoSkip('Mishnah 1');
      expect(container.read(skippedTasksProvider), isEmpty);
    },
  );

  test('task section notifier changes and resets its selection', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final notifier = container.read(schedulerTaskSectionProvider.notifier);

    notifier.setSection(SchedulerTaskSection.overdue);
    expect(
      container.read(schedulerTaskSectionProvider),
      SchedulerTaskSection.overdue,
    );
    notifier.reset();
    expect(
      container.read(schedulerTaskSectionProvider),
      SchedulerTaskSection.all,
    );
  });

  test(
    'previously skipped refs are read from the archived preference key',
    () async {
      SharedPreferences.setMockInitialValues({
        'skipped_tasks_previous_refs': ['Mishnah 2'],
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(await container.read(previouslySkippedRefsProvider.future), {
        'Mishnah 2',
      });
    },
  );

  group('overdueCountForCurriculumProvider', () {
    test('counts only overdue tasks for the requested curriculum', () async {
      final container = _withTasks([
        _task(
          ref: 'mish-overdue-1',
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
        ),
        _task(
          ref: 'mish-today',
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
        ),
        _task(
          curriculum: CurriculumId.bavli,
          ref: 'bavli-overdue',
          priority: DailyTaskPriority.overdueNewLearning,
          isOverdue: true,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        await container.read(
          overdueCountForCurriculumProvider(CurriculumId.mishnayos).future,
        ),
        1,
      );
      expect(
        await container.read(
          overdueCountForCurriculumProvider(CurriculumId.bavli).future,
        ),
        1,
      );
    });
  });

  group('firstTaskInTrackForCategoryProvider', () {
    test('selects the first task in each CurriculumId bucket', () async {
      final container = _withTasks([
        _task(
          ref: 'review',
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
        ),
        _task(
          ref: 'today',
          priority: DailyTaskPriority.todayProgram,
          isOverdue: false,
        ),
        _task(
          ref: 'overdue',
          priority: DailyTaskPriority.overdueProgram,
          isOverdue: true,
        ),
        _task(
          curriculum: CurriculumId.bavli,
          ref: 'bavli-review',
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
        ),
      ]);
      addTearDown(container.dispose);

      final review = await container.read(
        firstTaskInTrackForCategoryProvider(
          curriculumId: CurriculumId.mishnayos,
          category: TrackTaskCategory.review,
        ).future,
      );
      final dueToday = await container.read(
        firstTaskInTrackForCategoryProvider(
          curriculumId: CurriculumId.mishnayos,
          category: TrackTaskCategory.dueToday,
        ).future,
      );
      final overdue = await container.read(
        firstTaskInTrackForCategoryProvider(
          curriculumId: CurriculumId.mishnayos,
          category: TrackTaskCategory.overdue,
        ).future,
      );

      expect(review?.contentItemSefariaRef, 'review');
      expect(dueToday?.contentItemSefariaRef, 'today');
      expect(overdue?.contentItemSefariaRef, 'overdue');
      final bavliReview = await container.read(
        firstTaskInTrackForCategoryProvider(
          curriculumId: CurriculumId.bavli,
          category: TrackTaskCategory.review,
        ).future,
      );
      expect(bavliReview?.contentItemSefariaRef, 'bavli-review');
    });

    test('returns null when the requested bucket is empty', () async {
      final container = _withTasks([
        _task(
          ref: 'today',
          priority: DailyTaskPriority.newLearning,
          isOverdue: false,
        ),
      ]);
      addTearDown(container.dispose);

      expect(
        await container.read(
          firstTaskInTrackForCategoryProvider(
            curriculumId: CurriculumId.mishnayos,
            category: TrackTaskCategory.review,
          ).future,
        ),
        isNull,
      );
    });
  });

  group('SkippedTasks persistence lifecycle', () {
    test(
      'date rollover archives stale refs and clears the current set',
      () async {
        SharedPreferences.setMockInitialValues({
          'skipped_tasks_date': '2026-05-28',
          'skipped_tasks_refs': ['old_A', 'old_B'],
        });
        final container = ProviderContainer(
          overrides: [
            clockProvider.overrideWith((ref) => DateTime.utc(2026, 5, 29)),
          ],
        );
        addTearDown(container.dispose);
        final listener = container.listen(skippedTasksProvider, (_, __) {});
        addTearDown(listener.close);
        await container.read(skippedTasksProvider.notifier).debugReadyForTest;

        expect(container.read(skippedTasksProvider), isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(
          prefs.getStringList('skipped_tasks_previous_refs'),
          containsAll(['old_A', 'old_B']),
        );
      },
    );

    test(
      'dispose during an in-flight prefs load does not log a load failure',
      () async {
        SharedPreferences.setMockInitialValues({});
        final store = _GatedSkippedTasksStore({
          'flutter.skipped_tasks_date': '2026-05-29',
          'flutter.skipped_tasks_refs': ['ref_X'],
        });
        SharedPreferencesStorePlatform.instance = store;
        addTearDown(() => SharedPreferences.setMockInitialValues({}));
        final container = ProviderContainer(
          overrides: [
            clockProvider.overrideWith((ref) => DateTime.utc(2026, 5, 29)),
          ],
        );
        final listener = container.listen(skippedTasksProvider, (_, __) {});
        final notifier = container.read(skippedTasksProvider.notifier);
        final before = AppLogger.instance.talker.history.length;
        container.dispose();
        store.openGate();
        await notifier.debugReadyForTest;

        final messages = AppLogger.instance.talker.history
            .skip(before)
            .map((entry) => entry.generateTextMessage());
        expect(
          messages.any((message) => message.contains('Failed to load')),
          isFalse,
        );
        listener.close();
      },
    );
  });
}
