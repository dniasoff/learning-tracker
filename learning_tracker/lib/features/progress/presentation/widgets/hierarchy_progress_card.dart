import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/stage_breakdown_row.dart';

/// Expandable card showing progress for a hierarchy level.
///
/// Shows level name, progress bar, completion stats. Tapping expands to
/// show sub-levels with their own progress bars.
class HierarchyProgressCard extends ConsumerWidget {
  const HierarchyProgressCard({
    super.key,
    required this.level,
    this.curriculumColor,
  });

  final HierarchyLevelProgress level;
  final Color? curriculumColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSubLevels = level.subLevels != null && level.subLevels!.isNotEmpty;
    final color = curriculumColor ?? Theme.of(context).colorScheme.primary;

    if (hasSubLevels) {
      return _ExpandableHierarchyCard(level: level, color: color);
    }

    return _HierarchySurfaceCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: _LevelContent(level: level, color: color),
      ),
    );
  }
}

class _HierarchySurfaceCard extends StatelessWidget {
  const _HierarchySurfaceCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppTheme.brandOutline.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ExpandableHierarchyCard extends StatelessWidget {
  const _ExpandableHierarchyCard({required this.level, required this.color});

  final HierarchyLevelProgress level;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _HierarchySurfaceCard(
      child: Theme(
        data: theme.copyWith(
          dividerTheme: DividerThemeData(
            color: AppTheme.brandOutline.withValues(alpha: 0.4),
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            childrenPadding: EdgeInsets.zero,
            shape: const Border(),
            collapsedShape: const Border(),
            title: Text(
              level.levelName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: AppTheme.brandInk,
              ),
            ),
            subtitle: _ProgressSummaryLine(level: level),
            leading: _ProgressCircle(
              percentage: level.completionPercentage,
              color: color,
            ),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StageBreakdownRow(stageBreakdown: level.stageBreakdown),
                    if (level.subLevels != null) ...[
                      Divider(
                        height: 20,
                        color: AppTheme.brandOutline.withValues(alpha: 0.45),
                      ),
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
        ),
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
    final theme = Theme.of(context);
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
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.brandInk,
                    ),
                  ),
                  _ProgressSummaryLine(level: level),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: level.completionPercentage,
            backgroundColor: AppTheme.brandCreamSoft,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 8,
          ),
        ),
        const SizedBox(height: 8),
        StageBreakdownRow(stageBreakdown: level.stageBreakdown),
      ],
    );
  }
}

class _ProgressSummaryLine extends ConsumerWidget {
  const _ProgressSummaryLine({required this.level});

  final HierarchyLevelProgress level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pct = formatFractionAsPercent(level.completionPercentage);
    final terms = domainTermLabels(ref);
    // Chazara entries are those after the first (stageOrder > 0).
    // For single-stage tracks the breakdown has only one entry (the learn
    // stage), so the chazaros suffix is omitted entirely (Rule 8).
    final chazaraEntries = level.stageBreakdown.length > 1
        ? level.stageBreakdown.skip(1).toList()
        : const <StageBreakdownEntry>[];
    final chazarosCount = chazaraEntries.fold<int>(
      0,
      (sum, entry) => sum + entry.count,
    );
    final hasChazara = chazaraEntries.isNotEmpty;
    final baseText = '${level.completedItems}/${level.totalItems} ($pct)';
    return Text(
      hasChazara
          ? '$baseText · $chazarosCount ${terms.chazaros.toLowerCase()}'
          : baseText,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: AppTheme.brandInkMuted,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ProgressCircle extends StatelessWidget {
  const _ProgressCircle({required this.percentage, required this.color});

  final double percentage;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final label = formatFractionAsPercent(percentage);
    final textStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontSize: 9,
      fontWeight: FontWeight.w800,
      height: 1.0,
      letterSpacing: -0.15,
      color: AppTheme.brandInk,
    );

    return SizedBox(
      width: 40,
      height: 40,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              value: percentage,
              backgroundColor: color.withValues(alpha: 0.15),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              strokeWidth: 3,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                textHeightBehavior: const TextHeightBehavior(
                  applyHeightToFirstAscent: false,
                  applyHeightToLastDescent: false,
                ),
                style: textStyle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

