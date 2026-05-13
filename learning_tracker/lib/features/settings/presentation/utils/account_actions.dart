import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/navigation/router_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/auth/domain/models/app_user.dart';
import 'package:learning_tracker/features/auth/domain/services/account_lifecycle_service.dart';
import 'package:learning_tracker/features/auth/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/account_management_providers.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/delete_account_dialog.dart';
import 'package:learning_tracker/features/settings/presentation/widgets/reauthenticate_dialog.dart';
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
                  child: const Text('Sign Out'),
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
                  child: const Text('Cancel'),
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
    ref.read(routerProvider).parentPinGuard.lock();

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
        const SnackBar(
          content: Text('Failed to sign out. Please try again.'),
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

  final service = ref.read(accountManagementServiceProvider);

  final hasPassword = user.providers.contains('password');
  final hasGoogle = user.providers.contains('google.com');

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
    try {
      await service.reauthenticateWithGoogle();
      reauthenticated = true;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User cancelled — do nothing.
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Re-authentication failed. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Re-authentication failed. Please try again.'),
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

  String? deleteError;
  try {
    await service.deleteAccount(user.uid);
  } catch (e) {
    deleteError = e.toString();
  } finally {
    // AuthStateNotifier is keepAlive and doesn't auto-react to Firebase
    // auth changes — always clear it here so the router guards see a
    // signed-out user regardless of whether deleteAccount fully succeeded.
    ref.read(authStateProvider.notifier).signOut();
    ref.invalidate(authStateProvider);
  }

  if (!context.mounted) return;

  if (deleteError != null) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Account sign-out complete, but deletion was partial: $deleteError',
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 6),
      ),
    );
  } else {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Account deleted'),
        content: const Text(
          'Your account and all associated data have been permanently deleted.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  if (!context.mounted) return;
  // Use root AppRouter — context.router inside a tab cannot navigate to
  // root-level routes and throws, preventing sign-in navigation.
  unawaited(ref.read(routerProvider).replaceAll([const SignInRoute()]));
}

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
          const SnackBar(
            content: Text('Could not resolve this account. Try again.'),
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
          const SnackBar(
            content: Text('Only offline accounts can be deleted here.'),
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
    ref.read(routerProvider).parentPinGuard.lock();

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
          content: Text('Failed to delete account: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
