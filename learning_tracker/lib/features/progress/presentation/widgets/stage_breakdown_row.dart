import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';

/// Displays stage breakdown as "Learned: X, Chazara 1: Y, Chazara 2: Z".
///
/// Stage names stored in the DB may be in Hebrew or English (legacy). This
/// widget resolves them through [DomainTermLabels.resolveStoredStageName] so
/// the breakdown re-renders live when the Hebrew Terms toggle changes (§8).
class StageBreakdownRow extends ConsumerWidget {
  const StageBreakdownRow({super.key, required this.stageBreakdown});

  final List<StageBreakdownEntry> stageBreakdown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stageBreakdown.isEmpty) {
      return const SizedBox.shrink();
    }

    final terms = domainTermLabels(ref);
    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: stageBreakdown.map((entry) {
        final displayName = terms.resolveStoredStageName(entry.stageName);
        return Text(
          '$displayName: ${entry.count}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }
}
