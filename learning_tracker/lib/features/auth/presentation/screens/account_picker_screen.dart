import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/auth/domain/services/account_lifecycle_service.dart';
import 'package:learning_tracker/features/auth/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/auth/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
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
    final theme = Theme.of(context);
    final registry = ref.watch(deviceRegistryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Choose an Account')),
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
              // route to WelcomeRoute), but handle gracefully.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  unawaited(context.router.replaceAll([const WelcomeRoute()]));
                }
              });
              return const SizedBox.shrink();
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: accounts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) =>
                        _AccountTile(account: accounts[index]),
                  ),
                ),
                // [+ Add another account] button
                if (accounts.length < kMaxDeviceAccounts)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Column(
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                context.router.push(AccountCreationRoute()),
                            icon: const Icon(Icons.add),
                            label: Text(
                              'Add another account '
                              '(${kMaxDeviceAccounts - accounts.length} '
                              'slots remaining)',
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'Maximum $kMaxDeviceAccounts accounts reached',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AccountTile extends ConsumerWidget {
  const _AccountTile({required this.account});
  final DeviceAccount account;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCloud = account.tier == 'cloudBorn';

    // Cloud session status
    final fbUser = FirebaseAuth.instance.currentUser;
    final hasValidSession =
        isCloud && fbUser != null && fbUser.uid == account.firebaseUid;

    return Dismissible(
      key: ValueKey(account.accountId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: isCloud
              ? theme.colorScheme.errorContainer
              : theme.colorScheme.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          isCloud ? 'Remove from device' : 'Delete account',
          style: TextStyle(
            color: isCloud
                ? theme.colorScheme.onErrorContainer
                : theme.colorScheme.onError,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      confirmDismiss: (direction) => _confirmDismiss(context, isCloud),
      onDismissed: (_) => _onDismissed(context, ref),
      child: Card(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
            child: Icon(
              isCloud ? Icons.cloud : Icons.phone_android,
              color: theme.colorScheme.primary,
            ),
          ),
          title: Text(
            account.displayName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(account.email),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    isCloud ? Icons.cloud : Icons.phone_android,
                    size: 12,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCloud ? 'Cloud' : 'Local',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  if (isCloud && !hasValidSession) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.warning_amber,
                      size: 12,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'Sign in again',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: isCloud
              ? (hasValidSession
                    ? const Icon(Icons.chevron_right)
                    : Icon(Icons.warning_amber, color: theme.colorScheme.error))
              : const Icon(Icons.lock_outline, size: 20),
          onTap: () => _onTap(context, ref, hasValidSession),
        ),
      ),
    );
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    bool hasValidSession,
  ) async {
    final isCloud = account.tier == 'cloudBorn';

    if (isCloud && hasValidSession) {
      // Instant switch — cached Firebase session is valid.
      // Swap the active DB to this account's file BEFORE reading the
      // profile — the cached userDatabaseProvider still points at the
      // previous account otherwise (keepAlive).
      activeDbFileName = account.dbFileName;
      ref.invalidate(userDatabaseProvider);

      final profile = await ref
          .read(userDatabaseProvider)
          .userProfileDao
          .findCloudBornByFirebaseUid(account.firebaseUid!);
      if (profile != null && context.mounted) {
        final prefs = await SharedPreferences.getInstance();
        final session = SessionPersistenceService(
          prefs: prefs,
          registry: ref.read(deviceRegistryProvider),
        );
        await session.setActiveAccount(account.accountId);
        // Re-assert onboarding-complete so AuthGuard lets AppShellRoute
        // through; sign-out clears this flag and the picker is the
        // entry point that restores it.
        await prefs.setBool(kOnboardingComplete, true);
        ref
            .read(authStateProvider.notifier)
            .setCloudBornSession(profile: profile);
        if (context.mounted) {
          unawaited(context.router.replaceAll([const AppShellRoute()]));
        }
      }
    } else if (isCloud && !hasValidSession) {
      // Expired session — route to sign-in with email pre-filled
      if (context.mounted) {
        unawaited(context.router.push(const SignInRoute()));
      }
    } else {
      // Local-born — show password prompt
      if (context.mounted) {
        _showPasswordPrompt(context, ref);
      }
    }
  }

  void _showPasswordPrompt(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    String? error;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Sign in as ${account.displayName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(account.email),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  errorText: error,
                ),
                autofocus: true,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  // Swap to this account's DB first — LocalAuthService
                  // reads the argon2 hash from the account's own DB,
                  // not the globally cached one.
                  activeDbFileName = account.dbFileName;
                  ref.invalidate(userDatabaseProvider);

                  final dao = ref.read(userDatabaseProvider).userProfileDao;
                  final service = LocalAuthService(dao: dao);
                  final profile = await service.signIn(
                    email: account.email,
                    password: controller.text,
                  );
                  final prefs = await SharedPreferences.getInstance();
                  final session = SessionPersistenceService(
                    prefs: prefs,
                    registry: ref.read(deviceRegistryProvider),
                  );
                  await session.setActiveAccount(account.accountId);
                  await prefs.setBool(kOnboardingComplete, true);
                  ref
                      .read(authStateProvider.notifier)
                      .setLocalBornSession(profile: profile);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  if (context.mounted) {
                    unawaited(
                      context.router.replaceAll([const AppShellRoute()]),
                    );
                  }
                } on InvalidCredentialsException {
                  setDialogState(() => error = 'Incorrect password');
                }
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      ),
    ).then((_) => controller.dispose());
  }

  Future<bool> _confirmDismiss(BuildContext context, bool isCloud) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(isCloud ? 'Remove from device?' : 'Delete account?'),
            content: Text(
              isCloud
                  ? 'Your cloud data is safe — you can sign back in anytime.'
                  : 'All learning data will be permanently lost. '
                        'This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                ),
                child: Text(isCloud ? 'Remove' : 'Delete Forever'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _onDismissed(BuildContext context, WidgetRef ref) async {
    final registry = ref.read(deviceRegistryProvider);
    final docsDir = await getApplicationDocumentsDirectory();
    final service = AccountLifecycleService(
      registry: registry,
      databasesPath: docsDir.path,
    );

    final isCloud = account.tier == 'cloudBorn';
    if (isCloud) {
      await service.removeCloudFromDevice(account.accountId);
    } else {
      await service.deleteLocalAccount(account.accountId);
    }
  }
}
