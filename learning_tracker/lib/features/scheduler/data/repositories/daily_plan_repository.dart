import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

/// Snapshots the day's scheduled tasks and serves them back on subsequent
/// reads. The scheduler is invoked only when no snapshot exists for
/// ([profileId], local date); completions do not trigger regeneration.
class DailyPlanRepository {
  DailyPlanRepository(this._db);

  final UserDatabase _db;

  /// Returns today's plan, running [buildPlan] exactly once per local day
  /// to materialize rows. Subsequent calls on the same local day read the
  /// snapshot regardless of any completions that happened since.
  Future<List<DailyTask>> getOrSnapshotPlan({
    required int profileId,
    required DateTime now,
    required Future<List<DailyTask>> Function() buildPlan,
  }) async {
    final planDate = DateUtils.extractLocalDate(now);

    final hasPlan = await _db.dailyPlanDao.hasPlanForDay(
      profileId: profileId,
      planDate: planDate,
    );

    if (!hasPlan) {
      final freshTasks = await buildPlan();
      await _persistPlan(
        profileId: profileId,
        planDate: planDate,
        tasks: freshTasks,
        now: now,
      );
    }

    final rows = await _db.dailyPlanDao.getPlanForDay(
      profileId: profileId,
      planDate: planDate,
    );
    return rows.map(_rowToTask).toList();
  }

  Future<void> _persistPlan({
    required int profileId,
    required DateTime planDate,
    required List<DailyTask> tasks,
    required DateTime now,
  }) async {
    final entries = <DailyPlansCompanion>[];
    for (var i = 0; i < tasks.length; i++) {
      final task = tasks[i];
      entries.add(
        DailyPlansCompanion.insert(
          profileId: profileId,
          curriculumId: task.curriculumId.storageKey,
          planDate: planDate,
          sefariaRef: task.contentItemSefariaRef,
          stageOrder: task.stageOrder,
          stageDefinitionId: task.stageDefinitionId,
          trackId: task.trackId,
          trackLabel: Value(task.trackLabel),
          priority: task.priority.name,
          isOverdue: Value(task.isOverdue),
          reason: Value(task.reason),
          stageName: Value(task.stageName),
          estimatedEffortMinutes: Value(task.estimatedEffortMinutes),
          sortOrder: Value(i),
          createdAt: now,
        ),
      );
    }
    await _db.dailyPlanDao.insertEntries(entries);
  }

  DailyTask _rowToTask(DailyPlan row) {
    return DailyTask(
      curriculumId: CurriculumId.values.firstWhere(
        (c) => c.storageKey == row.curriculumId,
      ),
      contentItemSefariaRef: row.sefariaRef,
      stageOrder: row.stageOrder,
      stageDefinitionId: row.stageDefinitionId,
      priority: DailyTaskPriority.values.firstWhere(
        (p) => p.name == row.priority,
        orElse: () => DailyTaskPriority.newLearning,
      ),
      isOverdue: row.isOverdue,
      reason: row.reason,
      stageName: row.stageName,
      trackId: row.trackId,
      trackLabel: row.trackLabel,
      estimatedEffortMinutes: row.estimatedEffortMinutes,
    );
  }
}
