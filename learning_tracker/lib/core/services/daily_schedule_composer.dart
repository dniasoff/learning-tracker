import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

/// Result of composing a daily schedule across all active curricula.
class ComposedDailySchedule {
  ComposedDailySchedule({required this.tasks, required this.summary});

  /// The prioritized, capped list of tasks for the day.
  final List<DailyTask> tasks;

  /// Human-readable summary, e.g. "15 tasks across 3 curricula".
  final String summary;

  /// Tasks grouped by curriculum.
  late final Map<CurriculumId, List<DailyTask>> groupedByCurriculum = () {
    final grouped = <CurriculumId, List<DailyTask>>{};
    for (final task in tasks) {
      grouped.putIfAbsent(task.curriculumId, () => []).add(task);
    }
    return Map<CurriculumId, List<DailyTask>>.unmodifiable(grouped);
  }();
}

/// Aggregates per-curriculum daily tasks into a unified daily learning plan.
///
/// Lives in `lib/core/services/` per P6 — not in any feature module.
/// Depends on abstract interfaces only — no direct feature module imports
/// (DailyTask is a domain model, not a feature import).
class DailyScheduleComposer {
  /// Default maximum tasks per day.
  static const int defaultMaxTasksPerDay = 20;

  /// Compose a unified daily schedule from per-curriculum task lists.
  ///
  /// [perCurriculumTasks] maps each active curriculum to its generated tasks.
  /// [maxTasksPerDay] caps the total number of tasks returned.
  ComposedDailySchedule compose(
    Map<CurriculumId, List<DailyTask>> perCurriculumTasks, {
    int maxTasksPerDay = defaultMaxTasksPerDay,
  }) {
    if (perCurriculumTasks.isEmpty) {
      return ComposedDailySchedule(
        tasks: [],
        summary: 'You have 0 tasks across 0 curricula today',
      );
    }

    // Separate overdue from non-overdue across all curricula
    final overdueTasks = <DailyTask>[];
    final onTimeTasks = <CurriculumId, List<DailyTask>>{};

    for (final entry in perCurriculumTasks.entries) {
      for (final task in entry.value) {
        if (task.isOverdue) {
          overdueTasks.add(task);
        } else {
          onTimeTasks.putIfAbsent(entry.key, () => []).add(task);
        }
      }
    }

    // Sort overdue by priority (overdueChazara first)
    overdueTasks.sort((a, b) => a.priority.index.compareTo(b.priority.index));

    // Round-robin the on-time tasks across curricula
    final roundRobinTasks = _roundRobin(onTimeTasks);

    // Guarantee at least some new-learning slots even when overdue is heavy.
    // Reserve 10% of cap (minimum 2) for non-overdue tasks.
    final reservedForNew = (maxTasksPerDay * 0.1).ceil().clamp(
      2,
      maxTasksPerDay,
    );
    final maxOverdue = maxTasksPerDay - reservedForNew;
    final cappedOverdue = overdueTasks.length > maxOverdue
        ? overdueTasks.sublist(0, maxOverdue)
        : overdueTasks;

    // Combine: overdue first, then round-robin on-time
    final allTasks = [...cappedOverdue, ...roundRobinTasks];

    // Apply load cap
    final capped = allTasks.length > maxTasksPerDay
        ? allTasks.sublist(0, maxTasksPerDay)
        : allTasks;

    // Build summary
    final distinctCurricula = capped.map((t) => t.curriculumId).toSet().length;
    final summary =
        'You have ${capped.length} task${capped.length == 1 ? '' : 's'} '
        'across $distinctCurricula curricul${distinctCurricula == 1 ? 'um' : 'a'} today';

    return ComposedDailySchedule(tasks: capped, summary: summary);
  }

  /// Interleave tasks from multiple curricula in round-robin order.
  List<DailyTask> _roundRobin(
    Map<CurriculumId, List<DailyTask>> tasksByCurriculum,
  ) {
    if (tasksByCurriculum.isEmpty) return [];

    final result = <DailyTask>[];
    // Sort by curriculum name for deterministic round-robin order (M1)
    final sortedKeys = tasksByCurriculum.keys.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final queues = sortedKeys
        .map((k) => List<DailyTask>.of(tasksByCurriculum[k]!))
        .toList();

    // Sort each queue by priority
    for (final q in queues) {
      q.sort((a, b) => a.priority.index.compareTo(b.priority.index));
    }

    var round = 0;
    var added = true;
    while (added) {
      added = false;
      for (final q in queues) {
        if (round < q.length) {
          result.add(q[round]);
          added = true;
        }
      }
      round++;
    }

    return result;
  }
}
