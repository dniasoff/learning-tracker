import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/milestone_badge.dart';

@RoutePage()
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(
      dashboardActiveCurriculaStreamProvider,
    );
    final streakAsync = ref.watch(dashboardStreakProvider);
    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final globalPointsAsync = ref.watch(dashboardGlobalPointsProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final journeyAsync = ref.watch(journeyViewModelProvider(profileId));
    final trackMetricsAsync = ref.watch(trackDualProgressMetricsProvider(profileId));
    final overviewStatsAsync = ref.watch(progressOverviewStatsProvider);

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Progress')),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.brandCreamCard,
              AppTheme.brandBlueSoft.withValues(alpha: 0.2),
              AppTheme.brandCream,
            ],
          ),
        ),
        child: SafeArea(
          top: false,
          child: activeCurriculaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (activeCurricula) {
              if (activeCurricula.isEmpty) {
                return const EmptyState(
                  message: 'No progress yet',
                  subtitle: 'Start learning to see your progress here.',
                  icon: Icons.trending_up_outlined,
                );
              }

              final userMode = userModeAsync.asData?.value ?? UserMode.adult;
              final streakData = streakAsync.asData?.value;
              final currentStreak = streakData?.currentStreak ?? 0;
              final maxStreak = streakData?.maxStreak ?? 0;
              final totalPoints = globalPointsAsync.asData?.value ?? 0;
              final journey = journeyAsync.asData?.value;
            final overviewStats = overviewStatsAsync.asData?.value;
            final totalCompletions =
                overviewStats?.totalCompletions ?? journey?.totalCompletions ?? 0;
            final totalUniqueUnits =
                overviewStats?.totalUniqueItems ?? journey?.totalUniqueUnits ?? 0;
              final trackMetrics = trackMetricsAsync.asData?.value ?? const <TrackDualProgressMetric>[];

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dashboardActiveCurriculaStreamProvider);
                  ref.invalidate(dashboardStreakProvider);
                  if (userMode == UserMode.child) {
                    ref.invalidate(dashboardGlobalPointsProvider);
                  }
                  ref.invalidate(progressOverviewStatsProvider);
                  ref.invalidate(journeyViewModelProvider(profileId));
                  for (final c in activeCurricula) {
                    ref.invalidate(dashboardCompletionPercentageProvider(c));
                  }
                },
                child: userMode == UserMode.child
                    ? _ChildProgressView(
                        currentStreak: currentStreak,
                        maxStreak: maxStreak,
                        totalCompletions: totalCompletions,
                        totalUniqueUnits: totalUniqueUnits,
                        totalPoints: totalPoints,
                        activeCurricula: activeCurricula,
                        journey: journey,
                        trackMetrics: trackMetrics,
                      )
                    : _AdultProgressView(
                        totalCompletions: totalCompletions,
                        totalUniqueUnits: totalUniqueUnits,
                        activeCurricula: activeCurricula,
                        currentStreak: currentStreak,
                        maxStreak: maxStreak,
                        trackMetrics: trackMetrics,
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ChildProgressView extends StatelessWidget {
  const _ChildProgressView({
    required this.currentStreak,
    required this.maxStreak,
    required this.totalCompletions,
    required this.totalUniqueUnits,
    required this.totalPoints,
    required this.activeCurricula,
    required this.journey,
    required this.trackMetrics,
  });

  final int currentStreak;
  final int maxStreak;
  final int totalCompletions;
  final int totalUniqueUnits;
  final int totalPoints;
  final List<CurriculumId> activeCurricula;
  final JourneyViewModel? journey;
  final List<TrackDualProgressMetric> trackMetrics;

  @override
  Widget build(BuildContext context) {
    final totalPercentage = totalUniqueUnits > 0
        ? (totalCompletions / totalUniqueUnits * 100)
        : 0.0;
    final allMilestones = <MilestoneAchievement>[];
    if (journey != null) {
      for (final curr in journey!.curricula) {
        allMilestones.addAll(curr.milestones);
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _CompletionRingWidget(
          percentage: totalPercentage,
          completions: totalCompletions,
          total: totalUniqueUnits,
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                backgroundColor: AppTheme.childPointsAccent,
                icon: Icons.star,
                value: totalPoints.toString(),
                label: 'Total Points',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                backgroundColor: AppTheme.childStreakAccent,
                icon: Icons.local_fire_department,
                value: '$maxStreak',
                label: 'Best Streak',
                sublabel: 'days',
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SiyumBanner(
          siyumCount: allMilestones
              .where((m) => m.type == 'curriculum_complete')
              .length,
          onViewAll: () => context.router.push(const GamificationRoute()),
        ),
        const SizedBox(height: 20),
        _CurriculaMasterySection(activeCurricula: activeCurricula),
        if (trackMetrics.isNotEmpty) ...[
          const SizedBox(height: 20),
          _TrackViewSection(trackMetrics: trackMetrics),
        ],
        const SizedBox(height: 20),
        if (allMilestones.isNotEmpty)
          _RecentAchievementsRow(
            milestones: allMilestones,
            onSeeAll: () => context.router.push(const GamificationRoute()),
          ),
      ],
    );
  }
}

class _AdultProgressView extends StatelessWidget {
  const _AdultProgressView({
    required this.totalCompletions,
    required this.totalUniqueUnits,
    required this.activeCurricula,
    required this.currentStreak,
    required this.maxStreak,
    required this.trackMetrics,
  });

  final int totalCompletions;
  final int totalUniqueUnits;
  final List<CurriculumId> activeCurricula;
  final int currentStreak;
  final int maxStreak;
  final List<TrackDualProgressMetric> trackMetrics;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Overview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _StatItem(
                        icon: Icons.check_circle,
                        iconColor: Theme.of(context).colorScheme.primary,
                        value: '$totalCompletions',
                        label: 'Completions',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.auto_stories,
                        iconColor: AppTheme.brandBlue,
                        value: '$totalUniqueUnits',
                        label: 'Units Done',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.local_fire_department,
                        iconColor: AppTheme.brandGold,
                        value: '$currentStreak / $maxStreak',
                        label: 'Current / Best Streak',
                      ),
                    ),
                    Expanded(
                      child: _StatItem(
                        icon: Icons.menu_book,
                        iconColor: AppTheme.brandCoral,
                        value: '${activeCurricula.length}',
                        label: 'Active Tracks',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        const _QuickAccessSection(),
        const SizedBox(height: 20),
        if (trackMetrics.isNotEmpty) ...[
          _TrackViewSection(trackMetrics: trackMetrics),
          const SizedBox(height: 20),
        ],
        _CurriculaMasterySection(activeCurricula: activeCurricula),
      ],
    );
  }
}

