import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/schedule_config.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_completion_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_content_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_learning_order_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/repositories/scheduler_stage_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/services/scheduler_engine.dart';

class _ContentRepo implements SchedulerContentRepository {
  List<SchedulerContentItem> items = [];
  @override
  Future<List<SchedulerContentItem>> getLeafItems(CurriculumId id) async =>
      items;
}

class _CompletionRepo implements SchedulerCompletionRepository {
  List<SchedulerCompletion> completions = [];
  @override
  Future<List<SchedulerCompletion>> getCompletions(CurriculumId id) async =>
      completions;
}

class _StageRepo implements SchedulerStageRepository {
  List<SchedulerStage> stages = [];
  @override
  Future<List<SchedulerStage>> getStages(CurriculumId id) async => stages;
}

class _OrderRepo implements SchedulerLearningOrderRepository {
  List<SchedulerOrderItem> order = [];
  @override
  Future<List<SchedulerOrderItem>> getOrder(CurriculumId id) async => order;
}

void main() {
  late _ContentRepo contentRepo;
  late _CompletionRepo completionRepo;
  late _StageRepo stageRepo;
  late _OrderRepo orderRepo;
  late SchedulerEngine engine;

  const curriculum = CurriculumId.mishnayos;
  final today = DateTime.utc(2026, 3, 15);

  List<SchedulerContentItem> items(int n) => List.generate(
    n,
    (i) => SchedulerContentItem(sefariaRef: 'ref_$i', sortOrder: i),
  );

  const stages = [
    SchedulerStage(id: 1, stageOrder: 1, stageName: 'Learn', delayDays: 0),
    SchedulerStage(id: 2, stageOrder: 2, stageName: 'Chazara 1', delayDays: 1),
  ];

  setUp(() {
    contentRepo = _ContentRepo()..items = items(30);
    completionRepo = _CompletionRepo();
    stageRepo = _StageRepo()..stages = List.of(stages);
    orderRepo = _OrderRepo();
    engine = SchedulerEngine(
      contentRepository: contentRepo,
      completionRepository: completionRepo,
      stageRepository: stageRepo,
      learningOrderRepository: orderRepo,
    );
  });

  ScheduleConfig configFor({
    required double? pace,
    required DateTime? startedAt,
    Set<String> priorlyShown = const <String>{},
    DateTime? now,
    String? learningUnit,
  }) => ScheduleConfig(
    curriculumId: curriculum,
    trackId: 1,
    trackLabel: 'personal',
    currentDate: now ?? today,
    pacePerDay: pace,
    trackStartedAt: startedAt,
    priorlyShownRefs: priorlyShown,
    learningUnit: learningUnit,
  );

  group('SchedulerEngine self-paced new-learning', () {
    test(
      'day 0 with empty priorlyShown emits exactly pacePerDay new tasks',
      () async {
        final tasks = await engine.generateDailyTasks(
          configFor(pace: 5, startedAt: today, priorlyShown: const {}),
        );

        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        expect(newTasks, hasLength(5));
        expect(newTasks.map((t) => t.contentItemSefariaRef).toList(), [
          'ref_0',
          'ref_1',
          'ref_2',
          'ref_3',
          'ref_4',
        ]);
        expect(newTasks.every((t) => !t.isOverdue), isTrue);
        expect(
          tasks.where((t) => t.isOverdue),
          isEmpty,
          reason: 'No overdue carryover when nothing was previously shown',
        );
      },
    );

    test(
      'day 1, yesterday shown nothing completed: prior 5 are overdue + 5 new',
      () async {
        final tasks = await engine.generateDailyTasks(
          configFor(
            pace: 5,
            startedAt: today.subtract(const Duration(days: 1)),
            priorlyShown: const {'ref_0', 'ref_1', 'ref_2', 'ref_3', 'ref_4'},
          ),
        );

        final overdue = tasks.where((t) => t.isOverdue).toList();
        final newToday = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();

        expect(
          overdue.map((t) => t.contentItemSefariaRef).toList(),
          ['ref_0', 'ref_1', 'ref_2', 'ref_3', 'ref_4'],
          reason:
              'All previously-shown items missing first-stage completion '
              'must show as overdue today',
        );
        expect(
          newToday.map((t) => t.contentItemSefariaRef).toList(),
          ['ref_5', 'ref_6', 'ref_7', 'ref_8', 'ref_9'],
          reason: 'Today batch must skip everything already in priorlyShown',
        );
      },
    );

    test('completed items drop from overdue carryover', () async {
      completionRepo.completions = [
        // First-stage completions for refs 0 and 2; refs 1, 3, 4 still pending.
        SchedulerCompletion(
          sefariaRef: 'ref_0',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: today.subtract(const Duration(hours: 1)),
        ),
        SchedulerCompletion(
          sefariaRef: 'ref_2',
          stageOrder: 1,
          trackType: 'personal',
          completedAt: today.subtract(const Duration(hours: 1)),
        ),
      ];

      final tasks = await engine.generateDailyTasks(
        configFor(
          pace: 5,
          startedAt: today.subtract(const Duration(days: 1)),
          priorlyShown: const {'ref_0', 'ref_1', 'ref_2', 'ref_3', 'ref_4'},
        ),
      );

      final overdue = tasks
          .where((t) => t.isOverdue)
          .map((t) => t.contentItemSefariaRef)
          .toList();
      expect(overdue, ['ref_1', 'ref_3', 'ref_4']);
    });

    test(
      'gap of 3 days (priorlyShown of 15 items) overdue + next 5 today',
      () async {
        final priorly = {for (var i = 0; i < 15; i++) 'ref_$i'};

        final tasks = await engine.generateDailyTasks(
          configFor(
            pace: 5,
            startedAt: today.subtract(const Duration(days: 3)),
            priorlyShown: priorly,
          ),
        );

        final overdue = tasks
            .where((t) => t.isOverdue)
            .map((t) => t.contentItemSefariaRef)
            .toList();
        final newToday = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .map((t) => t.contentItemSefariaRef)
            .toList();
        expect(overdue, hasLength(15));
        expect(newToday, ['ref_15', 'ref_16', 'ref_17', 'ref_18', 'ref_19']);
      },
    );

    test('today batch picks next unshown items even after reorder', () async {
      // User reordered: ref_99 jumped to position 0.
      orderRepo.order = [
        const SchedulerOrderItem(sefariaRef: 'ref_99', userSortOrder: 0),
      ];
      contentRepo.items = [
        ...items(30),
        const SchedulerContentItem(sefariaRef: 'ref_99', sortOrder: 99),
      ];

      final tasks = await engine.generateDailyTasks(
        configFor(
          pace: 5,
          startedAt: today.subtract(const Duration(days: 1)),
          // Original 5 from before the reorder are still the priorly-shown
          // set — moving ref_99 to position 0 doesn't retroactively make
          // it overdue.
          priorlyShown: const {'ref_0', 'ref_1', 'ref_2', 'ref_3', 'ref_4'},
        ),
      );

      final overdue = tasks
          .where((t) => t.isOverdue)
          .map((t) => t.contentItemSefariaRef)
          .toList();
      expect(
        overdue,
        ['ref_0', 'ref_1', 'ref_2', 'ref_3', 'ref_4'],
        reason:
            'Overdue is anchored to priorlyShown, not to current order. '
            'ref_99 must NOT appear as overdue.',
      );

      final newToday = tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .map((t) => t.contentItemSefariaRef)
          .toList();
      // Today's batch walks current orderedRefs: ref_99 at pos 0, then
      // ref_0..ref_29 in source order. ref_0..4 are filtered out (in
      // priorlyShown), so today's 5 are ref_99, ref_5, ref_6, ref_7, ref_8.
      expect(newToday, ['ref_99', 'ref_5', 'ref_6', 'ref_7', 'ref_8']);
    });

    test(
      'legacy path runs when pacePerDay is null (program-track config)',
      () async {
        // No pacePerDay set → engine takes the existing branch.
        final tasks = await engine.generateDailyTasks(
          ScheduleConfig(
            curriculumId: curriculum,
            trackId: 1,
            trackLabel: 'program',
            currentDate: today,
          ),
        );
        final newTasks = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .toList();
        // Legacy default new-items-per-day is 5.
        expect(newTasks, hasLength(5));
        expect(
          newTasks.every((t) => !t.isOverdue),
          isTrue,
          reason: 'Legacy path always emits new-learning as not overdue',
        );
      },
    );

    test(
      'legacy path runs when trackStartedAt is null even if pacePerDay set',
      () async {
        final tasks = await engine.generateDailyTasks(
          ScheduleConfig(
            curriculumId: curriculum,
            trackId: 1,
            trackLabel: 'personal',
            currentDate: today,
            pacePerDay: 5,
            // trackStartedAt missing → snapshot path skipped.
          ),
        );
        expect(
          tasks.where((t) => t.isOverdue),
          isEmpty,
          reason:
              'Without trackStartedAt the snapshot path is skipped and '
              'no overdue carryover should appear',
        );
      },
    );
  });

  group('SchedulerEngine coarse-unit batching (1 perek = all its mishnas)', () {
    setUp(() {
      // Mishnayos with 3 perakim: perek 1 has 5 mishnas, perek 2 has 8,
      // perek 3 has 4. Refs are ordered globally (perek 1 leaves first,
      // then perek 2, then perek 3).
      final items = <SchedulerContentItem>[];
      var sort = 0;
      void addPerek(String masechta, String perekNum, int mishnaCount) {
        for (var m = 1; m <= mishnaCount; m++) {
          items.add(
            SchedulerContentItem(
              sefariaRef: '$masechta $perekNum.$m',
              sortOrder: sort++,
              level1: 'Zeraim',
              level2: masechta,
              level3: perekNum,
              level4: '$m',
            ),
          );
        }
      }

      addPerek('Berachos', '1', 5);
      addPerek('Berachos', '2', 8);
      addPerek('Berachos', '3', 4);
      contentRepo.items = items;
    });

    test(
      'pace=1 perek/day emits ALL mishnas of the next un-introduced perek',
      () async {
        final tasks = await engine.generateDailyTasks(
          configFor(
            pace: 1,
            startedAt: today,
            priorlyShown: const {},
            learningUnit: 'perek',
          ),
        );
        final newRefs = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .map((t) => t.contentItemSefariaRef)
            .toList();
        expect(
          newRefs,
          [
            'Berachos 1.1',
            'Berachos 1.2',
            'Berachos 1.3',
            'Berachos 1.4',
            'Berachos 1.5',
          ],
          reason:
              'Asking for 1 perek/day should emit the full first perek '
              '(5 mishnas), not a single mishna.',
        );
      },
    );

    test('pace=2 perek/day emits the first two perakim in full', () async {
      final tasks = await engine.generateDailyTasks(
        configFor(
          pace: 2,
          startedAt: today,
          priorlyShown: const {},
          learningUnit: 'perek',
        ),
      );
      final newRefs = tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .map((t) => t.contentItemSefariaRef)
          .toList();
      // Perek 1 = 5 mishnas + Perek 2 = 8 mishnas → 13 refs.
      expect(newRefs, hasLength(13));
      expect(newRefs.first, 'Berachos 1.1');
      expect(newRefs.last, 'Berachos 2.8');
    });

    test(
      'partially-shown perek is skipped (treated as already introduced)',
      () async {
        // Day 2: perek 1 was introduced on day 1 (all 5 mishnas in
        // priorlyShown). Today should jump to perek 2.
        final tasks = await engine.generateDailyTasks(
          configFor(
            pace: 1,
            startedAt: today.subtract(const Duration(days: 1)),
            priorlyShown: const {
              'Berachos 1.1',
              'Berachos 1.2',
              'Berachos 1.3',
              'Berachos 1.4',
              'Berachos 1.5',
            },
            learningUnit: 'perek',
          ),
        );
        final newRefs = tasks
            .where((t) => t.priority == DailyTaskPriority.newLearning)
            .map((t) => t.contentItemSefariaRef)
            .toList();
        expect(newRefs, [
          'Berachos 2.1',
          'Berachos 2.2',
          'Berachos 2.3',
          'Berachos 2.4',
          'Berachos 2.5',
          'Berachos 2.6',
          'Berachos 2.7',
          'Berachos 2.8',
        ]);
      },
    );

    test('learningUnit==leaf falls back to leaf-counted pace', () async {
      // For Mishnayos the leaf is 'Mishna'. Setting learningUnit='mishna'
      // must NOT switch on coarse grouping — pace=5 should emit exactly
      // 5 mishnas.
      final tasks = await engine.generateDailyTasks(
        configFor(
          pace: 5,
          startedAt: today,
          priorlyShown: const {},
          learningUnit: 'mishna',
        ),
      );
      final newRefs = tasks
          .where((t) => t.priority == DailyTaskPriority.newLearning)
          .map((t) => t.contentItemSefariaRef)
          .toList();
      expect(newRefs, hasLength(5));
      expect(newRefs.first, 'Berachos 1.1');
      expect(newRefs.last, 'Berachos 1.5');
    });
  });
}
