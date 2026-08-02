import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/tutored_mirror_wipe_service.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/services/account_lifecycle_service.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show currentAccountIdProvider, selectedProfileIdProvider;
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show activeTutoredProfileSelectionProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shared account actions used by multiple settings surfaces.

Future<void> showSignOutConfirmation(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.46),
    builder: (context) {
      final theme = Theme.of(context);
      return Dialog(
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(34),
          ),
          clipBehavior: Clip.antiAlias,
          // Scroll the icon + body + buttons so the dialog never overflows on a
          // short screen / large text; the padding moves inside the scroll view
          // so it scrolls with the content.
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: context.colors.statusErrorSoft,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: context.colors.chartRed,
                        size: 40,
                      ),
                    ),
                    Positioned(
                      top: -1,
                      right: -2,
                      child: Container(
                        width: 23,
                        height: 23,
                        decoration: BoxDecoration(
                          color: context.colors.brandBlue,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: context.colors.brandCreamCard,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.question_mark_rounded,
                          size: 13,
                          // AUD dark-mode sweep: was a hardcoded
                          // Colors.white — brandBlue LIGHTENS in dark mode
                          // (an ink-role token used here as a fill), so a
                          // fixed white glyph sank to 2.52:1.
                          // theme.colorScheme.onPrimary is the app's own
                          // contrast-computed pair for this exact fill.
                          color: theme.colorScheme.onPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  AppLocalizations.of(context)!.signOutConfirmTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: context.colors.brandBlueDeep,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  AppLocalizations.of(context)!.signOutConfirmBody,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: context.colors.brandInkMuted,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: context.colors.brandBlue,
                      // AUD dark-mode sweep: was a hardcoded Colors.white —
                      // same brandBlue-as-fill issue as the badge icon
                      // above (2.52:1 in dark). theme.colorScheme.onPrimary
                      // is the app's own contrast-computed pair for this
                      // fill (already used by every FilledButton that does
                      // NOT override its foreground).
                      foregroundColor: theme.colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                      elevation: 2,
                    ),
                    child: Text(AppLocalizations.of(context)!.signOutLabel),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: context.colors.brandInkMuted,
                      // AUD dark-mode sweep: was a hardcoded
                      // Color(0xFFF0F1F5) pale-grey chip under the already
                      // brightness-aware brandInkMuted text (lightens in
                      // dark) — measured 2.28:1 in dark. brandCreamSoft is
                      // the paired recessed-surface token (near-identical
                      // in light; darkens with the text in dark, 5.97:1).
                      backgroundColor: context.colors.brandCreamSoft,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: Text(AppLocalizations.of(context)!.actionCancel),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  // Capture the root router + registry BEFORE mutating auth state. Signing out
  // flips authStateProvider to signed-out, which trips the router's authGuard
  // and tears down the AppShell (and the Settings page whose context/ref were
  // passed in here). After that teardown, reading providers off the disposed
  // widget's `ref` throws and the navigation below would be skipped silently —
  // leaving the user stranded on Settings. Capturing first makes navigation
  // independent of the caller widget's lifecycle.
  final router = ref.read(routerProvider);
  final registry = ref.read(deviceRegistryProvider);

  try {
    // T5.lifecycle — wipe tutored mirrors before clearing auth state so we
    // still have the accountId and the DB handle.
    final accountId = ref.read(currentAccountIdProvider);
    final db = ref.read(userDatabaseProvider);
    // R4-H2: pass onWipe so exit() fires even when AppShell is not mounted.
    // The keepAlive tutoredListenerSupervisorProvider would otherwise keep
    // subscriptions alive indefinitely if AppShell is not mounted at sign-out.
    await TutoredMirrorWipeService(
      profileDao: db.profileDao,
      onWipe: (_) =>
          ref.read(activeTutoredProfileSelectionProvider.notifier).exit(),
    ).wipeAllMirrors(accountId);

    final service = ref.read(accountManagementServiceProvider);
    await service.signOut();
    // Hard sign-out: clear Firebase session so the user must re-authenticate
    // on next launch rather than being silently resumed via cached token.
    await ref.read(authRepositoryProvider).signOut();
    ref.read(authStateProvider.notifier).signOut();
    router.pinGuard.lock();

    final accounts = await registry.getAllAccounts();
    // Use root AppRouter — context.router inside a tab's StackRouter cannot
    // navigate to root-level routes (SignInRoute, AccountPickerRoute). Both
    // router + registry were captured above, before auth-state teardown.
    if (accounts.isNotEmpty) {
      await router.replaceAll([const AccountPickerRoute()]);
    } else {
      await router.replaceAll([const SignInRoute()]);
    }
  } catch (e) {
    if (context.mounted) {
      // AUD dark-mode sweep: backgroundColor was context.colors
      // .brandCoralDeep — an INK-role token that LIGHTENS in dark mode —
      // used as a fill under the SnackBar theme's default (also near-
      // white-in-dark) content text: both went light together, measured
      // 1.5:1 in dark. theme.colorScheme.error/onError is the app's own
      // fill+contrast-computed-text pair (same mechanism as onPrimary
      // above) for exactly this "error surface" role — 7.6:1 in dark,
      // 5.52:1 in light (was 5.87:1; still comfortably >4.5:1).
      final theme = Theme.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.errorSignOutFailed,
            style: TextStyle(color: theme.colorScheme.onError),
          ),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }
}

Future<void> showDeleteAccountFlow(
  BuildContext context,
  WidgetRef ref,
  AppUser? user,
) async {
  if (user == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final offlineMsg = AppLocalizations.of(
    context,
  )!.errorDeleteAccountRequiresInternet;
  final isOnline = await ref.read(connectivityServiceProvider).isOnline;
  if (!isOnline) {
    messenger.showSnackBar(SnackBar(content: Text(offlineMsg)));
    return;
  }

  final service = ref.read(accountManagementServiceProvider);

  final hasPassword = user.providers.contains('password');
  final hasGoogle = user.providers.contains('google.com');

  if (!context.mounted) return;

  // Show the type-DELETE confirmation first so the user knows what they're
  // doing before being prompted for credentials. The dialog copy explains
  // that a sign-in prompt follows.
  final confirmed = await showDeleteAccountDialog(
    context: context,
    needsReauth: hasGoogle || hasPassword,
    reauthProvider: hasGoogle ? 'Google' : null,
  );
  if (confirmed != true || !context.mounted) return;

  var reauthenticated = false;

  if (hasPassword) {
    reauthenticated =
        await showReauthenticateDialog(
          context: context,
          email: user.email ?? '',
          service: service,
        ) ??
        false;
  } else if (hasGoogle) {
    // Show an explanation before invoking Google Sign-In so the user
    // understands WHY they are being redirected to Google.
    final proceed = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.46),
      builder: (ctx) {
        final l10n = AppLocalizations.of(ctx)!;
        return AlertDialog(
          title: Text(l10n.reauthGoogleTitle),
          content: Text(l10n.reauthGoogleBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.actionCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l10n.reauthGoogleContinue),
            ),
          ],
        );
      },
    );
    if (proceed != true || !context.mounted) return;

    try {
      await service.reauthenticateWithGoogle();
      reauthenticated = true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User cancelled — do nothing.
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorReauthFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorReauthFailed),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  } else {
    // No re-auth provider available but we still have a Firebase user —
    // treat as already authenticated (e.g. anonymous/custom token).
    reauthenticated = true;
  }

  if (!reauthenticated || !context.mounted) return;

  // Navigate to a blocking overlay immediately after re-auth so the user
  // cannot interact with the app while deletion runs (may take 10+ seconds).
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black87,
    builder: (ctx) => UncontrolledProviderScope(
      container: ProviderScope.containerOf(context),
      child: _DeletingAccountOverlay(accountId: user.uid),
    ),
  );
}

