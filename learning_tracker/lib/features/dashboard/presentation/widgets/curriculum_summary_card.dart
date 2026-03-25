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
              Row(
                children: [
                  Text(
                    '$percentage% complete',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (summary.paceStatus?.projectedCompletionDate != null) ...[
                    const Spacer(),
                    _ProjectedDate(
                      date: summary.paceStatus!.projectedCompletionDate!,
                    ),
                  ] else if (summary.paceStatus != null) ...[
                    const Spacer(),
                    Text(
                      'No projection',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
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

    final (label, color, icon) = switch (paceStatus!.status) {
      PaceStatusType.ahead => (
        '${paceStatus!.daysDelta}d ahead',
        Colors.green,
        Icons.trending_up,
      ),
      PaceStatusType.behind => (
        '${paceStatus!.daysDelta.abs()}d behind',
        Colors.orange,
        Icons.trending_down,
      ),
      PaceStatusType.onPace => ('On pace', Colors.blue, Icons.trending_flat),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectedDate extends StatelessWidget {
  const _ProjectedDate({required this.date});

  final DateTime date;

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = '${_months[date.month]} ${date.day}, ${date.year}';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.flag_outlined,
          size: 12,
          color: Colors.white.withValues(alpha: 0.4),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}
