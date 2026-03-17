import 'package:flutter/material.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// Card showing per-curriculum analytics: on-track status, completion %, points.
class CurriculumCard extends StatelessWidget {
  final CurriculumSummary summary;

  const CurriculumCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pctText =
        '${(summary.completionPercentage * 100).toStringAsFixed(0)}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    summary.curriculum.displayNameEn,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                _PaceBadge(status: summary.paceStatus),
              ],
            ),
            const SizedBox(height: 12),
            // Completion progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.completionPercentage,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$pctText complete', style: theme.textTheme.bodySmall),
                Text(
                  '${summary.points} pts',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.amber.shade700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PaceBadge extends StatelessWidget {
  final PaceStatusType status;

  const _PaceBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // Exhaustive switch on PaceStatusType — will cause a compile error
    // if new values are added to the enum, ensuring they are handled.
    final (label, color) = switch (status) {
      PaceStatusType.ahead => ('Ahead', Colors.green),
      PaceStatusType.onPace => ('On Pace', Colors.blue),
      PaceStatusType.behind => ('Behind', Colors.orange),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
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
