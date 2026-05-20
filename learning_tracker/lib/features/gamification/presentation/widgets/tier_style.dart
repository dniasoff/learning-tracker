import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

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

  /// Returns the [TierStyle] appropriate for the given milestone [title].
  /// [isLegend] overrides the title-based lookup for the legend tier.
  static TierStyle forTitle(String title, bool isLegend) {
    final t = title.trim();
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
    switch (t) {
      case 'Bronze Star':
        return const TierStyle(
          cardBg: Color(0xFFF5E6D3),
          borderColor: Color(0xFFE8D5C4),
          iconBg: Color(0xFF8D6E63),
          iconFg: Colors.white,
          iconBorder: Color(0xFF6D4C41),
          titleColor: Color(0xFF4E342E),
          mutedIconColor: Color(0xFF8D6E63),
          barBg: Color(0xFFFFE0B2),
          barFill: Color(0xFF6D4C41),
          tagBg: Color(0xFFFFE0B2),
          tagFg: Color(0xFFBF360C),
          lockIconColor: Color(0xFF5D4037),
        );
      case 'Silver Star':
        return const TierStyle(
          cardBg: Colors.white,
          borderColor: Color(0xFFECEFF1),
          iconBg: AppColors.streakEmpty,
          iconFg: Colors.white,
          iconBorder: AppColors.iconBlueGrey,
          titleColor: Color(0xFF37474F),
          mutedIconColor: AppColors.streakEmpty,
          barBg: Color(0xFFE8ECEF),
          barFill: Color(0xFF546E7A),
          tagBg: Color(0xFFCFD8DC),
          tagFg: Color(0xFF455A64),
          lockIconColor: Color(0xFF607D8B),
        );
      case 'Gold Star':
        return const TierStyle(
          cardBg: Color(0xFFFFF9E6),
          borderColor: Color(0xFFFFECB3),
          iconBg: Color(0xFFFFC400),
          iconFg: Colors.white,
          iconBorder: Color(0xFFFFA000),
          titleColor: Color(0xFFF57F17),
          mutedIconColor: Color(0xFFFFB300),
          barBg: Color(0xFFFFE082),
          barFill: Color(0xFFFF8F00),
          tagBg: Color(0xFFFFF3C4),
          tagFg: Color(0xFFE65100),
          lockIconColor: Color(0xFFF9A825),
        );
      case 'Platinum Star':
        return const TierStyle(
          cardBg: Color(0xFFFAFCFF),
          borderColor: Color(0xFFBBDEFB),
          iconBg: Color(0xFFE3F2FD),
          iconFg: Color(0xFF42A5F5),
          iconBorder: Color(0xFF64B5F6),
          titleColor: Color(0xFF1565C0),
          mutedIconColor: Color(0xFF64B5F6),
          barBg: Color(0xFFBBDEFB),
          barFill: Color(0xFF2196F3),
          tagBg: Color(0xFFE1F5FE),
          tagFg: Color(0xFF0277BD),
          lockIconColor: Color(0xFF5C6BC0),
        );
      case 'Premium Star':
        return const TierStyle(
          cardBg: Color(0xFFF3E5F5),
          borderColor: Color(0xFFE1BEE7),
          iconBg: Color(0xFFEDE7F6),
          iconFg: Color(0xFF7E57C2),
          iconBorder: Color(0xFFB39DDB),
          titleColor: Color(0xFF4527A0),
          mutedIconColor: Color(0xFF9575CD),
          barBg: Color(0xFFCE93D8),
          barFill: Color(0xFF7B1FA2),
          tagBg: Color(0xFFE1BEE7),
          tagFg: Color(0xFF4A148C),
          lockIconColor: Color(0xFF6A1B9A),
        );
      case 'Diamond Star':
        return const TierStyle(
          cardBg: Color(0xFFE0F7FF),
          borderColor: Color(0xFF80DEEA),
          iconBg: Color(0xFFE0F7FA),
          iconFg: Color(0xFF00BCD4),
          iconBorder: Color(0xFF4DD0E1),
          titleColor: Color(0xFF006064),
          mutedIconColor: Color(0xFF00ACC1),
          barBg: Color(0xFF80DEEA),
          barFill: Color(0xFF00ACC1),
          tagBg: Color(0xFFB2EBF2),
          tagFg: Color(0xFF00838F),
          lockIconColor: AppColors.chartTeal,
        );
      case 'Elite Star':
        return const TierStyle(
          cardBg: Color(0xFFFCE4EC),
          borderColor: Color(0xFFF8BBD0),
          iconBg: Color(0xFFF8BBD0),
          iconFg: Color(0xFFEC407A),
          iconBorder: Color(0xFFF48FB1),
          titleColor: Color(0xFFAD1457),
          mutedIconColor: Color(0xFFF06292),
          barBg: Color(0xFFF8BBD0),
          barFill: Color(0xFFE91E63),
          tagBg: Color(0xFFF8BBD0),
          tagFg: Color(0xFFAD1457),
          lockIconColor: Color(0xFFC2185B),
        );
      default:
        return const TierStyle(
          cardBg: Colors.white,
          borderColor: Color(0xFFE0E0E0),
          iconBg: Color(0xFFF5F5F5),
          iconFg: AppColors.iconBlueGrey,
          iconBorder: Color(0xFFB0BEC5),
          titleColor: Color(0xFF37474F),
          mutedIconColor: AppColors.streakEmpty,
          barBg: Color(0xFFECEFF1),
          barFill: AppTheme.brandBlue,
          tagBg: Color(0xFFECEFF1),
          tagFg: Color(0xFF546E7A),
          lockIconColor: AppColors.iconBlueGrey,
        );
    }
  }
}
