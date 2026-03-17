import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/pace_calculator.dart';

/// Aggregated data for the tutor dashboard.
class TutorDashboardData {
  final List<CurriculumId> activeCurricula;
  final List<Completion> completionHistory;
  final List<ChazaraQueueItem> chazaraQueue;
  final Map<CurriculumId, TutorPaceInfo> paceInfo;
  final List<DailyTask> dailyTasks;

  const TutorDashboardData({
    required this.activeCurricula,
    required this.completionHistory,
    required this.chazaraQueue,
    required this.paceInfo,
    required this.dailyTasks,
  });

  /// Filter all data by a specific curriculum.
  TutorDashboardData filterByCurriculum(CurriculumId curriculum) {
    return TutorDashboardData(
      activeCurricula: activeCurricula,
      completionHistory: completionHistory
          .where((c) => c.curriculumId == curriculum.storageKey)
          .toList(),
      chazaraQueue: chazaraQueue
          .where((c) => c.curriculumId == curriculum)
          .toList(),
      paceInfo: {
        if (paceInfo.containsKey(curriculum)) curriculum: paceInfo[curriculum]!,
      },
      dailyTasks: dailyTasks
          .where((t) => t.curriculumId == curriculum)
          .toList(),
    );
  }
}

/// A chazara item with urgency classification.
class ChazaraQueueItem {
  final CurriculumId curriculumId;
  final String sefariaRef;
  final String stageName;
  final ChazaraUrgency urgency;
  final DateTime dueDate;
  final int daysOverdue;

  const ChazaraQueueItem({
    required this.curriculumId,
    required this.sefariaRef,
    required this.stageName,
    required this.urgency,
    required this.dueDate,
    required this.daysOverdue,
  });
}

/// Urgency levels for chazara items.
enum ChazaraUrgency { overdue, dueToday, upcoming }

/// Pace information for a curriculum.
class TutorPaceInfo {
  final PaceStatus? paceStatus;
  final double completionPercentage;
  final int totalCompletions;

  const TutorPaceInfo({
    required this.paceStatus,
    required this.completionPercentage,
    required this.totalCompletions,
  });
}

/// Read-only aggregator that computes tutor dashboard data from existing providers.
class TutorDashboardAggregator {
  final AppDatabase _db;

  TutorDashboardAggregator(this._db);

  /// Compute the full tutor dashboard data snapshot.
  Future<TutorDashboardData> compute({
    required DateTime now,
    required List<DailyTask> allTasks,
  }) async {
    final activeKeys = await _db.activeCurriculumDao.getActiveCurricula();
    final activeCurricula = activeKeys
        .map<CurriculumId?>((key) {
          final matches = CurriculumId.values.where((c) => c.storageKey == key);
          return matches.isNotEmpty ? matches.first : null;
        })
        .whereType<CurriculumId>()
        .toList();

    // Completion history — only fetch today's completions for the dashboard display
    final startOfDay = DateUtils.startOfLocalDay(now);
    final endOfDay = DateUtils.endOfLocalDay(now);
    final todayCompletions = await _db.completionDao.getCompletionsByDateRange(
      startOfDay,
      endOfDay,
    );
    final sortedCompletions = [...todayCompletions]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    // Build chazara queue from daily tasks
    final chazaraQueue = _buildChazaraQueue(allTasks, now);

    // Pace info per curriculum (needs all completions per curriculum)
    final paceInfo = <CurriculumId, TutorPaceInfo>{};
    for (final curriculum in activeCurricula) {
      final curriculumCompletions = await _db.completionDao
          .getCompletionsByCurriculum(curriculum.storageKey);
      paceInfo[curriculum] = await _computePaceInfo(
        curriculum,
        curriculumCompletions,
        now,
      );
    }

    return TutorDashboardData(
      activeCurricula: activeCurricula,
      completionHistory: sortedCompletions,
      chazaraQueue: chazaraQueue,
      paceInfo: paceInfo,
      dailyTasks: allTasks,
    );
  }

