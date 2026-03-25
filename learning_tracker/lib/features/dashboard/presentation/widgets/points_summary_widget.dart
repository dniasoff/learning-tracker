import 'package:flutter/material.dart';

/// Dashboard points summary for child mode.
///
/// Hidden in adult mode — the parent widget should not render this.
class PointsSummaryWidget extends StatelessWidget {
  final int totalPoints;

  const PointsSummaryWidget({super.key, required this.totalPoints});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.star, color: Colors.amber, size: 24),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$totalPoints pts',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Current Balance',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Icon(
              Icons.stars,
              color: Colors.amber.withValues(alpha: 0.5),
              size: 32,
            ),
          ],
        ),
      ),
    );
  }
}
