import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:learning_tracker/core/constants/hebrew_terms.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/hebrew_terms_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

CurriculumId _curriculumIdForTrack(CurriculumTrack track) {
  return CurriculumId.values.firstWhere(
    (c) => c.storageKey == track.curriculumId,
    orElse: () => CurriculumId.mishnayos,
  );
}

String _trackTypeLabel(String trackTypeStorageKey) {
  try {
    return TrackType.fromStorageKey(trackTypeStorageKey).displayNameEn;
  } on Object {
    return trackTypeStorageKey;
  }
}

/// Primary blue for active-track CTA (design spec).
const Color _kActiveTrackPrimaryBlue = Color(0xFF122FA0);

/// Green completion bar (self-paced card).
const Color _kActiveTrackCompletionGreen = Color(0xFF22C55E);

/// Grey pill behind next-task / current-focus content.
const Color _kActiveTrackFocusPillBg = Color(0xFFF1F2F5);

/// Lifetime bar on the “all caught up” dashboard stats card (design spec).
const Color _kAllCaughtUpProgressFill = Color(0xFFFFB775);

/// Child dashboard — points & rewards hero (design spec).
const Color _kChildRewardsCardBlueTop = Color(0xFF1E52D4);
const Color _kChildRewardsCardBlueDeep = Color(0xFF0E266F);
const Color _kChildRewardsProgressTrack = Color(0xFF0A1F55);
const Color _kChildRewardsProgressFill = Color(0xFF22C55E);

void _openSchedulerSection(
  BuildContext context,
  WidgetRef ref,
  SchedulerTaskSection section,
) {
  ref.read(schedulerTaskSectionProvider.notifier).setSection(section);
  context.router.push(const SchedulerRoute());
}

void _openProgressScreen(BuildContext context) {
  context.router.navigate(const ProgressRoute());
}

