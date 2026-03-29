import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_bar_title.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';

@RoutePage()
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(dashboardActiveCurriculaProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final globalPointsAsync = ref.watch(dashboardGlobalPointsProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final journeyAsync = ref.watch(journeyViewModelProvider(profileId));

    return Scaffold(
      appBar: AppBar(title: const AppBarTitle(text: 'Progress')),
      body: SafeArea(
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
            final totalCompletions = journey?.totalCompletions ?? 0;
            final totalUniqueUnits = journey?.totalUniqueUnits ?? 0;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardActiveCurriculaProvider);
                ref.invalidate(dashboardStreakProvider);
                ref.invalidate(dashboardGlobalPointsProvider);
                ref.invalidate(journeyViewModelProvider(profileId));
                for (final c in activeCurricula) {
                  ref.invalidate(dashboardCompletionPercentageProvider(c));
                }
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _OverviewStatsRow(
                    currentStreak: currentStreak,
                    maxStreak: maxStreak,
                    totalCompletions: totalCompletions,
                    totalUniqueUnits: totalUniqueUnits,
                    totalPoints: totalPoints,
                    userMode: userMode,
                  ),
                  const SizedBox(height: 20),
                  _QuickAccessSection(
                    onCharts: () =>
                        context.router.push(const ProgressChartsRoute()),
                    onJourney: () =>
                        context.router.push(LearningJourneyRoute()),
                    onHistory: () =>
                        context.router.push(CompletionHistoryRoute()),
                  ),
                  const SizedBox(height: 20),
                  _CurriculaProgressSection(activeCurricula: activeCurricula),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _OverviewStatsRow extends StatelessWidget {
  const _OverviewStatsRow({
    required this.currentStreak,
    required this.maxStreak,
    required this.totalCompletions,
    required this.totalUniqueUnits,
    required this.totalPoints,
    required this.userMode,
  });

  final int currentStreak;
  final int maxStreak;
  final int totalCompletions;
  final int totalUniqueUnits;
  final int totalPoints;
  final UserMode userMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overview',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.local_fire_department,
                    iconColor: Colors.orange,
                    value: '$currentStreak',
                    label: 'Day Streak',
                    sublabel: 'Best: $maxStreak',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle,
                    iconColor: theme.colorScheme.primary,
                    value: '$totalCompletions',
                    label: 'Completions',
                  ),
                ),
                Expanded(
                  child: _StatItem(
                    icon: Icons.auto_stories,
                    iconColor: Colors.deepPurple,
                    value: '$totalUniqueUnits',
                    label: 'Units Done',
                  ),
                ),
                if (userMode == UserMode.child)
                  Expanded(
                    child: _StatItem(
                      icon: Icons.star,
                      iconColor: Colors.amber,
                      value: '$totalPoints',
                      label: 'Points',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.sublabel,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final String? sublabel;

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
        if (sublabel != null)
          Text(
            sublabel!,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );
  }
}

class _QuickAccessSection extends StatelessWidget {
  const _QuickAccessSection({
    required this.onCharts,
    required this.onJourney,
    required this.onHistory,
  });

  final VoidCallback onCharts;
  final VoidCallback onJourney;
  final VoidCallback onHistory;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detailed Views', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.bar_chart, color: Colors.indigo),
                title: const Text('Progress Charts'),
                subtitle: const Text('Completions, trends, streak calendar'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onCharts,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(
                  Icons.auto_stories,
                  color: Colors.deepPurple,
                ),
                title: const Text('Learning Journey'),
                subtitle: const Text('Lifetime achievements & milestones'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onJourney,
              ),
              const Divider(height: 1, indent: 56),
              ListTile(
                leading: const Icon(Icons.history, color: Colors.teal),
                title: const Text('Completion History'),
                subtitle: const Text('Detailed log of all completions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: onHistory,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CurriculaProgressSection extends ConsumerWidget {
  const _CurriculaProgressSection({required this.activeCurricula});

  final List<CurriculumId> activeCurricula;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('By Curriculum', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
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
                      '$count completions',
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
