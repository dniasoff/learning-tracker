import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Scrollable list of [CurriculumCompletionSummary] rows with expandable
/// per-curriculum tree views. Consumed by [LifetimeKnowledgeScreen].
///
/// When [showProvenance] is true, terminal nodes render a small
/// "how was this learned" label (e.g. "Live · 3 chazaros").
///
/// [shrinkWrap] / [physics] are forwarded to the inner [ListView] so callers
/// that embed the list inside another scroll view (e.g. the Lifetime
/// Knowledge screen which adds a header card above the list) can render
/// without nested-scroll friction.
class CurriculumBreakdownList extends StatefulWidget {
  const CurriculumBreakdownList({
    super.key,
    required this.summaries,
    this.showProvenance = false,
    this.shrinkWrap = false,
    this.physics,
    this.padding,
  });

  final List<CurriculumCompletionSummary> summaries;
  final bool showProvenance;
  final bool shrinkWrap;
  final ScrollPhysics? physics;
  final EdgeInsetsGeometry? padding;

  @override
  State<CurriculumBreakdownList> createState() =>
      _CurriculumBreakdownListState();
}

class _CurriculumBreakdownListState extends State<CurriculumBreakdownList> {
  final Set<CurriculumId> _expanded = {};
  final Map<String, bool> _treeExpanded = {};

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      padding: widget.padding ?? const EdgeInsets.fromLTRB(16, 8, 16, 32),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: widget.summaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final summary = widget.summaries[index];
        return _CurriculumCard(
          summary: summary,
          isExpanded: _expanded.contains(summary.curriculumId),
          treeExpanded: _treeExpanded,
          l10n: l10n,
          showProvenance: widget.showProvenance,
          onExpandToggle: () => setState(() {
            if (_expanded.contains(summary.curriculumId)) {
              _expanded.remove(summary.curriculumId);
            } else {
              _expanded.add(summary.curriculumId);
            }
          }),
          onTreeExpandToggle: (key, isExpanded) => setState(() {
            _treeExpanded[key] = isExpanded;
          }),
        );
      },
    );
  }
}

class _CurriculumCard extends ConsumerWidget {
  const _CurriculumCard({
    required this.summary,
    required this.isExpanded,
    required this.treeExpanded,
    required this.l10n,
    required this.showProvenance,
    required this.onExpandToggle,
    required this.onTreeExpandToggle,
  });

