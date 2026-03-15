import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_request.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';

class DailyTaskCard extends ConsumerStatefulWidget {
  const DailyTaskCard({
    required this.task,
    required this.onDismissed,
    required this.onCompleted,
    super.key,
  });

  final DailyTask task;
  final VoidCallback onDismissed;
  final VoidCallback onCompleted;

  @override
  ConsumerState<DailyTaskCard> createState() => _DailyTaskCardState();
}

class _DailyTaskCardState extends ConsumerState<DailyTaskCard> {
  bool _isLoading = false;

  Future<void> _handleMarkComplete() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      final useCase = ref.read(markCompletionUseCaseProvider);
      final request = CompletionRequest(
        curriculumId: widget.task.curriculumId.storageKey,
        sefariaRef: widget.task.contentItemSefariaRef,
        stageId: widget.task.stageDefinitionId,
        trackType: TrackType.personal.storageKey,
      );
      await useCase(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Marked as complete'),
              ],
            ),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onCompleted();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark complete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final theme = Theme.of(context);
    final curriculumColor = AppTheme.getCurriculumColor(task.curriculumId);

    final stageLabel = task.stageOrder == 1 ? 'Learn' : task.stageName;

    return Dismissible(
      key: ValueKey(
        'dismiss_${task.curriculumId.storageKey}_'
        '${task.contentItemSefariaRef}_${task.stageOrder}',
      ),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => widget.onDismissed(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: theme.colorScheme.outline.withValues(alpha: 0.2),
        child: Icon(Icons.skip_next, color: theme.colorScheme.onSurface),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Curriculum color indicator
              Container(
                width: 4,
                height: 48,
                decoration: BoxDecoration(
                  color: curriculumColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.contentItemSefariaRef.replaceAll('_', ' '),
                            style: theme.textTheme.titleSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (task.isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Overdue',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.error,
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
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: curriculumColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            task.curriculumId.displayNameEn,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: curriculumColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          stageLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.timer_outlined,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          '${task.estimatedEffortMinutes}m',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Mark complete button
              _isLoading
                  ? const SizedBox(
                      width: 36,
                      height: 36,
                      child: Padding(
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.check_circle_outline),
                      tooltip: 'Mark as done',
                      onPressed: _handleMarkComplete,
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
