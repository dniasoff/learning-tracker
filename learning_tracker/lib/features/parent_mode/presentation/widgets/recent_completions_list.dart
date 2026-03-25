import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';

/// List of recent completion items (last 7 days).
class RecentCompletionsList extends StatelessWidget {
  final List<RecentCompletion> completions;

  const RecentCompletionsList({super.key, required this.completions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalCount = completions.length;
    final displayedCompletions = completions.take(20).toList();

    return Card(
      child: Column(
        children: [
          ...displayedCompletions.map((c) {
            final curriculum = CurriculumId.values
                .where((cid) => cid.storageKey == c.curriculumId)
                .firstOrNull;
            final curriculumName =
                curriculum?.displayNameEn ?? c.curriculumId;
            final curriculumColor = curriculum != null
                ? AppTheme.getCurriculumColor(curriculum)
                : theme.colorScheme.primary;
            final localDate = c.completedAt.toLocal();
            final dateStr =
                '${localDate.month}/${localDate.day} ${localDate.hour}:${localDate.minute.toString().padLeft(2, '0')}';

            return ListTile(
              dense: true,
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: curriculumColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.check_circle_outline,
                  color: curriculumColor,
                  size: 18,
                ),
              ),
              title: Text(
                c.sefariaRef,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
              subtitle: Text(
                '$curriculumName - $dateStr',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: c.points > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '+${c.points}',
                        style: const TextStyle(
                          color: Colors.amber,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    )
                  : null,
            );
          }),
          if (totalCount > 20)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Showing 20 of $totalCount',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
