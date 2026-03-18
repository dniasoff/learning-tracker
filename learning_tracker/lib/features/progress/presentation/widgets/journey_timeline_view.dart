import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/track_type_badge.dart';

/// Chronological timeline view of all completions, most recent first.
class JourneyTimelineView extends StatelessWidget {
  const JourneyTimelineView({super.key, required this.viewModel});

  final JourneyViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    // Collect all completions with their curriculum context
    final allEntries = <_TimelineEntry>[];
    for (final curriculum in viewModel.curricula) {
      for (final completion in curriculum.completions) {
        allEntries.add(_TimelineEntry(
          completion: completion,
          curriculumId: curriculum.curriculumId,
        ));
      }
    }

    // Sort by date descending
    allEntries.sort(
      (a, b) => b.completion.completedAt.compareTo(a.completion.completedAt),
    );

    if (allEntries.isEmpty) {
      return const Center(
        child: Text('No completions to show', style: TextStyle(color: Colors.grey)),
      );
    }

    // Group by month
    final grouped = <String, List<_TimelineEntry>>{};
    for (final entry in allEntries) {
      final key = _monthKey(entry.completion.completedAt);
      grouped.putIfAbsent(key, () => []).add(entry);
    }

    final months = grouped.keys.toList();

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: months.length,
      itemBuilder: (context, index) {
        final month = months[index];
        final entries = grouped[month]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month header
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                month,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...entries.map((e) => _TimelineCard(entry: e)),
          ],
        );
      },
    );
  }

  String _monthKey(DateTime date) {
    const months = [
      '', 'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return '${months[date.month]} ${date.year}';
  }
}

class _TimelineEntry {
  const _TimelineEntry({
    required this.completion,
    required this.curriculumId,
  });

  final UnitCompletion completion;
  final CurriculumId curriculumId;
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCurriculumColor(entry.curriculumId);
    final completion = entry.completion;
    final date = completion.completedAt.toLocal();
    final formattedDate = '${date.day}/${date.month}/${date.year}';
    final ordinal = _ordinal(completion.completionNumber);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 8,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        title: Text(
          completion.displayNameEn,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        subtitle: Row(
          children: [
            Text(
              '${entry.curriculumId.displayNameEn} · $ordinal completion · $formattedDate',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: TrackTypeBadge(trackType: completion.trackType),
      ),
    );
  }

  String _ordinal(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
    return switch (n % 10) {
      1 => '${n}st',
      2 => '${n}nd',
      3 => '${n}rd',
      _ => '${n}th',
    };
  }
}
