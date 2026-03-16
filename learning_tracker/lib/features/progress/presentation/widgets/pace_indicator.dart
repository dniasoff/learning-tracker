import 'package:flutter/material.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// Shows behind/on-track/ahead status badge for a curriculum goal.
class PaceIndicator extends StatelessWidget {
  const PaceIndicator({super.key, required this.paceStatus});

  final PaceStatus paceStatus;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (paceStatus.status) {
      PaceStatusType.ahead => (
        'Ahead by ${paceStatus.daysDelta} days',
        Colors.green,
        Icons.trending_up,
      ),
      PaceStatusType.onPace => (
        'On pace',
        Colors.blue,
        Icons.check_circle_outline,
      ),
      PaceStatusType.behind => (
        'Behind by ${paceStatus.daysDelta.abs()} days',
        Colors.orange,
        Icons.trending_down,
      ),
    };

    return Card(
      color: color.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
