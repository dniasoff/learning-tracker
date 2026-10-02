import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/domain/value_objects/account_tier.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/core/providers/path_uid_resolver_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/features/account/data/repositories/account_repository_adapter.dart';
import 'package:learning_tracker/features/account/domain/models/account_auth_provider.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/account_lifecycle_service.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
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

/// The user signed in on [accountId]'s OWN named app, or `null` when that
/// account has no session to re-attach to (DNI-520). Every device account
/// keeps its own persisted Auth session, so a tile's "valid session" badge is
/// per account — there is no single device-wide Firebase user any more.
/// Re-evaluated when the active account's auth state changes.
final accountSessionUserProvider = FutureProvider.autoDispose
    .family<AppUser?, String>((ref, accountId) async {
      ref.watch(firebaseAuthStateProvider);
      try {
        return await ref.read(authRepositoryProvider).restoreSession(accountId);
      } on Object catch (_) {
        // No named app could be attached (never signed in on this device in
        // this build, or the platform refused): show "sign in again".
        return null;
      }
    });

/// Account picker shown after sign-out when other accounts remain
/// on the device, or when the user wants to switch accounts.
///
/// Displays all device accounts from the registry with their session
/// status and a swipe-to-remove-from-device action.
@RoutePage()
class AccountPickerScreen extends ConsumerStatefulWidget {
  const AccountPickerScreen({super.key});

  @override
  ConsumerState<AccountPickerScreen> createState() =>
      _AccountPickerScreenState();
}

class _AccountPickerScreenState extends ConsumerState<AccountPickerScreen> {
  // AUD-account-07: captured ONCE in initState, not rebuilt inside build().
  // registry.getAllAccounts() called directly inside `Widget build()`
  // (via `FutureBuilder(future: registry.getAllAccounts())`) returned a
  // brand-new Future every rebuild — FutureBuilder tracks futures by
  // identity, so any unrelated rebuild of this widget (switching accounts,
  // a locale/theme change, any ancestor rebuild) restarted the
  // FutureBuilder into ConnectionState.waiting, flashing the loading
  // spinner over an already-rendered list and re-querying the device
  // registry. deviceRegistryProvider is `keepAlive: true` (an app-lifetime
  // singleton opened once at startup), so reading it once here — rather
  // than watching it in build() — loses no reactivity.
  late final Future<List<DeviceAccount>> _accountsFuture;

