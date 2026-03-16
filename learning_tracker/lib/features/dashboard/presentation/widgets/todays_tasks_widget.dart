import 'package:flutter/material.dart';

/// Displays "X tasks due today" with a quick-start button.
class TodaysTasksWidget extends StatelessWidget {
  final int taskCount;
  final VoidCallback onQuickStart;

  const TodaysTasksWidget({
    super.key,
    required this.taskCount,
    required this.onQuickStart,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.task_alt,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$taskCount task${taskCount == 1 ? '' : 's'} due today',
                style: theme.textTheme.titleSmall,
              ),
            ),
            FilledButton.tonal(
              onPressed: onQuickStart,
              child: const Text('Start'),
            ),
          ],
        ),
      ),
    );
  }
}
