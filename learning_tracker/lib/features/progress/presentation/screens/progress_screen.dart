import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/progress_providers.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/lifetime_folder_styled_widgets.dart';

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
      globalLifetimeCurriculaProvider(profileId),
    );
    final overviewStatsAsync = ref.watch(progressOverviewStatsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      body: Theme(
        data: baseTheme.copyWith(
          textTheme: interTextTheme,
          primaryTextTheme: interTextTheme,
        ),
        child: SafeArea(
          child: activeCurriculaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Center(child: Text('Error: $error')),
            data: (activeCurricula) {
              if (activeCurricula.isEmpty) {
                return const EmptyState(
                  message: 'No progress yet',
                  subtitle: 'Start learning to see your progress here.',
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
                  ref.invalidate(globalLifetimeCurriculaProvider(profileId));
                  for (final curriculum in activeCurricula) {
                    ref.invalidate(
                      dashboardCompletionPercentageProvider(curriculum),
                    );
                  }
                  ref.invalidate(
                    lifetimeTotalsAcrossAllCurriculaProvider(profileId),
                  );
                },
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(25, 8, 25, 20),
                  children: [
                    Text(
                      'Progress',
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
                    const SizedBox(height: 20),
                    _CurriculaMasterySection(activeCurricula: activeCurricula),
                    const SizedBox(height: 18),
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
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _OverviewStatCard(
          icon: Icons.verified_outlined,
          iconColor: const Color(0xFFF8C146),
          value: '$totalCompletions',
          label: 'COMPLETIONS',
        ),
        _OverviewStatCard(
          icon: Icons.menu_book_outlined,
          iconColor: AppTheme.brandBlue,
          value: '$totalUniqueUnits',
          label: 'UNITS DONE',
        ),
        _OverviewStatCard(
          icon: Icons.local_fire_department_rounded,
          iconColor: Colors.white,
          value: '$currentStreak',
          label: 'DAY STREAK',
          highlighted: true,
        ),
        _OverviewStatCard(
          icon: Icons.hub_outlined,
          iconColor: const Color(0xFFF8C146),
          value: '$activeTracks',
          label: 'ACTIVE TRACKS',
        ),
      ],
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  const _OverviewStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    this.highlighted = false,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cardColor = highlighted ? const Color(0xFFFF6E76) : Colors.white;
    final valueColor = highlighted ? Colors.white : const Color(0xFF11182C);
    final labelColor = highlighted
        ? Colors.white.withValues(alpha: 0.82)
        : const Color(0xFF7C8595);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF03174C).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (highlighted)
            Align(
              alignment: Alignment.topRight,
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: highlighted ? 0.18 : 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: iconColor, size: 17),
              ),
              const Spacer(),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: labelColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressChartsTile extends StatelessWidget {
  const _ProgressChartsTile();

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFF03174C).withValues(alpha: 0.06),
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
                    'Progress Charts',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Completions, trends, and more',
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

class _CurriculaMasterySection extends ConsumerWidget {
  const _CurriculaMasterySection({required this.activeCurricula});

  final List<CurriculumId> activeCurricula;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Curriculum Mastery',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final curriculum in activeCurricula)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CurriculumProgressTile(curriculum: curriculum),
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
    final completionAsync = ref.watch(
      dashboardCompletionPercentageProvider(curriculum),
    );
    final percentage = completionAsync.asData?.value ?? 0.0;
    final percentageText = formatFractionAsPercent(percentage);
    final color = AppTheme.getCurriculumColor(curriculum);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        context.router.push(
          CurriculumProgressRoute(curriculumId: curriculum.storageKey),
        );
      },
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF03174C).withValues(alpha: 0.05),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        curriculum.displayNameEn,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF172347),
                        ),
                      ),
                      Text(
                        curriculum.displayNameHe,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF8A92A4),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$percentageText DONE',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF243053),
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: percentage,
                minHeight: 9,
                backgroundColor: const Color(0xFFE8ECF3),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
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
    if (widget.summaries.isEmpty) {
      return const SizedBox.shrink();
    }

    final withProgress =
        widget.summaries.where((s) => s.learnedLeafCount > 0).toList()..sort(
          (a, b) => a.curriculumId.displayNameEn.compareTo(
            b.curriculumId.displayNameEn,
          ),
        );

    if (withProgress.isEmpty) {
      return const SizedBox.shrink();
    }

    return LifetimeFolderSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LifetimeFolderPageHeader(
            title: 'Learning Lifetime',
            subtitle: 'Per curriculum: expand to browse what you have learned',
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
          titleEn: id.displayNameEn,
          titleHe: id.displayNameHe,
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final node in summary.tree)
                    LifetimeFolderTreeNode(
                      node: node,
                      depth: 0,
                      nodeKey: '${id.storageKey}/0/${node.label}',
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
