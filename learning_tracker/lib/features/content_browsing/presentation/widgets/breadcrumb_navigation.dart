import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

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
    // arrow points in the correct reading direction.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final separatorIcon = isRtl ? Icons.chevron_left : Icons.chevron_right;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 1),
        ),
      ),
      child: SingleChildScrollView(
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
                onTap: () => onBreadcrumbTap(i),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BreadcrumbItem extends StatelessWidget {
  const _BreadcrumbItem({
    required this.label,
    required this.isLast,
    required this.onTap,
  });

  final String label;
  final bool isLast;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isLast) {
      // Current level - not clickable
      return Text(
        label,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
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
