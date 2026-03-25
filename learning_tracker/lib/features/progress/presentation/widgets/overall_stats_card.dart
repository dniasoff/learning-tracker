import 'package:flutter/material.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';

/// Card displaying overall curriculum statistics.
class OverallStatsCard extends StatelessWidget {
  const OverallStatsCard({super.key, required this.stats});

  final OverallCurriculumStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall Progress',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            _StatRow(label: 'Total items', value: stats.totalItems),
            _StatRow(
              label: 'Completed all stages',
              value: stats.completedAllStages,
              color: Colors.green,
            ),
            _StatRow(
              label: 'In progress',
              value: stats.inProgress,
              color: Colors.blue,
            ),
            _StatRow(
              label: 'Not started',
              value: stats.notStarted,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.label, required this.value, this.color});

  final String label;
  final int value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (color != null) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(label),
            ],
          ),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