  List<ChazaraQueueItem> _buildChazaraQueue(
    List<DailyTask> tasks,
    DateTime now,
  ) {
    final chazaraTasks = tasks.where(
      (t) =>
          t.priority == DailyTaskPriority.overdueChazara ||
          t.priority == DailyTaskPriority.scheduledChazara,
    );

    return chazaraTasks.map((task) {
      final daysOverdue = task.isOverdue
          ? int.tryParse(
                  RegExp(r'(\d+) day').firstMatch(task.reason)?.group(1) ?? '0',
                ) ??
                0
          : 0;

      // Compute actual due date from overdue days
      final dueDate = task.priority == DailyTaskPriority.overdueChazara
          ? now.subtract(Duration(days: daysOverdue))
          : now; // scheduledChazara is due today

      // Assign urgency: overdue, dueToday, or upcoming
      final ChazaraUrgency urgency;
      if (task.priority == DailyTaskPriority.overdueChazara) {
        urgency = ChazaraUrgency.overdue;
      } else if (dueDate.isAfter(now)) {
        urgency = ChazaraUrgency.upcoming;
      } else {
        urgency = ChazaraUrgency.dueToday;
      }

      return ChazaraQueueItem(
        curriculumId: task.curriculumId,
        sefariaRef: task.contentItemSefariaRef,
        stageName: task.stageName,
        urgency: urgency,
        dueDate: dueDate,
        daysOverdue: daysOverdue,
      );
    }).toList()..sort((a, b) {
      final urgencyCompare = a.urgency.index.compareTo(b.urgency.index);
      if (urgencyCompare != 0) return urgencyCompare;
      return b.daysOverdue.compareTo(a.daysOverdue);
    });
  }

  Future<TutorPaceInfo> _computePaceInfo(
    CurriculumId curriculum,
    List<Completion> completions,
    DateTime now,
  ) async {
    final personalCompletions = completions
        .where((c) => c.trackType == TrackType.personal.storageKey)
        .toList();

    final goals = await _db.goalDao.getGoalsByCurriculum(curriculum.storageKey);
    PaceStatus? paceStatus;

    if (goals.isNotEmpty && goals.first.targetDate != null) {
      final goal = goals.first;
      final dailyCounts = <DateTime, int>{};
      for (final c in personalCompletions) {
        final date = DateTime.utc(
          c.completedAt.year,
          c.completedAt.month,
          c.completedAt.day,
        );
        dailyCounts[date] = (dailyCounts[date] ?? 0) + 1;
      }

      final uniqueRefs = personalCompletions.map((c) => c.sefariaRef).toSet();
      final totalEstimate = uniqueRefs.isNotEmpty
          ? (uniqueRefs.length / (goal.targetPercent / 100)).ceil()
          : 100;

      paceStatus = PaceCalculator.calculate(
        goalStartDate: goal.createdAt,
        goalDeadline: goal.targetDate!,
        totalItems: totalEstimate,
        completedItems: uniqueRefs.length,
        dailyCompletionCounts: dailyCounts,
        today: now,
      );
    }

    // Completion percentage
    final stages = await _db.stageDao.getStageDefinitionsByCurriculum(
      curriculum.storageKey,
    );
    var completionPct = 0.0;
    if (stages.isNotEmpty && completions.isNotEmpty) {
      final totalStages = stages.length;
      final completionsByRef = <String, Set<int>>{};
      for (final c in completions) {
        completionsByRef.putIfAbsent(c.sefariaRef, () => {}).add(c.stageId);
      }
      var fullyCompleted = 0;
      for (final stageSet in completionsByRef.values) {
        if (stageSet.length >= totalStages) fullyCompleted++;
      }
      completionPct = completionsByRef.isNotEmpty
          ? fullyCompleted / completionsByRef.length
          : 0.0;
    }

    return TutorPaceInfo(
      paceStatus: paceStatus,
      completionPercentage: completionPct,
      totalCompletions: completions.length,
    );
  }
}
