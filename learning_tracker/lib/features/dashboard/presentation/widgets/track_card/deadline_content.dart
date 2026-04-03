import 'package:flutter/material.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/item_count_row.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/progress_bar_row.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/status_line.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// Deadline variant content for track cards.
class DeadlineContent extends StatelessWidget {
  const DeadlineContent({super.key, required this.progress});

  final TrackProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paceStatus = progress.paceStatus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressBarRow(
          percentage: progress.scopePercentage ?? 0,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 4),
        ItemCountRow(
          completed: progress.completedItems,
          total: progress.totalItems,
        ),
        const SizedBox(height: 4),
        _buildStatusLine(theme, paceStatus),
      ],
    );
  }

  Widget _buildStatusLine(ThemeData theme, PaceStatus? paceStatus) {
    if (paceStatus == null) {
      return const StatusLine(
        icon: Icons.check_circle_outline,
        text: 'On track',
        color: Colors.green,
      );
    }

    final daysDelta = paceStatus.daysDelta;
    if (daysDelta >= 0) {
      return StatusLine(
        icon: daysDelta > 0 ? Icons.arrow_upward : Icons.check_circle_outline,
        text: daysDelta > 0 ? '$daysDelta days ahead' : 'On track',
        color: Colors.green,
      );
    }

    final absDelta = daysDelta.abs();
    final color = absDelta >= 8 ? theme.colorScheme.error : Colors.amber;
    final projected = paceStatus.projectedCompletionDate;
    final projectedText = projected != null
        ? ' — may finish ${projected.month}/${projected.day}'
        : '';

    return StatusLine(
      icon: Icons.warning_amber_rounded,
      text: '$absDelta days behind$projectedText',
      color: color,
    );
  }
}
