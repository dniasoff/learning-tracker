import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/network_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/services/account_lifecycle_service.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
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
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
          decoration: BoxDecoration(
            color: AppTheme.brandCreamCard,
            borderRadius: BorderRadius.circular(34),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFDE7EA),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFB43A4A),
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
                        color: AppTheme.brandBlue,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.brandCreamCard,
                          width: 2,
                        ),
                      ),
                      child: const Icon(
                        Icons.question_mark_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Sign Out',
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: AppTheme.brandBlueDeep,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Are you sure you want to sign out?\n'
                'Your data will be preserved for when\n'
                'you sign back in.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppTheme.brandInkMuted,
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
                    backgroundColor: AppTheme.brandBlue,
                    foregroundColor: Colors.white,
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
                    foregroundColor: AppTheme.brandInkMuted,
                    backgroundColor: const Color(0xFFF0F1F5),
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
      );
    },
  );

  if (confirmed != true || !context.mounted) return;

  try {
    final service = ref.read(accountManagementServiceProvider);
    await service.signOut();
    // Hard sign-out: clear Firebase session so the user must re-authenticate
    // on next launch rather than being silently resumed via cached token.
    await ref.read(authRepositoryProvider).signOut();
    ref.read(authStateProvider.notifier).signOut();
    ref.read(routerProvider).pinGuard.lock();

    final registry = ref.read(deviceRegistryProvider);
    final accounts = await registry.getAllAccounts();
    // Use root AppRouter — context.router inside a tab's StackRouter cannot
    // navigate to root-level routes (SignInRoute, AccountPickerRoute).
    final router = ref.read(routerProvider);
    if (accounts.isNotEmpty) {
      await router.replaceAll([const AccountPickerRoute()]);
    } else {
      await router.replaceAll([const SignInRoute()]);
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.errorSignOutFailed),
          backgroundColor: AppTheme.brandCoralDeep,
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
  String? _error;

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
      // AuthStateNotifier is keepAlive — always clear so router guards see
      // signed-out state regardless of whether deleteAccount fully succeeded.
      ref.read(authStateProvider.notifier).signOut();
      ref.invalidate(authStateProvider);
      // Replace the underlying route stack with SignIn BEFORE dismissing the
      // overlay. Popping first briefly exposes the now-wiped Settings screen
      // with full interactivity until the async replace lands.
      await ref.read(routerProvider).replaceAll([const SignInRoute()]);
      if (mounted) Navigator.of(context).pop(); // close overlay
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
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
              child: _error != null
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
        const SizedBox(height: 8),
        Text(
          _error!,
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () {
            setState(() => _error = null);
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
    if (account == null || account.tier != 'localBorn') {
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

    if (activeDbFileName == account.dbFileName) {
      activeDbFileName = 'learning_tracker';
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
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(
              context,
            )!.errorDeleteAccountFailed(e.toString()),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
