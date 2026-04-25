import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';

/// Blue gradient used by Learning lifetime / mark-what-you-learned flows.
class LifetimeFolderGradients {
  static LinearGradient get card {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        AppTheme.brandBlue.withValues(alpha: 0.95),
        AppTheme.brandBlueBright.withValues(alpha: 0.85),
      ],
    );
  }
}

/// Rounded [Card] with the shared learning-lifetime look.
class LifetimeFolderSurface extends StatelessWidget {
  const LifetimeFolderSurface({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LifetimeFolderGradients.card,
        ),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

/// Top row: folder icon + title + optional subtitle.
class LifetimeFolderPageHeader extends StatelessWidget {
  const LifetimeFolderPageHeader({
    super.key,
    this.icon = Icons.folder_special_rounded,
    required this.title,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Intro / tip block on the same gradient.
class LifetimeFolderFrostedHint extends StatelessWidget {
  const LifetimeFolderFrostedHint({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
  });

  final Widget? leading;
  final String? title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null)
                  Text(
                    title!,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.82),
                      height: 1.35,
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

/// Curriculum row: frosted background, `>` or expand chevron.
class LifetimeCurriculumFolderRow extends StatelessWidget {
  const LifetimeCurriculumFolderRow({
    super.key,
    required this.titleEn,
    required this.titleHe,
    this.trailingPercent,
    this.isExpanded = false,
    this.isExpandableListStyle = true,
    this.onTap,
  });

  final String titleEn;
  final String titleHe;
  final String? trailingPercent;
  final bool isExpanded;

  /// When true, shows expand/less like Progress; when false, always a forward chevron (e.g. navigation).
  final bool isExpandableListStyle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.menu_book_outlined,
                  size: 22,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleEn,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        titleHe,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (trailingPercent != null) ...[
                  Text(
                    trailingPercent!,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(
                  isExpandableListStyle
                      ? (isExpanded
                            ? Icons.expand_more_rounded
                            : Icons.chevron_right_rounded)
                      : Icons.chevron_right_rounded,
                  color: Colors.white.withValues(alpha: 0.9),
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tree panel (dark on gradient) for folder nodes or marking rows.
class LifetimeFolderListPanel extends StatelessWidget {
  const LifetimeFolderListPanel({
    super.key,
    this.maxHeight,
    required this.child,
  });

  final double? maxHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight!)
          : const BoxConstraints(),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: child,
      ),
    );
  }
}

// --- Read-only tree (Progress) ---

class LifetimeFolderTreeNode extends StatefulWidget {
  const LifetimeFolderTreeNode({
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
  final void Function(String, bool) onExpandToggle;

  @override
  State<LifetimeFolderTreeNode> createState() => _LifetimeFolderTreeNodeState();
}

class _LifetimeFolderTreeNodeState extends State<LifetimeFolderTreeNode> {
  @override
  Widget build(BuildContext context) {
    final color = switch (widget.node.state) {
      LifetimeNodeState.full => const Color(0xFF3BDD87),
      LifetimeNodeState.partial => const Color(0xFFFFD26A),
      LifetimeNodeState.none => Colors.white.withValues(alpha: 0.5),
    };
    final indent = widget.depth * 20.0;
    final hasChildren = widget.node.children.isNotEmpty;
    final isExpanded = widget.expandedNodes[widget.nodeKey] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: indent),
          child: GestureDetector(
            onTap: hasChildren
                ? () => widget.onExpandToggle(widget.nodeKey, !isExpanded)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasChildren)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        isExpanded
                            ? Icons.expand_less_rounded
                            : Icons.chevron_right_rounded,
                        size: 18,
                        color: color,
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Icon(
                        Icons.description_outlined,
                        size: 16,
                        color: color,
                      ),
                    ),
                  Container(
                    width: 6,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      widget.node.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasChildren && isExpanded)
          for (final child in widget.node.children)
            LifetimeFolderTreeNode(
              node: child,
              depth: widget.depth + 1,
              nodeKey: '${widget.nodeKey}/${child.label}',
              expandedNodes: widget.expandedNodes,
              onExpandToggle: widget.onExpandToggle,
            ),
      ],
    );
  }
}

// --- Marking: scope row with check + folder chrome ---

/// Visual state for [LifetimeMarkingScopeRow]: same green / amber / gray as the read-only tree.
enum MarkingRowVisual { none, direct, implicit }

class LifetimeMarkingScopeRow extends StatelessWidget {
  const LifetimeMarkingScopeRow({
    super.key,
    required this.primary,
    this.secondary,
    this.visual = MarkingRowVisual.none,
    this.indent = 0,
    this.hasDrill = true,
    required this.onToggle,
    this.isImplicit = false,
    this.onDrill,
  });

  final String primary;
  final String? secondary;
  final MarkingRowVisual visual;
  final double indent;
  final bool hasDrill;
  final VoidCallback onToggle;
  final bool isImplicit;
  final VoidCallback? onDrill;

  @override
  Widget build(BuildContext context) {
    final color = switch (visual) {
      MarkingRowVisual.direct => const Color(0xFF3BDD87),
      MarkingRowVisual.implicit => const Color(0xFFFFD26A),
      MarkingRowVisual.none => Colors.white.withValues(alpha: 0.5),
    };
    final selected =
        visual == MarkingRowVisual.direct ||
        visual == MarkingRowVisual.implicit;

    return Padding(
      padding: EdgeInsets.only(left: indent, top: 4, bottom: 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: Center(
                child: Checkbox(
                  value: selected,
                  onChanged: isImplicit
                      ? null
                      : (_) {
                          onToggle();
                        },
                  fillColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? color
                        : Colors.transparent,
                  ),
                  checkColor: Colors.white,
                  side: WidgetStateBorderSide.resolveWith(
                    (states) => BorderSide(
                      color: color.withValues(alpha: 0.7),
                      width: 1.4,
                    ),
                  ),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: const VisualDensity(
                    horizontal: -4,
                    vertical: -2,
                  ),
                ),
              ),
            ),
            Icon(
              hasDrill
                  ? Icons.chevron_right_rounded
                  : Icons.description_outlined,
              size: 18,
              color: color,
            ),
            const SizedBox(width: 4),
            Container(
              width: 6,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: onToggle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (secondary != null && secondary!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        secondary!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontStyle: isImplicit ? FontStyle.italic : null,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (hasDrill && onDrill != null)
              IconButton(
                icon: Icon(
                  Icons.navigate_next_rounded,
                  color: color.withValues(alpha: 0.9),
                ),
                onPressed: onDrill,
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      ),
    );
  }
}

String? percentTextForCurriculum(CurriculumLifetimeSummary summary) {
  if (summary.totalLeafCount == 0) return null;
  return formatFractionAsPercent(summary.percentage);
}
