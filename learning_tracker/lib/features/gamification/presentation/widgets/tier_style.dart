import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart'
    show RewardTier;

/// Immutable visual style descriptor for an achievement tier card.
/// Encapsulates all colours needed to render a single tier consistently.
class TierStyle {
  const TierStyle({
    required this.cardBg,
    required this.borderColor,
    required this.iconBg,
    required this.iconFg,
    required this.iconBorder,
    required this.titleColor,
    required this.mutedIconColor,
    required this.barBg,
    required this.barFill,
    required this.tagBg,
    required this.tagFg,
    required this.lockIconColor,
  });

  final Color cardBg;
  final Color borderColor;
  final Color iconBg;
  final Color iconFg;
  final Color iconBorder;
  final Color titleColor;
  final Color mutedIconColor;
  final Color barBg;
  final Color barFill;
  final Color tagBg;
  final Color tagFg;
  final Color lockIconColor;

  /// Returns the [TierStyle] appropriate for the given [tier].
  ///
  /// [tier] is a stable, non-localizable key (AUD-gamification-07) --
  /// callers derive it via [RewardTier.classify] rather than passing the
  /// milestone's raw display title directly. [isLegend] overrides the
  /// tier-based lookup for the legend tier.
  static TierStyle forTier(RewardTier tier, bool isLegend) {
    if (isLegend) {
      return TierStyle(
        cardBg: Colors.transparent,
        borderColor: Colors.transparent,
        iconBg: Colors.white.withValues(alpha: 0.12),
        iconFg: Colors.white,
        iconBorder: Colors.white30,
        titleColor: Colors.white,
        mutedIconColor: Colors.white70,
        barBg: AppColors.chartBarBg,
        barFill: AppColors.chartBarFillMuted,
        tagBg: Colors.white.withValues(alpha: 0.2),
        tagFg: Colors.white,
        lockIconColor: Colors.white70,
      );
    }
    switch (tier) {
      case RewardTier.bronze:
        return const TierStyle(
          cardBg: AppColors.gamifTierBronzeCardBg,
          borderColor: AppColors.gamifTierBronzeBorder,
          iconBg: AppColors.gamifTierBronzeIconAccent,
          iconFg: Colors.white,
          iconBorder: AppColors.gamifTierBronzeDeepAccent,
          titleColor: AppColors.gamifTierBronzeTitle,
          mutedIconColor: AppColors.gamifTierBronzeIconAccent,
          barBg: AppColors.gamifTierBronzeSoftAccent,
          barFill: AppColors.gamifTierBronzeDeepAccent,
          tagBg: AppColors.gamifTierBronzeSoftAccent,
          tagFg: AppColors.gamifTierBronzeTagFg,
          lockIconColor: AppColors.gamifTierBronzeLockIcon,
        );
      case RewardTier.silver:
        return const TierStyle(
          cardBg: Colors.white,
          borderColor: AppColors.gamifTierSilverBorder,
          iconBg: AppColors.streakEmpty,
          iconFg: Colors.white,
          iconBorder: AppColors.iconBlueGrey,
          titleColor: AppColors.gamifInkCharcoal,
          mutedIconColor: AppColors.streakEmpty,
          barBg: AppColors.gamifTierSilverBarBg,
          barFill: AppColors.gamifTierSilverBarFill,
          tagBg: AppColors.gamifTierSilverTagBg,
          tagFg: AppColors.gamifInkSlateDark,
          lockIconColor: AppColors.gamifTierSilverLockIcon,
        );
      case RewardTier.gold:
        return const TierStyle(
          cardBg: AppColors.gamifTierGoldCardBg,
          borderColor: AppColors.gamifTierGoldBorder,
          iconBg: AppColors.gamifTierGoldIconBg,
          iconFg: Colors.white,
          iconBorder: AppColors.auditActionRewardChanged,
          titleColor: AppColors.gamifTierGoldTitle,
          mutedIconColor: AppColors.gamifTierGoldMutedIcon,
          barBg: AppColors.gamifTierGoldBarBg,
          barFill: AppColors.gamifTierGoldBarFill,
          tagBg: AppColors.gamifTierGoldTagBg,
          tagFg: AppColors.accentBurntOrange,
          lockIconColor: AppColors.gamifTierGoldLockIcon,
        );
      case RewardTier.platinum:
        return const TierStyle(
          cardBg: AppColors.gamifTierPlatinumCardBg,
          borderColor: AppColors.gamifTierPlatinumSoftAccent,
          iconBg: AppColors.gamifTierPlatinumIconBg,
          iconFg: AppColors.gamifTierPlatinumIconFg,
          iconBorder: AppColors.gamifTierPlatinumMidAccent,
          titleColor: AppColors.gamifTierPlatinumTitle,
          mutedIconColor: AppColors.gamifTierPlatinumMidAccent,
          barBg: AppColors.gamifTierPlatinumSoftAccent,
          barFill: AppColors.gamifTierPlatinumBarFill,
          tagBg: AppColors.gamifTierPlatinumTagBg,
          tagFg: AppColors.gamifTierPlatinumTagFg,
          lockIconColor: AppColors.gamifTierPlatinumLockIcon,
        );
      case RewardTier.premium:
        return const TierStyle(
          cardBg: AppColors.gamifTierPremiumCardBg,
          borderColor: AppColors.gamifTierPremiumSoftAccent,
          iconBg: AppColors.gamifTierPremiumIconBg,
          iconFg: AppColors.gamifTierPremiumIconFg,
          iconBorder: AppColors.gamifTierPremiumIconBorder,
          titleColor: AppColors.gamifTierPremiumTitle,
          mutedIconColor: AppColors.gamifTierPremiumMutedIcon,
          barBg: AppColors.gamifTierPremiumBarBg,
          barFill: AppColors.gamifTierPremiumBarFill,
          tagBg: AppColors.gamifTierPremiumSoftAccent,
          tagFg: AppColors.gamifLegendGradientEnd,
          lockIconColor: AppColors.gamifTierPremiumLockIcon,
        );
      case RewardTier.diamond:
        return const TierStyle(
          cardBg: AppColors.gamifTierDiamondCardBg,
          borderColor: AppColors.gamifTierDiamondSoftAccent,
          iconBg: AppColors.gamifTierDiamondIconBg,
          iconFg: AppColors.gamifTierDiamondIconFg,
          iconBorder: AppColors.gamifTierDiamondIconBorder,
          titleColor: AppColors.gamifTierDiamondTitle,
          mutedIconColor: AppColors.gamifTierDiamondAccent,
          barBg: AppColors.gamifTierDiamondSoftAccent,
          barFill: AppColors.gamifTierDiamondAccent,
          tagBg: AppColors.gamifTierDiamondTagBg,
          tagFg: AppColors.gamifTierDiamondTagFg,
          lockIconColor: AppColors.chartTeal,
        );
      case RewardTier.elite:
        return const TierStyle(
          cardBg: AppColors.gamifTierEliteCardBg,
          borderColor: AppColors.gamifTierEliteSoftAccent,
          iconBg: AppColors.gamifTierEliteSoftAccent,
          iconFg: AppColors.gamifTierEliteIconFg,
          iconBorder: AppColors.gamifTierEliteIconBorder,
          titleColor: AppColors.gamifTierEliteDeepAccent,
          mutedIconColor: AppColors.gamifTierEliteMutedIcon,
          barBg: AppColors.gamifTierEliteSoftAccent,
          barFill: AppColors.gamifTierEliteBarFill,
          tagBg: AppColors.gamifTierEliteSoftAccent,
          tagFg: AppColors.gamifTierEliteDeepAccent,
          lockIconColor: AppColors.gamifTierEliteLockIcon,
        );
      case RewardTier.legend:
      case RewardTier.custom:
        return const TierStyle(
          cardBg: Colors.white,
          borderColor: AppColors.gamifTierCustomBorder,
          iconBg: AppColors.gamifTierCustomIconBg,
          iconFg: AppColors.iconBlueGrey,
          iconBorder: AppColors.gamifTierLockedIconGrey,
          titleColor: AppColors.gamifInkCharcoal,
          mutedIconColor: AppColors.streakEmpty,
          barBg: AppColors.gamifTierSilverBorder,
          barFill: AppTheme.brandBlue,
          tagBg: AppColors.gamifTierSilverBorder,
          tagFg: AppColors.gamifTierSilverBarFill,
          lockIconColor: AppColors.iconBlueGrey,
        );
    }
  }
}
