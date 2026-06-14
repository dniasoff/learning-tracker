import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/presentation/providers/scheduler_providers.dart';

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
    final stageLabel = domainTermLabels(
      ref,
    ).resolveStoredStageName(task.stageName);

    return Dismissible(
      key: ValueKey(
        'dismiss_${task.curriculumId.storageKey}_'
        '${task.contentItemSefariaRef}_${task.stageOrder}',
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismissed(),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
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
                            child: Builder(
                              builder: (_) {
                                // Single label renderer — same path as the
                                // reader's AppBar and the browse screen rows.
                                var label =
                                    ref
                                        .watch(
                                          renderedDisplayForRefProvider(
                                            task.contentItemSefariaRef,
                                          ),
                                        )
                                        .asData
                                        ?.value ??
                                    task.contentItemSefariaRef.replaceAll(
                                      '_',
                                      ' ',
                                    );
                                // 2b: for a daf-paced (coarse) track the card
                                // represents the whole daf, so show the daf —
                                // the seeded day label if present, else collapse
                                // the trailing amud off the breadcrumb.
                                final coarseIds = ref
                                    .watch(coarsePacedTrackIdsProvider)
                                    .asData
                                    ?.value;
                                if (coarseIds != null &&
                                    coarseIds.contains(task.trackId)) {
                                  final useHebrew = domainTermLabels(
                                    ref,
                                  ).isHebrew;
                                  final seeded = useHebrew
                                      ? task.unitDisplayHe
                                      : task.unitDisplayEn;
                                  label = (seeded != null && seeded.isNotEmpty)
                                      ? seeded
                                      : collapseAmudLeaf(label);
                                }
                                return Text(
                                  label,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: AppTheme.brandInk,
                                      ),
                                  overflow: TextOverflow.ellipsis,
                                );
                              },
                            ),
                          ),
                          if (task.isOverdue)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.statusDanger,
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
                            child: CurriculumLabel.curriculum(
                              task.curriculumId,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: curriculumColor,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              stageLabel,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppTheme.brandInkMuted,
                                fontWeight: FontWeight.w600,
                              ),
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
