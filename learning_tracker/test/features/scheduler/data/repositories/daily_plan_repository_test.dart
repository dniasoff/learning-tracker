import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/data/repositories/daily_plan_repository.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

void main() {
  late DailyPlanRepository repo;
  var buildCount = 0;

  DailyTask task(
    String ref, {
    DailyTaskPriority priority = DailyTaskPriority.newLearning,
    bool isOverdue = false,
    int stageOrder = 1,
    String stageName = 'Learning',
  }) => DailyTask(
    curriculumId: CurriculumId.mishnayos,
    contentItemSefariaRef: ref,
    stageOrder: stageOrder,
    stageDefinitionId: 100 + stageOrder,
    priority: priority,
    isOverdue: isOverdue,
    reason: stageName,
    stageName: stageName,
    trackLabel: 'Mishnayos',
  );

  setUp(() {
    repo = DailyPlanRepository();
    buildCount = 0;
  });

  test('snapshots once per local day and isolates ULID profiles', () async {
    final now = DateTime.utc(2026, 4, 19, 10);
    Future<List<DailyTask>> build() async {
      buildCount++;
      return [task('item-$buildCount')];
    }

    final first = await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      now: now,
      buildPlan: build,
    );
    final sameDay = await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      now: now.add(const Duration(hours: 5)),
      buildPlan: build,
    );
    final otherProfile = await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000002',
      now: now,
      buildPlan: build,
    );

    expect(first.isNew, isTrue);
    expect(sameDay.isNew, isFalse);
    expect(sameDay.tasks.single.contentItemSefariaRef, 'item-1');
    expect(otherProfile.tasks.single.contentItemSefariaRef, 'item-2');
    expect(buildCount, 2);
  });

  test('next local day gets a fresh snapshot', () async {
    final today = DateTime.utc(2026, 4, 19, 10);
    await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      now: today,
      buildPlan: () async => [task('today')],
    );

    final tomorrow = await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      now: DateTime.utc(2026, 4, 20, 10),
      buildPlan: () async => [task('tomorrow')],
    );

    expect(tomorrow.isNew, isTrue);
    expect(tomorrow.tasks.single.contentItemSefariaRef, 'tomorrow');
  });

  test('rebuildPlan replaces the current-day snapshot', () async {
    final now = DateTime.utc(2026, 4, 19, 10);
    await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      now: now,
      buildPlan: () async => [task('old')],
    );

    final rebuilt = await repo.rebuildPlan(
      profileId: '01J00000000000000000000001',
      now: now,
      buildPlan: () async => [task('new')],
    );

    expect(rebuilt.single.contentItemSefariaRef, 'new');
    final cached = await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      now: now,
      buildPlan: () async => [task('unexpected')],
    );
    expect(cached.isNew, isFalse);
    expect(cached.tasks.single.contentItemSefariaRef, 'new');
  });

  test('preserves priority ordering from the built plan', () async {
    final now = DateTime.utc(2026, 4, 19, 10);
    final plan = [
      task(
        'overdue-review',
        priority: DailyTaskPriority.overdueChazara,
        isOverdue: true,
        stageOrder: 2,
        stageName: 'Review',
      ),
      task('new-learning'),
    ];

    final result = await repo.getOrSnapshotPlan(
      profileId: '01J00000000000000000000001',
      now: now,
      buildPlan: () async => plan,
    );

    expect(result.tasks, hasLength(2));
    expect(result.tasks.first.contentItemSefariaRef, 'overdue-review');
    expect(result.tasks.first.priority, DailyTaskPriority.overdueChazara);
    expect(result.tasks.first.isOverdue, isTrue);
    expect(result.tasks.last.contentItemSefariaRef, 'new-learning');
    expect(result.tasks.last.priority, DailyTaskPriority.newLearning);
  });
}
