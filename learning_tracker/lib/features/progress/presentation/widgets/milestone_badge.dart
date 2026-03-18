import 'package:flutter/material.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';

/// Displays a milestone achievement badge with icon and label.
class MilestoneBadge extends StatelessWidget {
  const MilestoneBadge({super.key, required this.milestone});

  final MilestoneAchievement milestone;

  @override
  Widget build(BuildContext context) {
    final isCurriculumComplete = milestone.type == 'curriculum_complete';
    final icon = isCurriculumComplete ? Icons.emoji_events : Icons.star;
    final color = isCurriculumComplete ? Colors.amber : Colors.orange;
    final label = isCurriculumComplete
        ? 'Completed ${milestone.displayName}!'
        : 'Completed Seder ${milestone.displayName}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
