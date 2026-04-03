import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

/// Individual task item card for the dashboard task list.
class DashboardTaskItem extends StatelessWidget {
  const DashboardTaskItem({
    super.key,
    required this.task,
    required this.showTrackLabel,
    this.onComplete,
  });

  final DailyTask task;
  final bool showTrackLabel;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final borderColor = task.isOverdue
        ? theme.colorScheme.error
        : AppTheme.getCurriculumColor(task.curriculumId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {}, // Navigate to learning screen
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: borderColor, width: 4),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: [trackLabel · ] contentRef
                    Text(
                      showTrackLabel
                          ? '${task.trackLabel} · ${task.contentItemSefariaRef}'
                          : task.contentItemSefariaRef,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Line 2: stageName [· N day(s) overdue]
                    _buildSubtitle(theme),
                  ],
                ),
              ),
              // Quick-complete button
              IconButton(
                icon: Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                onPressed: onComplete,
                tooltip: 'Mark complete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(ThemeData theme) {
    if (task.isOverdue) {
      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: task.stageName,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            TextSpan(
              text: ' · overdue',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Text(
      task.stageName,
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
