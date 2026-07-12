import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/app/restore/restore_providers.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_phase.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_status.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_error_code.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

@RoutePage()
class DeviceRestoreScreen extends ConsumerStatefulWidget {
  const DeviceRestoreScreen({super.key});

  @override
  ConsumerState<DeviceRestoreScreen> createState() =>
      _DeviceRestoreScreenState();
}

class _DeviceRestoreScreenState extends ConsumerState<DeviceRestoreScreen> {
  @override
  void initState() {
    super.initState();
    _startRestore();
  }

  Future<void> _startRestore() async {
    // Yield one microtask so initState() finishes before any ref.read /
    // ref.invalidate calls.  Flutter forbids reading inherited widgets
    // synchronously inside initState (Riverpod reads are InheritedWidget-based).
    await Future<void>.microtask(() {});
    if (!mounted) return;
    final service = ref.read(deviceRestoreServiceProvider);
    if (service == null) {
      // Local-only account — no Firestore restore possible.  Navigate to the
      // app shell immediately so the user is not left on a blank idle screen.
      // (SY-2: null-service early-return blank-screen fix.)
      if (mounted) _navigateToApp();
      return;
    }
    final success = await service.restore();
    if (!mounted) return;
    if (success) {
      await _navigateAfterRestore();
      return;
    }
    // restore() returned false.  Two cases:
    //   • error   — the service already emitted RestoreStatus.error(...) and
    //               the build() method renders a retry / skip affordance.
    //               No navigation needed — let the error card handle it.
    //   • idle    — the service decided the device does NOT need a restore
    //               (e.g. restoreStatePrefKey == 'complete' but the
    //               RestoreGuard was reset). The screen would render
    //               SizedBox.shrink() permanently.  Since the guard already
    //               activated, we must clear it and route to the app shell
    //               so the user is never left on a blank screen.
    //
    // Read the current status directly from the service (not from
    // restoreStatusProvider, which may be overridden in tests) to ensure the
    // idle-escape path uses the authoritative in-flight status.
    if (service.currentStatus is RestoreStatusIdle) {
      _navigateToApp();
    }
  }

  Future<void> _retry() async {
    final service = ref.read(deviceRestoreServiceProvider);
    if (service == null) return;
    final success = await service.retry();
    if (mounted && success) {
      await _navigateAfterRestore();
    }
  }

  /// Drops cached values from the providers most likely to have rendered
  /// the empty pre-restore snapshot (profile lists, the active profile).
  /// The dashboard, picker, and shell rebuild from the now-populated DB on
  /// the next frame. We do NOT invalidate the database connection itself —
  /// that would close Drift's executor mid-flight.
  void _refreshProvidersAfterRestore() {
    ref.invalidate(profileListProvider);
    ref.invalidate(profileListStreamProvider);
    ref.invalidate(selectedProfileProvider);
  }

  void _navigateToApp() {
    _refreshProvidersAfterRestore();
    final router = ref.read(routerProvider);
    router.restoreGuard.markRestoreComplete();
    context.router.replaceAll([const AppShellRoute()]);
  }

  /// Plan §F Phase 4 deliverable 5 — route to the right screen post-restore
  /// based on the just-merged profile count. NEVER goes to the onboarding
  /// wizard: by the time we get here, [DeviceRestoreService.restore]
  /// returned true, so at minimum the pull populated whatever profiles
  /// exist in the cloud. Treat the just-pulled local DB as the source of
  /// truth — exactly the gap the spec calls out.
  ///
  /// Routing matrix:
  ///   * profile count == 1 → [AppShellRoute] with the sole profile selected.
  ///   * profile count >= 2 → [ProfilePickerRoute] so the user picks.
  ///   * profile count == 0 → [AppShellRoute] (defensive — the restoreGuard
  ///                          will keep us out of the picker until a profile
  ///                          exists; this path is unreachable when restore
  ///                          actually pulled cloud profiles down).
  Future<void> _navigateAfterRestore() async {
    _refreshProvidersAfterRestore();
    final router = ref.read(routerProvider);
    router.restoreGuard.markRestoreComplete();

    final db = ref.read(userDatabaseProvider);
    final accountId = ref.read(currentAccountIdProvider);
    final profiles = await db.profileDao.getProfilesByAccount(accountId);

    if (!mounted) return;

    if (profiles.length == 1) {
      ref.read(selectedProfileIdProvider.notifier).select(profiles.first.id);
      await context.router.replaceAll([const AppShellRoute()]);
    } else if (profiles.length > 1) {
      ref.read(selectedProfileIdProvider.notifier).clear();
      await context.router.replaceAll([const ProfilePickerRoute()]);
    } else {
      await context.router.replaceAll([const AppShellRoute()]);
    }
  }

