import 'package:flutter/material.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';

/// Displays stage breakdown as "Learned: X, Chazara 1: Y, Chazara 2: Z".
class StageBreakdownRow extends StatelessWidget {
  const StageBreakdownRow({super.key, required this.stageBreakdown});

  final List<StageBreakdownEntry> stageBreakdown;

  @override
  Widget build(BuildContext context) {
    if (stageBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: stageBreakdown.map((entry) {
        return Text(
          '${entry.stageName}: ${entry.count}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        );
      }).toList(),
    );
  }
}
