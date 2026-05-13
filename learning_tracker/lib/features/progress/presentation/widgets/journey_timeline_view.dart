import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_completion_row.dart';

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
        allEntries.add(
          _TimelineEntry(
            completion: completion,
            curriculumId: curriculum.curriculumId,
          ),
        );
      }
    }

    // Sort by date descending
    allEntries.sort(
      (a, b) => b.completion.completedAt.compareTo(a.completion.completedAt),
    );

    if (allEntries.isEmpty) {
      return Center(
        child: Text(
          'No completions to show',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
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
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
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
  const _TimelineEntry({required this.completion, required this.curriculumId});

  final UnitCompletion completion;
  final CurriculumId curriculumId;
}

/// Timeline card — uses the shared [JourneyCompletionRow] and builds the
/// subtitle inline to avoid duplicating layout logic.
class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({required this.entry});

  final _TimelineEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppTheme.getCurriculumColor(entry.curriculumId);
    final completion = entry.completion;
    final date = completion.completedAt.toLocal();
    final formattedDate = '${date.day}/${date.month}/${date.year}';
    final ordinal = _ordinal(completion.completionNumber);
    final curriculumLabel = curriculumLabelText(
      ref,
      curriculum: entry.curriculumId,
    );
    final subtitle = '$curriculumLabel · $ordinal completion · $formattedDate';

    return JourneyCompletionRow(
      completion: completion,
      curriculumId: entry.curriculumId,
      curriculumColor: color,
      subtitle: subtitle,
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
