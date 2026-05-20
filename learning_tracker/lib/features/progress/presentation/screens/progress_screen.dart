import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/core/widgets/stat_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final baseTheme = Theme.of(context);
    final interTextTheme = GoogleFonts.interTextTheme(baseTheme.textTheme)
        .apply(
          bodyColor: baseTheme.colorScheme.onSurface,
          displayColor: baseTheme.colorScheme.onSurface,
        );
    final activeCurriculaAsync = ref.watch(
      dashboardActiveCurriculaStreamProvider,
    );
    final streakAsync = ref.watch(dashboardStreakProvider);
    final profileId = ref.watch(activeProfileIdProvider);
    final lifetimeSummariesAsync = ref.watch(
      lifetimeSummariesProvider(profileId),
    );
    final overviewStatsAsync = ref.watch(progressOverviewStatsProvider);

    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: AppColors.surfaceF4b,
      body: Theme(
        data: baseTheme.copyWith(
          textTheme: interTextTheme,
          primaryTextTheme: interTextTheme,
        ),
        child: SafeArea(
          child: activeCurriculaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) =>
                Center(child: Text(l10n.errorWithMessage(error.toString()))),
            data: (activeCurricula) {
              if (activeCurricula.isEmpty) {
                return EmptyState(
                  message: l10n.progressNoDataTitle,
                  subtitle: l10n.progressNoDataSubtitle,
                  icon: Icons.trending_up_outlined,
                );
              }

              final streakData = streakAsync.asData?.value;
              final currentStreak = streakData?.currentStreak ?? 0;
              final overviewStats = overviewStatsAsync.asData?.value;
              final totalCompletions = overviewStats?.totalCompletions ?? 0;
              final totalUniqueUnits = overviewStats?.totalUniqueItems ?? 0;
              final lifetimeSummaries =
                  lifetimeSummariesAsync.asData?.value ??
                  const <CurriculumLifetimeSummary>[];

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dashboardActiveCurriculaStreamProvider);
                  ref.invalidate(dashboardStreakProvider);
                  ref.invalidate(progressOverviewStatsProvider);
                  ref.invalidate(lifetimeSummariesProvider(profileId));
                  // ignore: deprecated_member_use
                  ref.invalidate(globalLifetimeCurriculaProvider(profileId));
                  ref.invalidate(
                    lifetimeTotalsAcrossAllCurriculaProvider(profileId),
                  );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(25, 8, 25, 20),
                  children: [
                    Text(
                      l10n.progress,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 12),
                    _StatGrid(
                      totalCompletions: totalCompletions,
                      totalUniqueUnits: totalUniqueUnits,
                      currentStreak: currentStreak,
                      activeTracks: activeCurricula.length,
                    ),
                    const SizedBox(height: 16),
                    const _ProgressChartsTile(),
                    const SizedBox(height: 8),
                    const _LearningJourneyTile(),
                    const SizedBox(height: 8),
                    const _ItemsLearnedTile(),
                    const SizedBox(height: 20),
                    _LearningLifetimeTreeCard(summaries: lifetimeSummaries),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({
    required this.totalCompletions,
    required this.totalUniqueUnits,
    required this.currentStreak,
    required this.activeTracks,
  });

  final int totalCompletions;
  final int totalUniqueUnits;
  final int currentStreak;
  final int activeTracks;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.0,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _OverviewStatCard(
          icon: Icons.verified_outlined,
          iconColor: AppColors.chartAmber,
          value: '$totalUniqueUnits',
          label: l10n.statCompletions,
          onTap: () => context.router.push(CompletionHistoryRoute()),
        ),
        _OverviewStatCard(
          icon: Icons.menu_book_outlined,
          iconColor: AppTheme.brandBlue,
          value: '$totalCompletions',
          label: l10n.statUnitsDone,
          onTap: () => context.router.push(const TasksDoneRoute()),
        ),
        _OverviewStatCard(
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.white,
          value: '$currentStreak',
          label: l10n.statDayStreak,
          highlighted: true,
          onTap: () => context.router.push(const StreakHistoryRoute()),
        ),
        _OverviewStatCard(
          icon: Icons.hub_outlined,
          iconColor: AppColors.chartAmber,
          value: '$activeTracks',
          label: l10n.statActiveTracks,
          onTap: () => context.router.push(TrackManagementHubRoute()),
        ),
      ],
    );
  }
}

