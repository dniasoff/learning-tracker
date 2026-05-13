import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/journey_completion_row.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/milestone_badge.dart';

/// Grouped view: completions organized by curriculum → seder → unit.
class JourneyGroupedView extends StatelessWidget {
  const JourneyGroupedView({super.key, required this.viewModel});

  final JourneyViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: viewModel.curricula.length,
      itemBuilder: (context, index) {
        return _CurriculumSection(journey: viewModel.curricula[index]);
      },
    );
  }
}

class _CurriculumSection extends ConsumerWidget {
  const _CurriculumSection({required this.journey});

  final CurriculumJourney journey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = AppTheme.getCurriculumColor(journey.curriculumId);
    final progress = journey.totalUnitsAvailable > 0
        ? journey.uniqueUnitsCompleted / journey.totalUnitsAvailable
        : 0.0;

    // Group completions by unit identifier
    final groupedByUnit = <String, List<UnitCompletion>>{};
    for (final completion in journey.completions) {
      groupedByUnit
          .putIfAbsent(completion.unitIdentifier, () => [])
          .add(completion);
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Curriculum header with progress bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CurriculumLabel.curriculum(
                  journey.curriculumId,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${journey.uniqueUnitsCompleted} of ${journey.totalUnitsAvailable} units completed',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: color.withValues(alpha: 0.15),
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          // Milestone badges
          if (journey.milestones.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: journey.milestones
                    .map((m) => MilestoneBadge(milestone: m))
                    .toList(),
              ),
            ),

          // Unit completions — use shared JourneyCompletionRow
          if (groupedByUnit.isNotEmpty)
            ...groupedByUnit.entries.map(
              (entry) => _UnitCompletionTile(
                completions: entry.value,
                curriculumId: journey.curriculumId,
                curriculumColor: color,
              ),
            ),

          if (journey.completions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'No completions yet',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnitCompletionTile extends StatelessWidget {
  const _UnitCompletionTile({
    required this.completions,
    required this.curriculumId,
    required this.curriculumColor,
  });

  final List<UnitCompletion> completions;
  final CurriculumId curriculumId;
  final Color curriculumColor;

  @override
  Widget build(BuildContext context) {
    final latestCompletion = completions.reduce(
      (a, b) => a.completedAt.isAfter(b.completedAt) ? a : b,
    );
    final count = completions.length;
    final suffix = count > 1 ? ' ($count completions)' : '';

    return JourneyCompletionRow(
      completion: latestCompletion,
      curriculumId: curriculumId,
      curriculumColor: curriculumColor,
      // Append count suffix to the label via a subtitle note when multiple.
      // We use dense=true for the grouped layout.
      subtitle: suffix.isNotEmpty ? suffix.trim() : null,
      dense: true,
    );
  }
}
