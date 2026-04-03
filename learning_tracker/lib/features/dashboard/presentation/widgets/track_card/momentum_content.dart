import 'package:flutter/material.dart';
import 'package:learning_tracker/features/dashboard/domain/models/momentum_status.dart';
import 'package:learning_tracker/features/dashboard/domain/models/track_progress.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/item_count_row.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/progress_bar_row.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/track_card/shared/status_line.dart';

/// Momentum variant content for track cards.
///
/// Uses gentle, never-punishing language.
class MomentumContent extends StatelessWidget {
  const MomentumContent({super.key, required this.progress});

  final TrackProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final momentum = progress.momentum;

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
        // Momentum text
        if (momentum != null) ...[
          if (momentum.level == MomentumLevel.gettingStarted)
            Text(
              '${progress.completedItems} completed so far',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            Text(
              '${momentum.recentCount} this week · avg ${momentum.personalAverage.toStringAsFixed(1)}/week',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 4),
        ],
        _buildStatusLine(theme, momentum),
      ],
    );
  }

  Widget _buildStatusLine(ThemeData theme, MomentumStatus? momentum) {
    if (momentum == null) {
      return const StatusLine(
        icon: Icons.auto_awesome,
        text: 'Getting started',
        color: Colors.blue,
      );
    }

    switch (momentum.level) {
      case MomentumLevel.gettingStarted:
        return StatusLine(
          icon: Icons.auto_awesome,
          text: 'Getting started',
          color: theme.colorScheme.primary,
        );
      case MomentumLevel.active:
        return const StatusLine(
          icon: Icons.check_circle_outline,
          text: 'Active',
          color: Colors.green,
        );
      case MomentumLevel.slowing:
        return const StatusLine(
          icon: Icons.arrow_forward,
          text: 'Slowing',
          color: Colors.amber,
        );
      case MomentumLevel.paused:
        final daysAgo = momentum.daysSinceLastCompletion;
        final text = daysAgo != null
            ? 'Paused · last: $daysAgo days ago'
            : 'Paused';
        return StatusLine(
          icon: Icons.pause_circle_outline,
          text: text,
          color: theme.colorScheme.onSurfaceVariant,
        );
    }
  }
}
