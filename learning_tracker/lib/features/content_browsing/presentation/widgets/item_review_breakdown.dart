import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Displays per-stage review counts for a content item (AC-5).
///
/// Shows "Stage Name: N" for each stage. Returns [SizedBox.shrink] if empty.
class ItemReviewBreakdown extends StatelessWidget {
  const ItemReviewBreakdown({
    super.key,
    required this.stageBreakdown,
    required this.stageNames,
  });

  /// Map of stageId -> count.
  final Map<int, int> stageBreakdown;

  /// Map of stageId -> stage display name.
  final Map<int, String> stageNames;

  @override
  Widget build(BuildContext context) {
    if (stageBreakdown.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final sortedEntries = stageBreakdown.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: sortedEntries.map((entry) {
        final name =
            stageNames[entry.key] ??
            l10n.itemReviewBreakdownStageFallback(entry.key);
        return Text(
          '$name: ${entry.value}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }
}
