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
import 'package:learning_tracker/features/gamification/presentation/widgets/streak_widget.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';

@RoutePage()
class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(dashboardActiveCurriculaProvider);
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final userModeAsync = ref.watch(dashboardUserModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const AppBarTitle(text: 'Learn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Search content',
            onPressed: () => context.router.push(const CurriculumListRoute()),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: activeCurriculaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (activeCurricula) {
            if (activeCurricula.isEmpty) {
              return EmptyState(
                message: 'No active tracks',
                subtitle: 'Add a track to start learning.',
                icon: Icons.menu_book_outlined,
                action: FilledButton.icon(
                  onPressed: () =>
                      context.router.push(const TrackManagementHubRoute()),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Track'),
                ),
              );
            }

            final userMode = userModeAsync.asData?.value ?? UserMode.adult;
            final streakData = streakAsync.asData?.value;
            final currentStreak = streakData?.currentStreak ?? 0;
            final maxStreak = streakData?.maxStreak ?? 0;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(allDailyTasksProvider);
                ref.invalidate(dashboardActiveCurriculaProvider);
                ref.invalidate(dashboardStreakProvider);
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  StreakWidget(
                    currentStreak: currentStreak,
                    maxStreak: maxStreak,
                    userMode: userMode,
                  ),
                  const SizedBox(height: 16),
                  _DailyTasksSection(
                    dailyTasksAsync: dailyTasksAsync,
                    onViewAll: () =>
                        context.router.push(const SchedulerRoute()),
                  ),
                  const SizedBox(height: 24),
                  _CurriculaSection(activeCurricula: activeCurricula),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DailyTasksSection extends ConsumerWidget {
  const _DailyTasksSection({
    required this.dailyTasksAsync,
    required this.onViewAll,
  });

  final AsyncValue<List<DailyTask>> dailyTasksAsync;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Today's Tasks", style: theme.textTheme.titleMedium),
            TextButton(onPressed: onViewAll, child: const Text('View All')),
          ],
        ),
        const SizedBox(height: 8),
        dailyTasksAsync.when(
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
          error: (e, _) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error loading tasks: $e'),
            ),
          ),
          data: (tasks) {
            if (tasks.isEmpty) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      Icon(
                        Icons.celebration_outlined,
                        color: theme.colorScheme.primary,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'All caught up!',
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'No tasks remaining for today.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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

            // Show up to 5 tasks inline
            final previewTasks = tasks.take(5).toList();
            return Column(
              children: [
                ...previewTasks.map(
                  (task) => DailyTaskCard(
                    key: ValueKey(
                      '${task.curriculumId.storageKey}_'
                      '${task.contentItemSefariaRef}_${task.stageOrder}',
                    ),
                    task: task,
                    onDismissed: () {
                      ref
                          .read(skippedTasksProvider.notifier)
                          .skip(task.contentItemSefariaRef);
                    },
                    onCompleted: () {
                      ref.invalidate(allDailyTasksProvider);
                    },
                  ),
                ),
                if (tasks.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton(
                      onPressed: onViewAll,
                      child: Text('${tasks.length - 5} more tasks...'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _CurriculaSection extends StatelessWidget {
  const _CurriculaSection({required this.activeCurricula});

  final List<CurriculumId> activeCurricula;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Curricula', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...activeCurricula.map(
          (curriculum) => _CurriculumTile(curriculum: curriculum),
        ),
      ],
    );
  }
}

class _CurriculumTile extends ConsumerWidget {
  const _CurriculumTile({required this.curriculum});

  final CurriculumId curriculum;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final completionAsync = ref.watch(
      dashboardCompletionPercentageProvider(curriculum),
    );
    final percentage = completionAsync.asData?.value ?? 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          context.router.push(
            ContentHierarchyRoute(curriculumId: curriculum.storageKey),
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
                      curriculum.displayNameEn,
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
                      '${(percentage * 100).toStringAsFixed(0)}% complete',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.bar_chart, size: 20),
                    tooltip: 'View progress',
                    onPressed: () {
                      context.router.push(
                        CurriculumProgressRoute(
                          curriculumId: curriculum.storageKey,
                        ),
                      );
                    },
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
