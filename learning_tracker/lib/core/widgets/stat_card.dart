import 'package:flutter/material.dart';

/// A tappable stat card primitive used across the Progress overview and the
/// dashboard's task-category stat grid.
///
/// **Full variant** (icon present): renders an icon pill at the top-start
/// corner, then a [Spacer], then [value] + [label].  This variant requires a
/// height-constrained parent (e.g. a [GridView] cell or fixed-height
/// [SizedBox]) because of the [Spacer].
///
/// **Compact variant** (icon omitted): renders [value] + [label] centred
/// vertically with normal [Column] flow — no [Spacer] — so it can be sized
/// intrinsically.  This is the mode used by [TaskCategoryStatBox].
///
/// RTL-safe: paddings use [EdgeInsetsDirectional] and the decorative circle
/// on the highlighted variant is aligned with [AlignmentDirectional.topEnd].
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    this.icon,
    this.iconColor,
    required this.value,
    required this.label,
    this.highlighted = false,
    this.cardColor,
    this.valueColor,
    this.labelColor,
    this.borderRadius = 22,
    this.padding = const EdgeInsets.all(14),
    this.onTap,
  });

  /// Icon rendered in the leading pill at the top-start corner.  When `null`
  /// the compact (no-spacer) layout is used.
  final IconData? icon;

  /// Colour applied to both the icon and the pill background (at reduced
  /// opacity).  Ignored when [icon] is `null`.
  final Color? iconColor;

  /// Primary numeric (or text) value displayed prominently.
  final String value;

  /// Short descriptive label shown below [value].
  final String label;

  /// When `true` the card renders in the accent (highlighted) variant:
  /// coral background, white text, and a subtle decorative circle.
  final bool highlighted;

  /// Overrides the default card background colour.
  final Color? cardColor;

  /// Overrides the default value text colour.
  final Color? valueColor;

  /// Overrides the default label text colour.
  final Color? labelColor;

  /// Corner radius applied to the card and its ink-well.  Defaults to 22.
  final double borderRadius;

  /// Internal padding of the card.  Defaults to `EdgeInsets.all(14)`.
  final EdgeInsetsGeometry padding;

  /// Called when the card is tapped.  When `null` the card is still rendered
  /// but no ink-well feedback is produced on tap.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final effectiveCardColor =
        cardColor ?? (highlighted ? const Color(0xFFFF6E76) : Colors.white);
    final effectiveValueColor =
        valueColor ?? (highlighted ? Colors.white : const Color(0xFF11182C));
    final effectiveLabelColor =
        labelColor ??
        (highlighted
            ? Colors.white.withValues(alpha: 0.82)
            : const Color(0xFF7C8595));

    final radius = BorderRadius.circular(borderRadius);
    final hasIcon = icon != null && iconColor != null;

    return Material(
      color: effectiveCardColor,
      borderRadius: radius,
      elevation: 0,
      shadowColor: const Color(0xFF03174C).withValues(alpha: 0.08),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        splashColor: highlighted ? Colors.white.withValues(alpha: 0.18) : null,
        highlightColor: highlighted
            ? Colors.white.withValues(alpha: 0.08)
            : null,
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveCardColor,
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF03174C).withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: hasIcon
              ? _FullLayout(
                  icon: icon!,
                  iconColor: iconColor!,
                  highlighted: highlighted,
                  value: value,
                  label: label,
                  effectiveValueColor: effectiveValueColor,
                  effectiveLabelColor: effectiveLabelColor,
                )
              : _CompactLayout(
                  value: value,
                  label: label,
                  highlighted: highlighted,
                  effectiveValueColor: effectiveValueColor,
                  effectiveLabelColor: effectiveLabelColor,
                ),
        ),
      ),
    );
  }
}

// ─── Private layout helpers ───────────────────────────────────────────────────

/// Full layout: icon pill at top-start, spacer, value, label.
/// Requires a height-constrained parent due to the [Spacer].
class _FullLayout extends StatelessWidget {
  const _FullLayout({
    required this.icon,
    required this.iconColor,
    required this.highlighted,
    required this.value,
    required this.label,
    required this.effectiveValueColor,
    required this.effectiveLabelColor,
  });

  final IconData icon;
  final Color iconColor;
  final bool highlighted;
  final String value;
  final String label;
  final Color effectiveValueColor;
  final Color effectiveLabelColor;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (highlighted)
          Align(
            alignment: AlignmentDirectional.topEnd,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
            ),
          ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: highlighted ? 0.18 : 0.14),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, color: iconColor, size: 17),
            ),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: effectiveValueColor,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: effectiveLabelColor,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Compact layout: centred value + label with no icon, no spacer.
/// Can be sized intrinsically — suitable for [TaskCategoryStatBox].
class _CompactLayout extends StatelessWidget {
  const _CompactLayout({
    required this.value,
    required this.label,
    required this.highlighted,
    required this.effectiveValueColor,
    required this.effectiveLabelColor,
  });

  final String value;
  final String label;
  final bool highlighted;
  final Color effectiveValueColor;
  final Color effectiveLabelColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: effectiveValueColor,
            fontWeight: FontWeight.w800,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: effectiveLabelColor,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}
