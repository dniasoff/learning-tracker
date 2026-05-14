import 'package:flutter/material.dart';
import 'package:learning_tracker/features/scheduler/domain/models/delta_value.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';

/// Color-coded pace indicator for curriculum cards.
///
/// Shows ahead (green), on-pace (yellow), or behind (red) with a
/// numeric days-delta label.
class PaceIndicator extends StatelessWidget {
  final PaceStatus paceStatus;

  const PaceIndicator({super.key, required this.paceStatus});

  @override
  Widget build(BuildContext context) {
    final color = _colorForStatus(paceStatus.status);
    final label = _labelForStatus(paceStatus);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, color: color, size: 12),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  static Color _colorForStatus(PaceStatusType status) {
    switch (status) {
      case PaceStatusType.ahead:
        return Colors.green;
      case PaceStatusType.onPace:
        return Colors.amber;
      case PaceStatusType.behind:
        return Colors.red;
    }
  }

  static String _labelForStatus(PaceStatus pace) {
    if (pace.status == PaceStatusType.onPace) return 'On pace';
    return switch (pace.delta) {
      DateScheduleDelta(:final value) =>
        pace.status == PaceStatusType.ahead
            ? '+${value.days} days ahead'
            : '${value.days.abs()} days behind',
      PaceScheduleDelta(:final value) =>
        pace.status == PaceStatusType.ahead
            ? '+${value.itemsPerWeek} items/week ahead'
            : '${value.itemsPerWeek.abs()} items/week behind',
    };
  }
}

/// Displays the projected completion date.
class ProjectedCompletionText extends StatelessWidget {
  final DateTime? projectedDate;

  const ProjectedCompletionText({super.key, this.projectedDate});

  @override
  Widget build(BuildContext context) {
    if (projectedDate == null) {
      return const SizedBox.shrink();
    }

    final localizations = MaterialLocalizations.of(context);
    final formatted = localizations.formatMediumDate(projectedDate!);

    return Text(
      "At current pace, you'll finish by $formatted",
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
    );
  }
}
