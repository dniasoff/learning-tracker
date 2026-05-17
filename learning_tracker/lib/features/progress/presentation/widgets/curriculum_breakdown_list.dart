import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/presentation/providers/items_learned_providers.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Scrollable list of [CurriculumCompletionSummary] rows with expandable
/// per-curriculum tree views. Shared between [ItemsLearnedScreen] and
/// [LifetimeViewScreen].
class CurriculumBreakdownList extends StatefulWidget {
  const CurriculumBreakdownList({
    super.key,
    required this.summaries,
  });

  final List<CurriculumCompletionSummary> summaries;

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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: widget.summaries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final summary = widget.summaries[index];
        return _CurriculumCard(
          summary: summary,
          isExpanded: _expanded.contains(summary.curriculumId),
          treeExpanded: _treeExpanded,
          l10n: l10n,
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
    required this.onExpandToggle,
    required this.onTreeExpandToggle,
  });

  final CurriculumCompletionSummary summary;
  final bool isExpanded;
  final Map<String, bool> treeExpanded;
  final AppLocalizations l10n;
  final VoidCallback onExpandToggle;
  final void Function(String key, bool isExpanded) onTreeExpandToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final useHebrew = ref.watch(useHebrewTermsProvider);
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
                            backgroundColor:
                                curriculumColor.withValues(alpha: 0.15),
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
                          if (!useHebrew)
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
      );
    }).toList();
  }
}

/// A single expandable tree node inside a curriculum breakdown card.
class CurriculumBreakdownTreeNode extends StatelessWidget {
  const CurriculumBreakdownTreeNode({
    super.key,
    required this.node,
    required this.depth,
    required this.nodeKey,
    required this.expandedNodes,
    required this.onExpandToggle,
  });

  final LifetimeTreeNode node;
  final int depth;
  final String nodeKey;
  final Map<String, bool> expandedNodes;
  final void Function(String key, bool isExpanded) onExpandToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isExpanded = expandedNodes[nodeKey] ?? false;
    final hasChildren = node.children.isNotEmpty;
    final stateColor = _stateColor(node.state);

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap:
              hasChildren ? () => onExpandToggle(nodeKey, !isExpanded) : null,
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
}
