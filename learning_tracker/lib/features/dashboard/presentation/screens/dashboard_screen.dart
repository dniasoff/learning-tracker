import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/models/pace_status.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(
      dashboardActiveCurriculaStreamProvider,
    );
    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final selectedProfileAsync = ref.watch(selectedProfileProvider);
    final profileName = selectedProfileAsync.asData?.value?.displayName;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.22),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: activeCurriculaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) =>
                Center(child: Text(l10n.errorWithMessage(e.toString()))),
            data: (activeCurricula) {
              final userMode = userModeAsync.asData?.value ?? UserMode.adult;
              final streakData = streakAsync.asData?.value;
              final currentStreak = streakData?.currentStreak ?? 0;
              final profileId = ref.watch(activeProfileIdProvider);

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dashboardActiveCurriculaStreamProvider);
                  ref.invalidate(dashboardUserModeProvider);
                  ref.invalidate(dashboardStreakProvider);
                  ref.invalidate(dashboardGlobalPointsProvider);
                  ref.invalidate(dashboardChildNextRewardProvider);
                  ref.invalidate(allDailyTasksProvider);
                  ref.invalidate(
                    lifetimeTotalsAcrossAllCurriculaProvider(profileId),
                  );
                  ref.invalidate(globalLifetimeCurriculaProvider(profileId));
                  for (final c in activeCurricula) {
                    ref.invalidate(dashboardCompletionPercentageProvider(c));
                    ref.invalidate(dashboardLastCompletionProvider(c));
                    ref.invalidate(dashboardPaceStatusProvider(c));
                  }
                },
                child: _DashboardBody(
                  activeCurricula: activeCurricula,
                  userMode: userMode,
                  currentStreak: currentStreak,
                  profileName: profileName,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final List<CurriculumId> activeCurricula;
  final UserMode userMode;
  final int currentStreak;
  final String? profileName;

  const _DashboardBody({
    required this.activeCurricula,
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
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
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
    final name = profileName ?? l10n.learner;
    final now = DateTime.now();

    final totalPoints = globalPointsAsync.asData?.value ?? 0;
    final allTasks = dailyTasksAsync.asData?.value ?? const <DailyTask>[];
    final lifetimeTotals = lifetimeTotalsAsync.asData?.value;
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

    if (activeCurricula.isEmpty) {
      final isChildMode =
          ref.watch(selectedProfileProvider).asData?.value?.mode == 'child';
      return _EmptyDashboard(
        name: name,
        greeting: _greeting(l10n),
        isChildMode: isChildMode,
      );
    }

    final groupedTasks = _groupTasks(allTasks);
    final todayCount = groupedTasks.todayTasks.length;
    final overdueCount = groupedTasks.overdueTasks.length;
    final reviewCount = groupedTasks.reviewTasks.length;
    final totalRemaining = todayCount + overdueCount + reviewCount;
    final level = (1 + (cumulativeLifetime * 19)).clamp(1, 20).round();
    final doneDisplay = lifetimePercentStr;
    final sectionsDetail = lifetimeSectionsStr;

    final focusLabel = groupedTasks.todayTasks.isNotEmpty
        ? groupedTasks.todayTasks
              .take(2)
              .map((t) => t.curriculumId.displayNameEn.toUpperCase())
              .join(' / ')
        : l10n.noFocusTag;

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
                  Text(
                    l10n.greetingHelloName(name),
                    style: _iosTextStyle(
                      context,
                      size: 27,
                      weight: FontWeight.w800,
                      color: AppTheme.brandInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
          _ChildTotalPointsPill(
            totalPoints: totalPoints,
            l10n: l10n,
            numberFormat: numberFormat,
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.dashboardRewardsGallery,
                    style: _iosTextStyle(
                      context,
                      size: 22,
                      weight: FontWeight.w800,
                      color: AppTheme.brandInk,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      context.router.push(const GamificationRoute()),
                  child: Text(
                    l10n.dashboardSeeAllRewards,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppTheme.brandBlueBright,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _ChildMysteryChestCard(
            nextRewardAsync: ref.watch(dashboardChildNextRewardProvider),
            globalPointsFallback: totalPoints,
            l10n: l10n,
            theme: theme,
            numberFormat: numberFormat,
            onOpenRewards: () => context.router.push(const GamificationRoute()),
          ),
          const SizedBox(height: 12),
        ],
        _DashboardLevelPointsCard(
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
        _MainFocusMissionCard(
          title: l10n.todaysTasks,
          subtitle: groupedTasks.todayTasks.isNotEmpty
              ? groupedTasks.todayTasks
                    .take(2)
                    .map((t) => t.curriculumId.displayNameEn)
                    .join(' / ')
              : l10n.noTasksInLane,
          focusLabel: focusLabel,
          count: todayCount,
          onTap: () {
            ref
                .read(schedulerTaskSectionProvider.notifier)
                .setSection(SchedulerTaskSection.today);
            context.router.push(const SchedulerRoute());
          },
        ),
        const SizedBox(height: 14),
        _CompactMissionCard(
          label: l10n.reviewSection,
          title: l10n.chazaraReview,
          count: reviewCount,
          color: AppTheme.brandGold,
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
        _CompactMissionCard(
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
          height: 320,
          child: _CurriculaCarouselSection(
            title: l10n.activeCurricula,
            activeCurricula: activeCurricula,
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
          _StreakRecoveryBanner(currentStreak: currentStreak),
        ],
      ],
    );
  }
}

class _ChildTotalPointsPill extends StatelessWidget {
  const _ChildTotalPointsPill({
    required this.totalPoints,
    required this.l10n,
    required this.numberFormat,
  });

  final int totalPoints;
  final AppLocalizations l10n;
  final NumberFormat numberFormat;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.brandBlueDeep, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandBlue.withValues(alpha: 0.1),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: const BoxDecoration(
              color: Color(0xFFFFD54F),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.totalPoints.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandBlueDeep,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l10n.dashboardPointsValue(numberFormat.format(totalPoints)),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildMysteryChestCard extends StatelessWidget {
  const _ChildMysteryChestCard({
    required this.nextRewardAsync,
    required this.globalPointsFallback,
    required this.l10n,
    required this.theme,
    required this.numberFormat,
    required this.onOpenRewards,
  });

  final AsyncValue<DashboardChildNextReward?> nextRewardAsync;
  final int globalPointsFallback;
  final AppLocalizations l10n;
  final ThemeData theme;
  final NumberFormat numberFormat;
  final VoidCallback onOpenRewards;

  @override
  Widget build(BuildContext context) {
    return nextRewardAsync.when(
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (next) {
        const defaultThreshold = 1500;
        final threshold = next?.threshold ?? defaultThreshold;
        final progressPoints = next?.trackPoints ?? globalPointsFallback;
        final pct = threshold > 0
            ? (progressPoints / threshold).clamp(0.0, 1.0)
            : 0.0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenRewards,
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF3949AB), Color(0xFF1A237E)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.card_giftcard_rounded,
                        color: Color(0xFFFFD54F),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      l10n.dashboardMysteryChest,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.dashboardTapToUnlockAtPts(
                        numberFormat.format(threshold),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.7,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 7,
                        backgroundColor: Colors.white.withValues(alpha: 0.22),
                        color: const Color(0xFF66BB6A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DashboardLevelPointsCard extends StatelessWidget {
  const _DashboardLevelPointsCard({
    required this.userMode,
    required this.level,
    required this.totalPoints,
    required this.overdueCount,
    required this.todayCount,
    required this.reviewCount,
    required this.doneDisplay,
    required this.lifetimeSectionsDetail,
    required this.cumulativeLifetime,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final bubbleData = userMode == UserMode.child
        ? [
            (l10n.bubbleOverdue, '$overdueCount', Colors.white),
            (l10n.bubbleTodayDue, '$todayCount', Colors.white),
            (l10n.dashboardBubbleDone, doneDisplay, const Color(0xFF76F4A7)),
          ]
        : [
            (l10n.bubbleOverdue, '$overdueCount', Colors.white),
            (l10n.bubbleTodayDue, '$todayCount', Colors.white),
            (l10n.bubbleChazara, '$reviewCount', const Color(0xFF76F4A7)),
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
                  child: _DashboardStatBubble(
                    label: bubbleData[i].$1,
                    value: bubbleData[i].$2,
                    valueColor: bubbleData[i].$3,
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
          ClipRRect(
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
        ],
      ),
    );
  }
}

class _DashboardStatBubble extends StatelessWidget {
  const _DashboardStatBubble({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 96,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              height: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w800,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _MainFocusMissionCard extends StatelessWidget {
  const _MainFocusMissionCard({
    required this.title,
    required this.subtitle,
    required this.focusLabel,
    required this.count,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String focusLabel;
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.brandOutline.withValues(alpha: 0.65),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandInk.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.mainFocus,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '$count',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 50,
                      color: AppTheme.brandBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(
                      focusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brandCoralDeep,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 42,
                child: FilledButton(
                  onPressed: onTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.brandBlue,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 42),
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(l10n.startLearning),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactMissionCard extends StatelessWidget {
  const _CompactMissionCard({
    required this.label,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
    this.backgroundColor,
    this.borderColor,
    this.labelColor,
    this.titleColor,
    this.dashedBorder = false,
  });

  final String label;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? labelColor;
  final Color? titleColor;
  final bool dashedBorder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget content = Ink(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(20),
        border: dashedBorder
            ? null
            : Border.all(
                color:
                    borderColor ??
                    AppTheme.brandOutline.withValues(alpha: 0.45),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: labelColor ?? AppTheme.brandInkMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '$count',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 36,
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (dashedBorder) {
      content = CustomPaint(
        painter: _DashedRoundedBorderPainter(
          color: borderColor ?? theme.colorScheme.error,
          borderRadius: 20,
          strokeWidth: 1.3,
        ),
        child: content,
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class _CurriculaCarouselSection extends StatefulWidget {
  const _CurriculaCarouselSection({
    required this.title,
    required this.activeCurricula,
    required this.allTasks,
    required this.titleStyle,
  });

  final String title;
  final List<CurriculumId> activeCurricula;
  final List<DailyTask> allTasks;
  final TextStyle titleStyle;

  @override
  State<_CurriculaCarouselSection> createState() =>
      _CurriculaCarouselSectionState();
}

class _CurriculaCarouselSectionState extends State<_CurriculaCarouselSection> {
  late final PageController _controller;
  int _activeIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: widget.titleStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            _ArrowButton(
              icon: Icons.chevron_left_rounded,
              isEnabled: _activeIndex > 0,
              onTap: _activeIndex > 0
                  ? () {
                      _controller.previousPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  : null,
            ),
            const SizedBox(width: 6),
            _ArrowButton(
              icon: Icons.chevron_right_rounded,
              isEnabled: _activeIndex < widget.activeCurricula.length - 1,
              onTap: _activeIndex < widget.activeCurricula.length - 1
                  ? () {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                      );
                    }
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 14),
        Expanded(
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.activeCurricula.length,
            onPageChanged: (value) {
              setState(() {
                _activeIndex = value;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _CurriculumCard(
                  curriculum: widget.activeCurricula[index],
                  allTasks: widget.allTasks,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.isEnabled,
    required this.onTap,
  });

  final IconData icon;
  final bool isEnabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isEnabled
              ? AppTheme.brandCreamSoft
              : AppTheme.brandCreamSoft.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Icon(
          icon,
          size: 32,
          color: isEnabled ? AppTheme.brandInk : AppTheme.brandInkMuted,
        ),
      ),
    );
  }
}

class _DashedRoundedBorderPainter extends CustomPainter {
  _DashedRoundedBorderPainter({
    required this.color,
    required this.borderRadius,
    required this.strokeWidth,
  });

  final Color color;
  final double borderRadius;
  final double strokeWidth;
  static const double _dashWidth = 6;
  static const double _dashGap = 4;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(borderRadius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final end = (distance + _dashWidth).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, end), paint);
        distance += _dashWidth + _dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _DashboardTaskGroups {
  const _DashboardTaskGroups({
    required this.todayTasks,
    required this.overdueTasks,
    required this.reviewTasks,
  });

  final List<DailyTask> todayTasks;
  final List<DailyTask> overdueTasks;
  final List<DailyTask> reviewTasks;
}

_DashboardTaskGroups _groupTasks(List<DailyTask> tasks) {
  final todayTasks = <DailyTask>[];
  final overdueTasks = <DailyTask>[];
  final reviewTasks = <DailyTask>[];

  bool isReview(DailyTask task) =>
      task.priority == DailyTaskPriority.overdueChazara ||
      task.priority == DailyTaskPriority.scheduledChazara;

  for (final task in tasks) {
    if (isReview(task)) {
      reviewTasks.add(task);
      continue;
    }

    if (task.isOverdue) {
      overdueTasks.add(task);
      continue;
    }

    todayTasks.add(task);
  }

  return _DashboardTaskGroups(
    todayTasks: todayTasks,
    overdueTasks: overdueTasks,
    reviewTasks: reviewTasks,
  );
}

/// AC-1, 2, 6: Curriculum card with pace badge and real task data.
class _CurriculumCard extends ConsumerWidget {
  final CurriculumId curriculum;
  final List<DailyTask> allTasks;

  const _CurriculumCard({required this.curriculum, required this.allTasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final displayNamePrimary = curriculum.displayNameHe;
    final displayNameSecondary = curriculum.displayNameEn;
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final completionAsync = ref.watch(
      dashboardCompletionPercentageProvider(curriculum),
    );
    final hasProgramEnrollmentAsync = ref.watch(
      dashboardHasProgramEnrollmentProvider(curriculum),
    );
    final paceAsync = ref.watch(dashboardPaceStatusProvider(curriculum));
    final percentage = completionAsync.asData?.value ?? 0.0;
    final pctDisplay = formatFractionAsPercent(percentage);
    final profileId = ref.watch(activeProfileIdProvider);
    ref.watch(globalLifetimeCurriculaProvider(profileId));

    // AC-6: Compute per-curriculum task count and today's study item
    final curriculumTasks = allTasks
        .where((t) => t.curriculumId == curriculum)
        .toList();
    final todayTask = curriculumTasks.isNotEmpty ? curriculumTasks.first : null;
    final hasProgramEnrollment =
        hasProgramEnrollmentAsync.asData?.value ?? false;

    // AC-1: Get pace status
    final paceStatus = paceAsync.asData?.value;

    // Count overdue and today tasks for programmed tracks
    final overdueTasks = curriculumTasks.where((t) => t.isOverdue).length;
    final todayTasks = curriculumTasks.where((t) => !t.isOverdue).length;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: AppTheme.brandOutline.withValues(alpha: 0.4)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          context.router.push(
            ContentHierarchyRoute(curriculumId: curriculum.storageKey),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: curriculumColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: curriculumColor,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      displayNamePrimary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (hasProgramEnrollment)
                    // Show task counts for programmed tracks
                    if (paceAsync.isLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: curriculumColor.withValues(alpha: 0.5),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.brandCreamSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: _MiniPaceBadge(paceStatus: paceStatus),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (overdueTasks > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFD63C3C,
                                    ).withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$overdueTasks overdue',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: const Color(0xFFD63C3C),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                )
                              else if (todayTasks > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.brandBlue.withValues(
                                      alpha: 0.14,
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '$todayTasks today',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.brandBlue,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      )
                  else
                  // Show pace badge for self-paced tracks
                  if (paceAsync.isLoading)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: curriculumColor.withValues(alpha: 0.5),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.brandCreamSoft,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: _MiniPaceBadge(paceStatus: paceStatus),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                displayNameSecondary,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                todayTask?.contentItemSefariaRef ?? l10n.noProjection,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              if (hasProgramEnrollment)
                _ProgrammedDueFoot(
                  overdueTasks: overdueTasks,
                  todayTasks: todayTasks,
                  l10n: l10n,
                )
              else ...[
                Row(
                  children: [
                    Text(
                      l10n.carouselCompletion,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      pctDisplay,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AnimatedProgressBar(
                  value: percentage,
                  color: curriculumColor,
                  backgroundColor: AppTheme.brandCreamSoft,
                  height: 10,
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                ),
              ],
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () =>
                          context.router.navigate(const LearningRoute()),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(double.infinity, 34),
                        padding: EdgeInsets.zero,
                        backgroundColor: const Color(0xFFE4E8F0),
                        foregroundColor: AppTheme.brandBlue,
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(l10n.continueCta),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Footer for programmed tracks: overdue vs due today (not leaf completion %).
class _ProgrammedDueFoot extends StatelessWidget {
  const _ProgrammedDueFoot({
    required this.overdueTasks,
    required this.todayTasks,
    required this.l10n,
  });

  final int overdueTasks;
  final int todayTasks;
  final AppLocalizations l10n;

  static const _overdueColor = Color(0xFFD63C3C);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalDue = overdueTasks + todayTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.tabSchedule,
          style: theme.textTheme.labelSmall?.copyWith(
            color: AppTheme.brandInkMuted,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: overdueTasks > 0
                      ? _overdueColor.withValues(alpha: 0.1)
                      : AppTheme.brandCreamSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.overdue,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Text(
                      '$overdueTasks',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: overdueTasks > 0
                            ? _overdueColor
                            : AppTheme.brandInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: BoxDecoration(
                  color: todayTasks > 0
                      ? AppTheme.brandBlue.withValues(alpha: 0.1)
                      : AppTheme.brandCreamSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.dueToday,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    Text(
                      '$todayTasks',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: todayTasks > 0
                            ? AppTheme.brandBlue
                            : AppTheme.brandInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (totalDue == 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.nothingDueInQueue,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.brandInkMuted,
                height: 1.2,
              ),
            ),
          ),
      ],
    );
  }
}

/// Compact pace badge for the curriculum card header.
class _MiniPaceBadge extends StatelessWidget {
  const _MiniPaceBadge({required this.paceStatus});

  final PaceStatus? paceStatus;

  @override
  Widget build(BuildContext context) {
    if (paceStatus == null) return const SizedBox.shrink();

    final (label, color, icon) = switch (paceStatus!.status) {
      PaceStatusType.ahead => (
        '${paceStatus!.daysDelta}d',
        AppTheme.brandGold,
        Icons.trending_up,
      ),
      PaceStatusType.behind => (
        '${paceStatus!.daysDelta.abs()}d',
        AppTheme.brandCoralDeep,
        Icons.trending_down,
      ),
      PaceStatusType.onPace => ('OK', AppTheme.brandBlue, Icons.trending_flat),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _StreakRecoveryBanner extends ConsumerWidget {
  final int currentStreak;

  const _StreakRecoveryBanner({required this.currentStreak});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final recoveryAsync = ref.watch(dashboardStreakRecoveryProvider);
    return recoveryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (info) {
        if (!info.wasRecovered) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            color: AppTheme.brandCoral.withValues(alpha: 0.15),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(
                    Icons.shield,
                    color: AppTheme.brandCoral,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.streakRecovery(info.currentStreak),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.brandCoral,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyDashboard extends StatelessWidget {
  final String name;
  final String greeting;
  final bool isChildMode;

  const _EmptyDashboard({
    required this.name,
    required this.greeting,
    required this.isChildMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final accent = theme.colorScheme.primary;
    final onSurface = theme.colorScheme.onSurface;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$greeting,',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: onSurface.withValues(alpha: 0.7),
              ),
            ),
            Text(
              name,
              style: theme.textTheme.headlineMedium?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withValues(alpha: 0.2),
                    accent.withValues(alpha: 0.05),
                  ],
                ),
                border: Border.all(color: accent.withValues(alpha: 0.3)),
              ),
              child: Icon(Icons.menu_book_rounded, color: accent, size: 40),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.noTracksYet,
              style: theme.textTheme.titleLarge?.copyWith(
                color: onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isChildMode ? l10n.askGrownUpToAddTrack : l10n.firstTrackPrompt,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
            if (!isChildMode) ...[
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => context.router.push(
                    TrackManagementHubRoute(startAdding: true),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addTrack),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