class _TrackViewSection extends StatelessWidget {
  const _TrackViewSection({required this.trackMetrics});

  final List<TrackDualProgressMetric> trackMetrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.route, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Track View',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Current cycle progress and lifetime curriculum coverage per track.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < trackMetrics.length; i++) ...[
              _TrackDualMetricRow(metric: trackMetrics[i]),
              if (i < trackMetrics.length - 1) const Divider(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrackDualMetricRow extends StatelessWidget {
  const _TrackDualMetricRow({required this.metric});

  final TrackDualProgressMetric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          metric.trackLabel,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 2),
        Text(
          metric.isProgramTrack
              ? 'Program track • ${metric.curriculumId.displayNameHe}'
              : 'Self-paced track • ${metric.curriculumId.displayNameHe}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        _PercentageBar(
          title: 'Current Cycle',
          percentage: metric.currentCyclePercentage,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 8),
        _PercentageBar(
          title: 'Lifetime Curriculum',
          percentage: metric.lifetimePercentage,
          color: AppTheme.brandGold,
        ),
      ],
    );
  }
}

class _PercentageBar extends StatelessWidget {
  const _PercentageBar({
    required this.title,
    required this.percentage,
    required this.color,
  });

  final String title;
  final double percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(title, style: theme.textTheme.bodySmall),
            ),
            Text(
              formatFractionAsPercent(percentage),
              style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: percentage.clamp(0.0, 1.0),
          minHeight: 8,
          borderRadius: BorderRadius.circular(8),
          color: color,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
        ),
      ],
    );
  }
}

