import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/domain/services/account_lifecycle_service.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    hide authStateProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show selectedProfileIdProvider;
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show activeTutoredProfileSelectionProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Account picker shown after sign-out when other accounts remain
/// on the device, or when the user wants to switch accounts.
///
/// Displays all device accounts from the registry with tier badges,
/// session status, and swipe-to-remove/delete actions.
@RoutePage()
class AccountPickerScreen extends ConsumerWidget {
  const AccountPickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final registry = ref.watch(deviceRegistryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.surfaceF5,
      body: SafeArea(
        child: FutureBuilder<List<DeviceAccount>>(
          future: registry.getAllAccounts(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final accounts = snapshot.data!;
            if (accounts.isEmpty) {
              // No accounts left — shouldn't happen (caller should
              // route to SignInRoute), but handle gracefully.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  unawaited(context.router.replaceAll([const SignInRoute()]));
                }
              });
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                    children: [
                      Text(
                        l10n.accountPickerTitle,
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: AppTheme.brandInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.accountPickerSubtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.brandInkMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ...accounts.map(
                        (account) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AccountTile(account: account),
                        ),
                      ),
                    ],
                  ),
                ),
                _BottomAddAccountSection(
                  l10n: l10n,
                  accountCount: accounts.length,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomAddAccountSection extends StatelessWidget {
  const _BottomAddAccountSection({
    required this.l10n,
    required this.accountCount,
  });

  final AppLocalizations l10n;
  final int accountCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          if (accountCount < kMaxDeviceAccounts)
            _DashedOutlineButton(
              onTap: () => context.router.push(SignupRoute()),
              child: Text(
                l10n.accountPickerAddAnother(kMaxDeviceAccounts - accountCount),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppTheme.brandBlueDeep,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                l10n.accountPickerMaxAccountsShort(kMaxDeviceAccounts),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            l10n.accountPickerPrivacyFooter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppTheme.brandInkMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashedOutlineButton extends StatelessWidget {
  const _DashedOutlineButton({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const radius = 24.0;
    return CustomPaint(
      painter: const _DashedRRectPainter(
        color: AppTheme.brandBlueDeep,
        strokeWidth: 1.4,
        radius: radius,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(radius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    const dashWidth = 6.0;
    const dashSpace = 5.0;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = (distance + dashWidth).clamp(0, metric.length).toDouble();
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += dashWidth + dashSpace;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});
  final DeviceAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isCloud = account.accountTier.isCloud;

    // Cloud session status
    final fbUser = ref.read(authRepositoryProvider).currentUser;
    final hasValidSession =
        isCloud && fbUser != null && fbUser.uid == account.firebaseUid;

    return Dismissible(
      key: ValueKey(account.accountId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        decoration: BoxDecoration(
          color: const Color(0xFFF3CCD1),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          isCloud
              ? l10n.accountRemoveFromDevice
              : l10n.accountDeleteAccountAction,
          style: const TextStyle(
            color: AppTheme.brandCoralDeep,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      confirmDismiss: (direction) => _confirmDismiss(context, isCloud),
      onDismissed: (_) => _onDismissed(context, ref),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () => _onTap(context, ref, hasValidSession),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.brandOutline.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _avatarBg(isCloud, hasValidSession),
                  child: Icon(
                    isCloud ? Icons.cloud_rounded : Icons.smartphone_rounded,
                    color: _avatarFg(isCloud, hasValidSession),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppTheme.brandInk,
                        ),
                      ),
                      Text(
                        account.email,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.brandInkMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _pillBg(isCloud, hasValidSession),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _pillText(l10n, isCloud, hasValidSession),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _pillFg(isCloud, hasValidSession),
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isCloud
                      ? (hasValidSession
                            ? Icons.chevron_right_rounded
                            : Icons.warning_rounded)
                      : Icons.lock_outline_rounded,
                  color: isCloud && !hasValidSession
                      ? const Color(0xFFBA273A)
                      : AppTheme.brandInkMuted,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _avatarBg(bool isCloud, bool hasValidSession) {
    if (!isCloud) return const Color(0xFFFEE6C5);
    if (!hasValidSession) return const Color(0xFFF8DDE2);
    return AppTheme.brandBlueSoft;
  }

  Color _avatarFg(bool isCloud, bool hasValidSession) {
    if (!isCloud) return const Color(0xFF6A4926);
    if (!hasValidSession) return AppColors.chartRed;
    return AppTheme.brandBlue;
  }

  Color _pillBg(bool isCloud, bool hasValidSession) {
    if (!isCloud) return const Color(0xFFE8EBF0);
    if (!hasValidSession) return AppColors.statusErrorSoft;
    return const Color(0xFFE8EEFF);
  }

  Color _pillFg(bool isCloud, bool hasValidSession) {
    if (!isCloud) return AppTheme.brandInkMuted;
    if (!hasValidSession) return const Color(0xFFBA273A);
    return AppTheme.brandBlueDeep;
  }

  String _pillText(AppLocalizations l10n, bool isCloud, bool hasValidSession) {
    if (!isCloud) return l10n.badgeLocalAccount;
    if (!hasValidSession) return l10n.badgeSignInAgain;
    return l10n.badgeCloudAccount;
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    bool hasValidSession,
  ) async {
    final isCloud = account.accountTier.isCloud;

    if (isCloud && hasValidSession) {
      // Instant switch — cached Firebase session is valid.
      // Swap the active DB to this account's file BEFORE reading the
      // profile — the cached userDatabaseProvider still points at the
      // previous account otherwise (keepAlive).
      ref
          .read(accountDbFileNameProvider.notifier)
          .setFileName(account.dbFileName);
      ref.invalidate(userDatabaseProvider);

      await _activateCloudAccountFromLocalData(context, ref);
    } else if (isCloud && !hasValidSession) {
      // Use the same configured/overridable checker the rest of the app reads
      // (the provider instance), NOT the package's static singleton — the
      // singleton is unconfigured and untestable, and on an offline device it
      // could mis-probe and push the user to SignInRoute (a network sign-in)
      // instead of restoring local data. Offline-first requires the local data
      // activate without any network round-trip.
      final isOnline = await ref
          .read(internetConnectionCheckerProvider)
          .hasConnection;
      if (isOnline) {
        // Online but the live Firebase session belongs to a DIFFERENT account
        // (one auth slot; currentUser still points at the previously-active
        // account) or no session at all. The device has ONE Firebase
        // currentUser slot, so to read/write THIS account's Firestore space we
        // must re-authenticate to its identity. google_sign_in shows the native
        // account picker; both accounts already live on the device so it's a
        // one-tap, no-password re-auth. Supersedes the old DEC-34 "route to
        // SignInRoute" behaviour for the cloud→cloud switch case.
        if (!context.mounted) return;
        await _reauthAndActivateCloudAccount(context, ref);
      } else {
        // Offline-first cloud behavior: allow local access and queue sync ops.
        if (!context.mounted) return;
        await _activateCloudAccountFromLocalData(context, ref);
      }
    } else {
      // Local-born — instant local activation (no modal password dialog).
      await _activateLocalAccountFromLocalData(context, ref);
    }
  }

  /// Re-authenticate Firebase to THIS cloud account's Google identity, then
  /// activate it. The device holds a single Firebase `currentUser` slot, so a
  /// cloud→cloud switch must align the live session with the target account or
  /// every Firestore read/write into `users/{uid}/…` is permission-denied
  /// (and tutoring breaks — the tutor can't read the child's data).
  ///
  /// Flow:
  ///   0. SILENT-FIRST: try `reauthWithGoogleSilently()` (no UI). If it
  ///      resolves the cached Google session AND its uid == the target's
  ///      `firebaseUid`, activate with NO picker. (Limitation: silent only
  ///      returns the last-authorized Google account, so a cross-account
  ///      switch to a not-cached account yields null / wrong uid and falls
  ///      through to the interactive picker below.)
  ///   1. `signInWithGoogle()` → native account picker (one-tap, no password).
  ///   2. Verify the re-authed uid == the target account's `firebaseUid`. If
  ///      the user picked a different Google account, or the uid drifted from a
  ///      server-side account re-creation, ABORT — do not activate the wrong
  ///      account; surface an error and leave the previous session intact.
  ///   3. On match: activate via the normal local-DB-swap + session path. The
  ///      `authStateProvider` rebuild flips `syncIdentityStatusProvider` back to
  ///      `matched` and the orchestrator/listeners re-resolve; we also kick a
  ///      best-effort launch pull so sync drains for the new identity.
  ///   4. On user-cancel / re-auth failure: fall back GRACEFULLY to local
  ///      activation (offline-first) and let the identity guard show the
  ///      "sign in to back up" state — never crash, never half-switch.
  Future<void> _reauthAndActivateCloudAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final authRepo = ref.read(authRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final targetUid = account.firebaseUid;

    // Tear down the previous account's Firestore real-time listeners BEFORE we
    // re-authenticate to the target identity. The device has a single
    // FirebaseAuth slot; once signInWithGoogle() flips the live uid, any
    // listener still subscribed under the PREVIOUS uid
    // (users/<oldUid>/learner_profiles, the tutor_grants OR-queries) is
    // re-evaluated against the new auth context and denied — the
    // PERMISSION_DENIED flood reported in the bug, and the cause of the
    // parent's "Manage Tutors" sticking on "Pending" (the tutor_grants listen
    // dies on the denial). The listener set is re-opened against the new
    // identity by the orchestrator's active-profile listener once the switch
    // completes. Best-effort: never block or throw out of the switch.
    await ref.read(syncOrchestratorProvider)?.stopListeners();

    // SILENT-FIRST: attempt a no-UI re-auth to the cached Google session. If it
    // resolves the TARGET account's uid, activate with no picker. A null result
    // (no cached session) or a uid mismatch (silent resolved a different cached
    // account) falls through to the interactive picker below — unchanged
    // behaviour. Silent only ever surfaces the last-authorized Google account,
    // so cross-account switches to a not-cached account still need the picker.
    if (targetUid != null) {
      try {
        final silentUser = await authRepo.reauthWithGoogleSilently();
        if (silentUser != null && silentUser.uid == targetUid) {
          if (!context.mounted) return;
          await _activateCloudAccountFromLocalData(context, ref);
          return;
        }
      } catch (_) {
        // Silent attempt failed (never shows UI) → fall through to interactive.
      }
    }

    try {
      await authRepo.signInWithGoogle();
    } on GoogleSignInException catch (e) {
      // User cancelled or interrupted the native picker → fall back to local
      // activation (current offline-first behaviour); no error toast.
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        if (!context.mounted) return;
        await _activateCloudAccountFromLocalData(context, ref);
        return;
      }
      // Any other Google failure → graceful local fallback; the identity guard
      // will surface the "sign in to back up" state in Settings.
      if (!context.mounted) return;
      await _activateCloudAccountFromLocalData(context, ref);
      return;
    } catch (_) {
      // Firebase token exchange / network failure → graceful local fallback.
      if (!context.mounted) return;
      await _activateCloudAccountFromLocalData(context, ref);
      return;
    }

    // Verify the re-authed identity matches the account the user tapped.
    final liveUid = authRepo.currentUser?.uid;
    if (targetUid == null || liveUid == null || liveUid != targetUid) {
      // Wrong Google account picked (or uid churn). Do NOT activate the wrong
      // account. Restore the prior live session is not possible without its
      // credential, so we sign the mis-picked session out (best-effort) and
      // abort the switch — the previously-active account's LOCAL data is in its
      // own DB file and is untouched.
      try {
        await authRepo.signOut();
      } catch (_) {
        // Sign-out best-effort; ignore.
      }
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.authGoogleSignInFailed)));
      return;
    }

    // Identity matched — activate the account locally + restart sync.
    if (!context.mounted) return;
    await _activateCloudAccountFromLocalData(context, ref);
  }

  Future<void> _activateCloudAccountFromLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Always swap DB first, so profile reads are scoped to this account.
    ref
        .read(accountDbFileNameProvider.notifier)
        .setFileName(account.dbFileName);
    ref.invalidate(userDatabaseProvider);

    final dao = ref.read(userDatabaseProvider).userProfileDao;
    var profile = account.firebaseUid == null
        ? null
        : await dao.findCloudBornByFirebaseUid(account.firebaseUid!);

    if (profile == null) {
      final profiles = await dao.getAllUserProfiles();
      for (final candidate in profiles) {
        if (candidate.accountTier.isCloud &&
            candidate.email.toLowerCase() == account.email.toLowerCase()) {
          profile = candidate;
          break;
        }
      }
    }

    if (profile == null || !context.mounted) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final session = SessionPersistenceService(
      prefs: prefs,
      registry: ref.read(deviceRegistryProvider),
    );
    await session.setActiveAccount(account.accountId);
    // Re-assert onboarding-complete so AuthGuard lets AppShellRoute through.
    await prefs.setBool(kOnboardingComplete, true);

    // R1o-C2: clear any stale selected profile id from the previous account.
    // Per-account autoincrement IDs collide; a leaked id would short-circuit
    // ProfileGuard onto the wrong profile in this account's DB.
    ref.read(selectedProfileIdProvider.notifier).clear();

    // An account switch lands on the switched account's OWN profile in NORMAL
    // mode: clear any active talmid selection and lock the parent-PIN gate
    // (pinGuard.lock() also clears parentPinAuthenticatedProfileId via its
    // onSessionLocked callback) so the previous account's tutor/parent context
    // never leaks into the new one.
    ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
    ref.read(routerProvider).pinGuard.lock();

    ref.read(authStateProvider.notifier).setCloudBornSession(profile: profile);

    // Restart sync for the now-active identity. The authStateProvider rebuild
    // above already re-resolves syncIdentityStatusProvider (→ matched when the
    // live Firebase uid equals this account's uid after re-auth) and rebuilds
    // the Firestore gateway/orchestrator. Kick a best-effort launch pull so the
    // outbox drains and listeners re-resolve immediately; offline-first means
    // this must never block or throw out of the switch.
    final orchestrator = ref.read(syncOrchestratorProvider);
    if (orchestrator != null) {
      // Re-open the Firestore real-time listeners against the now-active
      // identity. The previous account's listeners were torn down before
      // re-auth (see _reauthAndActivateCloudAccount / _onTap) so the set is
      // currently stopped; restart deterministically rebinds it to the new
      // uid + profile — even when the new account's active profile id collides
      // with the previous one (the orchestrator's profile-change listener
      // would not fire in that case).
      orchestrator.restartListeners();
      unawaited(
        orchestrator.pullOnLaunch().timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        ),
      );
    }

    if (context.mounted) {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  Future<void> _activateLocalAccountFromLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    ref
        .read(accountDbFileNameProvider.notifier)
        .setFileName(account.dbFileName);
    ref.invalidate(userDatabaseProvider);

    final dao = ref.read(userDatabaseProvider).userProfileDao;
    final profile = await dao.findLocalBornByEmail(account.email);
    if (profile == null || !context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final session = SessionPersistenceService(
      prefs: prefs,
      registry: ref.read(deviceRegistryProvider),
    );
    await session.setActiveAccount(account.accountId);
    await prefs.setBool(kOnboardingComplete, true);
    // R1o-C2: clear any stale selected profile id from the previous account.
    ref.read(selectedProfileIdProvider.notifier).clear();
    // Land on the switched account's OWN profile in NORMAL mode — drop any
    // talmid selection and lock the parent-PIN gate carried over from the
    // previous account.
    ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
    ref.read(routerProvider).pinGuard.lock();
    // DEC-34: do NOT call signOut() — switching accounts must never terminate
    // other accounts' sessions. The Drift DB swap above isolates the data;
    // the AuthState update below makes this account the active on-screen context.
    // Firebase's currentUser may still point at a cloud account from before the
    // switch; that is intentional — the local-born account does not use Firebase.
    ref.read(authStateProvider.notifier).setLocalBornSession(profile: profile);

    if (context.mounted) {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  Future<bool> _confirmDismiss(BuildContext context, bool isCloud) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final d = AppLocalizations.of(ctx)!;
            return AlertDialog(
              title: Text(
                isCloud
                    ? d.accountRemoveFromDeviceTitle
                    : d.accountDeleteAccountTitle,
              ),
              content: Text(
                isCloud
                    ? d.accountRemoveFromDeviceBody
                    : d.accountDeleteAccountBody,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(d.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: Theme.of(ctx).colorScheme.error,
                  ),
                  child: Text(
                    isCloud ? d.accountRemove : d.accountDeleteForever,
                  ),
                ),
              ],
            );
          },
        ) ??
        false;
  }

  Future<void> _onDismissed(BuildContext context, WidgetRef ref) async {
    final registry = ref.read(deviceRegistryProvider);
    final docsDir = await getApplicationDocumentsDirectory();
    final service = AccountLifecycleService(
      registry: registry,
      databasesPath: docsDir.path,
      authRepository: ref.read(authRepositoryProvider),
    );

    // D20: the picker is reachable MID-SESSION (Profile Switcher → Switch
    // Account). Removing the row of the CURRENTLY-ACTIVE account `deleteSync`s
    // its SQLite file out from under the live Drift connection (writes go to an
    // orphaned inode, reads can throw) while authState/selectedProfileId still
    // point at it. Tear the session down FIRST — close the Drift handle, clear
    // auth + selected profile + active-account pointer — then delete, then
    // route away. Mirrors showDeleteLocalAccountFlow.
    final isActive = ref.read(accountDbFileNameProvider) == account.dbFileName;
    if (isActive) {
      ref
          .read(accountDbFileNameProvider.notifier)
          .setFileName('learning_tracker');
      ref.invalidate(userDatabaseProvider);
      ref.read(authStateProvider.notifier).signOut();
      ref.read(selectedProfileIdProvider.notifier).clear();
      ref.read(routerProvider).pinGuard.lock();
      final prefs = await SharedPreferences.getInstance();
      await SessionPersistenceService(
        prefs: prefs,
        registry: registry,
      ).clearActiveAccount();
    }

    final isCloud = account.accountTier.isCloud;
    if (isCloud) {
      await service.removeCloudFromDevice(account.accountId);
    } else {
      await service.deleteLocalAccount(account.accountId);
    }

    if (!isActive || !context.mounted) return;
    // Active account is gone — route away from the now-orphaned context.
    final remaining = await registry.getAllAccounts();
    final router = ref.read(routerProvider);
    await router.replaceAll([
      remaining.isNotEmpty ? const AccountPickerRoute() : const SignInRoute(),
    ]);
  }
}
