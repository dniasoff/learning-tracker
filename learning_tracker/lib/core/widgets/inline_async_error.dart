import 'package:flutter/material.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Compact error affordance for a failed secondary async value.
class InlineAsyncError extends StatelessWidget {
  const InlineAsyncError({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: theme.colorScheme.error,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            l10n.errorWithMessage,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: Text(l10n.retry)),
      ],
    );
  }
}
