import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';


@RoutePage()
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCurriculaAsync = ref.watch(dashboardActiveCurriculaProvider);
    final userModeAsync = ref.watch(dashboardUserModeProvider);
    final streakAsync = ref.watch(dashboardStreakProvider);
    final selectedProfileAsync = ref.watch(selectedProfileProvider);
    final profileName = selectedProfileAsync.asData?.value?.displayName;
    final profileAvatar = selectedProfileAsync.asData?.value?.avatarIndex;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: const Text(
          'Learning Tracker',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.router.push(const NotificationsRoute()),
          ),
          if (profileAvatar != null)
            IconButton(
              onPressed: () {
                ref.read(selectedProfileIdProvider.notifier).clear();
                context.router.replace(const ProfilePickerRoute());
              },
              icon: ProfileAvatar(avatarIndex: profileAvatar, radius: 16),
              tooltip: 'Switch profile',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: activeCurriculaAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('Error: $e')),
          data: (activeCurricula) {
            final userMode = userModeAsync.asData?.value ?? UserMode.adult;
            final streakData = streakAsync.asData?.value;
            final currentStreak = streakData?.currentStreak ?? 0;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(dashboardActiveCurriculaProvider);
                ref.invalidate(dashboardUserModeProvider);
                ref.invalidate(dashboardStreakProvider);
                ref.invalidate(dashboardGlobalPointsProvider);
                ref.invalidate(allDailyTasksProvider);
                for (final c in activeCurricula) {
                  ref.invalidate(dashboardCompletionPercentageProvider(c));
                  ref.invalidate(dashboardLastCompletionProvider(c));
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

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);
    final globalPointsAsync = ref.watch(dashboardGlobalPointsProvider);
    final name = profileName ?? 'Learner';
    final now = DateTime.now();
    final months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final dateStr = '${months[now.month]} ${now.day}, ${now.year}';

    // Compute overall completion percentage
    var totalCompletion = 0.0;
    var loadedCount = 0;
    for (final curriculum in activeCurricula) {
      final pctAsync =
          ref.watch(dashboardCompletionPercentageProvider(curriculum));
      if (pctAsync.asData != null) {
        totalCompletion += pctAsync.asData!.value;
        loadedCount++;
      }
    }
    final avgCompletion =
        loadedCount > 0 ? (totalCompletion / loadedCount * 100).round() : 0;

    final totalPoints = globalPointsAsync.asData?.value ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Greeting header
        Text(
          '${_greeting()},',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        Text(
          name,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          dateStr,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 20),

        // Stats row
        Row(
          children: [
            Expanded(
              child: _StatCircle(
                icon: Icons.local_fire_department,
                iconColor: Colors.orange,
                value: '$currentStreak',
                label: 'STREAK',
              ),
            ),
            Expanded(
              child: _StatCircle(
                icon: Icons.check_circle,
                iconColor: theme.colorScheme.primary,
                value: '$avgCompletion%',
                label: 'DONE',
              ),
            ),
            Expanded(
              child: _StatCircle(
                icon: Icons.auto_stories,
                iconColor: Colors.deepPurple,
                value: '$totalPoints',
                label: userMode == UserMode.child ? 'POINTS' : 'PAGES',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Today's Learning section
        _TodaysLearningSection(
          dailyTasksAsync: dailyTasksAsync,
          onViewAll: () => context.router.push(const SchedulerRoute()),
        ),
        const SizedBox(height: 24),

        // Daily Progress bar
        dailyTasksAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (tasks) {
            if (tasks.isEmpty) return const SizedBox.shrink();
            return _DailyProgressBar(
              progress: 0.0,
              completed: 0,
              total: tasks.length,
            );
          },
        ),
        const SizedBox(height: 24),

        // Active Curricula
        if (activeCurricula.isNotEmpty) ...[
          Text('Active Curricula',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: activeCurricula.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _CurriculumCard(
                  curriculum: activeCurricula[index],
                );
              },
            ),
          ),
        ],
        const SizedBox(height: 24),

        // Recent Activity
        _RecentActivitySection(activeCurricula: activeCurricula),
      ],
    );
  }
}

class _StatCircle extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _StatCircle({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: iconColor.withValues(alpha: 0.1),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(height: 2),
              Text(
                value,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.5),
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

class _TodaysLearningSection extends ConsumerWidget {
  const _TodaysLearningSection({
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
            Text("Today's Learning",
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            dailyTasksAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (tasks) {
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${tasks.length} remaining',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
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
                            Text('All caught up!',
                                style: theme.textTheme.titleSmall),
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

            final previewTasks = tasks.take(5).toList();
            return Column(
              children: [
                ...previewTasks.map(
                  (task) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TaskItemCard(task: task, ref: ref),
                  ),
                ),
                if (tasks.length > 5)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
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

class _TaskItemCard extends StatelessWidget {
  const _TaskItemCard({required this.task, required this.ref});

  final DailyTask task;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curriculumColor = AppTheme.getCurriculumColor(task.curriculumId);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 40,
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
                    '${task.curriculumId.displayNameEn}: ${task.contentItemSefariaRef}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    task.stageName,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: task.isOverdue
                    ? Colors.orange.withValues(alpha: 0.15)
                    : curriculumColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                task.isOverdue ? 'Overdue' : task.stageName,
                style: TextStyle(
                  color: task.isOverdue ? Colors.orange : curriculumColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DailyProgressBar extends StatelessWidget {
  final double progress;
  final int completed;
  final int total;

  const _DailyProgressBar({
    required this.progress,
    required this.completed,
    required this.total,
  });

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
              'DAILY PROGRESS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.5),
                letterSpacing: 1,
              ),
            ),
            Text(
              '${(progress * 100).round()}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            valueColor:
                AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}

class _CurriculumCard extends ConsumerWidget {
  final CurriculumId curriculum;

  const _CurriculumCard({required this.curriculum});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculumColor = AppTheme.getCurriculumColor(curriculum);
    final completionAsync =
        ref.watch(dashboardCompletionPercentageProvider(curriculum));
    final percentage = completionAsync.asData?.value ?? 0.0;
    final pctDisplay = (percentage * 100).round();

    return SizedBox(
      width: 200,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            context.router.push(
              ContentHierarchyRoute(curriculumId: curriculum.storageKey),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      curriculum.displayNameEn,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    // Mini circular progress
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: percentage,
                            strokeWidth: 3,
                            backgroundColor:
                                curriculumColor.withValues(alpha: 0.15),
                            valueColor: AlwaysStoppedAnimation<Color>(
                                curriculumColor),
                          ),
                          Text(
                            '$pctDisplay%',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: curriculumColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                FilledButton(
                  onPressed: () {
                    context.router.push(
                      CurriculumProgressRoute(
                        curriculumId: curriculum.storageKey,
                      ),
                    );
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 36),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: const Text('Continue Learning'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentActivitySection extends ConsumerWidget {
  final List<CurriculumId> activeCurricula;

  const _RecentActivitySection({required this.activeCurricula});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    if (activeCurricula.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Recent Activity',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.auto_stories, color: Colors.deepPurple),
                title: const Text('My Learning Journey'),
                subtitle: const Text('See your lifetime achievements'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.router.push(LearningJourneyRoute()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
