import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Sync status and optional upgrade-to-cloud CTA (DNI-188).
class BackupSyncSection extends ConsumerWidget {
  const BackupSyncSection({super.key, this.parentSettingsHeroLayout = false});

  /// When true, local-only state uses a centered hero layout (Parent Settings).
  final bool parentSettingsHeroLayout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final syncStatus = ref.watch(syncStatusProvider);
    final authState = ref.watch(authStateProvider);
    return switch (syncStatus) {
      SyncStatusLocalOnly() => _buildLocalOnlyCard(
        context,
        theme,
        isLocalAuth: authState.isLocalBorn,
        heroLayout: parentSettingsHeroLayout,
      ),
      SyncStatusSynced(:final lastSyncedAt) => _buildCloudStatusCard(
        theme,
        icon: Icons.cloud_done_rounded,
        subtitle: l10n.backupLastSynced(_formatTimeAgo(lastSyncedAt)),
      ),
      SyncStatusSyncing() => _buildCloudStatusCard(
        theme,
        icon: Icons.sync_rounded,
        subtitle: l10n.backupSyncing,
      ),
      SyncStatusPending(:final pendingChanges) => _buildCloudStatusCard(
        theme,
        icon: Icons.schedule_rounded,
        subtitle: l10n.backupPendingChanges(pendingChanges),
      ),
      SyncStatusOffline(:final pendingChanges) => _buildCloudStatusCard(
        theme,
        icon: Icons.cloud_off_rounded,
        subtitle: pendingChanges > 0
            ? l10n.backupPendingChanges(pendingChanges)
            : 'Offline',
      ),
      SyncStatusError(:final message) => _buildCloudStatusCard(
        theme,
        icon: Icons.warning_amber_rounded,
        subtitle: l10n.backupSyncError(message),
      ),
      SyncStatusDegraded(:final pendingChanges, :final reason) =>
        _buildCloudStatusCard(
          theme,
          icon: Icons.sync_problem_rounded,
          subtitle: pendingChanges > 0
              ? 'Sync paused — $pendingChanges queued. $reason'
              : 'Sync paused. $reason',
        ),
    };
  }

  Widget _buildLocalOnlyCard(
    BuildContext context,
    ThemeData theme, {
    required bool isLocalAuth,
    required bool heroLayout,
  }) {
    final bodyTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.88),
      height: 1.35,
      fontWeight: FontWeight.w600,
      fontSize: 17,
    );

    if (heroLayout) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFF0B3FB4),
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x30053698),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.cloud_upload_outlined,
                    size: 28,
                    color: Color(0xFF0B3FB4),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Backup & Sync',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your learning progress is currently LOCAL ONLY. '
                'Upgrade to sync across all devices.',
                textAlign: TextAlign.center,
                style: bodyTextStyle,
              ),
              if (isLocalAuth) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFF3D4A5),
                      foregroundColor: const Color(0xFF2C2A26),
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: const Color(0xFF2C2A26),
                      ),
                    ),
                    onPressed: () =>
                        context.pushRoute(const UpgradeToCloudRoute()),
                    child: Text(AppLocalizations.of(context)!.backupUpgradeToCloud),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B3FB4),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30053698),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0x3A8EA4ED),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Backup & Sync',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 33,
                    height: 1.05,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Your learning progress is currently\nLOCAL ONLY. Upgrade to sync\nacross all devices.',
              style: bodyTextStyle,
            ),
            const SizedBox(height: 16),
            if (isLocalAuth)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF3D4A5),
                    foregroundColor: const Color(0xFF2C2A26),
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: const Color(0xFF2C2A26),
                    ),
                  ),
                  onPressed: () =>
                      context.pushRoute(const UpgradeToCloudRoute()),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: Color(0xFF322A23),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.arrow_upward_rounded,
                          color: Color(0xFFF3D4A5),
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.upgradeToCloudButton),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudStatusCard(
    ThemeData theme, {
    required IconData icon,
    required String subtitle,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B3FB4),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x30053698),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0x3A8EA4ED),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Backup & Sync',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.88),
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      fontSize: 15.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTimeFactory.nowLocal().difference(dateTime);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
