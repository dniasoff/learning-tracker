import 'package:flutter/material.dart';
import 'package:learning_tracker/core/services/daily_schedule_composer.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';

/// Displays the composed daily schedule as a single prioritized list
/// with curriculum badges on each task card.
class UnifiedDailyView extends StatelessWidget {
  const UnifiedDailyView({
    required this.schedule,
    required this.onTaskDismissed,
    required this.onTaskCompleted,
    super.key,
  });

  final ComposedDailySchedule schedule;
  final void Function(int index) onTaskDismissed;
  final void Function(int index) onTaskCompleted;

  @override
  Widget build(BuildContext context) {
    if (schedule.tasks.isEmpty) {
      return const Center(child: Text('No tasks for today'));
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: schedule.tasks.length,
      itemBuilder: (context, index) {
        final task = schedule.tasks[index];
        return DailyTaskCard(
          key: ValueKey(
            '${task.curriculumId.storageKey}_'
            '${task.contentItemSefariaRef}_${task.stageOrder}',
          ),
          task: task,
          onDismissed: () => onTaskDismissed(index),
          onCompleted: () => onTaskCompleted(index),
        );
      },
    );
  }
}
