import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Sync status and optional upgrade-to-cloud CTA (DNI-188).
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
            : l10n.backupOffline,
      ),
      // ST-4 / AUD-sync-01 (EH-5): SyncStatusError now carries a stable code
      // (never a pre-formatted message) — there is no raw text on the type
      // to short-circuit around any more. Same friendly message regardless
      // of code today (the retry action is identical either way); the
      // `code` field is available here if a future card wants to
      // differentiate.
      SyncStatusError() => _buildCloudStatusCard(
        theme,
        icon: Icons.warning_amber_rounded,
        subtitle:
            '${l10n.backupSyncCloudUnavailable}\n${l10n.backupSyncTapToRetry}',
        onTap: () => ref.read(syncOrchestratorProvider)?.retryPull(),
      ),
      SyncStatusDegraded(:final pendingChanges, :final reason) =>
        _buildDegradedCard(context, ref, theme, pendingChanges, reason),
    };
  }

  /// Degraded card. When the degradation is an account-identity mismatch (the
  /// device is signed into Firebase as a different account than the active
  /// one), render an actionable "Sign in as <email>" affordance that routes to
  /// the sign-in screen — once the matching Google account is signed in, the
  /// identity guard clears and the queued rows flush. Otherwise show the plain
  /// "sync paused" subtitle.
  Widget _buildDegradedCard(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    int pendingChanges,
    String reason,
  ) {
    final l10nLocal = AppLocalizations.of(context)!;
    final identity = ref.watch(syncIdentityStatusProvider);
    if (identity.isMismatch) {
      // AUD-settings-01 (EH-5): sync_orchestrator's `reason` for an identity
      // mismatch is a hand-built English sentence — it must never reach the
      // UI. Build the subtitle entirely from AppLocalizations, using the
      // structured fields on `identity` instead; `reason` stays unused here
      // (it remains a log-only/debug value on the orchestrator side).
      final activeEmail = identity.activeAccountEmail;
      final localizedMismatchReason = activeEmail != null
          ? l10nLocal.backupSyncIdentityMismatch(
              identity.signedInEmail ?? l10nLocal.backupSyncUnknownAccount,
              activeEmail,
            )
          : l10nLocal.backupSyncIdentityMismatchNoEmail;
      return _buildCloudStatusCard(
        theme,
        icon: Icons.person_off_rounded,
        subtitle: pendingChanges > 0
            ? l10nLocal.backupSyncPaused(
                pendingChanges,
                localizedMismatchReason,
              )
            : l10nLocal.backupSyncPausedNoCount(localizedMismatchReason),
        actionLabel: l10nLocal.backupSyncSignInToBackUp,
        onTap: () => context.pushRoute(const SignInRoute()),
      );
    }
    // ST-4 fix: the stuck-outbox reason is a raw English engineering string
    // ("outbox has N row(s) stuck after 3+ attempts") that leaks internal
    // terminology and English text into non-English UIs.  Replace it with a
    // friendly localized message; keep the raw reason only for other known
    // human-readable degraded states (e.g. quota exhausted).
    final isStuckOutbox = reason.contains('row(s) stuck');
    final localizedReason = isStuckOutbox
        ? l10nLocal.backupSyncOutboxStuck
        : reason;
    return _buildCloudStatusCard(
      theme,
      icon: Icons.sync_problem_rounded,
      subtitle: pendingChanges > 0
          ? l10nLocal.backupSyncPaused(pendingChanges, localizedReason)
          : l10nLocal.backupSyncPausedNoCount(localizedReason),
    );
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
                      backgroundColor: AppColors.peachMid,
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
                    backgroundColor: AppColors.peachMid,
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
                          color: AppColors.peachMid,
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

  Widget _buildCloudStatusCard(
    ThemeData theme, {
    required IconData icon,
    required String subtitle,
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    final card = DecoratedBox(
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
            if (actionLabel != null) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.peachMid,
                    foregroundColor: const Color(0xFF2C2A26),
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    textStyle: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      color: const Color(0xFF2C2A26),
                    ),
                  ),
                  onPressed: onTap,
                  child: Text(actionLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
    // A standalone action button owns the tap; don't also wrap the whole card.
    if (onTap == null || actionLabel != null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: card,
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
