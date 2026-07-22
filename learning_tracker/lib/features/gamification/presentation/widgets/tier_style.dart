import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
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
  static TierStyle forTier(AppPalette c, RewardTier tier, bool isLegend) {
    if (isLegend) {
      return TierStyle(
        cardBg: Colors.transparent,
        borderColor: Colors.transparent,
        iconBg: Colors.white.withValues(alpha: 0.12),
        iconFg: Colors.white,
        iconBorder: Colors.white30,
        titleColor: Colors.white,
        mutedIconColor: Colors.white70,
        barBg: c.chartBarBg,
        barFill: c.chartBarFillMuted,
        tagBg: Colors.white.withValues(alpha: 0.2),
        tagFg: Colors.white,
        lockIconColor: Colors.white70,
      );
    }
    switch (tier) {
      case RewardTier.bronze:
        return TierStyle(
          cardBg: c.gamifTierBronzeCardBg,
          borderColor: c.gamifTierBronzeBorder,
          iconBg: c.gamifTierBronzeIconAccent,
          iconFg: Colors.white,
          iconBorder: c.gamifTierBronzeDeepAccent,
          titleColor: c.gamifTierBronzeTitle,
          mutedIconColor: c.gamifTierBronzeIconAccent,
          barBg: c.gamifTierBronzeSoftAccent,
          barFill: c.gamifTierBronzeDeepAccent,
          tagBg: c.gamifTierBronzeSoftAccent,
          tagFg: c.gamifTierBronzeTagFg,
          lockIconColor: c.gamifTierBronzeLockIcon,
        );
      case RewardTier.silver:
        return TierStyle(
          cardBg: Colors.white,
          borderColor: c.gamifTierSilverBorder,
          iconBg: c.streakEmpty,
          iconFg: Colors.white,
          iconBorder: c.iconBlueGrey,
          titleColor: c.gamifInkCharcoal,
          mutedIconColor: c.streakEmpty,
          barBg: c.gamifTierSilverBarBg,
          barFill: c.gamifTierSilverBarFill,
          tagBg: c.gamifTierSilverTagBg,
          tagFg: c.gamifInkSlateDark,
          lockIconColor: c.gamifTierSilverLockIcon,
        );
      case RewardTier.gold:
        return TierStyle(
          cardBg: c.gamifTierGoldCardBg,
          borderColor: c.gamifTierGoldBorder,
          iconBg: c.gamifTierGoldIconBg,
          iconFg: Colors.white,
          iconBorder: c.auditActionRewardChanged,
          titleColor: c.gamifTierGoldTitle,
          mutedIconColor: c.gamifTierGoldMutedIcon,
          barBg: c.gamifTierGoldBarBg,
          barFill: c.gamifTierGoldBarFill,
          tagBg: c.gamifTierGoldTagBg,
          tagFg: c.accentBurntOrange,
          lockIconColor: c.gamifTierGoldLockIcon,
        );
      case RewardTier.platinum:
        return TierStyle(
          cardBg: c.gamifTierPlatinumCardBg,
          borderColor: c.gamifTierPlatinumSoftAccent,
          iconBg: c.gamifTierPlatinumIconBg,
          iconFg: c.gamifTierPlatinumIconFg,
          iconBorder: c.gamifTierPlatinumMidAccent,
          titleColor: c.gamifTierPlatinumTitle,
          mutedIconColor: c.gamifTierPlatinumMidAccent,
          barBg: c.gamifTierPlatinumSoftAccent,
          barFill: c.gamifTierPlatinumBarFill,
          tagBg: c.gamifTierPlatinumTagBg,
          tagFg: c.gamifTierPlatinumTagFg,
          lockIconColor: c.gamifTierPlatinumLockIcon,
        );
      case RewardTier.premium:
        return TierStyle(
          cardBg: c.gamifTierPremiumCardBg,
          borderColor: c.gamifTierPremiumSoftAccent,
          iconBg: c.gamifTierPremiumIconBg,
          iconFg: c.gamifTierPremiumIconFg,
          iconBorder: c.gamifTierPremiumIconBorder,
          titleColor: c.gamifTierPremiumTitle,
          mutedIconColor: c.gamifTierPremiumMutedIcon,
          barBg: c.gamifTierPremiumBarBg,
          barFill: c.gamifTierPremiumBarFill,
          tagBg: c.gamifTierPremiumSoftAccent,
          tagFg: c.gamifLegendGradientEnd,
          lockIconColor: c.gamifTierPremiumLockIcon,
        );
      case RewardTier.diamond:
        return TierStyle(
          cardBg: c.gamifTierDiamondCardBg,
          borderColor: c.gamifTierDiamondSoftAccent,
          iconBg: c.gamifTierDiamondIconBg,
          iconFg: c.gamifTierDiamondIconFg,
          iconBorder: c.gamifTierDiamondIconBorder,
          titleColor: c.gamifTierDiamondTitle,
          mutedIconColor: c.gamifTierDiamondAccent,
          barBg: c.gamifTierDiamondSoftAccent,
          barFill: c.gamifTierDiamondAccent,
          tagBg: c.gamifTierDiamondTagBg,
          tagFg: c.gamifTierDiamondTagFg,
          lockIconColor: c.chartTeal,
        );
      case RewardTier.elite:
        return TierStyle(
          cardBg: c.gamifTierEliteCardBg,
          borderColor: c.gamifTierEliteSoftAccent,
          iconBg: c.gamifTierEliteSoftAccent,
          iconFg: c.gamifTierEliteIconFg,
          iconBorder: c.gamifTierEliteIconBorder,
          titleColor: c.gamifTierEliteDeepAccent,
          mutedIconColor: c.gamifTierEliteMutedIcon,
          barBg: c.gamifTierEliteSoftAccent,
          barFill: c.gamifTierEliteBarFill,
          tagBg: c.gamifTierEliteSoftAccent,
          tagFg: c.gamifTierEliteDeepAccent,
          lockIconColor: c.gamifTierEliteLockIcon,
        );
      case RewardTier.legend:
      case RewardTier.custom:
        return TierStyle(
          cardBg: Colors.white,
          borderColor: c.gamifTierCustomBorder,
          iconBg: c.gamifTierCustomIconBg,
          iconFg: c.iconBlueGrey,
          iconBorder: c.gamifTierLockedIconGrey,
          titleColor: c.gamifInkCharcoal,
          mutedIconColor: c.streakEmpty,
          barBg: c.gamifTierSilverBorder,
          barFill: c.brandBlue,
          tagBg: c.gamifTierSilverBorder,
          tagFg: c.gamifTierSilverBarFill,
          lockIconColor: c.iconBlueGrey,
        );
    }
  }
}
