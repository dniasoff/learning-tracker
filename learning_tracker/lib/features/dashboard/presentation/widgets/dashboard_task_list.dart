import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_task_item.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

/// Unified cross-track task list for the dashboard.
///
/// Shows up to 5 tasks with priority sorting, "View all" link for overflow,
/// and "All done" celebration when empty.
class DashboardTaskList extends ConsumerWidget {
  const DashboardTaskList({
    super.key,
    required this.userMode,
    required this.showTrackLabels,
    required this.onViewAll,
    this.onCompleteTask,
  });

  final UserMode userMode;
  final bool showTrackLabels;
  final VoidCallback onViewAll;
  final void Function(DailyTask task)? onCompleteTask;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        dailyTasksAsync.when(
          loading: () => _sectionHeader(theme, null),
          error: (_, __) => _sectionHeader(theme, null),
          data: (tasks) => _sectionHeader(theme, tasks.length),
        ),
        const SizedBox(height: 12),

        // Task list or empty state
        dailyTasksAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Error loading tasks: $e'),
            ),
          ),
          data: (tasks) {
            if (tasks.isEmpty) {
              return _buildEmptyState(theme);
            }

            final grouped = _groupTasks(tasks);
            final hasSplitSections =
                grouped.overdueProgram.isNotEmpty ||
                grouped.todayProgram.isNotEmpty ||
                grouped.overdueReview.isNotEmpty ||
                grouped.todayReview.isNotEmpty;

            if (hasSplitSections) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (grouped.overdueProgram.isNotEmpty) ...[
                    _subHeader(
                      theme,
                      icon: Icons.warning_amber_rounded,
                      title:
                          'Missed previous days (${grouped.overdueProgram.length})',
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 6),
                    ...grouped.overdueProgram.map(
                      (task) => DashboardTaskItem(
                        task: task,
                        showTrackLabel: showTrackLabels,
                        onComplete: onCompleteTask != null
                            ? () => onCompleteTask!(task)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (grouped.todayProgram.isNotEmpty) ...[
                    _subHeader(
                      theme,
                      icon: Icons.today,
                      title:
                          "Today's program task (${grouped.todayProgram.length})",
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 6),
                    ...grouped.todayProgram.map(
                      (task) => DashboardTaskItem(
                        task: task,
                        showTrackLabel: showTrackLabels,
                        onComplete: onCompleteTask != null
                            ? () => onCompleteTask!(task)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (grouped.overdueReview.isNotEmpty) ...[
                    _subHeader(
                      theme,
                      icon: Icons.history,
                      title: 'Missed review (${grouped.overdueReview.length})',
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 6),
                    ...grouped.overdueReview.map(
                      (task) => DashboardTaskItem(
                        task: task,
                        showTrackLabel: showTrackLabels,
                        onComplete: onCompleteTask != null
                            ? () => onCompleteTask!(task)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (grouped.todayReview.isNotEmpty) ...[
                    _subHeader(
                      theme,
                      icon: Icons.refresh,
                      title: "Today's review (${grouped.todayReview.length})",
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 6),
                    ...grouped.todayReview.map(
                      (task) => DashboardTaskItem(
                        task: task,
                        showTrackLabel: showTrackLabels,
                        onComplete: onCompleteTask != null
                            ? () => onCompleteTask!(task)
                            : null,
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (grouped.todayLearning.isNotEmpty) ...[
                    _subHeader(
                      theme,
                      icon: Icons.menu_book,
                      title:
                          "Today's learning (${grouped.todayLearning.length})",
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(height: 6),
                    ...grouped.todayLearning.map(
                      (task) => DashboardTaskItem(
                        task: task,
                        showTrackLabel: showTrackLabels,
                        onComplete: onCompleteTask != null
                            ? () => onCompleteTask!(task)
                            : null,
                      ),
                    ),
                  ],
                ],
              );
            }

            final displayTasks = tasks.take(5).toList();
            return Column(
              children: [
                ...displayTasks.map(
                  (task) => DashboardTaskItem(
                    task: task,
                    showTrackLabel: showTrackLabels,
                    onComplete: onCompleteTask != null
                        ? () => onCompleteTask!(task)
                        : null,
                  ),
                ),
                if (tasks.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: onViewAll,
                      child: Text('View all (${tasks.length}) →'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _sectionHeader(ThemeData theme, int? remaining) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          "Today's Learning",
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (remaining != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$remaining remaining',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    final icon = userMode == UserMode.child
        ? Icons.celebration
        : Icons.check_circle;
    final color = userMode == UserMode.child ? Colors.amber : Colors.green;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            children: [
              Icon(icon, size: 48, color: color),
              const SizedBox(height: 8),
              Text(
                'All done for today!',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subHeader(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _GroupedTasks {
  const _GroupedTasks({
    required this.overdueProgram,
    required this.todayProgram,
    required this.overdueReview,
    required this.todayReview,
    required this.todayLearning,
  });

  final List<DailyTask> overdueProgram;
  final List<DailyTask> todayProgram;
  final List<DailyTask> overdueReview;
  final List<DailyTask> todayReview;
  final List<DailyTask> todayLearning;
}

_GroupedTasks _groupTasks(List<DailyTask> tasks) {
  final overdueProgram = <DailyTask>[];
  final todayProgram = <DailyTask>[];
  final overdueReview = <DailyTask>[];
  final todayReview = <DailyTask>[];
  final todayLearning = <DailyTask>[];

  for (final task in tasks) {
    switch (task.priority) {
      case DailyTaskPriority.overdueProgram:
        overdueProgram.add(task);
      case DailyTaskPriority.todayProgram:
        todayProgram.add(task);
      case DailyTaskPriority.overdueChazara:
        overdueReview.add(task);
      case DailyTaskPriority.overdueNewLearning:
        overdueReview.add(task);
      case DailyTaskPriority.scheduledChazara:
        todayReview.add(task);
      case DailyTaskPriority.newLearning:
        todayLearning.add(task);
    }
  }

  return _GroupedTasks(
    overdueProgram: overdueProgram,
    todayProgram: todayProgram,
    overdueReview: overdueReview,
    todayReview: todayReview,
    todayLearning: todayLearning,
  );
}
