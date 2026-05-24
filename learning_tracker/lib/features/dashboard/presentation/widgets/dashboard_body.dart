import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/sync/initial_sync_state.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/active_tracks_carousel_section.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/child_points_rewards_tab_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/compact_mission_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_all_caught_up_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_helpers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_level_points_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/empty_dashboard.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/main_focus_mission_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/skipped_onboarding_cta_banner.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/streak_recovery_banner.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
// Cross-feature import via the progress barrel (Rule 2 / DNI-386). The
// barrel re-exports `ProgressTierCounterRow`; deep importing
// `lib/features/progress/presentation/widgets/...` would violate the
// layering rule.
import 'package:learning_tracker/features/progress/progress.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class DashboardBody extends ConsumerWidget {
  final List<CurriculumTrack> activeTracks;
  final ProfileMode userMode;
  final int currentStreak;
  final String? profileName;

  const DashboardBody({
    super.key,
    required this.activeTracks,
    required this.userMode,
    required this.currentStreak,
    this.profileName,
  });

  String _greeting(AppLocalizations l10n) {
    final hour = DateTimeFactory.nowLocal().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  ({IconData icon, Color fg, Color bg}) _greetingChip() {
    final hour = DateTimeFactory.nowLocal().hour;
    if (hour < 12) {
      return (
        icon: Icons.wb_sunny_rounded,
        fg: const Color(0xFFE07A00),
        bg: const Color(0xFFFFF1D6),
      );
    }
    if (hour < 17) {
      return (
        icon: Icons.brightness_high_rounded,
        fg: const Color(0xFFC25400),
        bg: const Color(0xFFFFE7C7),
      );
    }
    return (
      icon: Icons.bedtime_rounded,
      fg: const Color(0xFF4A4296),
      bg: const Color(0xFFE7E5FB),
    );
  }

  String _formatDashboardDate(BuildContext context, DateTime date) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMd(locale).format(date);
  }

  TextStyle _iosTextStyle(
    BuildContext context, {
    required double size,
    required FontWeight weight,
    Color? color,
    double? height,
    double? letterSpacing,
  }) {
    return Theme.of(context).textTheme.bodyMedium!.copyWith(
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final profileId = ref.watch(activeProfileIdProvider);
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);
    // Use .select() so this widget only rebuilds when the integer value
    // changes — not on every completion-triggered AsyncValue re-emission
    // when points remain the same (e.g. adult users where this is always 0).
    final totalPoints = ref.watch(
      dashboardGlobalPointsProvider.select((v) => v.asData?.value ?? 0),
    );
    final lifetimeTotalsAsync = ref.watch(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId),
    );
    final terms = domainTermLabels(ref);
    final reviewSectionLabel = terms.reviewSection;
    // Gate chazara labels on whether any active track has chazara (Rule 8).
    final anyTrackHasChazara =
        ref.watch(anyActiveTrackHasChazaraProvider).asData?.value ?? false;
    final chazaraReviewLabel = anyTrackHasChazara ? terms.chazara : null;
    final chazaraBubbleLabel = anyTrackHasChazara ? terms.bubbleChazara : null;
    final name = profileName ?? l10n.learner;
    final now = DateTimeFactory.nowLocal();

    // §10.2 — "initial sync complete" gate.
    //
    // Before the first full Firestore pull finishes, the local DB may be empty
    // or partially merged.  Running the projection on that data would produce
    // a misleading count (artificially high overdue, or 0 that looks like
    // "all done").  We therefore treat the dashboard count tiles as "not ready"
    // until both conditions hold:
    //   1. dailyTasksAsync has emitted at least one value (DB query resolved).
    //   2. initialSyncCompleteProvider is true (full pull has completed once).
    //
    // An absent / loading / false value is treated the same: not ready.
    final initialSyncComplete =
        ref.watch(initialSyncCompleteProvider).asData?.value ?? false;

    // Provide an empty task list while not ready so the list-grouping helpers
    // below can run without null checks.  The counts derived from this list
    // are only shown when `tasksReady` is true.
    final allTasks = dailyTasksAsync.value ?? const <DailyTask>[];
    final lifetimeTotals = lifetimeTotalsAsync.hasValue
        ? lifetimeTotalsAsync.value
        : null;
    final cumulativeLifetime = lifetimeTotals?.percentage ?? 0.0;
    final numberFormat = NumberFormat.decimalPattern();
    final lifetimePercentStr = formatFractionAsPercent(cumulativeLifetime);
    final lifetimeSectionsStr = lifetimeTotals == null
        ? l10n.lifetimeSectionsSummary('0', '0', CurriculumId.values.length)
        : l10n.lifetimeSectionsSummary(
            numberFormat.format(lifetimeTotals.learnedSections),
            numberFormat.format(lifetimeTotals.totalSections),
            CurriculumId.values.length,
          );

    if (activeTracks.isEmpty) {
      final isChildMode =
          ref.watch(selectedProfileProvider).asData?.value?.profileMode ==
          ProfileMode.child;
      // W6.3: if user skipped track setup during onboarding, show CTA banner
      // instead of the generic empty-dashboard prompt.
      final skipState = ref.watch(onboardingSkipStateProvider).asData?.value;
      if (skipState != null && skipState.skipped && !isChildMode) {
        return const SkippedOnboardingCtaBanner();
      }
      return EmptyDashboard(
        name: name,
        greeting: _greeting(l10n),
        isChildMode: isChildMode,
      );
    }

    final groupedTasks = groupTasks(allTasks);
    final todayCount = groupedTasks.todayTasks.length;
    final overdueCount = groupedTasks.overdueTasks.length;
    final reviewCount = groupedTasks.reviewTasks.length;
    final totalRemaining = todayCount + overdueCount + reviewCount;
    final level = (1 + (cumulativeLifetime * 19)).clamp(1, 20).round();
    final doneDisplay = lifetimePercentStr;
    final sectionsDetail = lifetimeSectionsStr;

    // Tasks are "ready" only when the DB query has resolved AND the first full
    // Firestore pull has completed.  If either condition is unmet, the count
    // tiles show "…" — never 0, never a positive integer.
    final tasksReady = dailyTasksAsync.hasValue && initialSyncComplete;
    final lifetimeReady = lifetimeTotalsAsync.hasValue;
    // "All caught up" is suppressed until tasks are ready: showing it before
    // sync completes would mislead the user into thinking there's nothing to do
    // when in fact the data hasn't arrived yet.
    final showAllCaughtUp =
        tasksReady &&
        lifetimeReady &&
        reviewCount == 0 &&
        overdueCount == 0 &&
        todayCount == 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 30),
      children: [
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final chip = _greetingChip();
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: chip.bg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(chip.icon, size: 14, color: chip.fg),
                            const SizedBox(width: 6),
                            Text(
                              _greeting(l10n),
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: chip.fg,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      '$name!',
                      style: _iosTextStyle(
                        context,
                        size: 28,
                        weight: FontWeight.w800,
                        color: AppTheme.brandInk,
                      ),
                      maxLines: 1,
                      softWrap: false,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDashboardDate(context, now),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.statusDanger,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.statusDanger.withValues(alpha: 0.28),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.local_fire_department_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$currentStreak',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        // Tier counter row (engagement / achievement / lifetime [/ ⭐ points]).
        // Shared with Progress hub — same widget, same providers.
        // Child mode renders the fourth ⭐ points counter (see Task #14 brief).
        ProgressTierCounterRow(showPoints: userMode == ProfileMode.child),
        const SizedBox(height: 22),
        if (userMode == ProfileMode.child) ...[
          ChildPointsRewardsTabCard(
            totalPoints: totalPoints,
            l10n: l10n,
            theme: theme,
            numberFormat: numberFormat,
            nextRewardAsync: ref.watch(dashboardChildNextRewardProvider),
            // WS7.child-ui: opens the child's prize redemption screen.
            onOpenRewards: () =>
                context.router.push(const ChildRedemptionRoute()),
          ),
          const SizedBox(height: 18),
        ],
        if (showAllCaughtUp)
          DashboardAllCaughtUpCard(
            doneDisplay: doneDisplay,
            cumulativeLifetime: cumulativeLifetime,
          )
        else
          DashboardLevelPointsCard(
            userMode: userMode,
            level: level,
            totalPoints: totalPoints,
            overdueCount: overdueCount,
            todayCount: todayCount,
            reviewCount: reviewCount,
            doneDisplay: doneDisplay,
            lifetimeSectionsDetail: sectionsDetail,
            cumulativeLifetime: cumulativeLifetime,
            chazaraLabel: chazaraBubbleLabel,
            tasksReady: tasksReady,
          ),
        const SizedBox(height: 30),
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.todaysMissions,
                style: _iosTextStyle(
                  context,
                  size: 28,
                  weight: FontWeight.w800,
                  color: AppTheme.brandInk,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.statusDanger.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.remaining(totalRemaining),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: AppColors.statusDanger,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        MainFocusMissionCard(
          count: todayCount,
          onTap: () {
            ref
                .read(schedulerTaskSectionProvider.notifier)
                .setSection(SchedulerTaskSection.today);
            context.router.push(const SchedulerRoute());
          },
        ),
        // Only render the chazara review card when at least one active track
        // has chazara stages enabled (Rule 8).
        if (chazaraReviewLabel != null) ...[
          const SizedBox(height: 14),
          CompactMissionCard(
            label: reviewSectionLabel,
            title: chazaraReviewLabel,
            count: reviewCount,
            color: AppTheme.brandGold,
            labelColor: AppTheme.brandGoldDeep,
            backgroundColor: const Color(0xFFF1F2F5),
            borderColor: const Color(0xFFD4D7DE),
            onTap: () {
              ref
                  .read(schedulerTaskSectionProvider.notifier)
                  .setSection(SchedulerTaskSection.review);
              context.router.push(const SchedulerRoute());
            },
          ),
        ],
        const SizedBox(height: 14),
        CompactMissionCard(
          label: l10n.urgent,
          title: l10n.missedOverdue,
          count: overdueCount,
          color: AppColors.statusError,
          labelColor: AppColors.statusError,
          titleColor: AppColors.statusError,
          borderColor: AppColors.statusError,
          dashedBorder: true,
          onTap: () {
            ref
                .read(schedulerTaskSectionProvider.notifier)
                .setSection(SchedulerTaskSection.overdue);
            context.router.push(const SchedulerRoute());
          },
        ),
        const SizedBox(height: 30),
        SizedBox(
          height: 460,
          child: ActiveTracksCarouselSection(
            title: l10n.activeTracks,
            subtitle: l10n.activeTracksSubtitle,
            activeTracks: activeTracks,
            allTasks: allTasks,
            titleStyle: _iosTextStyle(
              context,
              size: 28,
              weight: FontWeight.w800,
              color: AppTheme.brandInk,
            ),
          ),
        ),
        if (userMode == ProfileMode.child) ...[
          const SizedBox(height: 14),
          StreakRecoveryBanner(currentStreak: currentStreak),
        ],
      ],
    );
  }
}
