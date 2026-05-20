import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_schedule_composer.dart';
import 'package:learning_tracker/features/scheduler/presentation/widgets/daily_task_card.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Displays composed daily tasks organized by curriculum with collapsible
/// sections.
class GroupedDailyView extends ConsumerWidget {
  const GroupedDailyView({
    required this.schedule,
    required this.onTaskDismissed,
    required this.onTaskCompleted,
    super.key,
  });

  final ComposedDailySchedule schedule;
  final void Function(CurriculumId curriculum, int taskIndex) onTaskDismissed;
  final void Function(CurriculumId curriculum, int taskIndex) onTaskCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = schedule.groupedByCurriculum;

    if (grouped.isEmpty) {
      return Center(child: Text(AppLocalizations.of(context)!.noTasksForToday));
    }

    // Canonical Jewish-learning order — never alphabetical. The
    // CurriculumId enum's declaration order is the source of truth.
    final curricula = grouped.keys.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: curricula.map((curriculum) {
        final tasks = grouped[curriculum]!;
        final color = AppTheme.getCurriculumColor(curriculum);

        return ExpansionTile(
          key: ValueKey('group_${curriculum.storageKey}'),
          initiallyExpanded: true,
          leading: CircleAvatar(backgroundColor: color, radius: 8),
          title: Text(
            '${curriculumLabelText(ref, curriculum: curriculum)} '
            '(${tasks.length})',
          ),
          children: List.generate(tasks.length, (i) {
            final task = tasks[i];
            return DailyTaskCard(
              key: ValueKey(
                'grouped_${task.curriculumId.storageKey}_'
                '${task.contentItemSefariaRef}_${task.stageOrder}',
              ),
              task: task,
              onDismissed: () => onTaskDismissed(curriculum, i),
              onCompleted: () => onTaskCompleted(curriculum, i),
            );
          }),
        );
      }).toList(),
    );
  }
}
