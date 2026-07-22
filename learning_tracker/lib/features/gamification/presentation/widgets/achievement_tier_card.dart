import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/gamification/domain/services/reward_milestone_service.dart'
    show RewardTier;
import 'package:learning_tracker/features/gamification/presentation/providers/achievements_overview_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/locked_achievement_shell.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/tier_icon_box.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/tier_style.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/track_tag_chip.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Card displaying a single achievement milestone row including:
/// - tier icon, title, status label, progress bar, and track tag.
/// Locked milestones are wrapped in a [LockedAchievementShell] blur overlay.
class AchievementTierCard extends StatelessWidget {
  const AchievementTierCard({
    super.key,
    required this.l10n,
    required this.row,
    required this.trackTag,
  });

  final AppLocalizations l10n;
  final AchievementRowVm row;
  final String trackTag;

  static Color _kBrandBlue(BuildContext context) => context.colors.brandBlue;

  double get _progressFraction {
    if (row.isUnlocked) return 1;
    final th = row.milestone.thresholdPoints;
    if (th <= 0) return 0;
    return (row.trackPoints / th).clamp(0.0, 1.0);
  }

  int get _percentRounded {
    if (row.isUnlocked) return 100;
    final th = row.milestone.thresholdPoints;
    if (th <= 0) return 0;
    return (row.trackPoints / th * 100).round().clamp(0, 100);
  }

  String _statusLabel(AppLocalizations l10n) {
    if (row.isUnlocked) return l10n.achievementsStatusUnlocked;
    if (row.isNextUp) return l10n.achievementsStatusComingSoon;
    return l10n.achievementsStatusLocked;
  }

  String _milestonePointsLine(BuildContext context) {
    final locale = Localizations.localeOf(context).toString();
    final fmt = NumberFormat.decimalPattern(locale);
    return l10n.achievementsMilestonePoints(
      fmt.format(row.milestone.thresholdPoints),
    );
  }

  Color _statusTextColor(BuildContext context, TierStyle scheme) {
    if (row.isLegendTier) {
      if (row.isUnlocked) return context.colors.streakActive;
      if (row.isNextUp) return Colors.white;
      return Colors.white70;
    }
    if (row.isUnlocked) return context.colors.statusSuccessDeep;
    if (row.isNextUp) return _kBrandBlue(context);
    return context.colors.streakEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = TierStyle.forTier(
      context.colors,
      RewardTier.classify(row.milestone.title),
      row.isLegendTier,
    );

    final cardContent = Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TierIconBox(
            scheme: scheme,
            unlocked: row.isUnlocked,
            comingSoon: row.isNextUp,
            rewardIconIndex: row.milestone.iconIndex,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 96),
                      child: Align(
                        alignment: AlignmentDirectional.topStart,
                        child: Text(
                          row.milestone.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: scheme.titleColor,
                                height: 1.2,
                              ),
                        ),
                      ),
                    ),
                    // AUD-gamification-02: PositionedDirectional(end:) so the
                    // badge stays clear of the topStart-aligned title in
                    // both LTR and RTL -- a plain Positioned(right:) pins
                    // the badge to the physical right in RTL too, where the
                    // title (topStart flips to physically right-aligned)
                    // also renders, overlapping it.
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: TrackTagChip(label: trackTag, scheme: scheme),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _statusLabel(l10n),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontStyle: FontStyle.italic,
                    color: _statusTextColor(context, scheme),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: _progressFraction,
                    minHeight: 7,
                    backgroundColor: scheme.barBg,
                    color: row.isLegendTier && row.isUnlocked
                        ? context.colors.streakActive
                        : scheme.barFill,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _milestonePointsLine(context),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: row.isLegendTier
                              ? Colors.white.withValues(alpha: 0.9)
                              : context.colors.inkSlate,
                        ),
                      ),
                    ),
                    Text(
                      l10n.achievementsProgressPercent(_percentRounded),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: row.isLegendTier
                            ? Colors.white.withValues(alpha: 0.9)
                            : context.colors.inkSlate,
                      ),
                    ),
                  ],
                ),
                if (row.isLegendTier) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.achievementsUltimateGoal,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final Widget card;
    if (row.isLegendTier) {
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.colors.gamifLegendGradientStart,
              context.colors.gamifLegendGradientEnd,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: context.colors.gamifLegendCardShadow,
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: cardContent,
      );
    } else {
      card = Material(
        color: scheme.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.borderColor),
        ),
        child: cardContent,
      );
    }

    if (row.isUnlocked) {
      return card;
    }

    return LockedAchievementShell(
      l10n: l10n,
      thresholdPoints: row.milestone.thresholdPoints,
      lightBlur: row.isNextUp,
      child: card,
    );
  }
}
