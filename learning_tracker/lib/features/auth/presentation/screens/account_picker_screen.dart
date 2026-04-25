import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/auth/domain/services/account_lifecycle_service.dart';
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
    final registry = ref.watch(deviceRegistryProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
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
                        'Choose an Account',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: AppTheme.brandInk,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Select a learner to continue your journey',
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
                _BottomAddAccountSection(accountCount: accounts.length),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _BottomAddAccountSection extends StatelessWidget {
  const _BottomAddAccountSection({required this.accountCount});

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
                '+1   Add another account '
                '(${kMaxDeviceAccounts - accountCount} slots remaining)',
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
                'Maximum $kMaxDeviceAccounts accounts reached',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppTheme.brandInkMuted,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Manage your privacy and security in Settings',
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
      painter: _DashedRRectPainter(
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
          color: const Color(0xFFF3CCD1),
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          isCloud ? 'Remove from device' : 'Delete account',
          style: TextStyle(
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
              border: Border.all(color: AppTheme.brandOutline.withValues(alpha: 0.4)),
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
                          _pillText(isCloud, hasValidSession),
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
    if (!hasValidSession) return const Color(0xFFB43A4A);
    return AppTheme.brandBlue;
  }

  Color _pillBg(bool isCloud, bool hasValidSession) {
    if (!isCloud) return const Color(0xFFE8EBF0);
    if (!hasValidSession) return const Color(0xFFFDE7EA);
    return const Color(0xFFE8EEFF);
  }

  Color _pillFg(bool isCloud, bool hasValidSession) {
    if (!isCloud) return AppTheme.brandInkMuted;
    if (!hasValidSession) return const Color(0xFFBA273A);
    return AppTheme.brandBlueDeep;
  }

  String _pillText(bool isCloud, bool hasValidSession) {
    if (!isCloud) return 'LOCAL ACCOUNT';
    if (!hasValidSession) return 'SIGN IN AGAIN';
    return 'CLOUD ACCOUNT';
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

      await _activateCloudAccountFromLocalData(context, ref);
    } else if (isCloud && !hasValidSession) {
      final isOnline = await InternetConnectionChecker.instance.hasConnection;
      if (isOnline) {
        // Online with invalid/expired session — route to sign-in.
        if (context.mounted) {
          unawaited(context.router.push(const SignInRoute()));
        }
      } else {
        // Offline-first cloud behavior: allow local access and queue sync ops.
        await _activateCloudAccountFromLocalData(context, ref);
      }
    } else {
      // Local-born — instant local activation (no modal password dialog).
      await _activateLocalAccountFromLocalData(context, ref);
    }
  }

  Future<void> _activateCloudAccountFromLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    // Always swap DB first, so profile reads are scoped to this account.
    activeDbFileName = account.dbFileName;
    ref.invalidate(userDatabaseProvider);

    final dao = ref.read(userDatabaseProvider).userProfileDao;
    var profile = account.firebaseUid == null
        ? null
        : await dao.findCloudBornByFirebaseUid(account.firebaseUid!);

    if (profile == null) {
      final profiles = await dao.getAllUserProfiles();
      for (final candidate in profiles) {
        if (candidate.tier == 'cloudBorn' &&
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

    ref.read(authStateProvider.notifier).setCloudBornSession(profile: profile);

    if (context.mounted) {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  Future<void> _activateLocalAccountFromLocalData(
    BuildContext context,
    WidgetRef ref,
  ) async {
    activeDbFileName = account.dbFileName;
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
    ref.read(authStateProvider.notifier).setLocalBornSession(profile: profile);

    if (context.mounted) {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
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
