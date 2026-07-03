import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/widgets/app_error_view.dart';
import 'package:learning_tracker/core/widgets/empty_state.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class LearningScreen extends ConsumerWidget {
  const LearningScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plusJakartaTheme = theme.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(theme.textTheme),
    );
    final l10n = AppLocalizations.of(context)!;
    final activeCurriculaAsync = ref.watch(
      dashboardActiveCurriculaStreamProvider,
    );
    // Non-blocking daf grouping: collapse a daf's amudim to one card when the
    // goal/content data is ready; otherwise show the ungrouped list (never block
    // the daily list on the grouping lookups).
    final rawDailyTasksAsync = ref.watch(allDailyTasksProvider);
    final coarsePacedIds =
        ref.watch(coarsePacedTrackIdsProvider).asData?.value ?? const <int>{};
    final contentIndex = ref.watch(contentIndexProvider).asData?.value;
    final dailyTasksAsync = (coarsePacedIds.isNotEmpty && contentIndex != null)
        ? rawDailyTasksAsync.whenData(
            (t) => collapseDafTasks(
              t,
              coarsePacedTrackIds: coarsePacedIds,
              index: contentIndex,
            ),
          )
        : rawDailyTasksAsync;
    final streakAsync = ref.watch(dashboardStreakProvider);
    final isChildMode =
        ref.watch(selectedProfileProvider).asData?.value?.profileMode ==
        ProfileMode.child;
    final activeTutoredSelection = ref.watch(
      activeTutoredProfileSelectionProvider,
    );
    final isTutoredSession = activeTutoredSelection != null;
    final tutorPerms = ref.watch(activeTutorPermissionsProvider);
    final currentStreak = streakAsync.asData?.value.currentStreak ?? 0;
    final maxStreak = streakAsync.asData?.value.maxStreak ?? 0;

    return Scaffold(
      backgroundColor: AppColors.surfaceF4,
      body: Theme(
        data: plusJakartaTheme,
        child: SafeArea(
          child: activeCurriculaAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, st) => AppErrorView(
              error: e,
              stackTrace: st,
              onRetry: () =>
                  ref.refresh(dashboardActiveCurriculaStreamProvider),
            ),
            data: (activeCurricula) {
              if (activeCurricula.isEmpty) {
                // Tutors can add tracks if canEditStages is permitted.
                final tutorCanAddTrack =
                    isTutoredSession && (tutorPerms?.canEditStages ?? false);
                final canAddTrack =
                    !isChildMode && (!isTutoredSession || tutorCanAddTrack);
                return EmptyState(
                  message: l10n.noActiveTracks,
                  subtitle: canAddTrack
                      ? l10n.addTrackToStart
                      : l10n.askGrownUpToAddTrack,
                  icon: Icons.menu_book_outlined,
                  action: canAddTrack
                      ? FilledButton.icon(
                          onPressed: () => context.router.push(
                            TrackManagementHubRoute(startAdding: true),
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(l10n.addTrack),
                        )
                      : null,
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(allDailyTasksProvider);
                  ref.invalidate(dashboardActiveCurriculaStreamProvider);
                  ref.invalidate(dashboardStreakProvider);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(25, 10, 25, 32),
                  children: [
                    const SizedBox(height: 18),
                    _StreakHeroCard(
                      currentStreak: currentStreak,
                      maxStreak: maxStreak,
                    ),
                    const SizedBox(height: 36),
                    _DailyTasksSection(
                      dailyTasksAsync: dailyTasksAsync,
                      onViewAll: () =>
                          context.router.push(const SchedulerRoute()),
                    ),
                    const SizedBox(height: 36),
                    const _BrowseSection(),
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

class _StreakHeroCard extends StatelessWidget {
  const _StreakHeroCard({required this.currentStreak, required this.maxStreak});

  final int currentStreak;
  final int maxStreak;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.router.push(const RecentActivityRoute()),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1B3FAF),
                  Color(0xFF1F4ECD),
                  Color(0xFF2632AF),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1F4ECD).withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.learnStreakCurrentAchievement,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        l10n.learnStreakDayStreak(currentStreak),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 38,
                          height: 1.02,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.workspace_premium_rounded,
                              color: Color(0xFFF7E7AF),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.learnStreakPersonalBest(maxStreak),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFFF6C54),
                  size: 56,
                ),
              ],
            ),
          ),
          Positioned(
            right: 14,
            bottom: -14,
            child: Transform.rotate(
              angle: 0.08,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.peachMid,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  // RTL-safe: no emoji; localised via ARB.
                  l10n.learnStreakKeepItUp,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: AppColors.peachDark,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
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
          children: [
            Expanded(
              child: Text(
                AppLocalizations.of(context)!.dailyTasksTitle,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 36,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAll,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF354993),
                padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              child: dailyTasksAsync.when(
                data: (tasks) => Text(
                  AppLocalizations.of(context)!.itemsCount(tasks.length),
                ),
                loading: () => const Text('...'),
                error: (_, __) =>
                    Text(AppLocalizations.of(context)!.itemsCount(0)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        dailyTasksAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, st) => AppErrorView(
            error: e,
            stackTrace: st,
            onRetry: () => ref.invalidate(allDailyTasksProvider),
          ),
          data: (tasks) {
            if (tasks.isEmpty) {
              return _InfoCard(
                icon: Icons.celebration_outlined,
                title: AppLocalizations.of(context)!.tasksAllCaughtUp,
                subtitle: AppLocalizations.of(
                  context,
                )!.tasksNoTasksRemainingToday,
              );
            }

            return Column(
              children: [
                for (final task in tasks.take(5)) ...[
                  _LearnTaskCard(task: task),
                  const SizedBox(height: 12),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

class _LearnTaskCard extends ConsumerWidget {
  const _LearnTaskCard({required this.task});

  final DailyTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculumColor = AppTheme.getCurriculumColor(task.curriculumId);
    final rendered =
        ref
            .watch(renderedDisplayForRefProvider(task.contentItemSefariaRef))
            .asData
            ?.value ??
        task.contentItemSefariaRef.replaceAll('_', ' ');
    // Drop the leading seder segment (e.g. "קודשים › ") so the title doesn't
    // overflow — the curriculum chip below already shows that context. Keeps
    // the rest of the breadcrumb (e.g. "חולין › דף כה › עמוד א").
    const breadcrumbSep = ' › ';
    final sepIdx = rendered.indexOf(breadcrumbSep);
    var taskTitle = sepIdx == -1
        ? rendered
        : rendered.substring(sepIdx + breadcrumbSep.length);
    // For a daf-paced (coarse) track this card represents the whole daf, so name
    // the daf — the seeded day label if present, else drop the trailing amud.
    final coarseIds = ref.watch(coarsePacedTrackIdsProvider).asData?.value;
    if (coarseIds != null && coarseIds.contains(task.trackId)) {
      final useHebrew = domainTermLabels(ref).isHebrew;
      final seeded = useHebrew ? task.unitDisplayHe : task.unitDisplayEn;
      taskTitle = (seeded != null && seeded.isNotEmpty)
          ? seeded
          : collapseAmudLeaf(taskTitle);
    }
    final isOverdue = task.isOverdue;
    final stageLabel = domainTermLabels(
      ref,
    ).resolveStoredStageName(task.stageName);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.router.push(
          TextDisplayRoute(sefariaRef: task.contentItemSefariaRef),
        ),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color:
                      (isOverdue
                              ? const Color(0xFFF05A67)
                              : curriculumColor.withValues(alpha: 0.2))
                          .withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isOverdue ? Icons.priority_high_rounded : _taskIcon(task),
                  color: isOverdue ? const Color(0xFFD33349) : curriculumColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge chips: a Wrap (not a Row) so that on a narrow
                    // viewport at large text the stage chip drops to a second
                    // line instead of overflowing horizontally. On normal
                    // devices both chips sit on one line, unchanged.
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusErrorSoft,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              AppLocalizations.of(context)!.bubbleOverdue,
                              style: theme.textTheme.labelSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFFC22840),
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brandCreamSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            stageLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: AppTheme.brandInkMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      taskTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.brandInk,
                        fontSize: 22,
                      ),
                    ),
                    // Rule-7 (no track types): the task card never renders a
                    // track-type label (e.g. "personal"/"אישי"). The stage chip
                    // above and the title breadcrumb already carry all the
                    // context the learner needs.
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // AUD-learning-05 (AX-3 / IL-7 defect class): swap the glyph for
              // RTL so the "go to detail" chevron keeps pointing toward the
              // forward-navigation edge instead of back into the card. Icon
              // has no matchTextDirection parameter of its own (that field
              // lives on IconData and chevron_right_rounded does not set
              // it) — direction-aware icon selection is the established
              // pattern in this codebase (see
              // breadcrumb_navigation.dart's breadcrumbSeparatorIcon).
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: const Color(0xFFA2A8B6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _taskIcon(DailyTask task) {
    return switch (task.priority) {
      DailyTaskPriority.overdueProgram => Icons.priority_high_rounded,
      DailyTaskPriority.todayProgram => Icons.menu_book_rounded,
      DailyTaskPriority.overdueChazara => Icons.history_rounded,
      // overdueNewLearning: not yet studied — use new-learning icon, not review
      DailyTaskPriority.overdueNewLearning => Icons.auto_stories_rounded,
      DailyTaskPriority.scheduledChazara => Icons.history_rounded,
      DailyTaskPriority.newLearning => Icons.auto_stories_rounded,
    };
  }
}

class _BrowseSection extends StatelessWidget {
  const _BrowseSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.learnBrowseSectionTitle,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 36,
          ),
        ),
        const SizedBox(height: 12),
        ...CurriculumId.values.map(
          (curriculum) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _CurriculumBrowseCard(curriculum: curriculum),
          ),
        ),
      ],
    );
  }
}

class _CurriculumBrowseCard extends StatelessWidget {
  const _CurriculumBrowseCard({required this.curriculum});

  final CurriculumId curriculum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = AppTheme.getCurriculumColor(curriculum);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.router.push(
          ContentHierarchyRoute(curriculumId: curriculum.storageKey),
        ),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.auto_stories_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: CurriculumLabel.curriculum(
                  curriculum,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: AppTheme.brandInk,
                  ),
                ),
              ),
              // AUD-learning-05 (AX-3 / IL-7 defect class): swap the glyph for
              // RTL so the "go to detail" chevron keeps pointing toward the
              // forward-navigation edge instead of back into the card. See
              // the matching comment on _LearnTaskCard's chevron above.
              Icon(
                Directionality.of(context) == TextDirection.rtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: const Color(0xFFA2A8B6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.brandBlue, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppTheme.brandInkMuted,
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
