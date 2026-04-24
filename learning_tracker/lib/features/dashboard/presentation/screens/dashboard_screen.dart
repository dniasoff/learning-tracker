import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/user_mode.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/core/widgets/animated_progress_bar.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/dashboard_date_header.dart';
import 'package:learning_tracker/features/dashboard/presentation/widgets/day_type_indicator.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/widgets/profile_avatar.dart';
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
    final profileAvatar = selectedProfileAsync.asData?.value?.avatarIndex;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          l10n.learningTracker,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
              tooltip: l10n.switchProfile,
            ),
        ],
      ),
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

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(dashboardActiveCurriculaStreamProvider);
                  ref.invalidate(dashboardUserModeProvider);
                  ref.invalidate(dashboardStreakProvider);
                  ref.invalidate(dashboardGlobalPointsProvider);
                  ref.invalidate(allDailyTasksProvider);
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

  String _greeting(AppLocalizations l10n) {
    final hour = DateTime.now().hour;
    if (hour < 12) return l10n.goodMorning;
    if (hour < 17) return l10n.goodAfternoon;
    return l10n.goodEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dailyTasksAsync = ref.watch(allDailyTasksProvider);
    final globalPointsAsync = ref.watch(dashboardGlobalPointsProvider);
    final name = profileName ?? l10n.learner;
    final now = DateTime.now();

    // Compute overall completion percentage
    var totalCompletion = 0.0;
    var loadedCount = 0;
    for (final curriculum in activeCurricula) {
      final pctAsync = ref.watch(
        dashboardCompletionPercentageProvider(curriculum),
      );
      if (pctAsync.asData != null) {
        totalCompletion += pctAsync.asData!.value;
        loadedCount++;
      }
    }
    final avgCompletion = loadedCount > 0 ? (totalCompletion / loadedCount) : 0.0;
    final avgCompletionDisplay = formatFractionAsPercent(avgCompletion);

    final totalPoints = globalPointsAsync.asData?.value ?? 0;
    final tasksToday = dailyTasksAsync.asData?.value.length ?? 0;
    final allTasks = dailyTasksAsync.asData?.value ?? const <DailyTask>[];
    final overdueProgramCount = allTasks
        .where((t) => t.priority == DailyTaskPriority.overdueProgram)
        .length;
    final todayProgramCount = allTasks
        .where((t) => t.priority == DailyTaskPriority.todayProgram)
        .length;
    final hasProgramCalendarTasks =
        overdueProgramCount > 0 || todayProgramCount > 0;

    if (activeCurricula.isEmpty) {
      final isChildMode =
          ref.watch(selectedProfileProvider).asData?.value?.mode == 'child';
      return _EmptyDashboard(
        name: name,
        greeting: _greeting(l10n),
        isChildMode: isChildMode,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [AppTheme.brandBlue, AppTheme.brandBlueBright],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.brandBlue.withValues(alpha: 0.25),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${_greeting(l10n)},',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.brandCreamCard.withValues(alpha: 0.86),
                ),
              ),
              Text(
                name,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.brandCreamCard,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              DefaultTextStyle(
                style: theme.textTheme.bodySmall!.copyWith(
                  color: AppTheme.brandCreamCard.withValues(alpha: 0.86),
                ),
                child: DashboardDateHeader(date: now),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // AC-4: Day type indicator
        dailyTasksAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (tasks) => DayTypeIndicator(tasks: tasks),
        ),

        const SizedBox(height: 20),

        // Streak recovery banner
        if (userMode == UserMode.child) ...[
          _StreakRecoveryBanner(currentStreak: currentStreak),
          const SizedBox(height: 12),
        ],

        // Stats row
        if (userMode == UserMode.child)
          Row(
            children: [
              Expanded(
                child: _StatCircle(
                  icon: Icons.local_fire_department,
                  iconColor: AppTheme.brandGold,
                  value: '$currentStreak',
                  label: l10n.streak,
                ),
              ),
              Expanded(
                child: _StatCircle(
                  icon: hasProgramCalendarTasks
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle,
                  iconColor: hasProgramCalendarTasks
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  value: hasProgramCalendarTasks
                      ? '$overdueProgramCount'
                      : avgCompletionDisplay,
                  label: hasProgramCalendarTasks ? 'overdue' : l10n.done,
                ),
              ),
              Expanded(
                child: _StatCircle(
                  icon: Icons.auto_stories,
                  iconColor: AppTheme.brandBlue,
                  value: '$totalPoints',
                  label: l10n.points,
                ),
              ),
            ],
          )
        else
          Row(
            children: [
              Expanded(
                child: _StatCircle(
                  icon: Icons.local_fire_department,
                  iconColor: AppTheme.brandGold,
                  value: '$currentStreak',
                  label: l10n.streak,
                ),
              ),
              Expanded(
                child: _StatCircle(
                  icon: hasProgramCalendarTasks
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle,
                  iconColor: hasProgramCalendarTasks
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                  value: hasProgramCalendarTasks
                      ? '$overdueProgramCount'
                      : avgCompletionDisplay,
                  label: hasProgramCalendarTasks ? 'overdue' : l10n.done,
                ),
              ),
              Expanded(
                child: _StatCircle(
                  icon: Icons.today,
                  iconColor: AppTheme.brandCoral,
                  value: hasProgramCalendarTasks
                      ? '$todayProgramCount'
                      : '$tasksToday',
                  label: hasProgramCalendarTasks ? 'today due' : l10n.todaysTasks,
                ),
              ),
            ],
          ),
        const SizedBox(height: 24),

        // AC-5: Today's Learning section (actual task items)
        _TodaysLearningSection(
          dailyTasksAsync: dailyTasksAsync,
          onViewAll: () => context.router.push(const SchedulerRoute()),
        ),
        const SizedBox(height: 24),

        // AC-1, 2, 6: Active Curricula with pace data
        if (activeCurricula.isNotEmpty) ...[
          Text(
            l10n.activeCurricula,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 232,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: activeCurricula.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                return _CurriculumCard(
                  curriculum: activeCurricula[index],
                  allTasks: dailyTasksAsync.asData?.value ?? [],
                );
              },
            ),
          ),
        ],
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
    final bg = iconColor.withValues(alpha: 0.12);
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: bg,
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
                  color: AppTheme.brandInk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurfaceVariant,
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
    final l10n = AppLocalizations.of(context)!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.todaysLearning,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            dailyTasksAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
              data: (tasks) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.remaining(tasks.length),
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
          error: (e, _) => _ErrorRetry(
            message: l10n.errorLoadingTasks(e.toString()),
            onRetry: () => ref.invalidate(allDailyTasksProvider),
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
                              l10n.allCaughtUp,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              l10n.noTasksRemaining,
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

            final grouped = _groupTasks(tasks);
            void openSection(SchedulerTaskSection section) {
              ref
                  .read(schedulerTaskSectionProvider.notifier)
                  .setSection(section);
              onViewAll();
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _TaskSummaryCard(
                        icon: Icons.today,
                        title: "Today's tasks",
                        count: grouped.todayTasks.length,
                        color: theme.colorScheme.primary,
                        onTap: () => openSection(SchedulerTaskSection.today),
                      ),
                      const SizedBox(width: 12),
                      _TaskSummaryCard(
                        icon: Icons.warning_amber_rounded,
                        title: 'Missed / Overdue tasks',
                        count: grouped.overdueTasks.length,
                        color: theme.colorScheme.error,
                        onTap: () => openSection(SchedulerTaskSection.overdue),
                      ),
                      const SizedBox(width: 12),
                      _TaskSummaryCard(
                        icon: Icons.refresh,
                        title: 'Chazara / Review tasks',
                        count: grouped.reviewTasks.length,
                        color: AppTheme.brandBlue,
                        onTap: () => openSection(SchedulerTaskSection.review),
                      ),
                    ],
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

class _TaskSummaryCard extends StatelessWidget {
  const _TaskSummaryCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 220,
      height: 96,
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$count',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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
    final lifetimeSummaryAsync = ref.watch(globalLifetimeCurriculaProvider(profileId));
    final lifetimeSummary = lifetimeSummaryAsync.asData?.value
        .where((s) => s.curriculumId == curriculum)
        .firstOrNull;
    final lifetimePctDisplay = formatFractionAsPercent(
      lifetimeSummary?.percentage ?? 0.0,
    );

    // AC-6: Compute per-curriculum task count and today's study item
    final curriculumTasks = allTasks
        .where((t) => t.curriculumId == curriculum)
        .toList();
    final todayTask = curriculumTasks.isNotEmpty ? curriculumTasks.first : null;
    final overdueProgramCount = curriculumTasks
        .where((t) => t.priority == DailyTaskPriority.overdueProgram)
        .length;
    final todayProgramCount = curriculumTasks
        .where((t) => t.priority == DailyTaskPriority.todayProgram)
        .length;
    final hasProgramEnrollment = hasProgramEnrollmentAsync.asData?.value ?? false;

    // AC-1: Get pace status
    final paceStatus = paceAsync.asData?.value;

    return SizedBox(
      width: 220,
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayNamePrimary,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            displayNameSecondary,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    // AC-7: Show shimmer while loading, nothing if no goal
                    if (paceAsync.isLoading)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: curriculumColor.withValues(alpha: 0.5),
                        ),
                      )
                    else
                      _MiniPaceBadge(paceStatus: paceStatus),
                  ],
                ),
                const SizedBox(height: 10),
                if (hasProgramEnrollment) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: curriculumColor.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: curriculumColor.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          overdueProgramCount > 0
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: overdueProgramCount > 0
                              ? theme.colorScheme.error
                              : AppTheme.brandGold,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                overdueProgramCount > 0
                                    ? 'Overdue: $overdueProgramCount'
                                    : 'Overdue: 0',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: overdueProgramCount > 0
                                      ? theme.colorScheme.error
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Today due: $todayProgramCount',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Lifetime: $lifetimePctDisplay',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: curriculumColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // AC-2: Animated progress bar (self-paced tracks)
                  AnimatedProgressBar(
                    value: percentage,
                    color: curriculumColor,
                    backgroundColor: curriculumColor.withValues(alpha: 0.15),
                    height: 4,
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.easeOut,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Current: $pctDisplay',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: curriculumColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lifetime: $lifetimePctDisplay',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.brandGoldDeep,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      // AC-2: Projected completion date
                      if (paceStatus?.projectedCompletionDate != null)
                        Text(
                          _formatProjectedDate(
                            paceStatus!.projectedCompletionDate!,
                          ),
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        )
                      else if (paceStatus != null)
                        Text(
                          l10n.noProjection,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ],
                const Spacer(),
                // AC-6: Today's study item for this track
                if (todayTask != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.today,
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: curriculumColor.withValues(alpha: 0.8),
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          todayTask.contentItemSefariaRef,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (curriculumTasks.length > 1)
                          Text(
                            l10n.plusNMore(curriculumTasks.length - 1),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                FilledButton(
                  onPressed: () {
                    context.router.navigate(const LearningRoute());
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(double.infinity, 36),
                    padding: EdgeInsets.zero,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  child: Text(l10n.continueLearning),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

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

  String _formatProjectedDate(DateTime date) =>
      '${_months[date.month]} ${date.day}';
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

/// AC-7: Error state with retry button.
class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
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
                  const Icon(Icons.shield, color: AppTheme.brandCoral, size: 24),
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
