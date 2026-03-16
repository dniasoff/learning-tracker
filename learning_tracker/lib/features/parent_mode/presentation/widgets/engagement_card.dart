import 'package:flutter/material.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';

/// Card showing engagement metrics: days active this week, average daily completions.
class EngagementCard extends StatelessWidget {
  final EngagementMetrics engagement;

  const EngagementCard({super.key, required this.engagement});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Days Active', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    '${engagement.daysActiveThisWeek}/7',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('this week', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Daily Average', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(
                    engagement.averageDailyCompletions.toStringAsFixed(1),
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text('completions/day', style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
