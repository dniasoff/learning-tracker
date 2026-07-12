import 'package:flutter/material.dart';
import 'package:learning_tracker/features/gamification/domain/reward_milestone_icons.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/tier_style.dart';

/// Square icon box shown on the left side of an [AchievementTierCard].
/// Renders the reward icon with a lock badge overlay when the milestone
/// is not yet unlocked.
class TierIconBox extends StatelessWidget {
  const TierIconBox({
    super.key,
    required this.scheme,
    required this.unlocked,
    required this.comingSoon,
    required this.rewardIconIndex,
  });

  final TierStyle scheme;
  final bool unlocked;
  final bool comingSoon;
  final int rewardIconIndex;

  @override
  Widget build(BuildContext context) {
    final isLocked = !unlocked;
    final borderColor = (comingSoon && isLocked)
        ? const Color(0xFFB0BEC5)
        : scheme.iconBorder;
    final rewardIcon = RewardMilestoneIcons.iconForIndex(rewardIconIndex);
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: scheme.iconBg,
        borderRadius: BorderRadius.circular(14),
        border: isLocked
            ? Border.all(color: borderColor, width: 1.5)
            : Border.all(color: scheme.iconBorder, width: 1.2),
      ),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Icon(
            rewardIcon,
            size: isLocked ? 26 : 30,
            color: isLocked ? scheme.mutedIconColor : scheme.iconFg,
          ),
          if (isLocked)
            PositionedDirectional(
              end: 3,
              bottom: 3,
              child: Icon(
                Icons.lock_rounded,
                size: 14,
                color: scheme.lockIconColor,
              ),
            ),
        ],
      ),
    );
  }
}
