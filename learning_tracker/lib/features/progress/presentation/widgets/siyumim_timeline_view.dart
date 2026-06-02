import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyum_milestone_label.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/siyumim_grouped_view.dart'
    show formatMilestoneDate;
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Chronological view of all siyumim (unit + aggregate + curriculum) across
/// every curriculum, newest first, grouped by month.
///
/// Per the IA brief: timeline mode "flattens the hierarchy" — each
/// milestone is a peer row. The screen still distinguishes the three levels
/// via icon (star / workspace_premium / emoji_events) and the
/// per-curriculum accent colour.
class SiyumimTimelineView extends ConsumerWidget {
  const SiyumimTimelineView({super.key, required this.viewModel});

  final JourneyViewModel viewModel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Flatten every milestone, paired with its curriculum context.
    final entries = <_TimelineEntry>[];
    for (final curriculum in viewModel.curricula) {
      for (final milestone in curriculum.milestones) {
        entries.add(
          _TimelineEntry(
            milestone: milestone,
            curriculumId: curriculum.curriculumId,
          ),
        );
      }
    }

    if (entries.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        child: Text(
          l10n.siyumimEmptyState,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // Newest first.
    entries.sort(
      (a, b) => b.milestone.achievedAt.compareTo(a.milestone.achievedAt),
    );

    // Group by month.
    final byMonth = <String, List<_TimelineEntry>>{};
    for (final entry in entries) {
      final key = _monthKey(entry.milestone.achievedAt);
      byMonth.putIfAbsent(key, () => []).add(entry);
    }

    final months = byMonth.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: months.length,
      itemBuilder: (context, idx) {
        final month = months[idx];
        final monthEntries = byMonth[month]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                month,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            for (final e in monthEntries) _TimelineCard(entry: e),
          ],
        );
      },
    );
  }

  static String _monthKey(DateTime date) {
    const months = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month]} ${date.year}';
  }
}

class _TimelineEntry {
  const _TimelineEntry({required this.milestone, required this.curriculumId});

  final MilestoneAchievement milestone;
  final CurriculumId curriculumId;
}

class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppTheme.getCurriculumColor(entry.curriculumId);
    final terms = domainTermLabels(ref);
    final m = entry.milestone;

    // Pick icon by level.
    late final IconData icon;
    late final String label;
    switch (m.level) {
      case MilestoneLevel.curriculum:
        icon = Icons.emoji_events;
        label = curriculumCompleteSiyumLabel(
          curriculumId: entry.curriculumId,
          terms: terms,
        );
      case MilestoneLevel.aggregate:
        icon = Icons.workspace_premium;
        label = aggregateSiyumLabel(
          curriculumId: entry.curriculumId,
          aggregateName: m.aggregateKey ?? m.displayName,
          terms: terms,
        );
      case MilestoneLevel.unit:
        icon = Icons.star;
        label = unitSiyumLabel(
          unitName: m.unitKey ?? m.displayName,
          unitScope: m.unitScope ?? 'masechta',
          terms: terms,
        );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            CurriculumLabel.curriculum(
              entry.curriculumId,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              ' · ${formatMilestoneDate(context, m.achievedAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