@RoutePage()
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTracksAsync = ref.watch(dashboardActiveTracksStreamProvider);
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
          child: activeTracksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) =>
                Center(child: Text(l10n.errorWithMessage(e.toString()))),
            data: (activeTracks) {
              final userMode = userModeAsync.asData?.value ?? UserMode.adult;
              final streakData = streakAsync.asData?.value;
              final currentStreak = streakData?.currentStreak ?? 0;
              final profileId = ref.watch(activeProfileIdProvider);

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dashboardActiveTracksStreamProvider);
                  ref.invalidate(dashboardUserModeProvider);
                  ref.invalidate(dashboardStreakProvider);
                  ref.invalidate(dashboardGlobalPointsProvider);
                  ref.invalidate(dashboardChildNextRewardProvider);
                  ref.invalidate(allDailyTasksProvider);
                  ref.invalidate(
                    lifetimeTotalsAcrossAllCurriculaProvider(profileId),
                  );
                  ref.invalidate(globalLifetimeCurriculaProvider(profileId));
                  ref.invalidate(trackDualProgressMetricsProvider(profileId));
                  for (final t in activeTracks) {
                    ref.invalidate(
                      dashboardTrackCompletionPercentageProvider(t.id),
                    );
                    final c = _curriculumIdForTrack(t);
                    ref.invalidate(dashboardLastCompletionProvider(c));
                    ref.invalidate(dashboardPaceStatusProvider(c));
                  }
                },
                child: _DashboardBody(
                  activeTracks: activeTracks,
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
  final List<CurriculumTrack> activeTracks;
  final UserMode userMode;
  final int currentStreak;
  final String? profileName;

  const _DashboardBody({
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
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  ({IconData icon, Color fg, Color bg}) _greetingChip() {
    final hour = DateTime.now().hour;
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
    final hebrewTerms = ref.watch(hebrewTermsScriptProvider);
    final reviewSectionLabel = hebrewTerms
        ? HebrewTerms.uiReviewSection
        : l10n.reviewSection;
    final chazaraReviewLabel = hebrewTerms
        ? HebrewTerms.uiChazaraReview
        : l10n.chazaraReview;
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

    if (activeTracks.isEmpty) {
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
          _ChildPointsRewardsTabCard(
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
          _DashboardAllCaughtUpCard(
            doneDisplay: doneDisplay,
            cumulativeLifetime: cumulativeLifetime,
          )
        else
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
          height: 460,
          child: _ActiveTracksCarouselSection(
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
          _StreakRecoveryBanner(currentStreak: currentStreak),
        ],
      ],
    );
  }
}

class _ChildPointsRewardsTabCard extends StatelessWidget {
  const _ChildPointsRewardsTabCard({
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
            color: AppTheme.brandBlue.withValues(alpha: 0.28),
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
                      _kChildRewardsCardBlueTop,
                      Color(0xFF1639A8),
                      _kChildRewardsCardBlueDeep,
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
                        backgroundColor: _kChildRewardsProgressTrack.withValues(
                          alpha: 0.85,
                        ),
                        color: _kChildRewardsProgressFill,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Center(
                    child: FilledButton(
                      onPressed: onOpenRewards,
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF1639A8),
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
                              color: const Color(0xFF1639A8),
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

/// Stats card when today due, overdue, and chazara counts are all zero.
class _DashboardAllCaughtUpCard extends StatelessWidget {
  const _DashboardAllCaughtUpCard({
    required this.doneDisplay,
    required this.cumulativeLifetime,
  });

  final String doneDisplay;
  final double cumulativeLifetime;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.brandBlue.withValues(alpha: 0.24),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1E52D4),
                      Color(0xFF1639A8),
                      Color(0xFF0E266F),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -14,
              child: Icon(
                Icons.menu_book_rounded,
                size: 172,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 34,
                        color: Color(0xFF1639A8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    l10n.dashboardAllCaughtUpTitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.dashboardAllCaughtUpSubtitle,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.dashboardLifetimeProgress,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Text(
                        doneDisplay,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _openProgressScreen(context),
                      borderRadius: BorderRadius.circular(999),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: AnimatedProgressBar(
                          value: cumulativeLifetime,
                          color: _kAllCaughtUpProgressFill,
                          backgroundColor: const Color(
                            0xFF0A1F4D,
                          ).withValues(alpha: 0.55),
                          height: 12,
                          duration: const Duration(milliseconds: 700),
                          curve: Curves.easeOutCubic,
                        ),
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

class _DashboardLevelPointsCard extends ConsumerWidget {
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

  static const List<SchedulerTaskSection> _bubbleSections = [
    SchedulerTaskSection.overdue,
    SchedulerTaskSection.today,
    SchedulerTaskSection.review,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final chazaraLabel = l10n.bubbleChazara;
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
                  child: _DashboardStatBubble(
                    label: bubbleData[i].$1,
                    value: bubbleData[i].$2,
                    valueColor: bubbleData[i].$3,
                    onTap: () =>
                        _openSchedulerSection(context, ref, _bubbleSections[i]),
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
              onTap: () => _openProgressScreen(context),
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

class _DashboardStatBubble extends StatelessWidget {
  const _DashboardStatBubble({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color valueColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Square bubbles sized to row width; FittedBox prevents bottom overflow
    // when the Done % or multi-line labels need more than a fixed 96px circle.
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Ink(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          color: valueColor,
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MainFocusMissionCard extends StatelessWidget {
  const _MainFocusMissionCard({required this.count, required this.onTap});

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
              Row(
                children: [
                  Text(
                    l10n.dueToday,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.brandBlue,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.brandBlue,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.brandBlue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.startLearning),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
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

class _ActiveTracksCarouselSection extends StatefulWidget {
  const _ActiveTracksCarouselSection({
    required this.title,
    required this.subtitle,
    required this.activeTracks,
    required this.allTasks,
    required this.titleStyle,
  });

  final String title;
  final String subtitle;
  final List<CurriculumTrack> activeTracks;
  final List<DailyTask> allTasks;
  final TextStyle titleStyle;

  @override
  State<_ActiveTracksCarouselSection> createState() =>
      _ActiveTracksCarouselSectionState();
}

class _ActiveTracksCarouselSectionState
    extends State<_ActiveTracksCarouselSection> {
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
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: widget.titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                      fontWeight: FontWeight.w500,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
              isEnabled: _activeIndex < widget.activeTracks.length - 1,
              onTap: _activeIndex < widget.activeTracks.length - 1
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
            itemCount: widget.activeTracks.length,
            onPageChanged: (value) {
              setState(() {
                _activeIndex = value;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _ActiveTrackCard(
                  track: widget.activeTracks[index],
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

class _TrackTaskBuckets {
  const _TrackTaskBuckets({
    required this.missedProgram,
    required this.dueTodayLane,
    required this.review,
  });

  /// Missed program days (non-review overdue), aligned with dashboard lanes.
  final int missedProgram;

  /// On-time program + new learning (not chazara).
  final int dueTodayLane;

  /// All chazara / review tasks for this track.
  final int review;

  int get total => missedProgram + dueTodayLane + review;
}

_TrackTaskBuckets _bucketTrackTasks(List<DailyTask> tasks) {
  var missedProgram = 0;
  var dueTodayLane = 0;
  var review = 0;

  bool isReview(DailyTask t) =>
      t.priority == DailyTaskPriority.overdueChazara ||
      t.priority == DailyTaskPriority.scheduledChazara;

  for (final t in tasks) {
    if (isReview(t)) {
      review++;
    } else if (t.isOverdue) {
      missedProgram++;
    } else {
      dueTodayLane++;
    }
  }

  return _TrackTaskBuckets(
    missedProgram: missedProgram,
    dueTodayLane: dueTodayLane,
    review: review,
  );
}

/// Task to highlight on the active-track card for calendar-linked programs.
///
/// [allTasks] is sorted with [DailyTaskPriority.overdueProgram] before
/// [DailyTaskPriority.todayProgram], so the first row is backlog — not
/// "today's" assignment. Prefer an explicit today row when present.
DailyTask? _programTrackFocusTask(List<DailyTask> tasks) {
  if (tasks.isEmpty) return null;
  for (final t in tasks) {
    if (t.priority == DailyTaskPriority.todayProgram) return t;
  }
  return tasks.first;
}

/// Active track card: program (task metrics) vs self-paced (completion) layouts.
class _ActiveTrackCard extends ConsumerWidget {
  final CurriculumTrack track;
  final List<DailyTask> allTasks;

  const _ActiveTrackCard({required this.track, required this.allTasks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final curriculum = _curriculumIdForTrack(track);
    final hebrewOnly = ref.watch(hebrewTermsScriptProvider);
    final displayNamePrimary =
        '${_trackTypeLabel(track.trackType)} · ${curriculum.displayNameHe}';
    final displayNameSecondary = hebrewOnly ? null : curriculum.displayNameEn;
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final bookIconBg = Color.lerp(
      _kActiveTrackPrimaryBlue.withValues(alpha: 0.2),
      curriculumColor.withValues(alpha: 0.2),
      0.45,
    )!;
    final completionAsync = ref.watch(
      dashboardTrackCompletionPercentageProvider(track.id),
    );
    final hasProgramEnrollmentAsync = ref.watch(
      dashboardHasProgramEnrollmentProvider(curriculum),
    );
    final percentage = completionAsync.asData?.value ?? 0.0;
    final pctDisplay = formatFractionAsPercent(percentage);
    final profileId = ref.watch(activeProfileIdProvider);
    final lifetimeSummariesAsync = ref.watch(
      globalLifetimeCurriculaProvider(profileId),
    );
    final lifetimeFraction = lifetimeSummariesAsync.when(
      data: (summaries) {
        for (final s in summaries) {
          if (s.curriculumId == curriculum) return s.percentage;
        }
        return 0.0;
      },
      loading: () => null,
      error: (_, __) => 0.0,
    );
    final lifetimePercentDisplay = lifetimeFraction == null
        ? '…'
        : formatFractionAsPercent(lifetimeFraction);

    final curriculumTasks = allTasks
        .where((t) => t.trackId == track.id)
        .toList();
    final hasProgramEnrollment =
        hasProgramEnrollmentAsync.asData?.value ?? false;
    final todayTask = hasProgramEnrollment
        ? _programTrackFocusTask(curriculumTasks)
        : (curriculumTasks.isNotEmpty ? curriculumTasks.first : null);
    final taskBuckets = _bucketTrackTasks(curriculumTasks);
    final focusLabel = hasProgramEnrollment
        ? l10n.activeTrackNextTask
        : l10n.activeTrackCurrentFocus;
    final focusRef = todayTask?.contentItemSefariaRef;
    // Renderer-driven: same path as reader, browse rows, daily task card.
    final focusValue = focusRef == null
        ? l10n.noProjection
        : (ref.watch(renderedDisplayForRefProvider(focusRef)).asData?.value ??
              focusRef);
    final lifetimeFull =
        lifetimeFraction != null && (lifetimeFraction - 1.0).abs() < 1e-6;

    return Card(
      elevation: 5,
      shadowColor: Colors.black26,
      surfaceTintColor: Colors.transparent,
      color: AppTheme.brandCreamCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          // Card-level tap: prefer the current-focus text when there is one
          // (matches the visible 'CURRENT FOCUS' label). Browse-tree fallback
          // only when nothing is scheduled.
          final focusRef = todayTask?.contentItemSefariaRef;
          if (focusRef != null && focusRef.isNotEmpty) {
            context.router.push(TextDisplayRoute(sefariaRef: focusRef));
          } else {
            context.router.push(
              ContentHierarchyRoute(curriculumId: curriculum.storageKey),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayNamePrimary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppTheme.brandInk,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (displayNameSecondary != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            displayNameSecondary,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandInk,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bookIconBg,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: _kActiveTrackPrimaryBlue,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _ActiveTrackFocusPill(label: focusLabel, value: focusValue),
              const SizedBox(height: 10),
              if (hasProgramEnrollment) ...[
                _ProgrammedTrackMetricsRow(
                  chazara: taskBuckets.review,
                  dueToday: taskBuckets.dueTodayLane,
                  overdue: taskBuckets.missedProgram,
                  l10n: l10n,
                  chazaraLabel: ref.watch(hebrewTermsScriptProvider)
                      ? HebrewTerms.uiActiveTrackChazara
                      : l10n.activeTrackMetricChazara,
                ),
                if (taskBuckets.total == 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l10n.nothingDueInQueue,
                      maxLines: 2,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                        height: 1.2,
                      ),
                    ),
                  ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      pctDisplay,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: AppTheme.brandInk,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      l10n.carouselCompletion,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppTheme.brandInkMuted,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                _ActiveTrackGreenProgress(value: percentage),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${l10n.trackLifetimeLearning} \u2022 $lifetimePercentDisplay',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.brandInkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (lifetimeFraction == null)
                          const SizedBox.shrink()
                        else
                          Icon(
                            lifetimeFull
                                ? Icons.check_circle_rounded
                                : Icons.show_chart_rounded,
                            size: 20,
                            color: lifetimeFull
                                ? _kActiveTrackCompletionGreen
                                : AppTheme.brandInkMuted,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () {
                        // If there's a concrete next-task / current focus,
                        // jump straight to its text — that's what the
                        // 'CURRENT FOCUS' label promised. Fall back to the
                        // Learn tab when there's nothing scheduled.
                        final focusRef = todayTask?.contentItemSefariaRef;
                        if (focusRef != null && focusRef.isNotEmpty) {
                          context.router.push(
                            TextDisplayRoute(sefariaRef: focusRef),
                          );
                        } else {
                          context.router.navigate(const LearningRoute());
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: _kActiveTrackPrimaryBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 48),
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.4,
                        ),
                      ),
                      child: Text(l10n.continueCta),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveTrackFocusPill extends StatelessWidget {
  const _ActiveTrackFocusPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kActiveTrackFocusPillBg,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: _kActiveTrackPrimaryBlue,
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.4,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppTheme.brandInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgrammedTrackMetricsRow extends StatelessWidget {
  const _ProgrammedTrackMetricsRow({
    required this.chazara,
    required this.dueToday,
    required this.overdue,
    required this.l10n,
    required this.chazaraLabel,
  });

  final int chazara;
  final int dueToday;
  final int overdue;
  final AppLocalizations l10n;
  final String chazaraLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: _ActiveTrackMetricBox(
            count: chazara,
            label: chazaraLabel,
            valueColor: chazara > 0
                ? const Color(0xFFB45309)
                : AppTheme.brandInk,
            valueBg: const Color(0xFFFFE7D1),
            labelStyle: theme.textTheme.labelSmall,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActiveTrackMetricBox(
            count: dueToday,
            label: l10n.activeTrackMetricDueToday,
            valueColor: dueToday > 0
                ? _kActiveTrackPrimaryBlue
                : AppTheme.brandInk,
            valueBg: const Color(0xFFDFE9FD),
            labelStyle: theme.textTheme.labelSmall,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActiveTrackMetricBox(
            count: overdue,
            label: l10n.activeTrackMetricOverdue,
            valueColor: const Color(0xFFD63C3C),
            valueBg: const Color(0xFFFFE0EB),
            labelStyle: theme.textTheme.labelSmall,
            countMutedWhenZero: true,
          ),
        ),
      ],
    );
  }
}

class _ActiveTrackMetricBox extends StatelessWidget {
  const _ActiveTrackMetricBox({
    required this.count,
    required this.label,
    required this.valueColor,
    required this.valueBg,
    required this.labelStyle,
    this.countMutedWhenZero = false,
  });

  final int count;
  final String label;
  final Color valueColor;
  final Color valueBg;
  final TextStyle? labelStyle;
  final bool countMutedWhenZero;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayColor = countMutedWhenZero && count == 0
        ? AppTheme.brandInk
        : valueColor;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      decoration: BoxDecoration(
        color: valueBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: displayColor,
              fontSize: 19,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: labelStyle?.copyWith(
              color: AppTheme.brandInkMuted,
              fontWeight: FontWeight.w800,
              fontSize: 9.5,
              height: 1.1,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActiveTrackGreenProgress extends StatelessWidget {
  const _ActiveTrackGreenProgress({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return AnimatedProgressBar(
      value: value.clamp(0.0, 1.0),
      color: _kActiveTrackCompletionGreen,
      backgroundColor: _kActiveTrackCompletionGreen.withValues(alpha: 0.22),
      height: 10,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
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
