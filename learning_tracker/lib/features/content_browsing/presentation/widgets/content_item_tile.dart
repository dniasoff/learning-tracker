import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Displays a single content item in the hierarchy browser.
///
/// Shows Hebrew and English names, with completion status indicators.
class ContentItemTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: _buildLeadingIcon(theme),
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
      trailing: _buildTrailing(theme),
      onTap: onTap,
    );
  }

  Widget _buildLeadingIcon(ThemeData theme) {
    if (item.isLeaf) {
      // Leaf items show completion status icon
      // TODO: Integrate with real completion data
      return Icon(
        Icons.radio_button_unchecked,
        color: theme.colorScheme.outline,
      );
    } else {
      // Container items show folder icon
      return Icon(Icons.folder, color: theme.colorScheme.primary);
    }
  }

  Widget? _buildTrailing(ThemeData theme) {
    if (item.isLeaf) {
      // Leaf items might show per-stage completion indicators
      // TODO: Implement per-stage indicators (e.g., learn, review, chazara)
      return null;
    } else {
      // Container items show chevron for drill-down
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
