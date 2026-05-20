import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class ChildPointsRewardsTabCard extends StatelessWidget {
  const ChildPointsRewardsTabCard({
    super.key,
    required this.totalPoints,
    required this.l10n,
    required this.theme,
    required this.numberFormat,
    required this.nextRewardAsync,
    required this.onOpenRewards,
  });

  final int totalPoints;
  final AppLocalizations l10n;
  final ThemeData theme;
  final NumberFormat numberFormat;
  final AsyncValue<DashboardChildNextReward?> nextRewardAsync;
  final VoidCallback onOpenRewards;

  static const int _defaultThreshold = 1500;

  @override
  Widget build(BuildContext context) {
    return nextRewardAsync.when(
      loading: () => _buildCard(context, next: null, isLoading: true),
      error: (_, __) => _buildCard(context, next: null, isLoading: false),
      data: (next) => _buildCard(context, next: next, isLoading: false),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required DashboardChildNextReward? next,
    required bool isLoading,
  }) {
    final hasReward = next != null;
    final showRewardSection = isLoading || hasReward;
    final threshold = next?.threshold ?? _defaultThreshold;
    final progressPoints = next?.trackPoints ?? totalPoints;
    final pct = threshold > 0
        ? (progressPoints / threshold).clamp(0.0, 1.0)
        : 0.0;
    final ptsRemaining = threshold > 0
        ? (threshold - progressPoints).clamp(0, 1 << 30)
        : 0;
    final rewardTitle = (next != null && next.title.trim().isNotEmpty)
        ? next.title.trim()
        : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E52D4).withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      kChildRewardsCardBlueTop,
                      AppColors.blueLight,
                      kChildRewardsCardBlueDeep,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -28,
              top: -24,
              child: Icon(
                Icons.star_rounded,
                size: 168,
                color: Colors.white.withValues(alpha: 0.09),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events_rounded,
                          color: Color(0xFFFFC107),
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.dashboardCurrentBalance,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.88),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.dashboardPointsValue(
                                numberFormat.format(totalPoints),
                              ),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 26,
                                height: 1.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (showRewardSection) ...[
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            hasReward
                                ? l10n.dashboardNextRewardWithName(rewardTitle)
                                : l10n.nextReward,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              height: 1.25,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (isLoading)
                          SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          )
                        else
                          Text(
                            l10n.dashboardPtsToGo(
                              numberFormat.format(ptsRemaining),
                            ),
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.82),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: isLoading ? null : pct,
                        minHeight: 8,
                        backgroundColor: kChildRewardsProgressTrack.withValues(
                          alpha: 0.85,
                        ),
                        color: kChildRewardsProgressFill,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Center(
                    child: FilledButton(
                      onPressed: onOpenRewards,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.blueLight,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 14,
                        ),
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.dashboardRedeemPrizes,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.blueLight,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.celebration_rounded, size: 22),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
