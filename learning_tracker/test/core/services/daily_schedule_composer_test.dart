import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/services/daily_schedule_composer.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:test/test.dart';

DailyTask _task(
  CurriculumId curriculum, {
  DailyTaskPriority priority = DailyTaskPriority.newLearning,
  bool isOverdue = false,
  String ref = 'ref',
  int stageOrder = 1,
}) {
  return DailyTask(
    curriculumId: curriculum,
    contentItemSefariaRef: '${curriculum.storageKey}_$ref',
    stageOrder: stageOrder,
    stageDefinitionId: stageOrder,
    priority: priority,
    isOverdue: isOverdue,
    reason: 'test',
    stageName: 'Stage $stageOrder',
    estimatedEffortMinutes: 5,
  );
}

void main() {
  late DailyScheduleComposer composer;

  setUp(() {
    composer = DailyScheduleComposer();
  });

  test('compose merges tasks from all active curricula into a single list', () {
    final result = composer.compose({
      CurriculumId.mishnayos: [
        _task(CurriculumId.mishnayos, ref: '1'),
        _task(CurriculumId.mishnayos, ref: '2'),
      ],
      CurriculumId.bavli: [_task(CurriculumId.bavli, ref: '1')],
    });

    expect(result.tasks.length, 3);
    expect(result.tasks.map((t) => t.curriculumId).toSet(), {
      CurriculumId.mishnayos,
      CurriculumId.bavli,
    });
  });

  test(
    'cross-curriculum prioritization places overdue items before on-time items',
    () {
      final result = composer.compose({
        CurriculumId.mishnayos: [_task(CurriculumId.mishnayos, ref: 'ontime')],
        CurriculumId.bavli: [
          _task(
            CurriculumId.bavli,
            ref: 'overdue',
            priority: DailyTaskPriority.overdueChazara,
            isOverdue: true,
          ),
        ],
      });

      expect(result.tasks.first.curriculumId, CurriculumId.bavli);
      expect(result.tasks.first.isOverdue, isTrue);
      expect(result.tasks.last.isOverdue, isFalse);
    },
  );

  test(
    'round-robin balancing: tasks alternate between curricula when no overdue',
    () {
      final result = composer.compose({
        CurriculumId.mishnayos: [
          _task(CurriculumId.mishnayos, ref: '1'),
          _task(CurriculumId.mishnayos, ref: '2'),
          _task(CurriculumId.mishnayos, ref: '3'),
        ],
        CurriculumId.bavli: [
          _task(CurriculumId.bavli, ref: '1'),
          _task(CurriculumId.bavli, ref: '2'),
          _task(CurriculumId.bavli, ref: '3'),
        ],
      });

      // Should alternate: mishnayos, bavli, mishnayos, bavli, ...
      // (or bavli, mishnayos — order of map entries)
      // Key assertion: should NOT exhaust one curriculum first
      final firstThree = result.tasks.sublist(0, 3);
      final curricula = firstThree.map((t) => t.curriculumId).toSet();
      expect(
        curricula.length,
        2,
        reason: 'First 3 tasks should come from both',
      );
    },
  );

  test('daily load cap enforced — cap 20, 30 tasks → only 20 returned', () {
    final tasks = List.generate(
      15,
      (i) => _task(CurriculumId.mishnayos, ref: 'm$i'),
    );
    final tasks2 = List.generate(
      15,
      (i) => _task(CurriculumId.bavli, ref: 'b$i'),
    );

    final result = composer.compose({
      CurriculumId.mishnayos: tasks,
      CurriculumId.bavli: tasks2,
    }, maxTasksPerDay: 20);

    expect(result.tasks.length, 20);
  });

  test('daily load cap is configurable via parameter', () {
    final tasks = List.generate(
      10,
      (i) => _task(CurriculumId.mishnayos, ref: '$i'),
    );

    final result10 = composer.compose({
      CurriculumId.mishnayos: tasks,
    }, maxTasksPerDay: 10);
    expect(result10.tasks.length, 10);

    final result5 = composer.compose({
      CurriculumId.mishnayos: tasks,
    }, maxTasksPerDay: 5);
    expect(result5.tasks.length, 5);
  });

  test('compose with zero active curricula returns empty list', () {
    final result = composer.compose({});
    expect(result.tasks, isEmpty);
    expect(result.summary, contains('0 tasks'));
  });

  test(
    'compose with one active curriculum returns that curriculum\'s tasks unchanged',
    () {
      final tasks = [
        _task(CurriculumId.mishnayos, ref: '1'),
        _task(CurriculumId.mishnayos, ref: '2'),
      ];

      final result = composer.compose({CurriculumId.mishnayos: tasks});

      expect(result.tasks.length, 2);
      for (final t in result.tasks) {
        expect(t.curriculumId, CurriculumId.mishnayos);
      }
    },
  );

  test('summary correctly counts tasks and distinct curricula', () {
    final result = composer.compose({
      CurriculumId.mishnayos: List.generate(
        5,
        (i) => _task(CurriculumId.mishnayos, ref: '$i'),
      ),
      CurriculumId.bavli: List.generate(
        5,
        (i) => _task(CurriculumId.bavli, ref: '$i'),
      ),
      CurriculumId.chumash: List.generate(
        5,
        (i) => _task(CurriculumId.chumash, ref: '$i'),
      ),
    });

    expect(result.summary, contains('15 tasks'));
    expect(result.summary, contains('3 curricula'));
  });

  test(
    'overdue tasks exceeding cap still allow some new learning tasks (M2)',
    () {
      // 25 overdue tasks with a cap of 20 — should still include new learning
      final overdue = List.generate(
        25,
        (i) => _task(
          CurriculumId.mishnayos,
          ref: 'overdue_$i',
          priority: DailyTaskPriority.overdueChazara,
          isOverdue: true,
        ),
      );
      final newLearning = List.generate(
        5,
        (i) => _task(CurriculumId.bavli, ref: 'new_$i'),
      );

      final result = composer.compose({
        CurriculumId.mishnayos: overdue,
        CurriculumId.bavli: newLearning,
      }, maxTasksPerDay: 20);

      expect(result.tasks.length, 20);

      final newTasks = result.tasks.where((t) => !t.isOverdue).toList();
      expect(
        newTasks.length,
        greaterThanOrEqualTo(2),
        reason: 'At least 2 new-learning slots should be reserved',
      );
    },
  );

  test(
    'round-robin order is deterministic regardless of map insertion order',
    () {
      // Insert in two different orders, expect same result
      final result1 = composer.compose({
        CurriculumId.mishnayos: [_task(CurriculumId.mishnayos, ref: '1')],
        CurriculumId.bavli: [_task(CurriculumId.bavli, ref: '1')],
      });
      final result2 = composer.compose({
        CurriculumId.bavli: [_task(CurriculumId.bavli, ref: '1')],
        CurriculumId.mishnayos: [_task(CurriculumId.mishnayos, ref: '1')],
      });

      expect(
        result1.tasks.map((t) => t.curriculumId).toList(),
        result2.tasks.map((t) => t.curriculumId).toList(),
        reason: 'Round-robin order should be deterministic',
      );
    },
  );

  test('groupedByCurriculum returns tasks organized by curriculum', () {
    final result = composer.compose({
      CurriculumId.mishnayos: [_task(CurriculumId.mishnayos, ref: '1')],
      CurriculumId.bavli: [_task(CurriculumId.bavli, ref: '1')],
    });

    final grouped = result.groupedByCurriculum;
    expect(grouped.keys, contains(CurriculumId.mishnayos));
    expect(grouped.keys, contains(CurriculumId.bavli));
    expect(grouped[CurriculumId.mishnayos]!.length, 1);
  });
}
