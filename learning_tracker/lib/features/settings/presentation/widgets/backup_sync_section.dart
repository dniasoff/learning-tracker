import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Sync status and optional upgrade-to-cloud CTA (DNI-188).
///
/// Story 1.5 / AD-11 (owner-ratified, 2026-08-02): this widget used to render
/// differentiated cards for `SyncStatusError` (appCheck / permissionDenied /
/// timeout, each with its own copy) and `SyncStatusDegraded` (stuck-outbox /
/// identity-mismatch, with a "Sign in to back up" re-auth affordance and a
/// tap-to-retry action on the transient error card). Those states no longer
/// exist in the slim `synced | syncing | offline` union (plus `localOnly`),
/// so that UI — including the tap-to-retry affordance shipped in v1.0.68 —
/// is gone. **This is a known, deliberate regression**: a permanently-failed
/// write now surfaces only as ambient `syncing`, with no differentiated card
/// and no per-item recovery action. The replacement is AD-30's per-item
/// "tap to retry" recovery affordance, landing in Phase 3 — not this story.
class BackupSyncSection extends ConsumerStatefulWidget {
  const BackupSyncSection({super.key, this.parentSettingsHeroLayout = false});

  /// When true, local-only state uses a centered hero layout (Parent Settings).
  final bool parentSettingsHeroLayout;

  @override
  ConsumerState<BackupSyncSection> createState() => _BackupSyncSectionState();
}

class _BackupSyncSectionState extends ConsumerState<BackupSyncSection> {
  @override
  void initState() {
    super.initState();
    // Kick a cold-start pull when the Backup & Sync surface mounts.
    //
    // The orchestrator's status stream starts at `localOnly` and only flips to
    // `synced` after a `pullOnLaunch`. On a cold launch that RESUMES an existing
    // cloud session (no fresh sign-in / device-restore / account-switch — the
    // three paths that already call `pullOnLaunch`) nothing triggered the pull,
    // so opening Parent Settings showed "Connecting…" indefinitely until a
    // background→foreground cycle fired the resume-pull. Triggering it here
    // resolves the status without that cycle.
    //
    // `pullOnLaunch`'s once-per-launch guard makes this a no-op if a pull
    // already ran (or is in flight) this session, so the extra call is cheap and
    // safe. Fire-and-forget with a timeout so a slow/failed pull never blocks
    // the UI (the orchestrator emits its own syncing/synced/error status).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        final authState = ref.read(authStateProvider);
        if (!authState.isCloudBorn) return;
        final orchestrator = ref.read(syncOrchestratorProvider);
        if (orchestrator == null) return;
        if (orchestrator.currentStatus is! SyncStatusLocalOnly) return;
        unawaited(
          orchestrator.pullOnLaunch().timeout(
            const Duration(seconds: 8),
            onTimeout: () {},
          ),
        );
      } catch (_) {
        // Best-effort kick: a provider build failure (e.g. in widget tests
        // that don't wire the full sync stack) must never crash the surface.
        // The orchestrator emits its own status; the UI degrades gracefully.
      }
    });
  }

  bool get parentSettingsHeroLayout => widget.parentSettingsHeroLayout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final syncStatus = ref.watch(syncStatusProvider);
    final authState = ref.watch(authStateProvider);
    // A cloud-born user briefly sees SyncStatusLocalOnly while the orchestrator
    // initialises before its first pullOnLaunch completes.  Show a neutral
    // "connecting" state rather than the "LOCAL ONLY — upgrade" prompt, which
    // is misleading for an account that already has cloud sync.
    if (syncStatus is SyncStatusLocalOnly && authState.isCloudBorn) {
      return _buildCloudStatusCard(
        theme,
        icon: Icons.sync_rounded,
        subtitle: l10n.backupConnecting,
      );
    }
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
        subtitle: l10n.backupLastSynced(_formatTimeAgo(l10n, lastSyncedAt)),
      ),
      SyncStatusSyncing() => _buildCloudStatusCard(
        theme,
        icon: Icons.sync_rounded,
        subtitle: l10n.backupSyncing,
      ),
      SyncStatusOffline() => _buildCloudStatusCard(
        theme,
        icon: Icons.cloud_off_rounded,
        subtitle: l10n.backupOffline,
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
              Text(
                AppLocalizations.of(context)!.backupSyncCardTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                AppLocalizations.of(context)!.backupSyncCardBody,
                textAlign: TextAlign.center,
                style: bodyTextStyle,
              ),
              if (isLocalAuth) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.peachMid,
                      foregroundColor: context.colors.peachDark,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      textStyle: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        color: context.colors.peachDark,
                      ),
                    ),
                    onPressed: () =>
                        context.pushRoute(const UpgradeToCloudRoute()),
                    child: Text(
                      AppLocalizations.of(context)!.backupUpgradeToCloud,
                    ),
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
            Row(
              children: [
                const CircleAvatar(
                  radius: 16,
                  backgroundColor: Color(0x3A8EA4ED),
                  child: Icon(
                    Icons.cloud_upload_outlined,
                    size: 17,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 10),
                // Flexible + ellipsis so the large title never overflows the
                // row horizontally on a narrow screen / large text.
                Flexible(
                  child: Text(
                    AppLocalizations.of(context)!.backupSyncCardTitle,
                    // Wrap to a second line before ellipsizing so the 33px
                    // title doesn't clip to "Backup & Sy…" at font scale 1.3.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 33,
                      height: 1.05,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              AppLocalizations.of(context)!.backupSyncCardBody,
              style: bodyTextStyle,
            ),
            const SizedBox(height: 16),
            if (isLocalAuth)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.peachMid,
                    foregroundColor: context.colors.peachDark,
                    minimumSize: const Size.fromHeight(42),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 20,
                      color: context.colors.peachDark,
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
                        // peachDark/peachMid (not the old fixed
                        // 0xFF322A23/peachMid pair): the badge circle was a
                        // fixed dark brown so, once peachMid itself went dark
                        // in dark mode, the peachMid icon on top of it became
                        // dark-on-dark. peachDark/peachMid already invert
                        // together (see the button foreground fix above),
                        // so swapping the circle to peachDark keeps this
                        // badge legible in both themes (run-9 audit).
                        decoration: BoxDecoration(
                          color: context.colors.peachDark,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: context.colors.peachMid,
                          size: 12,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          AppLocalizations.of(context)!.upgradeToCloudButton,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Story 1.5 / AD-11: this card no longer takes an `onTap`/`actionLabel` —
  // the tap-to-retry and "Sign in to back up" affordances it used to support
  // belonged to the now-removed SyncStatusError/SyncStatusDegraded cases (see
  // this file's class-level doc comment). AD-30's Phase 3 per-item recovery
  // affordance will need its own, differently-scoped UI when it lands.
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                      Text(
                        AppLocalizations.of(context)!.backupSyncCardTitle,
                        style: const TextStyle(
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
          ],
        ),
      ),
    );
  }

  static String _formatTimeAgo(AppLocalizations l10n, DateTime dateTime) {
    final diff = DateTimeFactory.nowLocal().difference(dateTime);
    if (diff.inMinutes < 1) return l10n.backupTimeAgoJustNow;
    if (diff.inMinutes < 60) return l10n.backupTimeAgoMinutes(diff.inMinutes);
    if (diff.inHours < 24) return l10n.backupTimeAgoHours(diff.inHours);
    return l10n.backupTimeAgoDays(diff.inDays);
  }
}
