import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/percentage_formatter.dart';
import 'package:learning_tracker/features/progress/presentation/providers/lifetime_knowledge_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Gradients for Learning lifetime on Progress (blue) and Settings (warm, no blue).
class LifetimeFolderGradients {
  static LinearGradient card(BuildContext context) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        context.colors.progressLifetimeCardGradientStart,
        // NOT brandBlue directly — it LIGHTENS in dark mode for its normal
        // ink-on-dark-surface role, which painted a light pastel-blue band
        // in the middle of this otherwise-deep gradient when used as a fill
        // (see AppPalette.progressLifetimeCardGradientMid's doc, run-11
        // progress-area sweep).
        context.colors.progressLifetimeCardGradientMid,
        context.colors.progressLifetimeCardGradientEnd,
      ],
      stops: [0.0, 0.45, 1.0],
    );
  }

  /// Full-screen soft background behind lifetime panels on Progress.
  static LinearGradient pageBackground(BuildContext context) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        context.colors.progressLifetimePageBgTop,
        context.colors.progressLifetimePageBgMid,
        context.colors.progressLifetimePageBgBottom,
      ],
    );
  }

  /// App bar on Settings lifetime screens (forest charcoal, no blue).
  static Color settingsAppBar(BuildContext context) =>
      context.colors.progressSettingsAppBar;

  /// Settings → Add what you've learned: warm paper tone, no blue.
  static LinearGradient settingsPageBackground(BuildContext context) {
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        context.colors.progressSettingsPageBgTop,
        context.colors.progressSettingsPageBgMid,
        context.colors.progressSettingsPageBgBottom,
      ],
    );
  }

  /// Settings lifetime card: forest / sage (matches growth metaphor, no blue).
  static LinearGradient settingsCard(BuildContext context) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        context.colors.progressSettingsCardGradientStart,
        context.colors.progressSettingsCardGradientMid,
        context.colors.progressSettingsCardGradientEnd,
      ],
      stops: [0.0, 0.48, 1.0],
    );
  }
}

/// Rounded [Card] with the shared learning-lifetime look.
class LifetimeFolderSurface extends StatelessWidget {
  const LifetimeFolderSurface({
    super.key,
    required this.child,
    this.padding,
    this.gradient,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// When null, uses [LifetimeFolderGradients.card] (Progress lifetime tree).
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: gradient ?? LifetimeFolderGradients.card(context),
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
///
/// When the Hebrew Terms toggle is on (default), shows only the Hebrew name.
/// When off, shows the English transliteration with the Hebrew name
/// underneath as a smaller secondary line — the one place in the app that
/// intentionally renders both forms simultaneously, hence the use of
/// [curriculumHebrewName] for the secondary.
class LifetimeCurriculumFolderRow extends ConsumerWidget {
  const LifetimeCurriculumFolderRow({
    super.key,
    required this.curriculumId,
    this.trailingPercent,
    this.isExpanded = false,
    this.isExpandableListStyle = true,
    this.showLearnedBadge = false,
    this.onTap,
  });

  final CurriculumId curriculumId;
  final String? trailingPercent;
  final bool isExpanded;

  /// When true, shows expand/less like Progress; when false, always a forward chevron (e.g. navigation).
  final bool isExpandableListStyle;

  /// Green check when this curriculum already has lifetime marks (Progress parity).
  final bool showLearnedBadge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final terms = domainTermLabels(ref);
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
                      CurriculumLabel.curriculum(
                        curriculumId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!terms.isHebrew) ...[
                        const SizedBox(height: 2),
                        Text(
                          curriculumHebrewName(curriculumId),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showLearnedBadge) ...[
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: context.colors.statusSuccessMuted,
                  ),
                  const SizedBox(width: 6),
                ],
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
    this.insetBackground = true,
  });

  final double? maxHeight;
  final Widget child;

  /// When false (e.g. light marking sheet), no grey inset behind the list.
  final bool insetBackground;

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: child,
    );

    return ConstrainedBox(
      constraints: maxHeight != null
          ? BoxConstraints(maxHeight: maxHeight!)
          : const BoxConstraints(),
      child: insetBackground
          ? Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: padded,
            )
          : padded,
    );
  }
}

// --- Read-only tree (Progress) ---

class LifetimeFolderTreeNode extends ConsumerStatefulWidget {
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
  ConsumerState<LifetimeFolderTreeNode> createState() =>
      _LifetimeFolderTreeNodeState();
}

