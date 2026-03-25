import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/milestone_badge.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/track_type_badge.dart';

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

class _CurriculumSection extends StatelessWidget {
  const _CurriculumSection({required this.journey});

  final CurriculumJourney journey;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCurriculumColor(journey.curriculumId);
    final progress = journey.totalUnitsAvailable > 0
        ? journey.uniqueUnitsCompleted / journey.totalUnitsAvailable
        : 0.0;

    // Group completions by unit type/seder (level1 grouping via unitIdentifier)
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
                Text(
                  journey.curriculumId.displayNameEn,
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

          // Unit completions
          if (groupedByUnit.isNotEmpty)
            ...groupedByUnit.entries.map(
              (entry) => _UnitCompletionTile(
                unitName: entry.value.first.displayNameEn,
                unitNameHe: entry.value.first.displayNameHe,
                completions: entry.value,
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
    required this.unitName,
    required this.unitNameHe,
    required this.completions,
    required this.curriculumColor,
  });

  final String unitName;
  final String unitNameHe;
  final List<UnitCompletion> completions;
  final Color curriculumColor;

  @override
  Widget build(BuildContext context) {
    final latestCompletion = completions.reduce(
      (a, b) => a.completedAt.isAfter(b.completedAt) ? a : b,
    );
    final count = completions.length;
    final suffix = count > 1 ? ' ($count completions)' : '';

    return ListTile(
      dense: true,
      leading: Container(
        width: 4,
        height: 32,
        decoration: BoxDecoration(
          color: curriculumColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              '$unitName$suffix',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          TrackTypeBadge(trackType: latestCompletion.trackType),
        ],
      ),
      subtitle: Text(unitNameHe, style: const TextStyle(fontSize: 12)),
    );
  }
}
