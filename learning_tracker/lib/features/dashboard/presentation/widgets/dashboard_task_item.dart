import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/curriculum_label_providers.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Individual task item card for the dashboard task list.
class DashboardTaskItem extends ConsumerWidget {
  const DashboardTaskItem({
    super.key,
    required this.task,
    required this.showTrackLabel,
    this.onComplete,
  });

  final DailyTask task;
  final bool showTrackLabel;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final borderColor = task.isOverdue
        ? theme.colorScheme.error
        : AppTheme.getCurriculumColor(task.curriculumId);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {}, // Navigate to learning screen
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: borderColor, width: 4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Line 1: [trackLabel · ] rendered display name
                    // Renderer-driven: matches reader, browse rows, and
                    // daily task card.
                    Builder(
                      builder: (_) {
                        final display =
                            ref
                                .watch(
                                  renderedDisplayForRefProvider(
                                    task.contentItemSefariaRef,
                                  ),
                                )
                                .asData
                                ?.value ??
                            task.contentItemSefariaRef.replaceAll('_', ' ');
                        return Text(
                          showTrackLabel
                              ? '${task.trackLabel} · $display'
                              : display,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    // Line 2: stageName [· N day(s) overdue]
                    _buildSubtitle(context, theme),
                  ],
                ),
              ),
              // Quick-complete button
              IconButton(
                icon: Icon(
                  Icons.check_circle_outline,
                  color: theme.colorScheme.primary,
                ),
                onPressed: onComplete,
                tooltip: 'Mark complete',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(BuildContext context, ThemeData theme) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer(
      builder: (context, ref, _) {
        final terms = domainTermLabels(ref);
        final chazaraReviewLabel = terms.chazara;
        final resolvedStageName = terms.resolveStoredStageName(task.stageName);
        return _buildSubtitleInner(
          theme,
          l10n,
          chazaraReviewLabel,
          resolvedStageName,
        );
      },
    );
  }

  Widget _buildSubtitleInner(
    ThemeData theme,
    AppLocalizations l10n,
    String chazaraReviewLabel,
    String resolvedStageName,
  ) {
    final baseStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final overdueStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.error,
      fontWeight: FontWeight.w600,
    );
    final dueTodayStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.brandBlue,
      fontWeight: FontWeight.w600,
    );
    final reviewStyle = theme.textTheme.bodySmall?.copyWith(
      color: AppTheme.brandGoldDeep,
      fontWeight: FontWeight.w600,
    );

    final isReview =
        task.priority == DailyTaskPriority.overdueChazara ||
        task.priority == DailyTaskPriority.scheduledChazara;
    final showDueToday =
        !task.isOverdue &&
        (task.priority == DailyTaskPriority.todayProgram ||
            task.priority == DailyTaskPriority.scheduledChazara);

    final suffixSpans = <InlineSpan>[];
    if (task.isOverdue) {
      suffixSpans.add(
        TextSpan(text: ' · ${l10n.overdue}', style: overdueStyle),
      );
    }
    if (showDueToday) {
      suffixSpans.add(
        TextSpan(text: ' · ${l10n.dueToday}', style: dueTodayStyle),
      );
    }
    if (isReview) {
      suffixSpans.add(
        TextSpan(text: ' · $chazaraReviewLabel', style: reviewStyle),
      );
    }

    if (suffixSpans.isEmpty) {
      return Text(resolvedStageName, style: baseStyle);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: resolvedStageName, style: baseStyle),
          ...suffixSpans,
        ],
      ),
    );
  }
}
