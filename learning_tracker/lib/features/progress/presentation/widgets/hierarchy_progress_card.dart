import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/curriculum_level_name.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/domain/models/curriculum_progress_data.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/learnt_tri_state.dart';
import 'package:learning_tracker/features/progress/presentation/widgets/stage_breakdown_row.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
        color: context.colors.brandCreamCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.brandOutline.withValues(alpha: 0.35),
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

class _ExpandableHierarchyCard extends ConsumerWidget {
  const _ExpandableHierarchyCard({required this.level, required this.color});

  final HierarchyLevelProgress level;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return _HierarchySurfaceCard(
      child: _TriStateNode(
        level: level,
        child: Theme(
          data: theme.copyWith(
            dividerTheme: DividerThemeData(
              color: context.colors.brandOutline.withValues(alpha: 0.4),
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
                renderCurriculumLevelName(
                  ref,
                  curriculumId: level.curriculumId,
                  level: level.level,
                  rawValue: level.levelName,
                ),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.colors.brandInk,
                ),
              ),
              subtitle: _ProgressSummaryLine(level: level),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ProgressCircle(
                    percentage: level.completionPercentage,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  LearntTriStateBox(
                    state: triStateFromCounts(
                      level.completedItems,
                      level.totalItems,
                    ),
                  ),
                ],
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
                          color: context.colors.brandOutline.withValues(
                            alpha: 0.45,
                          ),
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
      ),
    );
  }
}

class _LevelContent extends ConsumerWidget {
  const _LevelContent({required this.level, required this.color});

  final HierarchyLevelProgress level;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = triStateFromCounts(level.completedItems, level.totalItems);
    return _TriStateNode(
      level: level,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ProgressCircle(
                percentage: level.completionPercentage,
                color: color,
              ),
              const SizedBox(width: 12),
              LearntTriStateBox(state: state),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      renderCurriculumLevelName(
                        ref,
                        curriculumId: level.curriculumId,
                        level: level.level,
                        rawValue: level.levelName,
                      ),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: context.colors.brandInk,
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
              backgroundColor: context.colors.brandCreamSoft,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 8),
          StageBreakdownRow(stageBreakdown: level.stageBreakdown),
        ],
      ),
    );
  }
}

/// The FR-15 tri-state frame of one hierarchy node (DNI-474): a decorative
/// 12% state tint behind the node and a semantics label carrying the
/// state, count and name as text ("Berakhot, partial, 3 of 12 learnt").
class _TriStateNode extends ConsumerWidget {
  const _TriStateNode({required this.level, required this.child});

  final HierarchyLevelProgress level;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = triStateFromCounts(level.completedItems, level.totalItems);
    return Semantics(
      container: true,
      label: learntTriStateSemantics(
        l10n,
        name: renderCurriculumLevelName(
          ref,
          curriculumId: level.curriculumId,
          level: level.level,
          rawValue: level.levelName,
        ),
        state: state,
        learnt: level.completedItems,
        total: level.totalItems,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: learntTriStateColor(
            context,
            state,
          ).withValues(alpha: learntTriStateTintAlpha),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(padding: const EdgeInsets.all(6), child: child),
      ),
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
    // IL-2: the "chazaros" review-unit word must respect the Sephardi nusach in
    // English mode ("chazarot" not "chazaros"). Route it through the
    // variant-aware helper instead of the Ashkenazi-only [terms.chazaros]
    // getter. In Hebrew UI chazarosFor returns the locale-correct Hebrew form
    // (nusach-independent) so this stays correct there too.
    final variant = ref.watch(currentTransliterationVariantProvider);
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
          ? '$baseText · $chazarosCount '
                '${terms.chazarosFor(variant: variant).toLowerCase()}'
          : baseText,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: context.colors.brandInkMuted,
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
      color: context.colors.brandInk,
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
