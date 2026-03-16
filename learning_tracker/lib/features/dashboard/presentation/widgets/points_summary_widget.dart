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
      color: theme.colorScheme.tertiaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star,
              color: theme.colorScheme.onTertiaryContainer,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              '$totalPoints points',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onTertiaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
