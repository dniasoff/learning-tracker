import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

/// Card shown on the Daily Tasks list. Tapping opens the text page;
/// the Mark Complete action lives on that page, not inline here.
class DailyTaskCard extends ConsumerWidget {
  const DailyTaskCard({
    required this.task,
    required this.onDismissed,
    required this.onCompleted,
    super.key,
  });

  final DailyTask task;
  final VoidCallback onDismissed;
  // Kept for call-site compatibility; invoked externally when a completion
  // happens on the text page and the list should refresh.
  final VoidCallback onCompleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final curriculumColor = AppTheme.getCurriculumColor(task.curriculumId);
    final stageLabel = task.stageName;
    final xp = task.estimatedEffortMinutes * 3;

    return Dismissible(
      key: ValueKey(
        'dismiss_${task.curriculumId.storageKey}_'
        '${task.contentItemSefariaRef}_${task.stageOrder}',
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: theme.colorScheme.outline.withValues(alpha: 0.2),
        child: Icon(
          Icons.skip_next_rounded,
          color: theme.colorScheme.onSurface,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(28),
          onTap: () => context.router.push(
            TextDisplayRoute(sefariaRef: task.contentItemSefariaRef),
          ),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.brandInk.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 104,
                  decoration: BoxDecoration(
                    color: curriculumColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              task.contentItemSefariaRef.replaceAll('_', ' '),
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppTheme.brandInk,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (task.isOverdue)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF26666),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Overdue',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: curriculumColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              task.curriculumId.displayNameHe,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: curriculumColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            stageLabel,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.brandInkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(
                            Icons.timer_outlined,
                            size: 16,
                            color: AppTheme.brandInkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${task.estimatedEffortMinutes}m',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.brandInkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.stars_rounded,
                            size: 16,
                            color: AppTheme.brandInkMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+$xp XP',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.brandInkMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
