import 'package:flutter/material.dart';
import 'package:learning_tracker/features/dashboard/domain/models/chazara_status.dart';

/// Chazara compliance status line shown on track cards.
///
/// Only rendered when chazaraStatus is non-null.
class ChazaraStatusLine extends StatelessWidget {
  const ChazaraStatusLine({super.key, required this.status});

  final ChazaraStatus status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (status.isCaughtUp) {
      return Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
          const SizedBox(width: 4),
          Text(
            'chazara: caught up',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.green),
          ),
        ],
      );
    }

    final color = status.overdue >= 5
        ? theme.colorScheme.error
        : status.overdue > 0
        ? Colors.amber
        : theme.colorScheme.onSurfaceVariant;

    final parts = <String>[];
    if (status.dueToday > 0) parts.add('${status.dueToday} due today');
    if (status.overdue > 0) parts.add('${status.overdue} overdue');

    return Row(
      children: [
        if (status.overdue >= 5)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(Icons.warning_amber_rounded, size: 14, color: color),
          ),
        Text(
          'chazara: ${parts.join(' · ')}',
          style: theme.textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
