import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_schedule_composer.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Displays composed daily tasks organized by curriculum with collapsible
/// sections.
///
/// AUD-scheduler-01 (PF-2): built on a [CustomScrollView] with one
/// [SliverToBoxAdapter] section header per curriculum followed by a lazily
/// windowed [SliverList] for that curriculum's tasks — mirroring the
/// SliverList/SliverChildBuilderDelegate pattern `gamification_screen.dart`
/// already uses for its own unbounded list. Only on-screen [DailyTaskCard]s
/// are realized, however large a single curriculum's task backlog grows
/// (e.g. a lapsed user's overdue queue across weeks) — never the previous
/// `List.generate(tasks.length, ...)` feeding a non-lazy `ExpansionTile`,
/// which built every card in an expanded section up front regardless of
/// viewport.
class GroupedDailyView extends ConsumerStatefulWidget {
  const GroupedDailyView({
    required this.schedule,
    required this.onTaskDismissed,
    super.key,
  });

  final ComposedDailySchedule schedule;
  final void Function(CurriculumId curriculum, int taskIndex) onTaskDismissed;

  @override
  ConsumerState<GroupedDailyView> createState() => _GroupedDailyViewState();
}

class _GroupedDailyViewState extends ConsumerState<GroupedDailyView> {
  /// Curricula the user has manually collapsed this session. Every
  /// curriculum starts expanded — matching the previous
  /// `ExpansionTile(initiallyExpanded: true)` default — so a curriculum's
  /// presence here (rather than a boolean per curriculum) means "collapsed".
  final Set<CurriculumId> _collapsed = <CurriculumId>{};

  @override
  Widget build(BuildContext context) {
    final grouped = widget.schedule.groupedByCurriculum;

    if (grouped.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noTasksForToday));
    }

    // Canonical Jewish-learning order — never alphabetical. The
    // CurriculumId enum's declaration order is the source of truth.
    final curricula = grouped.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        for (final curriculum in curricula)
          ..._buildCurriculumSection(curriculum, grouped[curriculum]!),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
      ],
    );
  }

  List<Widget> _buildCurriculumSection(
    CurriculumId curriculum,
    List<DailyTask> tasks,
  ) {
    final expanded = !_collapsed.contains(curriculum);
    final color = AppTheme.getCurriculumColor(curriculum);
    final label =
        '${curriculumLabelText(ref, curriculum: curriculum)} '
        '(${tasks.length})';

    return [
      SliverToBoxAdapter(
        child: _CurriculumSectionHeader(
          key: ValueKey('group_${curriculum.storageKey}'),
          color: color,
          label: label,
          expanded: expanded,
          onTap: () => setState(() {
            if (expanded) {
              _collapsed.add(curriculum);
            } else {
              _collapsed.remove(curriculum);
            }
          }),
        ),
      ),
      if (expanded)
        SliverList(
          delegate: SliverChildBuilderDelegate((context, i) {
            final task = tasks[i];
            return DailyTaskCard(
              key: ValueKey(
                'grouped_${task.curriculumId.storageKey}_'
                '${task.contentItemSefariaRef}_${task.stageOrder}',
              ),
              task: task,
              onDismissed: () => widget.onTaskDismissed(curriculum, i),
            );
          }, childCount: tasks.length),
        ),
    ];
  }
}

/// Tappable curriculum section header — the sliver-based replacement for
/// `ExpansionTile`'s built-in header, since `ExpansionTile` itself is not
/// used here (its `children:` list has no virtualization; see the
/// class-level doc on [GroupedDailyView]).
class _CurriculumSectionHeader extends StatelessWidget {
  const _CurriculumSectionHeader({
    required this.color,
    required this.label,
    required this.expanded,
    required this.onTap,
    super.key,
  });

  final Color color;
  final String label;
  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(backgroundColor: color, radius: 8),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Icon(expanded ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }
}
