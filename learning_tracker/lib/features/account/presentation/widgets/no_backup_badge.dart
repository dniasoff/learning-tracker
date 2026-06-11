import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Persistent "No backup" badge — shown for local-born users (always,
/// since offline is their permanent state per v2 §4.6).
///
/// Tappable: opens the upgrade flow (Epic 20 story 20.9). Until the
/// upgrade flow lands as a dedicated route, tapping surfaces a bottom
/// sheet that explains the implications and points to Settings.
class NoBackupBadge extends ConsumerWidget {
  const NoBackupBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    if (!authState.isLocalBorn) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Tooltip(
      message:
          'This account exists only on this device. '
          'Tap to back it up to the cloud.',
      child: InkWell(
        onTap: () => _openUpgradeFlow(context),
        borderRadius: BorderRadius.circular(16),
        child: Semantics(
          button: true,
          label: 'No backup badge — tap to upgrade to cloud',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.colorScheme.error),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off,
                  size: 14,
                  color: theme.colorScheme.onErrorContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.noBackup,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openUpgradeFlow(BuildContext context) {
    context.router.push(const UpgradeToCloudRoute());
  }
}
