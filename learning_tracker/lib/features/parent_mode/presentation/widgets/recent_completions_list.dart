import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/parent_mode/domain/services/parent_dashboard_aggregator.dart';

/// List of recent completion items (last 7 days).
class RecentCompletionsList extends StatelessWidget {
  final List<RecentCompletion> completions;

  const RecentCompletionsList({super.key, required this.completions});

  @override
  Widget build(BuildContext context) {
    final totalCount = completions.length;
    final displayedCompletions = completions.take(20).toList();

    return Card(
      child: Column(
        children: [
          ...displayedCompletions.map((c) {
            final curriculumName =
                CurriculumId.values
                    .where((cid) => cid.storageKey == c.curriculumId)
                    .map((cid) => cid.displayNameEn)
                    .firstOrNull ??
                c.curriculumId;
            final localDate = c.completedAt.toLocal();
            final dateStr =
                '${localDate.month}/${localDate.day} ${localDate.hour}:${localDate.minute.toString().padLeft(2, '0')}';

            return ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle_outline, size: 20),
              title: Text(c.sefariaRef, overflow: TextOverflow.ellipsis),
              subtitle: Text('$curriculumName - $dateStr'),
              trailing: c.points > 0
                  ? Text(
                      '+${c.points}',
                      style: TextStyle(
                        color: Colors.amber.shade700,
                        fontWeight: FontWeight.w600,
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
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