  /// Maps each [RestorePhase] emitted by [DeviceRestoreService] to a
  /// localized label.
  ///
  /// AUD-app-02 (EH-5/EH-6): [phase] is a closed enum (not a free-text
  /// sentinel string), and this switch is EXHAUSTIVE — no wildcard `_` arm.
  /// Adding a new [RestorePhase] value without adding its case here is a
  /// compile error, not a silent fallback to raw English text.
  ///
  /// loop-iter2: DeviceRestoreService's phase lives outside owned roots and
  /// cannot import l10n directly, so the screen is the correct place to
  /// apply localization.
  String _localizePhase(RestorePhase phase, AppLocalizations l10n) {
    return switch (phase) {
      RestorePhase.pullingData => l10n.deviceRestorePhaseRestoring,
      RestorePhase.loadingCurricula => l10n.deviceRestorePhaseLoadingCurricula,
      RestorePhase.importingContent => l10n.deviceRestorePhaseImportingContent,
    };
  }

  /// Resolves a [SyncErrorCode] to a localized, user-facing subtitle.
  ///
  /// AUD-sync-01 (EH-5): [RestoreStatus.error] carries a stable code, never
  /// a pre-formatted message — this exhaustive switch is the single place
  /// that maps each code to user-facing text. The exception's raw text
  /// (exposed only via [RestoreStatus.error.debugDetail] for logs) must
  /// never reach this switch or be rendered.
  String _errorSubtitle(SyncErrorCode code, AppLocalizations l10n) {
    return switch (code) {
      SyncErrorCode.timeout => l10n.deviceRestoreErrorTimeout,
      SyncErrorCode.permissionDenied => l10n.deviceRestoreErrorPermissionDenied,
      SyncErrorCode.unknown => l10n.deviceRestoreErrorGeneric,
    };
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(restoreStatusProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // The status branches are fixed piles of content (no Expanded/Spacer),
      // so a plain SingleChildScrollView is the right escape valve: it
      // shrink-wraps and stays centred on normal screens, and scrolls instead
      // of throwing a RenderFlex overflow on short viewports / large text.
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: status.when(
            // SY-2: render a visible spinner so the user is never left on a
            // completely blank screen during the transient idle window while
            // restore() initialises, or when an edge-case keeps status idle.
            idle: () => const CircularProgressIndicator(),
            checking: () => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(l10n.deviceRestoreChecking),
              ],
            ),
            restoring: (phase, completedSteps, totalSteps) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(
                  _localizePhase(phase, l10n),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: totalSteps > 0 ? completedSteps / totalSteps : null,
                ),
                const SizedBox(height: 8),
                Text(l10n.deviceRestoreStep(completedSteps, totalSteps)),
              ],
            ),
            complete: (collectionsRestored) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: AppTheme.brandGold,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.deviceRestoreComplete,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            error: (code, debugDetail) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: AppTheme.brandCoralDeep,
                ),
                const SizedBox(height: 24),
                Text(
                  l10n.deviceRestoreFailed,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  // AUD-sync-01 (EH-5): resolve the stable code to a
                  // localized string — [debugDetail] is diagnostics-only
                  // and must never be rendered to the user.
                  _errorSubtitle(code, l10n),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                ElevatedButton(onPressed: _retry, child: Text(l10n.retry)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _navigateToApp,
                  child: Text(l10n.skipAndContinue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
