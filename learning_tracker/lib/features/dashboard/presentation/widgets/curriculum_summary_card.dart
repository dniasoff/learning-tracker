import 'package:flutter/material.dart';
import 'package:learning_tracker/core/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// A summary card for one curriculum on the dashboard.
///
/// Shows name, completion %, pace indicator, and next due item.
/// Tapping navigates to the per-curriculum progress screen.
class CurriculumSummaryCard extends StatelessWidget {
  final CurriculumSummary summary;
  final VoidCallback onTap;

  const CurriculumSummaryCard({
    super.key,
    required this.summary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = (summary.completionPercentage * 100).round();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      summary.curriculumId.displayNameEn,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _PaceBadge(paceStatus: summary.paceStatus),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: summary.completionPercentage,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
              const SizedBox(height: 4),
              Text('$percentage% complete', style: theme.textTheme.bodySmall),
              if (summary.nextDueItem != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Next: ${summary.nextDueItem}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _PaceBadge extends StatelessWidget {
  final PaceStatus? paceStatus;

  const _PaceBadge({required this.paceStatus});

  @override
  Widget build(BuildContext context) {
    if (paceStatus == null) return const SizedBox.shrink();

    final (icon, color) = switch (paceStatus!.status) {
      PaceStatusType.ahead => (Icons.trending_up, Colors.green),
      PaceStatusType.behind => (Icons.trending_down, Colors.orange),
      PaceStatusType.onPace => (Icons.trending_flat, Colors.blue),
    };

    return Icon(icon, color: color, size: 20);
  }
}
