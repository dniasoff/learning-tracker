import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/services/daily_schedule_composer.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_schedule_header.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/grouped_daily_view.dart';

@RoutePage()
class SchedulerScreen extends ConsumerStatefulWidget {
  const SchedulerScreen({super.key});

  @override
  ConsumerState<SchedulerScreen> createState() => _SchedulerScreenState();
}

class _SchedulerScreenState extends ConsumerState<SchedulerScreen> {
  bool _isGroupedView = false;
  late final SchedulerTaskSectionNotifier _sectionNotifier;

  @override
  void initState() {
    super.initState();
    _sectionNotifier = ref.read(schedulerTaskSectionProvider.notifier);
  }

  @override
  void dispose() {
    _sectionNotifier.reset();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncTasks = ref.watch(allDailyTasksProvider);
    final section = ref.watch(schedulerTaskSectionProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Daily Tasks')),
      body: SafeArea(
        top: false,
        child: asyncTasks.when(
          data: (tasks) {
            final visibleTasks = _filterTasks(tasks, section);
            if (visibleTasks.isEmpty) {
              return const EmptyState(
                message: 'All caught up! Great work!',
                subtitle: 'You have no tasks remaining for today.',
                icon: Icons.celebration_outlined,
              );
            }

            final schedule = ComposedDailySchedule(
              tasks: visibleTasks,
              summary: _summaryForSection(section, visibleTasks.length),
            );

            return Column(
              children: [
                DailyScheduleHeader(
                  summary: schedule.summary,
                  isGroupedView: _isGroupedView,
                  onToggleView: () =>
                      setState(() => _isGroupedView = !_isGroupedView),
                ),
                Expanded(
                  child: _isGroupedView
                      ? GroupedDailyView(
                          schedule: schedule,
                          onTaskDismissed: (curriculum, index) {
                            final grouped = schedule.groupedByCurriculum;
                            final task = grouped[curriculum]![index];
                            _skipTask(task);
                          },
                          onTaskCompleted: (curriculum, index) {
                            ref.invalidate(allDailyTasksProvider);
                          },
                        )
                      : _TaskList(tasks: visibleTasks),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Error loading tasks: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(allDailyTasksProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _skipTask(DailyTask task) {
    ref.read(skippedTasksProvider.notifier).skip(task.contentItemSefariaRef);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Task skipped until tomorrow'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () {
            ref
                .read(skippedTasksProvider.notifier)
                .undoSkip(task.contentItemSefariaRef);
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

String _summaryForSection(SchedulerTaskSection section, int count) {
  final noun = count == 1 ? 'task' : 'tasks';
  return switch (section) {
    SchedulerTaskSection.all => '$count $noun today',
    SchedulerTaskSection.today => '$count today $noun',
    SchedulerTaskSection.overdue => '$count missed/overdue $noun',
    SchedulerTaskSection.review => '$count chazara/review $noun',
  };
}

class _TaskList extends ConsumerWidget {
  const _TaskList({required this.tasks});
  final List<DailyTask> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        return DailyTaskCard(
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
                content: const Text('Task skipped until tomorrow'),
                action: SnackBarAction(
                  label: 'Undo',
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
        );
      },
    );
  }
}
