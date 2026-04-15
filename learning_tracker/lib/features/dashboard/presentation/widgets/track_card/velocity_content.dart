import 'package:flutter/material.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/item_count_row.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/progress_bar_row.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/status_line.dart';

/// Velocity variant content for track cards.
class VelocityContent extends StatelessWidget {
  const VelocityContent({super.key, required this.progress});

  final TrackProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final paceStatus = progress.paceStatus;
    final ratio = paceStatus != null && paceStatus.rollingAverage > 0
        ? paceStatus.rollingAverage /
              1.0 // simplified
        : 0.0;

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
        _buildStatusLine(theme, ratio),
      ],
    );
  }

  Widget _buildStatusLine(ThemeData theme, double ratio) {
    if (ratio >= 1.0) {
      return const StatusLine(
        icon: Icons.check_circle_outline,
        text: 'Above target',
        color: Colors.green,
      );
    }
    if (ratio >= 0.9) {
      return const StatusLine(
        icon: Icons.check_circle_outline,
        text: 'On pace',
        color: Colors.green,
      );
    }
    if (ratio >= 0.5) {
      return const StatusLine(
        icon: Icons.warning_amber_rounded,
        text: 'Below target',
        color: Colors.amber,
      );
    }
    return StatusLine(
      icon: Icons.warning_amber_rounded,
      text: 'Below target',
      color: theme.colorScheme.error,
    );
  }
}
