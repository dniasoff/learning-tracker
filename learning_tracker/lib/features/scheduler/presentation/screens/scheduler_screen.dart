import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_schedule_composer.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/grouped_daily_view.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class SchedulerScreen extends ConsumerWidget {
  const SchedulerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTasks = ref.watch(allDailyTasksProvider);
    // Non-blocking daf grouping: collapse a daf's amudim to one card when the
    // goal/content data is already available; otherwise show the ungrouped list
    // (never block the daily screen on the grouping lookups).
    final coarsePacedIds =
        ref.watch(coarsePacedTrackIdsProvider).asData?.value ?? const <int>{};
    final contentIndex = ref.watch(contentIndexProvider).asData?.value;
    final section = ref.watch(schedulerTaskSectionProvider);
    final isGroupedView = ref.watch(schedulerGroupedViewProvider);
    final theme = Theme.of(context);

    void skipTask(DailyTask task) {
      ref.read(skippedTasksProvider.notifier).skip(task.contentItemSefariaRef);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.taskSkippedUntilTomorrow),
          action: SnackBarAction(
            label: AppLocalizations.of(context)!.undoLabel,
            onPressed: () {
              ref
                  .read(skippedTasksProvider.notifier)
                  .undoSkip(task.contentItemSefariaRef);
            },
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.surfaceF5,
      body: SafeArea(
        child: asyncTasks.when(
          data: (rawTasks) {
            final tasks = (coarsePacedIds.isNotEmpty && contentIndex != null)
                ? collapseDafTasks(
                    rawTasks,
                    coarsePacedTrackIds: coarsePacedIds,
                    index: contentIndex,
                  )
                : rawTasks;
            final visibleTasks = _filterTasks(tasks, section);
            if (visibleTasks.isEmpty) {
              final l10n = AppLocalizations.of(context)!;
              return EmptyState(
                message: l10n.dashboardAllCaughtUpTitle,
                subtitle: section == SchedulerTaskSection.overdue
                    ? l10n.tasksNoOverdueTasksSubtitle
                    : l10n.tasksNoTasksRemainingTitle,
                icon: Icons.celebration_outlined,
              );
            }

            final schedule = ComposedDailySchedule(tasks: visibleTasks);

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: _HeaderRow(
                    titleStyle: theme.textTheme.headlineSmall?.copyWith(
                      color: AppTheme.brandBlueDeep,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                  child: _GoalCard(
                    count: visibleTasks.length,
                    isGroupedView: isGroupedView,
                    onToggleView: () => ref
                        .read(schedulerGroupedViewProvider.notifier)
                        .toggle(),
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: isGroupedView
                        ? GroupedDailyView(
                            schedule: schedule,
                            onTaskDismissed: (curriculum, index) {
                              final grouped = schedule.groupedByCurriculum;
                              final task = grouped[curriculum]![index];
                              skipTask(task);
                            },
                            onTaskCompleted: (curriculum, index) {
                              ref.invalidate(allDailyTasksProvider);
                            },
                          )
                        : _TaskList(tasks: visibleTasks),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) {
            AppLogger.instance.error(
              event: 'scheduler_tasks_load_failed',
              exception: error,
              stackTrace: stack,
            );
            final l10n = AppLocalizations.of(context)!;
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.errorLoadingTasks(l10n.errorSaveFailed)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(allDailyTasksProvider),
                    child: Text(l10n.actionRetry),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

List<DailyTask> _filterTasks(
  List<DailyTask> tasks,
  SchedulerTaskSection section,
) {
  switch (section) {
    case SchedulerTaskSection.all:
      return tasks;
    case SchedulerTaskSection.today:
      return tasks
          .where(
            (t) =>
                !t.isOverdue &&
                t.priority != DailyTaskPriority.overdueChazara &&
                t.priority != DailyTaskPriority.scheduledChazara,
          )
          .toList();
    case SchedulerTaskSection.overdue:
      return tasks.where((t) => t.isOverdue).toList();
    case SchedulerTaskSection.review:
      return tasks
          .where(
            (t) =>
                t.priority == DailyTaskPriority.overdueChazara ||
                t.priority == DailyTaskPriority.scheduledChazara,
          )
          .toList();
  }
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks});
  final List<DailyTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 90),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: DailyTaskCard(
            key: ValueKey(
              '${task.curriculumId.storageKey}_'
              '${task.contentItemSefariaRef}_${task.stageOrder}',
            ),
            task: task,
            onDismissed: () {
              ref
                  .read(skippedTasksProvider.notifier)
                  .skip(task.contentItemSefariaRef);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    AppLocalizations.of(context)!.taskSkippedUntilTomorrow,
                  ),
                  action: SnackBarAction(
                    label: AppLocalizations.of(context)!.undoLabel,
                    onPressed: () {
                      ref
                          .read(skippedTasksProvider.notifier)
                          .undoSkip(task.contentItemSefariaRef);
                    },
                  ),
                ),
              );
            },
            onCompleted: () {
              ref.invalidate(allDailyTasksProvider);
            },
          ),
        );
      },
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({this.titleStyle});

  final TextStyle? titleStyle;

  @override
  Widget build(BuildContext context) {
    return Text(
      AppLocalizations.of(context)!.dailyTasksTitle,
      style: titleStyle,
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({
    required this.count,
    required this.isGroupedView,
    required this.onToggleView,
  });

  final int count;
  final bool isGroupedView;
  final VoidCallback onToggleView;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B46C8), Color(0xFF143DB6), Color(0xFF11349D)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandBlue.withValues(alpha: 0.24),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.schedulerTodaysGoal,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.schedulerGoalTaskCount(count),
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onToggleView,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGroupedView
                    ? Icons.view_list_rounded
                    : Icons.grid_view_rounded,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