/// Thin screen-local alias that forwards directly to [StatCard].
///
/// Keeping the private name avoids touching call sites inside [_StatGrid]
/// while still satisfying the story AC that the implementation is backed
/// by the shared primitive (DNI-359 / 26.16).
class _OverviewStatCard extends StatelessWidget {
  const _OverviewStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.highlighted = false,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool highlighted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return StatCard(
      icon: icon,
      iconColor: iconColor,
      value: value,
      label: label,
      highlighted: highlighted,
      onTap: onTap,
    );
  }
}

class _ProgressChartsTile extends StatelessWidget {
  const _ProgressChartsTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.router.push(const ProgressChartsRoute()),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.blueNavy.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.bar_chart_rounded,
                color: AppTheme.brandBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.progressChartsTile,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.progressChartsTileSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.brandInkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningJourneyTile extends StatelessWidget {
  const _LearningJourneyTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.router.push(SiyumimMilestonesRoute()),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.blueNavy.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                color: AppTheme.brandBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.myLearningJourney,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.myLearningJourneySubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.brandInkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsLearnedTile extends StatelessWidget {
  const _ItemsLearnedTile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => context.router.push(const ItemsLearnedRoute()),
      child: Ink(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.blueNavy.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: const Color(0xFFEEF3FF),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.menu_book_outlined,
                color: AppTheme.brandBlue,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.itemsLearnedTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    l10n.itemsLearnedSubtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.brandInkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

class _LearningLifetimeTreeCard extends StatefulWidget {
  const _LearningLifetimeTreeCard({required this.summaries});

  final List<CurriculumLifetimeSummary> summaries;

  @override
  State<_LearningLifetimeTreeCard> createState() =>
      _LearningLifetimeTreeCardState();
}

class _LearningLifetimeTreeCardState extends State<_LearningLifetimeTreeCard> {
  final Set<CurriculumId> _expandedCurriculumIds = {};
  final Map<String, bool> _treeExpandedNodes = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (widget.summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort by canonical Jewish-learning order (CurriculumId enum index),
    // not alphabetical — Chumash → Nach → Mishnayos → Bavli → Yerushalmi →
    // codes → Mussar.
    final withProgress =
        widget.summaries.where((s) => s.learnedLeafCount > 0).toList()..sort(
          (a, b) => a.curriculumId.index.compareTo(b.curriculumId.index),
        );

    if (withProgress.isEmpty) {
      return const SizedBox.shrink();
    }

    return LifetimeFolderSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LifetimeFolderPageHeader(
            title: l10n.learningLifetime,
            subtitle: l10n.learningLifetimeExpandHint,
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < withProgress.length; i++) ...[
            if (i > 0) const SizedBox(height: 4),
            _curriculumRow(context, withProgress[i]),
          ],
        ],
      ),
    );
  }

  Widget _curriculumRow(
    BuildContext context,
    CurriculumLifetimeSummary summary,
  ) {
    final id = summary.curriculumId;
    final expanded = _expandedCurriculumIds.contains(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LifetimeCurriculumFolderRow(
          curriculumId: id,
          trailingPercent: percentTextForCurriculum(summary),
          isExpanded: expanded,
          isExpandableListStyle: true,
          onTap: () {
            setState(() {
              if (expanded) {
                _expandedCurriculumIds.remove(id);
              } else {
                _expandedCurriculumIds.add(id);
              }
            });
          },
        ),
        if (expanded) ...[
          const SizedBox(height: 8),
          LifetimeFolderListPanel(
            maxHeight: 280,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final node in summary.tree)
                    LifetimeFolderTreeNode(
                      node: node,
                      depth: 0,
                      nodeKey: '${id.storageKey}/0/${node.rawValue}',
                      expandedNodes: _treeExpandedNodes,
                      onExpandToggle: (key, isExpanded) {
                        setState(() {
                          _treeExpandedNodes[key] = isExpanded;
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
