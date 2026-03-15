import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';

@RoutePage()
class SchedulerScreen extends ConsumerWidget {
  const SchedulerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncTasks = ref.watch(allDailyTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Tasks')),
      body: asyncTasks.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const EmptyState(
              message: 'All caught up! Great work!',
              subtitle: 'You have no tasks remaining for today.',
              icon: Icons.celebration_outlined,
            );
          }

          return Column(
            children: [
              _TaskSummary(tasks: tasks),
              Expanded(child: _TaskList(tasks: tasks)),
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
    );
  }
}

class _TaskSummary extends StatelessWidget {
  const _TaskSummary({required this.tasks});
  final List<DailyTask> tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Group by curriculum
    final grouped = <CurriculumId, int>{};
    for (final task in tasks) {
      grouped[task.curriculumId] = (grouped[task.curriculumId] ?? 0) + 1;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${tasks.length} task${tasks.length == 1 ? '' : 's'} today',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            children: grouped.entries.map((entry) {
              final color = AppTheme.getCurriculumColor(entry.key);
              return Chip(
                avatar: CircleAvatar(backgroundColor: color, radius: 6),
                label: Text('${entry.key.displayNameEn}: ${entry.value}'),
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
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
