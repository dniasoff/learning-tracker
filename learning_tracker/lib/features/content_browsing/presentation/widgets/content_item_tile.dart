import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/learning/presentation/providers/completion_providers.dart';

/// Displays a single content item in the hierarchy browser.
///
/// Shows Hebrew and English names, with completion status indicators.
class ContentItemTile extends ConsumerWidget {
  const ContentItemTile({
    super.key,
    required this.item,
    required this.curriculum,
    required this.onTap,
  });

  final ContentItem item;
  final CurriculumId curriculum;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    // Watch completion count for this item.
    final completionsAsync = ref.watch(
      completionCountProvider(
        curriculumId: curriculum.storageKey,
        sefariaRef: item.sefariaRef,
      ),
    );
    final completionCount = completionsAsync.value ?? 0;

    return ListTile(
      leading: _buildLeadingIcon(theme, completionCount),
      title: Text(
        item.displayNameHe,
        style: theme.textTheme.titleMedium?.copyWith(
          fontFamily: 'Noto Sans Hebrew',
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.right,
      ),
      subtitle: Text(
        item.displayNameEn,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      trailing: _buildTrailing(theme, completionCount),
      onTap: onTap,
    );
  }

  Widget _buildLeadingIcon(ThemeData theme, int completionCount) {
    if (item.isLeaf) {
      // Leaf items show completion status icon based on actual completion data.
      final isCompleted = completionCount > 0;
      return Icon(
        isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isCompleted
            ? theme.colorScheme.primary
            : theme.colorScheme.outline,
      );
    } else {
      // Container items show folder icon.
      return Icon(Icons.folder, color: theme.colorScheme.primary);
    }
  }

  Widget? _buildTrailing(ThemeData theme, int completionCount) {
    if (item.isLeaf) {
      // Show completion count badge if item has been completed at least once.
      if (completionCount > 0) {
        return StageCompletionIndicators(
          stages: {for (var i = 0; i < completionCount; i++) i: true},
        );
      }
      return null;
    } else {
      // Container items show chevron for drill-down.
      return Icon(
        Icons.chevron_right,
        color: theme.colorScheme.onSurfaceVariant,
      );
    }
  }
}

/// Widget showing per-stage completion status for a leaf item.
///
/// Example: [✓ Learn] [○ Review] [○ Chazara]
class StageCompletionIndicators extends StatelessWidget {
  const StageCompletionIndicators({super.key, required this.stages});

  /// Map of stage ID to completion status.
  final Map<int, bool> stages;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: stages.entries.map((entry) {
        final isComplete = entry.value;
        return Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Icon(
            isComplete ? Icons.check_circle : Icons.circle_outlined,
            size: 16,
            color: isComplete
                ? theme.colorScheme.primary
                : theme.colorScheme.outline,
          ),
        );
      }).toList(),
    );
  }
}

/// Widget showing aggregate completion percentage for a container.
///
/// Example: "30%" with progress indicator
class AggregateCompletionIndicator extends StatelessWidget {
  const AggregateCompletionIndicator({super.key, required this.percentage});

  final double percentage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        SizedBox(
          width: 40,
          height: 4,
          child: LinearProgressIndicator(
            value: percentage / 100,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
          ),
        ),
      ],
    );
  }
}
