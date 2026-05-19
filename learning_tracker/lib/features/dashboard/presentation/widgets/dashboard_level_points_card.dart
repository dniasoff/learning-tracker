import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_stat_bubble.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class DashboardLevelPointsCard extends ConsumerWidget {
  const DashboardLevelPointsCard({
    super.key,
    required this.userMode,
    required this.level,
    required this.totalPoints,
    required this.overdueCount,
    required this.todayCount,
    required this.reviewCount,
    required this.doneDisplay,
    required this.lifetimeSectionsDetail,
    required this.cumulativeLifetime,
    required this.chazaraLabel,
  });

  final UserMode userMode;
  final int level;
  final int totalPoints;
  final int overdueCount;
  final int todayCount;
  final int reviewCount;
  final String doneDisplay;
  final String lifetimeSectionsDetail;
  final double cumulativeLifetime;

  /// Resolved chazara bubble label — Hebrew script or transliteration depending
  /// on the Hebrew Terms setting. Pre-resolved by the parent so this widget
  /// does not need to read [useHebrewTermsProvider] directly.
  final String chazaraLabel;

  static const List<SchedulerTaskSection> _bubbleSections = [
    SchedulerTaskSection.overdue,
    SchedulerTaskSection.today,
    SchedulerTaskSection.review,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bubbleData = userMode == UserMode.child
        ? [
            (l10n.bubbleOverdue, '$overdueCount', Colors.white),
            (l10n.bubbleTodayDue, '$todayCount', Colors.white),
            (chazaraLabel, '$reviewCount', const Color(0xFFFFC107)),
          ]
        : [
            (l10n.bubbleOverdue, '$overdueCount', Colors.white),
            (l10n.bubbleTodayDue, '$todayCount', Colors.white),
            (chazaraLabel, '$reviewCount', const Color(0xFFFFC107)),
          ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B46C8), Color(0xFF143DB6), Color(0xFF11349D)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandBlue.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                l10n.dashboardStats,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
              const Spacer(),
              Text(
                l10n.pointsAbbrev(totalPoints),
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (var i = 0; i < bubbleData.length; i++) ...[
                Expanded(
                  child: DashboardStatBubble(
                    label: bubbleData[i].$1,
                    value: bubbleData[i].$2,
                    valueColor: bubbleData[i].$3,
                    onTap: () {
                      ref
                          .read(schedulerTaskSectionProvider.notifier)
                          .setSection(_bubbleSections[i]);
                      context.router.push(const SchedulerRoute());
                    },
                  ),
                ),
                if (i < bubbleData.length - 1) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.learningLifetimeAllCurricula,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                doneDisplay,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            lifetimeSectionsDetail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 7),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.router.navigate(const ProgressRoute()),
              borderRadius: BorderRadius.circular(999),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: AnimatedProgressBar(
                  value: cumulativeLifetime,
                  color: const Color(0xFFF4C163),
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  height: 12,
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
