import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/services/cross_curriculum_aggregator.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/curriculum_summary_card.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/points_summary_widget.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/todays_tasks_widget.dart';
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';

@RoutePage()
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(dashboardActiveCurriculaProvider);
    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: activeCurriculaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
        data: (activeCurricula) {
          final userMode = userModeAsync.asData?.value ?? UserMode.adult;
          final streakData = streakAsync.asData?.value;
          final currentStreak = streakData?.currentStreak ?? 0;
          final maxStreak = streakData?.maxStreak ?? 0;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(dashboardActiveCurriculaProvider);
              ref.invalidate(dashboardUserModeProvider);
              ref.invalidate(dashboardStreakProvider);
              ref.invalidate(dashboardGlobalPointsProvider);
              for (final c in activeCurricula) {
                ref.invalidate(dashboardCompletionPercentageProvider(c));
                ref.invalidate(dashboardLastCompletionProvider(c));
              }
            },
            child: _DashboardBody(
              activeCurricula: activeCurricula,
              userMode: userMode,
              currentStreak: currentStreak,
              maxStreak: maxStreak,
            ),
          );
        },
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final List<CurriculumId> activeCurricula;
  final UserMode userMode;
  final int currentStreak;
  final int maxStreak;

  const _DashboardBody({
    required this.activeCurricula,
    required this.userMode,
    required this.currentStreak,
    required this.maxStreak,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = <CurriculumSummary>[];
    var allLoaded = true;

    for (final curriculum in activeCurricula) {
      final percentageAsync = ref.watch(
        dashboardCompletionPercentageProvider(curriculum),
      );
      final lastCompletionAsync = ref.watch(
        dashboardLastCompletionProvider(curriculum),
      );

      if (percentageAsync is AsyncLoading ||
          lastCompletionAsync is AsyncLoading) {
        allLoaded = false;
        continue;
      }

      summaries.add(
        CurriculumSummary(
          curriculumId: curriculum,
          completionPercentage: percentageAsync.asData?.value ?? 0.0,
          paceStatus: null,
          nextDueItem: null,
          todayTaskCount: 0,
          lastCompletionAt: lastCompletionAsync.asData?.value,
        ),
      );
    }

    if (!allLoaded && summaries.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final aggregator = ref.watch(crossCurriculumAggregatorProvider);
    final stats = aggregator.aggregate(
      activeCurricula: activeCurricula,
      completionPercentages: {
        for (final s in summaries) s.curriculumId: s.completionPercentage,
      },
      paceStatuses: {for (final s in summaries) s.curriculumId: s.paceStatus},
      todayTaskCounts: {
        for (final s in summaries) s.curriculumId: s.todayTaskCount,
      },
      nextDueItems: {for (final s in summaries) s.curriculumId: s.nextDueItem},
      lastCompletions: {
        for (final s in summaries) s.curriculumId: s.lastCompletionAt,
      },
    );

    final globalPointsAsync = ref.watch(dashboardGlobalPointsProvider);
    final mostRecent = stats.mostRecentlyActive;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        StreakWidget(
          currentStreak: currentStreak,
          maxStreak: maxStreak,
          userMode: userMode,
        ),
        const SizedBox(height: 12),
        if (userMode == UserMode.child)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: PointsSummaryWidget(
              totalPoints: globalPointsAsync.asData?.value ?? 0,
            ),
          ),
        TodaysTasksWidget(
          taskCount: stats.totalTasksToday,
          onQuickStart: () {
            context.router.push(const SchedulerRoute());
          },
        ),
        const SizedBox(height: 12),
        if (mostRecent != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ContinueLearningButton(
              curriculum: mostRecent.curriculumId,
              onTap: () {
                context.router.push(
                  CurriculumProgressRoute(
                    curriculumId: mostRecent.curriculumId.storageKey,
                  ),
                );
              },
            ),
          ),
        ...stats.curriculumSummaries.map(
          (summary) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: CurriculumSummaryCard(
              summary: summary,
              onTap: () {
                context.router.push(
                  CurriculumProgressRoute(
                    curriculumId: summary.curriculumId.storageKey,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _ContinueLearningButton extends StatelessWidget {
  final CurriculumId curriculum;
  final VoidCallback onTap;

  const _ContinueLearningButton({
    required this.curriculum,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.play_arrow),
      label: Text('Continue learning ${curriculum.displayNameEn}'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
