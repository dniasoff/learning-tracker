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

  @override
  Widget build(BuildContext context) {
    final asyncTasks = ref.watch(allDailyTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Daily Tasks')),
      body: SafeArea(
        top: false,
        child: asyncTasks.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return const EmptyState(
                message: 'All caught up! Great work!',
                subtitle: 'You have no tasks remaining for today.',
                icon: Icons.celebration_outlined,
              );
            }

            final schedule = ComposedDailySchedule(
              tasks: tasks,
              summary:
                  '${tasks.length} task${tasks.length == 1 ? '' : 's'} today',
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
                      : _TaskList(tasks: tasks),
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
