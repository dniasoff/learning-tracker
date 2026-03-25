import 'package:flutter/material.dart';
import 'package:learning_tracker/core/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
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
    final curriculumColor = AppTheme.getCurriculumColor(summary.curriculumId);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 32,
                    decoration: BoxDecoration(
                      color: curriculumColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
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
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: summary.completionPercentage,
                  minHeight: 6,
                  backgroundColor: curriculumColor.withValues(alpha: 0.15),
                  valueColor: AlwaysStoppedAnimation<Color>(curriculumColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$percentage% complete',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (summary.nextDueItem != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Next: ${summary.nextDueItem}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.4),
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

    final (label, color) = switch (paceStatus!.status) {
      PaceStatusType.ahead => ('Ahead', Colors.green),
      PaceStatusType.behind => ('Behind', Colors.orange),
      PaceStatusType.onPace => ('On Pace', Colors.blue),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
