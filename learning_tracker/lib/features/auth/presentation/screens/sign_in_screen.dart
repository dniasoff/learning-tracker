import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/features/auth/data/services/magic_link_service.dart';
import 'package:learning_tracker/features/auth/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/auth/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart'
    as auth_state;
import 'package:learning_tracker/features/auth/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/auth/presentation/widgets/email_verification_confirm_panel.dart';
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart'
    as validators;
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

@RoutePage()
class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

enum _SignInModeHint { cloud, cloudOffline, local, unknown }

/// Registry lookup result for the debounced email field. Connectivity is
/// applied in [build] via [ref.watch] so header cards track online/offline.
enum _RegistryMatchKind { none, localBorn, cloudBorn, notOnDevice }

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _keepSignedIn = true;
  /// Set when the email matches a device-registry account (shown under field).
  String? _registryFoundHint;
  _RegistryMatchKind _registryMatchKind = _RegistryMatchKind.none;
  Timer? _emailDebounce;

  @override
  void dispose() {
    _emailDebounce?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Epic 21.7: debounced live lookup against the device registry
  /// as the user types their email.
  void _onEmailChanged(String email) {
    _emailDebounce?.cancel();
    _emailDebounce = Timer(const Duration(milliseconds: 300), () async {
      final normalized = email.trim().toLowerCase();
      if (normalized.length < 5) {
        if (_registryMatchKind != _RegistryMatchKind.none ||
            _registryFoundHint != null) {
          setState(() {
            _registryFoundHint = null;
            _registryMatchKind = _RegistryMatchKind.none;
          });
        }
        return;
      }

      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(normalized);

      if (!mounted) return;
      setState(() {
        if (account != null) {
          final tierLabel = account.tier == 'cloudBorn' ? 'Cloud' : 'Local';
          _registryFoundHint = 'Found on this device ($tierLabel)';
          _registryMatchKind = account.tier == 'localBorn'
              ? _RegistryMatchKind.localBorn
              : _RegistryMatchKind.cloudBorn;
        } else {
          _registryFoundHint = null;
          _registryMatchKind = _RegistryMatchKind.notOnDevice;
        }
      });
    });
  }

  String? _validateEmail(String? value) => validators.validateEmail(value);

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  /// Legacy fallback for accounts that exist locally but are missing
  /// a device-registry entry. This preserves offline sign-in after
  /// migrations or partial registry corruption.
  Future<bool> _tryLocalFallbackSignIn({
    required String email,
    required String password,
  }) async {
    try {
      final dao = ref.read(userDatabaseProvider).userProfileDao;
      final service = LocalAuthService(dao: dao);
      final profile = await service.signIn(email: email, password: password);
      final prefs = await SharedPreferences.getInstance();
      ref
          .read(auth_state.authStateProvider.notifier)
          .setLocalBornSession(profile: profile);
      final profiles = await ref
          .read(userDatabaseProvider)
          .profileDao
          .getProfilesByAccount(1);
      final firstSignInNeedsSetup = profiles.isEmpty;
      if (firstSignInNeedsSetup) {
        await prefs.remove(kOnboardingComplete);
      } else {
        await prefs.setBool(kOnboardingComplete, true);
      }
      ref.read(selectedProfileIdProvider.notifier).clear();
      if (mounted) {
        if (firstSignInNeedsSetup) {
          unawaited(context.router.replaceAll([const OnboardingRoute()]));
        } else {
          unawaited(context.router.replaceAll([const ProfilePickerRoute()]));
        }
      }
      return true;
    } on InvalidCredentialsException {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Offline-first cloud session restore from device-registry account data.
  ///
  /// This allows cloud-born users to keep using their local data even when
  /// Firebase cannot be reached. Cloud sync resumes once auth is available.
  Future<bool> _tryOfflineCloudRestore(DeviceAccount account) async {
    try {
      // Switch to the account-scoped DB before resolving profile rows.
      activeDbFileName = account.dbFileName;
      ref.invalidate(userDatabaseProvider);

      final dao = ref.read(userDatabaseProvider).userProfileDao;
      var profile = account.firebaseUid == null
          ? null
          : await dao.findCloudBornByFirebaseUid(account.firebaseUid!);

      if (profile == null) {
        final allProfiles = await dao.getAllUserProfiles();
        for (final candidate in allProfiles) {
          if (candidate.tier == 'cloudBorn' &&
              candidate.email.toLowerCase() == account.email.toLowerCase()) {
            profile = candidate;
            break;
          }
        }
      }

      if (profile == null) {
        return false;
      }

      final prefs = await SharedPreferences.getInstance();
      final session = SessionPersistenceService(
        prefs: prefs,
        registry: ref.read(deviceRegistryProvider),
      );
      await session.setActiveAccount(account.accountId);
      await prefs.setBool(kOnboardingComplete, true);
      ref
          .read(auth_state.authStateProvider.notifier)
          .setCloudBornSession(profile: profile);
      ref.read(selectedProfileIdProvider.notifier).clear();
      if (mounted) {
        unawaited(context.router.replaceAll([const AppShellRoute()]));
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Epic 21.7: Smart credential routing. Checks the device
  /// registry first to determine which backend handles sign-in,
  /// then falls back to Firebase for emails not on this device.
  Future<void> _signInWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;

    setState(() => _isLoading = true);
    try {
      // Step 1: check device registry for this email
      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(email);

      if (account != null && account.tier == 'localBorn') {
        // Local-born account on this device → argon2id verification.
        // Swap to this account's DB first so the argon2 hash is read
        // from the correct file — otherwise we verify against whatever
        // DB was previously active and cross-account data leaks in.
        activeDbFileName = account.dbFileName;
        ref.invalidate(userDatabaseProvider);

        final dao = ref.read(userDatabaseProvider).userProfileDao;
        final service = LocalAuthService(dao: dao);
        final profile = await service.signIn(email: email, password: password);

        final prefs = await SharedPreferences.getInstance();
        final session = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );
        await session.setActiveAccount(account.accountId);

        ref
            .read(auth_state.authStateProvider.notifier)
            .setLocalBornSession(profile: profile);
        ref.read(selectedProfileIdProvider.notifier).clear();
        final profiles = await ref
            .read(userDatabaseProvider)
            .profileDao
            .getProfilesByAccount(1);
        final firstSignInNeedsSetup = profiles.isEmpty;
        if (firstSignInNeedsSetup) {
          await prefs.remove(kOnboardingComplete);
        } else {
          await prefs.setBool(kOnboardingComplete, true);
        }
        if (mounted) {
          if (firstSignInNeedsSetup) {
            unawaited(context.router.replaceAll([const OnboardingRoute()]));
          } else {
            unawaited(context.router.replaceAll([const ProfilePickerRoute()]));
          }
        }
      } else if (account != null && account.tier == 'cloudBorn') {
        // Cloud-born account on this device → try Firebase or cached session
        final isOnline = await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final authRepo = ref.read(authRepositoryProvider);
          await authRepo.signInWithEmail(email, password);
          final verified = await _ensureCloudEmailVerified();
          if (verified && mounted) await _navigateAfterSignIn();
        } else {
          final restored = await _tryOfflineCloudRestore(account);
          if (!restored) {
            _showError(
              "This account's local data is missing. "
              'Connect to the internet to restore it.',
            );
          }
        }
      } else {
        // Not in registry — try local fallback first, then Firebase.
        final signedInLocally = await _tryLocalFallbackSignIn(
          email: email,
          password: password,
        );
        if (signedInLocally) return;

        // Not on this device → try Firebase (could be account from another device)
        final isOnline = await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final authRepo = ref.read(authRepositoryProvider);
          await authRepo.signInWithEmail(email, password);
          final verified = await _ensureCloudEmailVerified();
          if (verified && mounted) await _navigateAfterSignIn();
        } else {
          _showError(
            "This email isn't on this device and we can't reach the cloud. "
            'Try again when online.',
          );
        }
      }
    } on InvalidCredentialsException {
      if (mounted) _showError('Incorrect password.');
    } on FirebaseAuthException catch (e) {
      if (mounted) _showError(_mapAuthError(e.code));
    } catch (e) {
      if (mounted) _showError('Sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _ensureCloudEmailVerified() async {
    final auth = ref.read(firebaseAuthProvider);
    final signedInUser = auth.currentUser;
    if (signedInUser == null) return false;

    final isPasswordAccount = signedInUser.providerData.any(
      (provider) => provider.providerId == 'password',
    );
    if (!isPasswordAccount) {
      return true;
    }

    final initiallyVerified = await _refreshAndCheckVerified();
    if (initiallyVerified) return true;

    // Firebase can be briefly eventually consistent after action-code apply.
    final verifiedAfterShortWait = await _waitForVerified(maxAttempts: 3);
    if (verifiedAfterShortWait) return true;

    final verifiedFromPendingCode = await _tryApplyPendingVerificationCode();
    if (verifiedFromPendingCode) {
      return true;
    }

    final stillUnverified = !(await _refreshAndCheckVerified());
    if (!stillUnverified) return true;
    final reloadedUser = auth.currentUser;
    if (reloadedUser == null) return false;

    final verifiedAfterPrompt = await _showEmailVerificationPrompt(
      reloadedUser.email ?? _emailController.text.trim(),
    );
    if (verifiedAfterPrompt) {
      return true;
    }

    await ref.read(authRepositoryProvider).signOut();
    return false;
  }

  /// Reload auth state and check whether current user is verified.
  Future<bool> _refreshAndCheckVerified() async {
    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null) return false;
    await user.reload();
    return auth.currentUser?.emailVerified ?? false;
  }

  Future<bool> _waitForVerified({required int maxAttempts}) async {
    for (var i = 0; i < maxAttempts; i++) {
      final verified = await _refreshAndCheckVerified();
      if (verified) return true;
      await Future<void>.delayed(const Duration(milliseconds: 350));
    }
    return false;
  }

  Future<bool> _tryApplyPendingVerificationCode() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingCode = prefs.getString(kPendingVerifyEmailOobCode);
    if (pendingCode == null || pendingCode.isEmpty) {
      return false;
    }

    try {
      final auth = ref.read(firebaseAuthProvider);
      await auth.checkActionCode(pendingCode);
      await auth.applyActionCode(pendingCode);
      await prefs.remove(kPendingVerifyEmailOobCode);
      await auth.currentUser?.reload();
      return auth.currentUser?.emailVerified ?? false;
    } on FirebaseAuthException catch (e) {
      // If the code is no longer usable, clear it to avoid retry loops.
      if (e.code == 'expired-action-code' || e.code == 'invalid-action-code') {
        await prefs.remove(kPendingVerifyEmailOobCode);
        // "invalid-action-code" can mean it was already consumed.
        // Re-check verification before treating it as failure.
        return _refreshAndCheckVerified();
      }
      return false;
    }
  }

  Future<bool> _showEmailVerificationPrompt(String email) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: EmailVerificationConfirmPanel(
            email: email,
            bodyText:
                'We sent a verification link to your inbox. '
                'Please check your email to continue.',
            verifiedLinkLabel: "I've verified",
            onSendAgain: () async {
              try {
                await ref.read(authRepositoryProvider).sendEmailVerification();
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Verification email sent again.'),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (!mounted) return;
                _showError(_mapAuthError(e.code));
              }
            },
            onCancel: () => Navigator.of(dialogContext).pop(false),
            onVerified: () async {
              final verified =
                  await _tryApplyPendingVerificationCode() ||
                  await _refreshAndCheckVerified() ||
                  await _waitForVerified(maxAttempts: 2);
              if (verified) {
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
                return;
              }
              if (!mounted) return;
              _showError('Email is still unverified. Check your inbox first.');
            },
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      if (!mounted) return;

      final googleUser = FirebaseAuth.instance.currentUser;
      if (googleUser == null) return;

      // Epic 21.8: check 5-account cap for genuinely new accounts
      final registry = ref.read(deviceRegistryProvider);
      final existingEntry = await registry.findByFirebaseUid(googleUser.uid);
      if (existingEntry == null) {
        final accounts = await registry.getAllAccounts();
        if (accounts.length >= kMaxDeviceAccounts) {
          if (mounted) {
            _showError(
              'Maximum $kMaxDeviceAccounts accounts reached. '
              'Remove one to add another.',
            );
          }
          await FirebaseAuth.instance.signOut();
          return;
        }
      }

      // Epic 21.8: collision with local-born account
      final localMatch = await registry.findByEmail(googleUser.email ?? '');
      if (localMatch != null && localMatch.tier == 'localBorn') {
        if (mounted) {
          _showError(
            'An offline account with this email exists on this device. '
            'Use the Upgrade to Cloud option in Settings instead.',
          );
        }
        await FirebaseAuth.instance.signOut();
        return;
      }

      if (mounted) {
        await _navigateAfterSignIn();
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showError(_mapAuthError(e.code));
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User cancelled — do nothing.
      } else if (mounted) {
        _showError('Google Sign-In failed. Please try again.');
      }
    } catch (e) {
      if (mounted) {
        _showError('Google Sign-In failed: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterSignIn() async {
    final user = ref.read(firebaseAuthProvider).currentUser;
    if (user == null || !mounted) return;

    // Epic 21: route this Firebase user into the right per-account DB
    // BEFORE promoteToCloud writes any profile rows. Otherwise the
    // placeholder profile lands in whichever DB was previously active
    // and the new account inherits the prior account's learning data.
    final registry = ref.read(deviceRegistryProvider);
    final existingEntry = await registry.findByFirebaseUid(user.uid);
    final prefs = await SharedPreferences.getInstance();
    final session = SessionPersistenceService(prefs: prefs, registry: registry);

    if (existingEntry != null) {
      // Returning account on this device — swap to its DB file.
      if (activeDbFileName != existingEntry.dbFileName) {
        activeDbFileName = existingEntry.dbFileName;
        ref.invalidate(userDatabaseProvider);
      }
      await ref
          .read(auth_state.authStateProvider.notifier)
          .promoteToCloud(user);
      if (!mounted) return;
      await session.setActiveAccount(existingEntry.accountId);
    } else {
      // Account not on this device — could be brand-new, or an existing
      // cloud account signing in on a new device. Allocate a fresh DB file
      // and register the account either way; we decide where to route
      // after pulling from Firestore and seeing whether profiles exist.
      final accountId = const Uuid().v4();
      final dbFileName = 'user_acc_$accountId.db';
      activeDbFileName = dbFileName;
      ref.invalidate(userDatabaseProvider);

      await ref
          .read(auth_state.authStateProvider.notifier)
          .promoteToCloud(user);
      if (!mounted) return;

      await session.registerAccount(
        accountId: accountId,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        tier: 'cloudBorn',
        firebaseUid: user.uid,
        dbFileName: dbFileName,
      );
    }

    // Sync profiles from Firestore into local DB before navigating.
    // Invalidate the sync engine so it picks up the just-swapped DB +
    // auth state, then pull synchronously so the next route decision
    // sees the real profile count rather than an empty local table.
    ref.invalidate(syncEngineProvider);
    final syncEngine = ref.read(syncEngineProvider);
    if (syncEngine != null) {
      await syncEngine.pullOnLaunch();
    }
    if (!mounted) return;

    // Decide onboarding vs app-shell by whether the cloud account has
    // any learner profiles. This is the single source of truth — local
    // data freshly pulled from Firestore — so new-device restores of
    // an existing cloud account land straight in the profile picker.
    var profileCount = await ref
        .read(userDatabaseProvider)
        .profileDao
        .countProfilesForAccount(1);

    if (profileCount == 0) {
      // If local is still empty, double-check cloud account-level profiles.
      // This avoids incorrectly routing returning cloud users into onboarding
      // when profile restore lagged behind the first pull attempt.
      final remoteProfiles =
          await ref.read(firestoreDataSourceProvider)?.fetchLearnerProfiles() ??
          const <Map<String, dynamic>>[];

      if (remoteProfiles.isNotEmpty && syncEngine != null) {
        await syncEngine.pullOnLaunch();
        profileCount = await ref
            .read(userDatabaseProvider)
            .profileDao
            .countProfilesForAccount(1);
      }
    }

    if (profileCount == 0) {
      // Brand-new cloud account with no existing cloud profiles — run through
      // onboarding to create the first profile + pick tracks.
      if (!mounted) return;
      unawaited(context.router.replaceAll([const OnboardingRoute()]));
      return;
    }

    // If exactly one profile exists, select it immediately and re-pull
    // profile-scoped Firestore data (tracks/completions/etc) with the
    // correct profileId instead of the bootstrap default (0).
    final profiles = await ref
        .read(userDatabaseProvider)
        .profileDao
        .getProfilesByAccount(1);
    if (profiles.length == 1) {
      ref.read(selectedProfileIdProvider.notifier).select(profiles.first.id);
      ref.invalidate(syncEngineProvider);
      final selectedSyncEngine = ref.read(syncEngineProvider);
      if (selectedSyncEngine != null) {
        await selectedSyncEngine.pullOnLaunch();
      }
    } else {
      // Multiple profiles: user chooses in profile picker.
      ref.read(selectedProfileIdProvider.notifier).clear();
    }

    await prefs.setBool(kOnboardingComplete, true);
    if (!mounted) return;
    unawaited(context.router.replaceAll([const AppShellRoute()]));
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Invalid email or password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Sign-in failed. Please try again.';
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppTheme.brandCoralDeep,
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  _SignInModeHint _effectiveSignInMode({required bool isOnline}) {
    if (_emailController.text.trim().isEmpty) {
      return isOnline ? _SignInModeHint.cloud : _SignInModeHint.local;
    }
    switch (_registryMatchKind) {
      case _RegistryMatchKind.none:
        return isOnline ? _SignInModeHint.cloud : _SignInModeHint.local;
      case _RegistryMatchKind.localBorn:
        return _SignInModeHint.local;
      case _RegistryMatchKind.cloudBorn:
        return isOnline ? _SignInModeHint.cloud : _SignInModeHint.cloudOffline;
      case _RegistryMatchKind.notOnDevice:
        return isOnline ? _SignInModeHint.cloud : _SignInModeHint.local;
    }
  }

  String? _registrySubtitle({required bool isOnline}) {
    switch (_registryMatchKind) {
      case _RegistryMatchKind.none:
        return null;
      case _RegistryMatchKind.localBorn:
      case _RegistryMatchKind.cloudBorn:
        return _registryFoundHint;
      case _RegistryMatchKind.notOnDevice:
        return isOnline
            ? "Not on this device \u2014 we'll check the cloud"
            : 'Not on this device (offline \u2014 only device accounts available)';
    }
  }

  Widget _buildSignInModeCard({
    required ThemeData theme,
    required _SignInModeHint mode,
  }) {
    switch (mode) {
      case _SignInModeHint.cloud:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.brandBlueBright.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.brandBlueBright.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.cloud_done_rounded, color: AppTheme.brandBlue),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cloud account: your data is backed up and syncs across devices.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      case _SignInModeHint.cloudOffline:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.brandCoralSoft.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppTheme.brandCoralDeep.withValues(alpha: 0.45),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.brandCoralDeep,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Cloud account is offline right now. We will try local cached data until internet returns.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppTheme.brandInk,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      case _SignInModeHint.local:
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.brandCoralSoft.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.brandCoralDeep.withValues(alpha: 0.55),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppTheme.brandCoralDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Local account only: no cloud backup and no device sync.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.brandInk,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.brandCoralSoft.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.brandCoralDeep.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.dangerous_rounded,
                    color: AppTheme.brandCoralDeep,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No cloud backup or device sync. Your data stays only on this device.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppTheme.brandInk,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      case _SignInModeHint.unknown:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOnline = connectivity.maybeWhen(data: (v) => v, orElse: () => true);
    final signInMode = _effectiveSignInMode(isOnline: isOnline);
    final registrySubtitle = _registrySubtitle(isOnline: isOnline);
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight - 28,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Stack(
                      children: [
                        Positioned(
                          top: -50,
                          right: -58,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFE9EAF2),
                            ),
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.fromLTRB(24, 26, 24, 28),
                          decoration: BoxDecoration(
                            color: AppTheme.brandCreamCard,
                            borderRadius: BorderRadius.circular(34),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome Back!',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Ready for your next learning adventure?',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: AppTheme.brandInkMuted,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 16),
                                _buildSignInModeCard(
                                  theme: theme,
                                  mode: signInMode,
                                ),
                                const SizedBox(height: 26),
                                _buildLabel('Your Email'),
                                const SizedBox(height: 8),
                                _buildAuthField(
                                  controller: _emailController,
                                  hintText: 'yourname@quest.com',
                                  prefixIcon: Icons.mail_rounded,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  validator: _validateEmail,
                                  onChanged: _onEmailChanged,
                                ),
                                if (registrySubtitle != null)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: 8,
                                      left: 4,
                                    ),
                                    child: Text(
                                      registrySubtitle,
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: AppTheme.brandInkMuted,
                                          ),
                                    ),
                                  ),
                                const SizedBox(height: 20),
                                _buildLabel('Secret Key'),
                                const SizedBox(height: 8),
                                _buildAuthField(
                                  controller: _passwordController,
                                  hintText: '........',
                                  prefixIcon: Icons.lock_rounded,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  validator: _validatePassword,
                                  onFieldSubmitted: (_) => _signInWithEmail(),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_off_rounded
                                          : Icons.visibility_rounded,
                                      color: AppTheme.brandInkMuted,
                                    ),
                                    onPressed: () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _keepSignedIn,
                                      onChanged: _isLoading
                                          ? null
                                          : (value) => setState(
                                              () => _keepSignedIn =
                                                  value ?? false,
                                            ),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const Text(
                                      'Keep me signed in',
                                      style: TextStyle(
                                        color: AppTheme.brandInkMuted,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 58,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [
                                          AppTheme.brandBlue,
                                          AppTheme.brandBlueBright,
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(30),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.brandBlueBright
                                              .withValues(alpha: 0.32),
                                          blurRadius: 18,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: FilledButton(
                                      onPressed: _isLoading
                                          ? null
                                          : _signInWithEmail,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: AppTheme.transparent,
                                        shadowColor: AppTheme.transparent,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: AppTheme.brandCreamCard,
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                if (isOnline)
                                  OutlinedButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : _signInWithGoogle,
                                    icon: const Icon(
                                      Icons.g_mobiledata_rounded,
                                    ),
                                    label: const Text('Sign in with Google'),
                                  ),
                                if (isOnline) const SizedBox(height: 20),
                                Center(
                                  child: RichText(
                                    text: TextSpan(
                                      style: theme.textTheme.bodyLarge
                                          ?.copyWith(
                                            color: AppTheme.brandInkMuted,
                                          ),
                                      children: [
                                        const TextSpan(
                                          text: 'New to the Quest? ',
                                        ),
                                        TextSpan(
                                          text: 'Register Here',
                                          style: const TextStyle(
                                            color: Color(0xFF8E6425),
                                            fontWeight: FontWeight.w700,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              if (!_isLoading) {
                                                context.router.replace(
                                                  SignupRoute(),
                                                );
                                              }
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.brandInk,
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildAuthField({
    required TextEditingController controller,
    required String hintText,
    required IconData prefixIcon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    bool obscureText = false,
    Widget? suffixIcon,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      obscureText: obscureText,
      enabled: !_isLoading,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppTheme.brandInkMuted,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Icon(prefixIcon, color: AppTheme.brandInkMuted),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: const Color(0xFFF0F1F6),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDCE0EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFDCE0EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.brandBlueBright),
        ),
      ),
    );
  }
}
