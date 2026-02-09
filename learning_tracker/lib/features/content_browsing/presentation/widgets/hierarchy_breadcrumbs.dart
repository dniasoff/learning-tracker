import 'package:flutter/material.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Data class for a breadcrumb item.
class BreadcrumbItem {
  const BreadcrumbItem({
    required this.displayNameHe,
    required this.displayNameEn,
  });

  final String displayNameHe;
  final String displayNameEn;
}

/// Breadcrumb navigation widget showing the current hierarchy position.
/// Example: "Mishnayos > Seder Zeraim > Berachos"
class HierarchyBreadcrumbs extends StatelessWidget {
  const HierarchyBreadcrumbs({
    super.key,
    required this.curriculumId,
    required this.navigationStack,
    required this.onTapLevel,
  });

  final String curriculumId;
  final List<BreadcrumbItem> navigationStack;
  final void Function(int depth) onTapLevel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final curriculum = CurriculumId.values.firstWhere(
      (c) => c.storageKey == curriculumId,
      orElse: () => CurriculumId.mishnayos,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Root: curriculum name (always present)
          _BreadcrumbChip(
            label: curriculum.displayNameHe,
            isLast: navigationStack.isEmpty,
            onTap: () => onTapLevel(0),
          ),

          // Hierarchy levels
          for (int i = 0; i < navigationStack.length; i++) ...[
            Icon(
              Icons.chevron_right,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            _BreadcrumbChip(
              label: navigationStack[i].displayNameHe,
              isLast: i == navigationStack.length - 1,
              onTap: () => onTapLevel(i + 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _BreadcrumbChip extends StatelessWidget {
  const _BreadcrumbChip({
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

    return InkWell(
      onTap: isLast ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isLast
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isLast
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurfaceVariant,
            fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
