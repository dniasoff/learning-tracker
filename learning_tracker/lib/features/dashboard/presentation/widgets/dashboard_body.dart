import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
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
import 'package:learning_tracker/features/dashboard/presentation/widgets/streak_recovery_banner.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

class DashboardBody extends ConsumerWidget {
  final List<CurriculumTrack> activeTracks;
  final UserMode userMode;
  final int currentStreak;
  final String? profileName;

  const DashboardBody({
    super.key,
    required this.activeTracks,
    required this.userMode,
    required this.currentStreak,
    this.profileName,
  });

  static const _months = [
    '',
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

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

  String _formatDashboardDate(DateTime date) {
    return '${_months[date.month]} ${date.day}, ${date.year}';
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
    final globalPointsAsync = ref.watch(dashboardGlobalPointsProvider);
    final lifetimeTotalsAsync = ref.watch(
      lifetimeTotalsAcrossAllCurriculaProvider(profileId),
    );
    final useHebrew = ref.watch(useHebrewTermsProvider);
    final reviewSectionLabel = useHebrew
        ? HebrewTerms.uiReviewSection
        : l10n.reviewSection;
    final chazaraReviewLabel = useHebrew
        ? HebrewTerms.uiChazaraReview
        : l10n.chazaraReview;
    final name = profileName ?? l10n.learner;
    final now = DateTimeFactory.nowLocal();

    final totalPoints = globalPointsAsync.hasValue ? globalPointsAsync.value : 0;
    final allTasks = dailyTasksAsync.hasValue
        ? dailyTasksAsync.value
        : const <DailyTask>[];
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
          ref.watch(selectedProfileProvider).asData?.value?.mode == 'child';
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

    final tasksReady = dailyTasksAsync.hasValue;
    final lifetimeReady = lifetimeTotalsAsync.hasValue;
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
                    _formatDashboardDate(now),
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
                color: const Color(0xFFF26666),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF26666).withValues(alpha: 0.28),
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
        const SizedBox(height: 24),
        if (userMode == UserMode.child) ...[
          ChildPointsRewardsTabCard(
            totalPoints: totalPoints,
            l10n: l10n,
            theme: theme,
            numberFormat: numberFormat,
            nextRewardAsync: ref.watch(dashboardChildNextRewardProvider),
            onOpenRewards: () => context.router.push(const GamificationRoute()),
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
                color: const Color(0xFFF26666).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                l10n.remaining(totalRemaining),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFFF26666),
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
        const SizedBox(height: 14),
        CompactMissionCard(
          label: l10n.urgent,
          title: l10n.missedOverdue,
          count: overdueCount,
          color: const Color(0xFFD63C3C),
          labelColor: const Color(0xFFD63C3C),
          titleColor: const Color(0xFFD63C3C),
          borderColor: const Color(0xFFD63C3C),
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
        if (userMode == UserMode.child) ...[
          const SizedBox(height: 14),
          StreakRecoveryBanner(currentStreak: currentStreak),
        ],
      ],
    );
  }
}
