import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
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
/// write now surfaces only as ambient `synced`, with no differentiated card
/// and no per-item recovery action. The replacement is AD-30's per-item
/// "tap to retry" recovery affordance, landing in Phase 3 — not this story.
///
/// Post-P3-5: the Drift sync engine (`core/sync/...`,
/// `features/sync/domain/models/sync_status.dart`) and its orchestrator were
/// archived (docs/_archive/drift-user-db/). There is no live Firestore-backed
/// replacement yet for the app-level `SyncStatus` union, `syncStatusProvider`,
/// or `SyncOrchestrator` this card rendered from — Firestore offline
/// persistence is transparent and exposes no "last synced" timestamp or
/// syncing/offline status to this widget, and a presentation/widgets file may
/// not import the data-access ring (AD-23/AD-28) to read one. Until such a
/// layer is re-created, the **cloud status card** (synced | syncing | offline,
/// plus the "connecting" transitional) is unbacked and throws
/// `UnsupportedError` in [build] — never a fabricated "synced". The
/// **cold-launch pull** trigger that consumed `syncOrchestratorProvider` is
/// removed in [initState]. Only the **local-only card + Upgrade to Cloud**
/// CTA — fully backed by auth state — still renders. See the BLOCKED notes
/// in [build] / [initState].
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
    // Cold-launch pull trigger (BUG-2 fix) REMOVED.
    //
    // It depended on `syncOrchestratorProvider` / `SyncOrchestrator.pullOnLaunch()`,
    // which were archived with the Drift sync engine (P3-5;
    // docs/_archive/drift-user-db/). There is no live Firestore-backed
    // replacement for an app-level sync orchestrator — Firestore persistence
    // is transparent and needs no client pull to "catch up". The old
    // fire-and-forget pull cannot be compiled without a backing engine, and
    // the no-fabrication rule forbids inventing one.
    //
    // BLOCKED: restoring a cloud refresh-on-launch trigger requires re-creating
    // `core/sync/...` and a `SyncOrchestrator` — outside this file's edit-only
    // scope (a presentation/widgets file may not reach the data-access ring,
    // AD-23/AD-28).
  }

  bool get parentSettingsHeroLayout => widget.parentSettingsHeroLayout;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);

    // The cloud sync-status card relied on the Drift engine's `SyncStatus`
    // union + `syncStatusProvider` (synced | syncing | offline, plus the
    // "connecting" transitional for a booting cloud account). That engine was
    // archived at P3-5 (docs/_archive/drift-user-db/) and no Firestore-backed
    // replacement exists yet. A backup surface that falsely claims "synced" is
    // actively dangerous, so this throws rather than fabricating a status;
    // it also cannot import the data-access ring from presentation
    // (AD-23/AD-28) to read one.
    //
    // BLOCKED: re-create a Firestore-backed sync-status layer
    // (`syncStatusProvider` / `SyncStatus`, re-pointed at Firestore), or an
    // owner decision to collapse this card to auth-tier-only, before removing
    // this throw. The widget used to show, for a cloud-born account:
    //   - synced      -> "Last synced Xm ago" (from lastSyncedAt)
    //   - syncing     -> l10n "Syncing…"
    //   - offline     -> "Offline"
    //   - localOnly   -> "Connecting…" (transitional, booting cloud account)
    // The cloud sync-status card relied on the Drift engine's `SyncStatus`
    // union + `syncStatusProvider` (synced | syncing | offline, plus the
    // "connecting" transitional). That engine was archived at P3-5 and no
    // Firestore-backed replacement exists yet.
    //
    // D-E: fail LOUDLY, which in a widget means VISIBLY — not fatally. An
    // earlier revision threw here, which meant every cloud-born account got an
    // error screen on opening Parent Settings; that is a worse regression than
    // the fabricated "synced" it was avoiding, and it took the surrounding
    // settings surface down with it.
    //
    // These three statements are all true and none is invented: cloud backup
    // IS active (a cloud-born account writes to Firestore, which queues
    // offline and replays on reconnect), the detailed status is unknown, and
    // NO "last synced" time is claimed because none is available.
    //
    // TODO(AD-30): replace with a real Firestore-backed status. The honest
    // signal exists — `SnapshotMetadata.hasPendingWrites` distinguishes
    // "unacked local writes" from "acked", and `isFromCache` distinguishes
    // offline — it just needs a provider in the data ring, which a
    // presentation/widgets file may not reach directly (AD-23/AD-28).
    if (authState.isCloudBorn) {
      return _buildStatusUnavailableCard(
        context,
        theme,
        heroLayout: parentSettingsHeroLayout,
      );
    }

    // Local-born (or signed-out): the local-only card + "Upgrade to Cloud"
    // CTA is fully backed by auth state alone — no sync engine required.
    return _buildLocalOnlyCard(
      context,
      theme,
      isLocalAuth: authState.isLocalBorn,
      heroLayout: parentSettingsHeroLayout,
    );
  }

  /// Backup card for a cloud-born account whose sync status cannot be
  /// determined. Deliberately states only what is known — see [build].
  Widget _buildStatusUnavailableCard(
    BuildContext context,
    ThemeData theme, {
    required bool heroLayout,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final bodyTextStyle = theme.textTheme.bodySmall?.copyWith(
      color: Colors.white.withValues(alpha: 0.88),
      height: 1.35,
      fontWeight: FontWeight.w600,
      fontSize: 17,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFF0B3FB4),
        borderRadius: BorderRadius.circular(heroLayout ? 24 : 16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.backupSyncCardTitle,
              style: theme.textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(l10n.backupSyncStatusUnavailable, style: bodyTextStyle),
          ],
        ),
      ),
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
}
