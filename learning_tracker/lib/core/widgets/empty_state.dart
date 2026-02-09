import 'package:flutter/material.dart';

/// EmptyState displays a message and illustration when no data is available.
///
/// Used for empty lists, search results, etc.
class EmptyState extends StatelessWidget {
  /// Message to display
  final String message;

  /// Optional secondary message with more details
  final String? subtitle;

  /// Optional icon to display
  final IconData? icon;

  /// Optional action button
  final Widget? action;

  const EmptyState({
    super.key,
    required this.message,
    this.subtitle,
    this.icon,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Placeholder illustration (simple icon for now)
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 96,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            Text(
              message,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 24),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
