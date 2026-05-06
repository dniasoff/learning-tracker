import 'package:flutter/material.dart';

/// Material icons parents can assign to a reward; [RewardMilestone.iconIndex]
/// indexes into [choices].
abstract final class RewardMilestoneIcons {
  RewardMilestoneIcons._();

  static const List<IconData> choices = <IconData>[
    Icons.emoji_events_rounded,
    Icons.card_giftcard_rounded,
    Icons.military_tech_rounded,
    Icons.workspace_premium_rounded,
    Icons.stars_rounded,
    Icons.star_rounded,
    Icons.celebration_rounded,
    Icons.redeem_rounded,
    Icons.favorite_rounded,
    Icons.auto_awesome_rounded,
    Icons.rocket_launch_rounded,
    Icons.verified_rounded,
    Icons.volunteer_activism_rounded,
    Icons.grade_rounded,
    Icons.local_activity_rounded,
    Icons.school_rounded,
    Icons.menu_book_rounded,
  ];

  static int clampIndex(int raw) {
    if (choices.isEmpty) return 0;
    if (raw < 0) return 0;
    if (raw >= choices.length) return choices.length - 1;
    return raw;
  }

  static IconData iconForIndex(int index) => choices[clampIndex(index)];
}
