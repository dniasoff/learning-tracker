import 'package:flutter/material.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/domain/services/goal_progress_calculator.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/pace_indicator.dart';

/// Displays goal progress: "X% complete, Y days remaining, Z items/day needed".
class GoalProgressCard extends StatelessWidget {
  final GoalProgress progress;
  final PaceStatus? paceStatus;
  final String? description;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const GoalProgressCard({
    super.key,
    required this.progress,
    this.paceStatus,
    this.description,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description != null && description!.isNotEmpty)
              Text(description!, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: (progress.percentComplete / 100).clamp(0.0, 1.0),
            ),
            const SizedBox(height: 8),
            Text(_buildProgressText(), style: theme.textTheme.bodyMedium),
            if (paceStatus != null) ...[
              const SizedBox(height: 8),
              PaceIndicator(paceStatus: paceStatus!),
              const SizedBox(height: 4),
              ProjectedCompletionText(
                projectedDate: paceStatus!.projectedCompletionDate,
              ),
            ],
            if (onEdit != null || onDelete != null) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (onEdit != null)
                    IconButton(icon: const Icon(Icons.edit), onPressed: onEdit),
                  if (onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: onDelete,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _buildProgressText() {
    final parts = <String>[
      '${progress.percentComplete.toStringAsFixed(1)}% complete',
    ];
    if (progress.daysRemaining != null) {
      parts.add('${progress.daysRemaining} days remaining');
    }
    if (progress.itemsPerDay != null) {
      parts.add('${progress.itemsPerDay!.toStringAsFixed(1)} items/day needed');
    }
    return parts.join(', ');
  }
}