class _LifetimeFolderTreeNodeState
    extends ConsumerState<LifetimeFolderTreeNode> {
  @override
  Widget build(BuildContext context) {
    final color = switch (widget.node.state) {
      LifetimeNodeState.full => context.colors.statusSuccessMuted,
      LifetimeNodeState.partial => context.colors.progressLifetimePartial,
      LifetimeNodeState.none => Colors.white.withValues(alpha: 0.5),
    };
    final indent = widget.depth * 20.0;
    final hasChildren = widget.node.children.isNotEmpty;
    final isExpanded = widget.expandedNodes[widget.nodeKey] ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: indent),
          child: GestureDetector(
            onTap: hasChildren
                ? () => widget.onExpandToggle(widget.nodeKey, !isExpanded)
                : null,
            child: Container(
              width: double.infinity,
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
                children: [
                  if (hasChildren)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
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
                      padding: const EdgeInsetsDirectional.only(end: 6),
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
                  Expanded(
                    child: CurriculumLabel.level(
                      curriculumId: widget.node.curriculumId,
                      level: widget.node.level,
                      rawValue: widget.node.rawValue,
                      parentL1Value: widget.node.parentL1Value,
                      hebrewName: widget.node.hebrewName,
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
              nodeKey: '${widget.nodeKey}/${child.rawValue}',
              expandedNodes: widget.expandedNodes,
              onExpandToggle: widget.onExpandToggle,
            ),
      ],
    );
  }
}

// --- Marking: scope row with check + folder chrome ---

/// Visual state for [LifetimeMarkingScopeRow]: same green / amber / gray as the read-only tree.
///
/// [partial] is the indeterminate state: some-but-not-all descendants under
/// this scope are selected, so the row's checkbox renders as a dash (tristate
/// `value: null`) rather than a full check or an empty box.
enum MarkingRowVisual { none, direct, implicit, partial }

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
    this.isPersisted = false,
    this.lightSurface = false,
    this.onDrill,
  });

  final String primary;
  final String? secondary;
  final MarkingRowVisual visual;
  final double indent;
  final bool hasDrill;
  final VoidCallback onToggle;
  final bool isImplicit;

  /// Saved in learning ledger — green like Progress tree, checkbox read-only.
  final bool isPersisted;

  /// Light sheet behind rows (no dark [LifetimeFolderListPanel] inset).
  final bool lightSurface;
  final VoidCallback? onDrill;

  @override
  Widget build(BuildContext context) {
    final color = isPersisted
        ? context.colors.statusSuccessMuted
        : switch (visual) {
            MarkingRowVisual.direct => context.colors.statusSuccessMuted,
            MarkingRowVisual.implicit ||
            MarkingRowVisual.partial => context.colors.progressLifetimePartial,
            MarkingRowVisual.none =>
              lightSurface
                  ? context.colors.progressLifetimeNoneOnLight
                  : Colors.white.withValues(alpha: 0.5),
          };
    // Indeterminate: some-but-not-all descendants selected. Drives the
    // tristate checkbox to a dash (value null) instead of a full check.
    final partial = !isPersisted && visual == MarkingRowVisual.partial;
    final selected =
        isPersisted ||
        visual == MarkingRowVisual.direct ||
        visual == MarkingRowVisual.implicit;
    // Tristate value: null = indeterminate dash, true = checked, false = empty.
    final checkboxValue = partial ? null : selected;

    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, top: 4, bottom: 0),
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
                  // Tristate so a partially-selected scope (some-but-not-all
                  // descendants marked) renders an indeterminate dash rather
                  // than a full check or an empty box.
                  tristate: partial,
                  value: checkboxValue,
                  onChanged: isPersisted || isImplicit
                      ? null
                      : (_) {
                          onToggle();
                        },
                  fillColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected) || partial
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
                onTap: isPersisted || isImplicit ? null : onToggle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primary,
                      maxLines: 2,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: lightSurface
                            ? context.colors.brandInk
                            : Colors.white.withValues(alpha: 0.95),
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
                          color: lightSurface
                              ? context.colors.brandInkMuted
                              : Colors.white.withValues(alpha: 0.7),
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
                  // AUD-progress-09 (AX-3): icon-only drill-in button needs a
                  // non-empty accessible label. `IconButton(tooltip:)` alone
                  // only populates `SemanticsData.tooltip`, not `.label`, on
                  // the current Flutter SDK (3.44.6) — see the identical fix
                  // shape in recent_activity_screen_a11y_test.dart
                  // (AUD-progress-02) / reward_config_header_a11y_test.dart
                  // (AUD-gamification-04). `semanticLabel` here maps to
                  // `Semantics(label:)`, the mechanism AX-3 names.
                  semanticLabel: AppLocalizations.of(
                    context,
                  )!.scopeShowContentsTooltip,
                ),
                onPressed: onDrill,
                // Visual tooltip on long-press/hover. Reuses the same string
                // already used for the equivalent drill-in chevron in
                // HierarchyTile (scope_tiles.dart) rather than minting a
                // near-duplicate ARB key for the same affordance.
                tooltip: AppLocalizations.of(context)!.scopeShowContentsTooltip,
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