class _CompletionRingWidget extends StatelessWidget {
  const _CompletionRingWidget({
    required this.percentage,
    required this.completions,
    required this.total,
  });

  final double percentage;
  final int completions;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentageText = formatPercentValue(percentage);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 180,
                  height: 180,
                  child: CircularProgressIndicator(
                    value: percentage / 100,
                    strokeWidth: 12,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppTheme.childPrimary,
                    ),
                    backgroundColor: AppTheme.childOutline,
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      percentageText,
                      style: theme.textTheme.displaySmall?.copyWith(
                        color: AppTheme.childPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text('Complete', style: theme.textTheme.labelMedium),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'You\'ve completed $completions of $total units',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.backgroundColor,
    required this.icon,
    required this.value,
    required this.label,
    this.sublabel,
  });

  final Color backgroundColor;
  final IconData icon;
  final String value;
  final String label;
  final String? sublabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [backgroundColor, backgroundColor.withValues(alpha: 0.82)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.brandCreamCard, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: AppTheme.brandCreamCard,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppTheme.brandCreamCard.withValues(alpha: 0.7),
            ),
            textAlign: TextAlign.center,
          ),
          if (sublabel != null) ...[
            const SizedBox(height: 2),
            Text(
              sublabel!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.brandCreamCard.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SiyumBanner extends StatelessWidget {
  const _SiyumBanner({required this.siyumCount, required this.onViewAll});

  final int siyumCount;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.childTrophyAccent, AppTheme.brandGoldDeep],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.emoji_events, color: AppTheme.brandCreamCard, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$siyumCount ${siyumCount == 1 ? 'Siyum' : 'Siyums'}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: AppTheme.brandCreamCard,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Completion celebrations',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppTheme.brandCreamCard.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          TextButton(onPressed: onViewAll, child: const Text('View All')),
        ],
      ),
    );
  }
}

class _RecentAchievementsRow extends StatelessWidget {
  const _RecentAchievementsRow({
    required this.milestones,
    required this.onSeeAll,
  });

  final List<MilestoneAchievement> milestones;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Achievements',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton(onPressed: onSeeAll, child: const Text('See All')),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              ...milestones.take(5).map((m) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: MilestoneBadge(milestone: m),
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurriculaMasterySection extends ConsumerWidget {
  const _CurriculaMasterySection({required this.activeCurricula});

  final List<CurriculumId> activeCurricula;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Curriculum Mastery',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...activeCurricula.map(
          (curriculum) => _CurriculumProgressTile(curriculum: curriculum),
        ),
      ],
    );
  }
}

class _CurriculumProgressTile extends ConsumerWidget {
  const _CurriculumProgressTile({required this.curriculum});

  final CurriculumId curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final completionAsync = ref.watch(
      dashboardCompletionPercentageProvider(curriculum),
    );
    final percentage = completionAsync.asData?.value ?? 0.0;
    final aggregateCountAsync = ref.watch(
      aggregateCountProvider(curriculum.storageKey),
    );
    final count = aggregateCountAsync.asData?.value ?? 0;
    final percentageText = formatFractionAsPercent(percentage);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.router.push(
            CurriculumProgressRoute(curriculumId: curriculum.storageKey),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: curriculumColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      curriculum.displayNameHe,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: percentage,
                        minHeight: 6,
                        backgroundColor: curriculumColor.withValues(
                          alpha: 0.15,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          curriculumColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$percentageText • $count completions',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAccessSection extends StatelessWidget {
  const _QuickAccessSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detailed Views', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const Icon(Icons.bar_chart, color: AppTheme.brandBlueDeep),
            title: const Text('Progress Charts'),
            subtitle: const Text('Completions, trends, streak calendar'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.router.push(const ProgressChartsRoute()),
          ),
        ),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
