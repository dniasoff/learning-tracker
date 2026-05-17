import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

/// Builder used by [DailyPlanRepository.backfillMissingSnapshots] to
/// synthesize what would have been today's plan for a single past day.
///
/// Inputs:
///   - [dayIndex] — 0-based day offset since the track was activated.
///   - [planDate] — the local-date midnight that snapshot belongs to.
///
/// Output: the refs (and their stage metadata) that should be recorded
/// for that day. Returning an empty list is a valid "no-op" for a day
/// that should have no new learning.
typedef DailySnapshotBuilder =
    Future<List<DailyTask>> Function({
      required int dayIndex,
      required DateTime planDate,
    });

/// Snapshots the day's scheduled tasks and serves them back on subsequent
/// reads. The scheduler is invoked only when no snapshot exists for
/// ([profileId], local date); completions do not trigger regeneration.
class DailyPlanRepository {
  DailyPlanRepository(this._db);

  final UserDatabase _db;

  /// Returns today's plan, running [buildPlan] exactly once per local day
  /// to materialize rows. Subsequent calls on the same local day read the
  /// snapshot regardless of any completions that happened since.
  ///
  /// The returned record also carries [isNew] = true when the plan was
  /// freshly generated in this call (i.e. no prior snapshot existed).
  /// Callers can use this flag to skip expensive integrity guards that only
  /// matter immediately after generation.
  Future<({List<DailyTask> tasks, bool isNew})> getOrSnapshotPlan({
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
    return (tasks: rows.map(_rowToTask).toList(), isNew: !hasPlan);
  }

  /// Writes a synthetic snapshot for each local-date between
  /// [activatedAt] and the day BEFORE [currentDate] that has no existing
  /// snapshot row for [trackId]. Used by self-paced tracks so the
  /// scheduler can present a backlog of "missed" items even when the app
  /// wasn't opened on those days.
  ///
  /// [buildSnapshotForDay] computes the refs that would have been
  /// scheduled for the given past day. Implementations typically use a
  /// position-based rule (orderedRefs[d*pace .. (d+1)*pace - 1]).
  ///
  /// Idempotent: re-running on a day that already has a snapshot is a
  /// no-op for that day.
  Future<void> backfillMissingSnapshots({
    required int profileId,
    required int trackId,
    required DateTime activatedAt,
    required DateTime currentDate,
    required DailySnapshotBuilder buildSnapshotForDay,
  }) async {
    final startDay = DateUtils.extractLocalDate(activatedAt);
    final todayLocal = DateUtils.extractLocalDate(currentDate);
    if (!startDay.isBefore(todayLocal)) return; // no gap to fill

    final totalDays = todayLocal.difference(startDay).inDays;
    for (var d = 0; d < totalDays; d++) {
      final planDate = startDay.add(Duration(days: d));
      final exists = await _db.dailyPlanDao.hasPlanForTrackOnDay(
        trackId: trackId,
        planDate: planDate,
      );
      if (exists) continue;
      final tasks = await buildSnapshotForDay(dayIndex: d, planDate: planDate);
      if (tasks.isEmpty) continue;
      await _persistPlan(
        profileId: profileId,
        planDate: planDate,
        tasks: tasks,
        now: planDate, // attribute the synthetic snapshot to that day
      );
    }
  }

  /// Forces regeneration for today's plan by clearing the existing snapshot.
  Future<List<DailyTask>> rebuildPlan({
    required int profileId,
    required DateTime now,
    required Future<List<DailyTask>> Function() buildPlan,
  }) async {
    final planDate = DateUtils.extractLocalDate(now);
    await _db.dailyPlanDao.deletePlanForDay(
      profileId: profileId,
      planDate: planDate,
    );

    final freshTasks = await buildPlan();
    await _persistPlan(
      profileId: profileId,
      planDate: planDate,
      tasks: freshTasks,
      now: now,
    );
    return freshTasks;
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
