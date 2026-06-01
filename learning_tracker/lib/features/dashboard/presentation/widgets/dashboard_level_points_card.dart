import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
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
    this.chazaraLabel,
    this.tasksReady = true,
  });

  final ProfileMode userMode;
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
  ///
  /// Null when no active track has chazara enabled (Rule 8) — the chazara
  /// bubble is suppressed entirely (not zeroed out).
  final String? chazaraLabel;

  /// Whether the task counts are ready to display.
  ///
  /// When `false` (initial sync has not yet completed), the OVERDUE / TODAY /
  /// CHAZARA bubbles show "…" instead of a number — never 0, never a positive
  /// integer.  The remaining tiles (level, points, lifetime progress) are
  /// unaffected.
  final bool tasksReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    // When tasksReady is false (initial sync not yet complete), show "…"
    // instead of any numeric count — the data is incomplete and must not be
    // presented as a meaningful number to the user.
    final overdueDisplay = tasksReady ? '$overdueCount' : '…';
    final todayDisplay = tasksReady ? '$todayCount' : '…';
    final reviewDisplay = tasksReady ? '$reviewCount' : '…';

    // Build bubble entries as (label, value, color, schedulerSection).
    // The chazara bubble is included only when chazaraLabel is non-null
    // (Rule 8: suppress entirely for tracks without chazara).
    final bubbles = [
      (
        l10n.bubbleOverdue,
        overdueDisplay,
        Colors.white,
        SchedulerTaskSection.overdue,
      ),
      (
        l10n.bubbleTodayDue,
        todayDisplay,
        Colors.white,
        SchedulerTaskSection.today,
      ),
      if (chazaraLabel != null)
        (
          chazaraLabel!,
          reviewDisplay,
          const Color(0xFFFFC107),
          SchedulerTaskSection.review,
        ),
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
              // BUG-7: points are a child-only concept (product rule: adults
              // have no points). For an adult this would always read "0 pts",
              // which violates the rule — so the points label is suppressed
              // entirely in adult mode. The rest of the card (task bubbles,
              // lifetime progress) is mode-agnostic and stays visible.
              if (userMode == ProfileMode.child)
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
              for (var i = 0; i < bubbles.length; i++) ...[
                Expanded(
                  child: DashboardStatBubble(
                    label: bubbles[i].$1,
                    value: bubbles[i].$2,
                    valueColor: bubbles[i].$3,
                    onTap: () {
                      ref
                          .read(schedulerTaskSectionProvider.notifier)
                          .setSection(bubbles[i].$4);
                      context.router.push(const SchedulerRoute());
                    },
                  ),
                ),
                if (i < bubbles.length - 1) const SizedBox(width: 10),
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