  final CurriculumCompletionSummary summary;
  final bool isExpanded;
  final Map<String, bool> treeExpanded;
  final AppLocalizations l10n;
  final bool showProvenance;
  final VoidCallback onExpandToggle;
  final void Function(String key, bool isExpanded) onTreeExpandToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final terms = domainTermLabels(ref);
    final theme = Theme.of(context);
    final curriculumColor = AppTheme.getCurriculumColorByKey(
      summary.curriculumId.storageKey,
    );
    final pct = summary.percentage;
    final pctText = formatFractionAsPercent(pct);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.brandCreamCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.brandOutline.withValues(alpha: 0.35),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onExpandToggle,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Progress circle
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: pct,
                            backgroundColor: curriculumColor.withValues(
                              alpha: 0.15,
                            ),
                            valueColor: AlwaysStoppedAnimation<Color>(
                              curriculumColor,
                            ),
                            strokeWidth: 3,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                          Text(
                            pctText,
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.brandInk,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CurriculumLabel.curriculum(
                            summary.curriculumId,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.brandInk,
                            ),
                          ),
                          if (!terms.isHebrew)
                            Text(
                              curriculumHebrewName(summary.curriculumId),
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppTheme.brandInkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          Text(
                            l10n.itemsLearnedOf(
                              summary.learnedLeafCount,
                              summary.totalLeafCount,
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppTheme.brandInkMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: AppTheme.brandInkMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: AppTheme.brandCreamSoft,
                    valueColor: AlwaysStoppedAnimation<Color>(curriculumColor),
                    minHeight: 6,
                  ),
                ),
                if (isExpanded && summary.tree.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  ..._buildTree(summary),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTree(CurriculumCompletionSummary summary) {
    return summary.tree.map((node) {
      final key = '${summary.curriculumId.storageKey}/0/${node.rawValue}';
      return CurriculumBreakdownTreeNode(
        node: node,
        depth: 0,
        nodeKey: key,
        expandedNodes: treeExpanded,
        onExpandToggle: onTreeExpandToggle,
        showProvenance: showProvenance,
      );
    }).toList();
  }
}

/// A single expandable tree node inside a curriculum breakdown card.
///
/// When [showProvenance] is true and the underlying [LifetimeTreeNode] carries
/// a [LifetimeLeafProvenance], a small label is rendered next to the leaf row
/// (e.g. "Live · 3 chazaros" / "Bulk-marked" / "Lifetime · imported"). The
/// label is suppressed on aggregating nodes — only terminal leaves surface
/// provenance.
class CurriculumBreakdownTreeNode extends ConsumerWidget {
  const CurriculumBreakdownTreeNode({
    super.key,
    required this.node,
    required this.depth,
    required this.nodeKey,
    required this.expandedNodes,
    required this.onExpandToggle,
    this.showProvenance = false,
  });

  final LifetimeTreeNode node;
  final int depth;
  final String nodeKey;
  final Map<String, bool> expandedNodes;
  final void Function(String key, bool isExpanded) onExpandToggle;

  /// When true and [node.provenance] is set, renders a per-leaf provenance
  /// label below the level label. Used by the Lifetime Knowledge screen; not
  /// used by older screens that only care about the tree state.
  final bool showProvenance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isExpanded = expandedNodes[nodeKey] ?? false;
    final hasChildren = node.children.isNotEmpty;
    final stateColor = _stateColor(node.state);
    final l10n = AppLocalizations.of(context)!;
    final terms = domainTermLabels(ref);

    final label = CurriculumLabel.level(
      curriculumId: node.curriculumId,
      level: node.level,
      rawValue: node.rawValue,
      parentL1Value: node.parentL1Value,
      hebrewName: node.hebrewName,
      style: theme.textTheme.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppTheme.brandInk,
      ),
    );

    final provenanceLabel =
        showProvenance && !hasChildren && node.provenance != null
        ? provenanceText(node.provenance!, l10n: l10n, terms: terms)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: hasChildren
              ? () => onExpandToggle(nodeKey, !isExpanded)
              : null,
          child: Padding(
            padding: EdgeInsets.only(
              left: depth * 16.0,
              top: 4,
              bottom: 4,
              right: 4,
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: stateColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(child: label),
                if (provenanceLabel != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    provenanceLabel,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppTheme.brandInkMuted,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
                if (hasChildren)
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: AppTheme.brandInkMuted,
                  ),
              ],
            ),
          ),
        ),
        if (isExpanded)
          ...node.children.map((child) {
            final childKey = '$nodeKey/${child.rawValue}';
            return CurriculumBreakdownTreeNode(
              node: child,
              depth: depth + 1,
              nodeKey: childKey,
              expandedNodes: expandedNodes,
              onExpandToggle: onExpandToggle,
              showProvenance: showProvenance,
            );
          }),
      ],
    );
  }

  Color _stateColor(LifetimeNodeState state) {
    switch (state) {
      case LifetimeNodeState.full:
        return AppTheme.brandGold;
      case LifetimeNodeState.partial:
        return AppTheme.brandBlue.withValues(alpha: 0.5);
      case LifetimeNodeState.none:
        return AppTheme.brandOutline;
    }
  }

  /// Renders a provenance label for the lifetime tier:
  ///   * live (chazaros = 0) → "Live" / "בלמידה"
  ///   * live (chazaros ≥ 1) → "Live · N chazaros" (the plural uses the
  ///     [DomainTermLabels.chazaros] term so the Hebrew Terms toggle swaps
  ///     the script: e.g. "Live · 3 חזרות" when the toggle is on)
  ///   * bulkMarked → "Bulk-marked" / "מסומן בקבוצה"
  ///   * lifetimeImported → "Lifetime · imported" / "ייבוא לכל החיים"
  ///
  /// Exposed (non-private) so widget tests can drive it through the same
  /// l10n + domain-term resolution the production widget uses without
  /// pumping the full ConsumerWidget. F9.
  @visibleForTesting
  static String provenanceText(
    LifetimeLeafProvenance p, {
    required AppLocalizations l10n,
    required DomainTermLabels terms,
  }) {
    switch (p.source) {
      case LifetimeLeafSource.live:
        final n = p.chazarosCount;
        if (n <= 0) return l10n.provenanceLive;
        // Build the "Live · N chazaros" string with the toggle-aware plural
        // so e.g. EN + Hebrew Terms ON renders "Live · 3 חזרות".
        return '${l10n.provenanceLive} · $n ${terms.chazaros}';
      case LifetimeLeafSource.bulkMarked:
        return l10n.provenanceBulkMarked;
      case LifetimeLeafSource.lifetimeImported:
        return l10n.provenanceLifetimeImported;
    }
  }
}
