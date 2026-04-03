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
    final color = userMode == UserMode.child
        ? Colors.amber
        : Colors.green;

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
}