// ---------------------------------------------------------------------------
// Blocking account-deletion overlay
// ---------------------------------------------------------------------------

/// Full-screen modal that runs [AccountManagementService.deleteAccount] and
/// prevents all app interaction while the wipe is in progress.
///
/// Uses [ProviderScope] re-parenting so it can read Riverpod providers even
/// though it is pushed via [showDialog] outside the normal route tree.
class _DeletingAccountOverlay extends ConsumerStatefulWidget {
  const _DeletingAccountOverlay({required this.accountId});

  final String accountId;

  @override
  ConsumerState<_DeletingAccountOverlay> createState() =>
      _DeletingAccountOverlayState();
}

class _DeletingAccountOverlayState
    extends ConsumerState<_DeletingAccountOverlay> {
  // EH-5 (AUD-core-auth-03): deliberately a bool, not the caught exception's
  // message/toString(). `deleteAccount()` can fail with anything from a
  // FirebaseAuthException (English SDK message) to this file's own
  // NotAuthenticatedException — none of that is safe to render untranslated.
  // `l10n.deletingAccountError` (in [_buildError]) is the only user-facing
  // copy; the raw error is logged via [AppLogger] for diagnostics instead.
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_runDeletion());
  }

  Future<void> _runDeletion() async {
    try {
      final service = ref.read(accountManagementServiceProvider);
      await service.deleteAccount(widget.accountId);
      if (!mounted) return;

      // D19: deleteAccount wipes the cloud + local table rows + prefs, but
      // leaves the DEVICE REGISTRY row and the per-account DB file intact, so
      // the deleted account reappears in the Account Picker on next launch and
      // tapping it activates an empty shell. Tear those down too: close the
      // open Drift handle (reset to the default file) BEFORE deleting the file,
      // then remove the file + registry row (which also clears
      // lastActiveAccountId — D10).
      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByFirebaseUid(widget.accountId);
      if (account != null) {
        if (ref.read(accountDbFileNameProvider) == account.dbFileName) {
          ref
              .read(accountDbFileNameProvider.notifier)
              .setFileName('learning_tracker');
          ref.read(activeAccountIdProvider.notifier).set(null);
          ref.invalidate(userDatabaseProvider);
        }
        final docsDir = await getApplicationDocumentsDirectory();
        await AccountLifecycleService(
          registry: registry,
          databasesPath: docsDir.path,
          authRepository: ref.read(authRepositoryProvider),
        ).removeCloudFromDevice(account.accountId);
      }
      if (!mounted) return;
      // AuthStateNotifier is keepAlive — always clear so router guards see
      // signed-out state regardless of whether deleteAccount fully succeeded.
      ref.read(authStateProvider.notifier).signOut();
      ref.invalidate(authStateProvider);
      // Replace the underlying route stack with SignIn BEFORE dismissing the
      // overlay. Popping first briefly exposes the now-wiped Settings screen
      // with full interactivity until the async replace lands.
      await ref.read(routerProvider).replaceAll([const SignInRoute()]);
      if (mounted) Navigator.of(context).pop(); // close overlay
    } catch (e, stackTrace) {
      if (mounted) {
        // EH-5 (AUD-core-auth-03): log the raw error for diagnostics — never
        // surface e.toString()/e.message in the UI (see [_hasError] doc).
        AppLogger.instance.error(
          event: 'delete_account_failed',
          fields: {'accountId': widget.accountId},
          exception: e,
          stackTrace: stackTrace,
        );
        setState(() => _hasError = true);
        // Still clear auth even on failure — account may be partially deleted.
        ref.read(authStateProvider.notifier).signOut();
        ref.invalidate(authStateProvider);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black87,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: _hasError
                  ? _buildError(context, l10n)
                  : _buildProgress(l10n),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgress(AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(color: Colors.white),
        const SizedBox(height: 24),
        Text(
          l10n.deletingAccountTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.deletingAccountBody,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, AppLocalizations l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.red, size: 48),
        const SizedBox(height: 16),
        Text(
          l10n.deletingAccountError,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            setState(() => _hasError = false);
            unawaited(_runDeletion());
          },
          child: Text(l10n.actionRetry),
        ),
        const SizedBox(height: 8),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.white70),
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(
              ref.read(routerProvider).replaceAll([const SignInRoute()]),
            );
          },
          child: Text(l10n.actionCancel),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
/// Permanent deletion for [Tier.localBorn] accounts (device-only data).
///
/// Closes the active Drift DB if needed, deletes the account DB file,
/// removes the registry row, clears session prefs, and routes to the
/// account picker or sign-in when nothing remains on device.
Future<void> showDeleteLocalAccountFlow(
  BuildContext context,
  WidgetRef ref,
) async {
  final authState = ref.read(authStateProvider);
  if (!authState.isLocalBorn) return;

  final confirmed = await showDeleteAccountDialog(context: context);
  if (confirmed != true || !context.mounted) return;

  try {
    final prefs = await SharedPreferences.getInstance();
    final registry = ref.read(deviceRegistryProvider);
    final session = SessionPersistenceService(prefs: prefs, registry: registry);
    final accountId = await session.resolveActiveAccountId();
    if (accountId == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorResolveAccount),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final account = await registry.findById(accountId);
    if (account == null || !account.accountTier.isLocal) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.errorOnlyOfflineDelete),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (ref.read(accountDbFileNameProvider) == account.dbFileName) {
      ref
          .read(accountDbFileNameProvider.notifier)
          .setFileName('learning_tracker');
      ref.read(activeAccountIdProvider.notifier).set(null);
      ref.invalidate(userDatabaseProvider);
    }

    final docsDir = await getApplicationDocumentsDirectory();
    final lifecycle = AccountLifecycleService(
      registry: registry,
      databasesPath: docsDir.path,
    );
    await lifecycle.deleteLocalAccount(accountId);

    await session.clearActiveAccount();

    final management = ref.read(accountManagementServiceProvider);
    await management.signOut();

    ref.read(authStateProvider.notifier).signOut();
    ref.read(selectedProfileIdProvider.notifier).clear();
    ref.read(routerProvider).pinGuard.lock();

    final remaining = await registry.getAllAccounts();
    final router = ref.read(routerProvider);
    if (remaining.isNotEmpty) {
      await router.replaceAll([const AccountPickerRoute()]);
    } else {
      await router.replaceAll([const SignInRoute()]);
    }
  } catch (e, stackTrace) {
    // EH-5/ST-4: never surface the raw exception's toString() in the UI —
    // log it for diagnostics and show only the fixed, localized fallback
    // copy instead.
    AppLogger.instance.error(
      event: 'delete_local_account_failed',
      exception: e,
      stackTrace: stackTrace,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorDeleteAccountFailed),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
