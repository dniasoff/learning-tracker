import 'package:flutter/material.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';

/// A single row in the hierarchy: checkbox + title + optional drill arrow.
class HierarchyTile extends StatelessWidget {
  const HierarchyTile({
    required this.title,
    required this.isSelected,
    required this.canDrill,
    required this.onCheck,
    this.onDrill,
    this.isImplicit = false,
    super.key,
  });

  final String title;
  final bool isSelected;
  final bool isImplicit;
  final bool canDrill;
  final VoidCallback onCheck;
  final VoidCallback? onDrill;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Checkbox(
        value: isSelected,
        onChanged: isImplicit ? null : (_) => onCheck(),
      ),
      title: Text(
        title,
        style: isImplicit
            ? TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)
            : null,
      ),
      trailing: canDrill
          ? IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onDrill,
              tooltip: 'Show contents',
            )
          : null,
      onTap: onCheck,
    );
  }
}

class ScopeLevelTile extends StatelessWidget {
  const ScopeLevelTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.onCheck,
    required this.canDrill,
    this.onDrill,
    this.badgeText,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final String? badgeText;
  final VoidCallback onCheck;
  final bool canDrill;
  final VoidCallback? onDrill;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.surfaceE9),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onCheck,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.surfaceF3,
                  child: Icon(icon, size: 19, color: AppTheme.brandBlueDeep),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            title,
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (badgeText != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.peachMid,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                badgeText!,
                                style: const TextStyle(
                                  color: AppColors.peachDark,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        // Wrap the "{n} {level} • {gloss}" subtitle to two
                        // lines so the seder gloss (e.g. "Festivals &
                        // Sabbaths") doesn't clip to "Festivals &" at large
                        // font scales / in a narrow tile.
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.brandInkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canDrill)
                      IconButton(
                        onPressed: onDrill,
                        icon: const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.brandInkMuted,
                        ),
                        tooltip: 'Show contents',
                      ),
                    Checkbox(
                      value: selected,
                      onChanged: (_) => onCheck(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
