import 'package:flutter/material.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Determines and displays the day type based on today's tasks.
///
/// - Study Day — has new-learning tasks
/// - Review Day — only chazara tasks (no new learning)
/// - Mixed — both new learning and chazara
/// - Rest Day — no tasks scheduled
class DayTypeIndicator extends StatelessWidget {
  const DayTypeIndicator({super.key, required this.tasks});

  final List<DailyTask> tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final (label, icon, color) = _resolve(tasks, l10n);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  static (String, IconData, Color) _resolve(
    List<DailyTask> tasks,
    AppLocalizations l10n,
  ) {
    if (tasks.isEmpty) {
      return (l10n.restDay, Icons.self_improvement, Colors.grey);
    }

    final hasNew = tasks.any(
      (t) => t.priority == DailyTaskPriority.newLearning,
    );
    final hasChazara = tasks.any(
      (t) =>
          t.priority == DailyTaskPriority.overdueChazara ||
          t.priority == DailyTaskPriority.scheduledChazara,
    );

    if (hasNew && hasChazara) {
      return (l10n.mixedDay, Icons.auto_awesome, Colors.purple);
    }
    if (hasNew) {
      return (l10n.studyDay, Icons.menu_book, Colors.green);
    }
    return (l10n.reviewDay, Icons.refresh, Colors.blue);
  }
}
