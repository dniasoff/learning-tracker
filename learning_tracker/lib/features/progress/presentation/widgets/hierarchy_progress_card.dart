import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/stage_breakdown_row.dart';

/// Expandable card showing progress for a hierarchy level.
///
/// Shows level name, progress bar, completion stats. Tapping expands to
/// show sub-levels with their own progress bars.
class HierarchyProgressCard extends StatelessWidget {
  const HierarchyProgressCard({
    super.key,
    required this.level,
    this.curriculumColor,
  });

  final HierarchyLevelProgress level;
  final Color? curriculumColor;

  @override
  Widget build(BuildContext context) {
    final hasSubLevels = level.subLevels != null && level.subLevels!.isNotEmpty;
    final color = curriculumColor ?? Theme.of(context).colorScheme.primary;

    if (hasSubLevels) {
      return _ExpandableHierarchyCard(level: level, color: color);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: _LevelContent(level: level, color: color),
      ),
    );
  }
}

class _ExpandableHierarchyCard extends StatelessWidget {
  const _ExpandableHierarchyCard({required this.level, required this.color});

  final HierarchyLevelProgress level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ExpansionTile(
        title: Text(
          level.levelName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: _ProgressSummaryLine(level: level),
        leading: _ProgressCircle(
          percentage: level.completionPercentage,
          color: color,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StageBreakdownRow(stageBreakdown: level.stageBreakdown),
                const SizedBox(height: 4),
                _TrackBreakdownLine(trackBreakdown: level.trackBreakdown),
                if (level.subLevels != null) ...[
                  const Divider(),
                  ...level.subLevels!.map(
                    (sub) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _LevelContent(level: sub, color: color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelContent extends StatelessWidget {
  const _LevelContent({required this.level, required this.color});

  final HierarchyLevelProgress level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _ProgressCircle(
              percentage: level.completionPercentage,
              color: color,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    level.levelName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  _ProgressSummaryLine(level: level),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: level.completionPercentage,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 8),
        StageBreakdownRow(stageBreakdown: level.stageBreakdown),
        const SizedBox(height: 4),
        _TrackBreakdownLine(trackBreakdown: level.trackBreakdown),
      ],
    );
  }
}

class _ProgressSummaryLine extends StatelessWidget {
  const _ProgressSummaryLine({required this.level});

  final HierarchyLevelProgress level;

  @override
  Widget build(BuildContext context) {
    final pct = formatFractionAsPercent(level.completionPercentage);
    return Text(
      '${level.completedItems}/${level.totalItems} ($pct)',
      style: Theme.of(context).textTheme.bodySmall,
    );
  }
}

class _ProgressCircle extends StatelessWidget {
  const _ProgressCircle({required this.percentage, required this.color});

  final double percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: percentage,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            strokeWidth: 3,
          ),
          Text(
            formatFractionAsPercent(percentage),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _TrackBreakdownLine extends StatelessWidget {
  const _TrackBreakdownLine({required this.trackBreakdown});

  final Map<TrackType, int> trackBreakdown;

  @override
  Widget build(BuildContext context) {
    final nonZero = trackBreakdown.entries.where((e) => e.value > 0).toList();
    if (nonZero.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 12,
      children: nonZero.map((entry) {
        final color = AppTheme.getTrackColor(entry.key);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 4),
            Text(
              '${entry.key.displayNameEn}: ${entry.value}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }
}