  @override
  void initState() {
    super.initState();
    _accountsFuture = ref.read(deviceRegistryProvider).getAllAccounts();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // AN-4: read the active DB filename so we can pin the active account
    // at position 0 for a stable, deterministic ordering. The remaining
    // accounts are sorted by createdAt-equivalent (accountId UUID is v4 and
    // not time-ordered, so we use dbFileName alphabetical as a proxy for
    // stable creation order). lastUsedAt ordering is intentionally NOT used
    // because it changes every time you switch accounts, causing cards to
    // reorder between visits and making tap-target positions unpredictable.
    final activeAccountId = ref.watch(activeAccountIdProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: context.colors.surfaceF5,
      body: SafeArea(
        child: FutureBuilder<List<DeviceAccount>>(
          future: _accountsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            // AN-4: stable deterministic ordering — active account first,
            // remaining accounts in stable dbFileName order.
            final rawAccounts = snapshot.data!;
            final accounts = [
              ...rawAccounts.where((a) => a.accountId == activeAccountId),
              ...rawAccounts
                  .where((a) => a.accountId != activeAccountId)
                  .toList()
                ..sort((a, b) => a.dbFileName.compareTo(b.dbFileName)),
            ];
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

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              children: [
                Text(
                  l10n.accountPickerTitle,
                  style: theme.textTheme.displaySmall?.copyWith(
                    color: context.colors.brandInk,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.accountPickerSubtitle,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: context.colors.brandInkMuted,
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
                  color: context.colors.brandBlueDeep,
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
                  color: context.colors.brandInkMuted,
                ),
              ),
            ),
          const SizedBox(height: 10),
          Text(
            l10n.accountPickerPrivacyFooter,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.colors.brandInkMuted,
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
    return Semantics(
      button: true,
      child: CustomPaint(
        painter: _DashedRRectPainter(
          color: context.colors.brandBlueDeep,
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

class _AccountTile extends ConsumerStatefulWidget {
  const _AccountTile({required this.account});
  final DeviceAccount account;

  @override
  ConsumerState<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends ConsumerState<_AccountTile> {
  // AN-4: prevent rapid-tap / re-entrancy on account switch. A single tap
  // can trigger network I/O (re-auth, DB swap) and navigation; a second tap
  // before the first completes would launch a second concurrent switch into
  // undefined state (wrong DB, duplicate route pushes, wrong profile).
  bool _switching = false;

  DeviceAccount get account => widget.account;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    // Cloud session status — watched (not read) so this badge stays live
    // when the Firebase session changes elsewhere while this tile is
    // mounted (e.g. a sibling tile's re-auth flow claiming the device's
    // single Firebase auth slot). SM-3 / AUD-account-18: a ref.read
    // snapshot here only re-evaluates when something else forces this
    // widget to rebuild, so it can silently go stale.
    final sessionUser = ref
        .watch(accountSessionUserProvider(account.accountId))
        .value;
    final hasValidSession =
        sessionUser != null && sessionUser.uid == account.firebaseUid;

    return Dismissible(
      key: ValueKey(account.accountId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        decoration: BoxDecoration(
          color: context.colors.statusErrorSoft,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Text(
          l10n.accountRemoveFromDevice,
          style: TextStyle(
            color: context.colors.brandCoralDeep,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      confirmDismiss: (direction) => _confirmDismiss(context),
      onDismissed: (_) => _onDismissed(context, ref),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: _switching
              ? null
              : () => _onTapGuarded(context, hasValidSession),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: context.colors.brandOutline.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: _avatarBg(hasValidSession),
                  child: Icon(
                    Icons.cloud_rounded,
                    color: _avatarFg(hasValidSession),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.displayName.trim().isEmpty
                            ? l10n.offlineAccountLabel
                            : account.displayName,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: context.colors.brandInk,
                        ),
                      ),
                      if (account.email.isNotEmpty)
                        Text(
                          account.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: context.colors.brandInkMuted,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _pillBg(hasValidSession),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          _pillText(l10n, hasValidSession),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: _pillFg(hasValidSession),
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
                  hasValidSession
                      ? Icons.chevron_right_rounded
                      : Icons.warning_rounded,
                  color: hasValidSession
                      ? context.colors.brandInkMuted
                      : context.colors.statusError,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _avatarBg(bool hasValidSession) {
    if (!hasValidSession) return const Color(0xFFF8DDE2);
    return context.colors.brandBlueSoft;
  }

  Color _avatarFg(bool hasValidSession) {
    // AUD-darkmode: chartRed is a chart-series-on-CARD role that LIGHTENS in
    // dark mode, but _avatarBg's paired pink above is a FIXED literal in
    // both themes -- measured ~2.00:1 in dark (light mode was already only
    // marginal at 4.51:1). accountPickerAlertBadgeIcon is pinned to the
    // exact old chartRed light literal in both themes.
    if (!hasValidSession) return context.colors.accountPickerAlertBadgeIcon;
    return context.colors.brandBlue;
  }

  Color _pillBg(bool hasValidSession) {
    if (!hasValidSession) return context.colors.statusErrorSoft;
    return const Color(0xFFE8EEFF);
  }

  Color _pillFg(bool hasValidSession) {
    if (!hasValidSession) return context.colors.statusError;
    // AUD-darkmode: brandBlueDeep is an ink-on-CARD role that LIGHTENS in
    // dark mode, but _pillBg's paired blue above is a FIXED literal in both
    // themes -- measured ~1.41:1 in dark. chazaraSelectedGradientStart is
    // pinned to this exact brandBlueDeep light literal (0xFF0E3392) in both
    // themes, restoring ~9.9:1.
    return context.colors.chazaraSelectedGradientStart;
  }

  String _pillText(AppLocalizations l10n, bool hasValidSession) {
    if (!hasValidSession) return l10n.badgeSignInAgain;
    return l10n.badgeCloudAccount;
  }

  /// AN-4: Guards against rapid double-tap / re-entrant switches by
  /// preventing a second tap while a switch is already in progress.
  Future<void> _onTapGuarded(BuildContext context, bool hasValidSession) async {
    if (_switching) return;
    if (mounted) setState(() => _switching = true);
    try {
      await _onTap(context, ref, hasValidSession);
    } finally {
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<void> _onTap(
    BuildContext context,
    WidgetRef ref,
    bool hasValidSession,
  ) async {
    // Local-only accounts have no cloud identity to re-authenticate. Older
    // registry rows may still carry the anonymous Firebase path uid, so the
    // tier is part of this guard as well.
    if (account.firebaseUid == null ||
        account.accountTier == AccountTier.local) {
      await _activateLocalAccount(context, ref);
      return;
    }

    // Each cloud account keeps its own persisted session on its own named
    // app (AD-1, DNI-520): re-attaching to it is local and works offline.
    final authRepo = ref.read(authRepositoryProvider);
    AppUser? sessionUser;
    try {
      sessionUser = await authRepo.restoreSession(account.accountId);
    } catch (_) {
      sessionUser = null;
    }
    if (sessionUser != null && sessionUser.uid == account.firebaseUid) {
      // Instant switch — the account's own named-app session is valid.
      if (!context.mounted) return;
      await _activateCloudAccountFromLocalData(context, ref);
      return;
    }

    // Use the same configured/overridable checker the rest of the app reads
    // (the provider instance), NOT the package's static singleton — the
    // singleton is unconfigured and untestable, and on an offline device it
    // could mis-probe and push the user to SignInRoute (a network sign-in)
    // instead of restoring local data. Offline-first requires the local data
    // activate without any network round-trip.
    final isOnline = await ref
        .read(internetConnectionCheckerProvider)
        .hasConnection;
    if (!context.mounted) return;
    if (isOnline) {
      // The account's named app has no (or a stale) session: sign THAT app
      // in again. Google shows the native picker (one tap, both accounts
      // already on the device); email/password asks for the password.
      await _reauthAndActivateCloudAccount(context, ref);
    } else {
      // Offline-first cloud behavior: allow local access from the SDK cache.
      await _activateCloudAccountFromLocalData(context, ref);
    }
  }

  /// AD-19 (DNI-520): a local/device-only account gets an anonymous Auth
  /// session on its OWN named app (`createAnonymousAccount`) before it is
  /// activated, so `activeAccountFirebaseProvider` resolves for it instead of
  /// failing with `AccountNotAuthenticatedException`. The anonymous uid is
  /// then persisted as the account's path uid (AD-24 initial bind, or a
  /// match). Needs the network only the first time; a later activation
  /// re-reads the persisted session offline.
  Future<void> _activateLocalAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final String pathUid;
    try {
      final user = await ref
          .read(authRepositoryProvider)
          .ensureAnonymousSession(account.accountId);
      final reconciled = await ref
          .read(pathUidResolverProvider)
          .reconcileLiveUid(accountId: account.accountId, liveUid: user.uid);
      pathUid = reconciled.newUid;
    } catch (_) {
      // Typically: first activation of this account with no network.
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.authLocalDataMissing)));
      return;
    }
    if (!context.mounted) return;
    await _activateCloudAccountFromLocalData(context, ref, pathUid: pathUid);
  }

  /// Signs THIS cloud account's own named app in again, then activates it.
  /// Every account has its own named-app Auth session (AD-1, DNI-520), so a
  /// switch never disturbs the previously active account's session; this
  /// only runs when the TARGET account's session is missing or stale.
  ///
  /// Flow:
  ///   0. SILENT-FIRST (Google): `pickGoogleAccountSilently()` (no UI). If the
  ///      cached Google account is this account's, sign its named app in with
  ///      NO picker. (Limitation: silent only returns the last-authorized
  ///      Google account.)
  ///   1. Otherwise the interactive picker (or, for email/password accounts,
  ///      a password prompt).
  ///   2. A Google account whose email is not this account's is rejected
  ///      BEFORE any Firebase sign-in. After sign-in the uid must equal the
  ///      account's `firebaseUid`; on a mismatch the named app is signed out
  ///      and nothing is activated.
  ///   3. On match: activate via the normal local-data + session path.
  ///   4. On user-cancel / re-auth failure: leave the picker unchanged.
  Future<void> _reauthAndActivateCloudAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final authRepo = ref.read(authRepositoryProvider);
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final targetUid = account.firebaseUid;
    final accountId = account.accountId;

    void showError(String message) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }

    final prefs = await SharedPreferences.getInstance();
    final provider = await _accountAuthProvider(ref, authRepo, prefs);

    AppUser? signedIn;
    // A missing marker is a legacy account. Preserve its Google flow for
    // backwards compatibility; new accounts are written below whenever their
    // live provider is known. Email/password accounts must never be sent to a
    // Google picker because that can authenticate a different identity.
    if (provider == AccountAuthProvider.emailPassword) {
      if (!context.mounted) return;
      final password = await _promptForPassword(context);
      if (password == null || password.isEmpty || !context.mounted) return;
      try {
        signedIn = await authRepo.signInToAccountWithEmail(
          accountId,
          account.email,
          password,
        );
      } catch (_) {
        if (context.mounted) showError(l10n.errorReauthFailed);
        return;
      }
    } else {
      // SILENT-FIRST: the cached Google account, no UI.
      if (targetUid != null) {
        try {
          final silent = await authRepo.pickGoogleAccountSilently();
          final silentToken = silent?.idToken;
          if (silentToken != null && _isThisAccountsEmail(silent?.email)) {
            final user = await authRepo.signInToAccountWithGoogle(
              accountId,
              silentToken,
            );
            if (user.uid == targetUid) {
              signedIn = user;
            } else {
              await authRepo.forAccount(accountId).signOut();
            }
          }
        } catch (_) {
          // Silent attempt failed (never shows UI) → use the interactive flow.
        }
      }

      if (signedIn == null) {
        try {
          final pick = await authRepo.pickGoogleAccount();
          final idToken = pick.idToken;
          if (idToken == null || !_isThisAccountsEmail(pick.email)) {
            // Wrong Google account picked: reject it before ANY Firebase
            // sign-in, so this account's named app is left untouched.
            if (context.mounted) showError(l10n.authGoogleSignInFailed);
            return;
          }
          signedIn = await authRepo.signInToAccountWithGoogle(
            accountId,
            idToken,
          );
        } on GoogleSignInException catch (e) {
          // Cancellation is a clean no-op. In particular, do not activate local
          // state after the credential flow was abandoned.
          if (e.code == GoogleSignInExceptionCode.canceled ||
              e.code == GoogleSignInExceptionCode.interrupted) {
            return;
          }
          if (context.mounted) showError(l10n.errorReauthFailed);
          return;
        } catch (_) {
          if (context.mounted) showError(l10n.errorReauthFailed);
          return;
        }
      }
    }

    // Verify the re-authed identity matches the account the user tapped.
    if (targetUid == null || signedIn.uid != targetUid) {
      // uid churn (e.g. the cloud account was re-created server-side). Do
      // NOT activate: sign this account's named app back out (best-effort)
      // and abort — every other account's session is untouched.
      try {
        await authRepo.forAccount(accountId).signOut();
      } catch (_) {
        // Sign-out best-effort; ignore.
      }
      showError(l10n.authGoogleSignInFailed);
      return;
    }

    // Identity matched — activate the account.
    if (!context.mounted) return;
    await _activateCloudAccountFromLocalData(context, ref);
  }

  /// Whether a Google picker [email] is this account's (case-insensitive).
  /// An unknown email (platform reported none) is not rejected here; the
  /// uid check after sign-in still guards the switch.
  bool _isThisAccountsEmail(String? email) {
    if (email == null || email.isEmpty || account.email.isEmpty) return true;
    return email.trim().toLowerCase() == account.email.trim().toLowerCase();
  }

  Future<String?> _promptForPassword(BuildContext context) {
    final controller = TextEditingController();
    final l10n = AppLocalizations.of(context)!;
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reauthDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          decoration: InputDecoration(
            labelText: l10n.currentPasswordLabel,
            hintText: l10n.reauthDialogBody,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.reauthVerify),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<AccountAuthProvider?> _accountAuthProvider(
    WidgetRef ref,
    AuthRepository authRepo,
    SharedPreferences prefs,
  ) async {
    final store = AccountAuthProviderStore(prefs);
    final persisted = store.read(account.accountId);
    if (persisted != null) return persisted;

    // Each saved account has its own named-app session (DNI-520) — the
    // only reliable provider source for an account that is not active.
    try {
      final sessionUser = await authRepo.restoreSession(account.accountId);
      final provider = sessionUser == null
          ? null
          : AccountAuthProviderId.fromProviderIds(sessionUser.providers);
      if (provider != null) await store.write(account.accountId, provider);
      return provider;
    } catch (_) {
      // Legacy accounts may have no named session. Keep the historical Google
      // fallback rather than blocking the picker; a successful switch stores
      // the live provider for the next visit.
      return null;
    }
  }

  Future<void> _activateCloudAccountFromLocalData(
    BuildContext context,
    WidgetRef ref, {
    String? pathUid,
  }) async {
    ref.read(activeAccountIdProvider.notifier).set(account.accountId);

    AccountEntity? accountEntity;
    final uid = pathUid ?? account.firebaseUid;
    if (uid != null) {
      try {
        // No local Drift cache anymore (P3-5) — Firestore's own offline
        // persistence (account_firebase.dart) transparently serves the
        // cached users/{uid} doc when offline, so this reads the same way
        // whether online or off.
        final syntheticUser = AppUser(
          uid: uid,
          email: account.email,
          displayName: account.displayName,
          emailVerified: true,
          providers: const <String>[],
        );
        accountEntity = await ref
            .read(firestoreAccountRepositoryAdapterProvider)
            .ensureAccountForFirebaseUser(syntheticUser);
      } catch (_) {
        accountEntity = null;
      }
    }

    if (accountEntity == null) {
      // ACCTPICK-03 / SI-04: the account is in the device registry but its
      // Firestore record could not be resolved (offline with nothing cached
      // yet, or the account was only ever registered on this device and
      // never actually reached the cloud). Silently returning leaves the
      // user stranded on the picker with no indication of the failure.
      // Surface a clear error so they know to connect to the internet.
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.authLocalDataMissing)));
      }
      return;
    }
    if (!context.mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final liveProvider = AccountAuthProviderId.fromProviderIds(
      ref.read(authRepositoryProvider).currentUser?.providers ??
          const <String>[],
    );
    if (liveProvider != null &&
        ref.read(authRepositoryProvider).currentUser?.uid == uid) {
      await AccountAuthProviderStore(
        prefs,
      ).write(account.accountId, liveProvider);
    }
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

    ref
        .read(authStateProvider.notifier)
        .setCloudBornSession(account: accountEntity);

    // Riverpod re-resolves every provider scoped off activeAccountIdProvider
    // (set above) the moment it changes — including the Firestore
    // repositories' real-time listeners, which get torn down and re-opened
    // against the new identity automatically. No manual restart/pull step
    // is needed anymore (P3-5: no sync-orchestrator to kick).

    if (context.mounted) {
      unawaited(context.router.replaceAll([const AppShellRoute()]));
    }
  }

  // d.accountRemoveFromDeviceBody promises "your cloud data is safe"
  // unconditionally. That held exactly while the Drift outbox-drain guard
  // (AUD-account-01) blocked removal on undrained rows; the guard is gone
  // now that the Drift outbox no longer exists (see
  // AccountLifecycleService's doc comment). The one residual gap is a
  // Firestore SDK offline-queued write not yet flushed at removal time —
  // FirebaseFirestore.waitForPendingWrites() is the primitive to rebuild a
  // guard against that, if/when the owner wants one.
  Future<bool> _confirmDismiss(BuildContext context) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final d = AppLocalizations.of(ctx)!;
            return AlertDialog(
              title: Text(d.accountRemoveFromDeviceTitle),
              content: Text(d.accountRemoveFromDeviceBody),
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
                  child: Text(d.accountRemove),
                ),
              ],
            );
          },
        ) ??
        false;

    return confirmed;
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
    // route away.
    final isActive = ref.read(activeAccountIdProvider) == account.accountId;
    if (isActive) {
      ref.read(activeAccountIdProvider.notifier).set(null);
      ref.read(authStateProvider.notifier).signOut();
      ref.read(selectedProfileIdProvider.notifier).clear();
      ref.read(routerProvider).pinGuard.lock();
      final prefs = await SharedPreferences.getInstance();
      await SessionPersistenceService(
        prefs: prefs,
        registry: registry,
      ).clearActiveAccount();
    }

    await service.removeCloudFromDevice(account.accountId);

    if (!isActive || !context.mounted) return;
    // Active account is gone — route away from the now-orphaned context.
    final remaining = await registry.getAllAccounts();
    final router = ref.read(routerProvider);
    await router.replaceAll([
      remaining.isNotEmpty ? const AccountPickerRoute() : const SignInRoute(),
    ]);
  }
}
