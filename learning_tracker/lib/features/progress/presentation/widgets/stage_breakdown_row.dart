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

    // Dedupe by resolved display name so each SRS stage label appears exactly
    // once. Two raw stage entries can collapse to the same display form — e.g.
    // a legacy "Learn"/"Limud" pair, a "Chazara 1"/"Review 1" alias pair, or
    // duplicate stage-definition rows. Without this, the expanded breakdown
    // rendered the same label twice (one Text per raw entry). We sum the counts
    // of all entries that resolve to the same label and preserve first-seen
    // order so the visible sequence (Limud → Chazara 1 → …) is stable.
    final orderedNames = <String>[];
    final countByName = <String, int>{};
    for (final entry in stageBreakdown) {
      final displayName = terms.resolveStoredStageName(entry.stageName);
      if (!countByName.containsKey(displayName)) {
        orderedNames.add(displayName);
      }
      countByName[displayName] = (countByName[displayName] ?? 0) + entry.count;
    }

    return Wrap(
      spacing: 16,
      runSpacing: 4,
      children: orderedNames.map((displayName) {
        return Text(
          '$displayName: ${countByName[displayName]}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      }).toList(),
    );
  }
}
