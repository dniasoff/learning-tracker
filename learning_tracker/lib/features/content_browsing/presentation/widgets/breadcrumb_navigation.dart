import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// The direction-aware breadcrumb separator chevron for [direction].
///
/// LTR reads left-to-right so the separator points right ([Icons.chevron_right],
/// rendered ›); RTL reads right-to-left so it points left ([Icons.chevron_left],
/// rendered ‹). Shared between [BreadcrumbNavigation] and the hosting screen's
/// root-chip separator so all separators in a single trail agree (R2 finding 4 —
/// previously the hardcoded root-chip chevron disagreed with the inner ones in
/// RTL).
IconData breadcrumbSeparatorIcon(TextDirection direction) =>
    direction == TextDirection.rtl ? Icons.chevron_left : Icons.chevron_right;

/// Displays breadcrumb navigation showing current position in content hierarchy.
///
/// Renders only the navigation stack — the curriculum root is shown by the
/// adjacent curriculum chip, so duplicating it here is redundant.
///
/// Example (current location is "Berachos" inside Seder Zeraim):
///   Seder Zeraim > Berachos (LTR)
///   Berachos < Seder Zeraim (RTL — chevron flips to point the correct direction)
///
/// IL-7: the chevron separator is direction-aware: [Icons.chevron_right] in
/// LTR layouts and [Icons.chevron_left] in RTL layouts (Hebrew terms mode).
/// The same helper [breadcrumbSeparatorIcon] is reused by the hosting screen's
/// root-chip separator so every separator in one trail points the same way.
class BreadcrumbNavigation extends StatelessWidget {
  const BreadcrumbNavigation({
    super.key,
    required this.curriculum,
    required this.levelLabels,
    required this.navigationStack,
    required this.onBreadcrumbTap,
  });

  final CurriculumId curriculum;
  final List<String> levelLabels;
  final List<String> navigationStack;
  final void Function(int level) onBreadcrumbTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // IL-7: flip the chevron for RTL (Hebrew terms mode) so the separator
    // arrow points in the correct reading direction. Uses the shared helper so
    // it can never drift from the hosting screen's root-chip separator.
    final separatorIcon = breadcrumbSeparatorIcon(Directionality.of(context));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      // R2 finding 5: cap the current (last) crumb to the available width so it
      // ellipsizes cleanly instead of being clipped mid-word at large text
      // scales (font scale 1.3, worse in RTL). LayoutBuilder lives OUTSIDE the
      // horizontal scroll view so it reports the bounded viewport width; the
      // ancestor crumbs still scroll horizontally when the trail is long.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxCurrentCrumbWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : double.infinity;
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < navigationStack.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(
                        separatorIcon,
                        size: 20,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  _BreadcrumbItem(
                    label: navigationStack[i],
                    isLast: i == navigationStack.length - 1,
                    maxWidth: maxCurrentCrumbWidth,
                    onTap: () => onBreadcrumbTap(i),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  const _BreadcrumbItem({
    required this.label,
    required this.isLast,
    required this.maxWidth,
    required this.onTap,
  });

  final String label;
  final bool isLast;

  /// Upper bound applied to the current (last) crumb so it ellipsizes instead
  /// of being clipped mid-word by the scroll viewport edge at large text scales.
  final double maxWidth;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLast) {
      // Current level - not clickable. Constrain + ellipsize so it never gets
      // cut mid-word at font scale 1.3 (R2 finding 5), in either LTR or RTL.
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      );
    }

    // Previous levels - clickable
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
