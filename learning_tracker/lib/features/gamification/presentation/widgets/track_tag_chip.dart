import 'package:flutter/material.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/tier_style.dart';

/// Small label chip showing which track a milestone belongs to.
/// Placed in the top-right corner of an [AchievementTierCard].
class TrackTagChip extends StatelessWidget {
  const TrackTagChip({super.key, required this.label, required this.scheme});

  final String label;
  final TierStyle scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.tagBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w800,
          fontSize: 10,
          letterSpacing: 0.4,
          color: scheme.tagFg,
        ),
      ),
    );
  }
}
