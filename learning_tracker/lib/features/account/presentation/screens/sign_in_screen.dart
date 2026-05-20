import 'dart:async';
import 'package:auto_route/auto_route.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart'
    show firestoreGatewayProvider;
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/theme/app_colors.dart';
import 'package:learning_tracker/core/theme/app_theme.dart';
import 'package:learning_tracker/core/utils/text_input_formatters.dart';
import 'package:learning_tracker/features/account/data/services/magic_link_service.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/domain/services/upgrade_to_cloud_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart'
    as auth_state;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/email_verification_confirm_panel.dart';
import 'package:learning_tracker/features/onboarding/domain/validators/auth_validators.dart'
    as validators;
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
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
      final l10n = AppLocalizations.of(context)!;
      setState(() {
        if (account != null) {
          final tierLabel = account.accountTier.isCloud
              ? l10n.authTierCloud
              : l10n.authTierLocal;
          _registryFoundHint = l10n.authFoundOnDevice(tierLabel);
          _registryMatchKind = account.accountTier.isLocal
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

  String? _validatePassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.authPasswordRequired;
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
      await ref.read(authRepositoryProvider).signOut();
      final profiles = await ref
          .read(userDatabaseProvider)
          .profileDao
          .getProfilesByAccount(ref.read(currentAccountIdProvider));
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
          if (candidate.accountTier.isCloud &&
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
    final l10n = AppLocalizations.of(context)!;

    // Watchdog: if sign-in takes more than 15 seconds, show an error and
    // revert the spinner so the user is not stuck waiting indefinitely.
    final watchdog = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        _showError(l10n.authSignInTimeout);
      }
    });

    try {
      // Step 1: check device registry for this email
      final registry = ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(email);

      if (account != null && account.accountTier.isLocal) {
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

        // Upgrade-to-cloud: user may have created + verified Firebase from
        // Settings while the local row is still localBorn. Finish the flip
        // and push local data without making them run Upgrade again.
        final isOnline = await InternetConnectionChecker.instance.hasConnection;
        if (isOnline && mounted) {
          final upgradeSvc = UpgradeToCloudService(
            dao: dao,
            authRepository: ref.read(authRepositoryProvider),
            registry: registry,
            accountId: account.accountId,
          );
          final finalized = await upgradeSvc.tryFinalizeVerifiedCloudUpgrade(
            localProfile: profile,
            password: password,
          );
          if (finalized != null && mounted) {
            // S7: the SyncOrchestrator is a per-session singleton. Do NOT
            // invalidate syncEngineProvider — that used to rebuild the
            // orchestrator and register duplicate lifecycle observers /
            // Firestore listeners. The orchestrator picks up the cloud-born
            // engine on its own; just trigger the push + pull directly.
            final orchestrator = ref.read(syncOrchestratorProvider);
            if (orchestrator != null) {
              await orchestrator.pushAllLocalData();
              await orchestrator.pullOnLaunch();
            }
            if (mounted) await _navigateAfterSignIn();
            return;
          }
        }

        ref
            .read(auth_state.authStateProvider.notifier)
            .setLocalBornSession(profile: profile);
        await ref.read(authRepositoryProvider).signOut();
        ref.read(selectedProfileIdProvider.notifier).clear();
        final profiles = await ref
            .read(userDatabaseProvider)
            .profileDao
            .getProfilesByAccount(ref.read(currentAccountIdProvider));
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
      } else if (account != null && account.accountTier.isCloud) {
        // Cloud-born account on this device → try Firebase or cached session
        final isOnline = await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final authRepo = ref.read(authRepositoryProvider);
          await authRepo
              .signInWithEmail(email, password)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw TimeoutException('Sign-in timed out'),
              );
          final verified = await _ensureCloudEmailVerified();
          if (verified && mounted) await _navigateAfterSignIn();
        } else {
          final restored = await _tryOfflineCloudRestore(account);
          if (!restored) {
            _showError(l10n.authLocalDataMissing);
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
          await authRepo
              .signInWithEmail(email, password)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw TimeoutException('Sign-in timed out'),
              );
          final verified = await _ensureCloudEmailVerified();
          if (verified && mounted) await _navigateAfterSignIn();
        } else {
          _showError(l10n.authEmailOfflineUnreachable);
        }
      }
    } on InvalidCredentialsException {
      if (mounted) _showError(l10n.authIncorrectPassword);
    } catch (e) {
      if (mounted) _showError(_mapAuthErrorFromException(e, l10n));
    } finally {
      watchdog.cancel();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _ensureCloudEmailVerified() async {
    final authRepo = ref.read(authRepositoryProvider);
    final signedInUser = authRepo.currentUser;
    if (signedInUser == null) return false;

    final isPasswordAccount = signedInUser.providers.contains('password');
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
    final reloadedUser = authRepo.currentUser;
    if (reloadedUser == null) return false;

    final verifiedAfterPrompt = await _showEmailVerificationPrompt(
      reloadedUser.email ?? _emailController.text.trim(),
    );
    if (verifiedAfterPrompt) {
      return true;
    }

    await authRepo.signOut();
    return false;
  }

  /// Reload auth state and check whether current user is verified.
  Future<bool> _refreshAndCheckVerified() async {
    final refreshed = await ref
        .read(authRepositoryProvider)
        .reloadCurrentUser();
    return refreshed?.emailVerified ?? false;
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
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.checkActionCode(pendingCode);
      await authRepo.applyActionCode(pendingCode);
      await prefs.remove(kPendingVerifyEmailOobCode);
      final refreshed = await authRepo.reloadCurrentUser();
      return refreshed?.emailVerified ?? false;
    } catch (e) {
      final code = _extractFirebaseCode(e);
      // If the code is no longer usable, clear it to avoid retry loops.
      if (code == 'expired-action-code' || code == 'invalid-action-code') {
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
        final dialogL10n = AppLocalizations.of(dialogContext)!;
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: EmailVerificationConfirmPanel(
            email: email,
            bodyText: dialogL10n.authVerifyEmailBody,
            verifiedLinkLabel: dialogL10n.authIveVerified,
            onSendAgain: () async {
              try {
                await ref.read(authRepositoryProvider).sendEmailVerification();
                if (!mounted) return;
                final m = AppLocalizations.of(context)!;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(m.authVerificationEmailSentAgain)),
                );
              } catch (e) {
                if (!mounted) return;
                _showError(
                  _mapAuthErrorFromException(e, AppLocalizations.of(context)!),
                );
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
              _showError(
                AppLocalizations.of(context)!.authEmailStillUnverified,
              );
            },
          ),
        );
      },
    );
    return result ?? false;
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    final l10n = AppLocalizations.of(context)!;

    // Watchdog: Google Sign-In can hang silently on slow connections.
    final watchdog = Timer(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        setState(() => _isLoading = false);
        _showError(l10n.authSignInTimeout);
      }
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();
      if (!mounted) return;

      final googleUser = ref.read(authRepositoryProvider).currentUser;
      if (googleUser == null) return;

      // Epic 21.8: check 5-account cap for genuinely new accounts
      final registry = ref.read(deviceRegistryProvider);
      final existingEntry = await registry.findByFirebaseUid(googleUser.uid);
      if (existingEntry == null) {
        final accounts = await registry.getAllAccounts();
        if (accounts.length >= kMaxDeviceAccounts) {
          if (mounted) {
            _showError(l10n.authMaxDeviceAccounts(kMaxDeviceAccounts));
          }
          await ref.read(authRepositoryProvider).signOut();
          return;
        }
      }

      // Epic 21.8: collision with local-born account
      final localMatch = await registry.findByEmail(googleUser.email ?? '');
      if (localMatch != null && localMatch.accountTier.isLocal) {
        if (mounted) {
          _showError(l10n.authOfflineUseUpgrade);
        }
        await ref.read(authRepositoryProvider).signOut();
        return;
      }

      if (mounted) {
        await _navigateAfterSignIn();
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User cancelled — do nothing.
      } else if (mounted) {
        _showError(l10n.authGoogleSignInFailed);
      }
    } catch (e) {
      if (mounted) {
        _showError(_mapAuthErrorFromException(e, l10n));
      }
    } finally {
      watchdog.cancel();
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _navigateAfterSignIn() async {
    final user = ref.read(authRepositoryProvider).currentUser;
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
    // The sync engine watches authStateProvider + userDatabaseProvider, so it
    // already reflects the just-swapped DB + promoted auth state without an
    // explicit invalidate. Pull with a bounded 8s timeout so the next route
    // decision sees the real profile count rather than an empty local table,
    // and a slow network cannot block navigation.
    //
    // S7: do NOT invalidate syncEngineProvider here — that rebuilt the
    // per-session SyncOrchestrator and registered duplicate lifecycle
    // observers / Firestore listeners (Bug #1).
    final orchestrator = ref.read(syncOrchestratorProvider);
    if (orchestrator != null) {
      await orchestrator.pullOnLaunch().timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
    }
    if (!mounted) return;

    // Decide onboarding vs app-shell by whether the cloud account has
    // any learner profiles. This is the single source of truth — local
    // data freshly pulled from Firestore — so new-device restores of
    // an existing cloud account land straight in the profile picker.
    var profileCount = await ref
        .read(userDatabaseProvider)
        .profileDao
        .countProfilesForAccount(ref.read(currentAccountIdProvider));

    var cloudAccountHasProfiles = false;
    if (profileCount == 0) {
      // If local is still empty, double-check cloud account-level profiles.
      // This avoids incorrectly routing returning cloud users into onboarding
      // when profile restore lagged behind the first pull attempt. Bound the
      // network call so a hung Firestore read cannot freeze the spinner.
      final remoteProfiles =
          await ref
              .read(firestoreGatewayProvider)
              ?.fetchLearnerProfiles()
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () => const <Map<String, dynamic>>[],
              ) ??
          const <Map<String, dynamic>>[];
      cloudAccountHasProfiles = remoteProfiles.isNotEmpty;

      if (cloudAccountHasProfiles && orchestrator != null) {
        // Returning cloud account — wait (bounded) for the retry pull so the
        // profile rows land BEFORE the route decision. Firing this in the
        // background and re-counting immediately always read zero, which
        // wrongly pushed returning users into onboarding.
        await orchestrator.pullOnLaunch().timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        );
        if (!mounted) return;
        profileCount = await ref
            .read(userDatabaseProvider)
            .profileDao
            .countProfilesForAccount(ref.read(currentAccountIdProvider));
      }
    }

    if (profileCount == 0 && !cloudAccountHasProfiles) {
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
        .getProfilesByAccount(ref.read(currentAccountIdProvider));
    if (profiles.length == 1) {
      ref.read(selectedProfileIdProvider.notifier).select(profiles.first.id);
      // S7: no syncEngineProvider invalidate — the orchestrator is a
      // per-session singleton and resolves the active profile lazily, so the
      // re-pull below already runs with the just-selected profileId.
      final selectedOrchestrator = ref.read(syncOrchestratorProvider);
      if (selectedOrchestrator != null) {
        // Fire the single-profile re-pull in the background — navigation
        // proceeds immediately; sync completes after the user is in the app.
        unawaited(selectedOrchestrator.pullOnLaunch());
      }
    } else {
      // Multiple profiles: user chooses in profile picker.
      ref.read(selectedProfileIdProvider.notifier).clear();
    }

    await prefs.setBool(kOnboardingComplete, true);
    if (!mounted) return;
    unawaited(context.router.replaceAll([const AppShellRoute()]));
  }

  String _mapAuthError(String code, AppLocalizations l10n) {
    switch (code) {
      case 'user-not-found':
        return l10n.authErrUserNotFound;
      case 'wrong-password':
        return l10n.authErrWrongPassword;
      case 'invalid-credential':
        return l10n.authErrInvalidCredential;
      case 'user-disabled':
        return l10n.authErrUserDisabled;
      case 'too-many-requests':
        return l10n.authErrTooManyRequests;
      case 'invalid-email':
        return l10n.authErrInvalidEmail;
      case 'network-request-failed':
        return l10n.authErrNetwork;
      default:
        return l10n.authErrSignInGeneric;
    }
  }

  /// Maps a caught exception to a user-friendly error message.
  /// Extracts the Firebase error code from the exception message if present.
  String _mapAuthErrorFromException(Object e, AppLocalizations l10n) {
    final code = _extractFirebaseCode(e);
    if (code != null) return _mapAuthError(code, l10n);
    return l10n.authErrSignInGeneric;
  }

  /// Extracts the Firebase error code from an exception (if present).
  String? _extractFirebaseCode(Object e) {
    final str = e.toString();
    // FirebaseAuthException.toString() contains the code in brackets.
    final match = RegExp(r'\[([a-z-]+)\]').firstMatch(str);
    return match?.group(1);
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

  String? _registrySubtitle({
    required bool isOnline,
    required AppLocalizations l10n,
  }) {
    switch (_registryMatchKind) {
      case _RegistryMatchKind.none:
        return null;
      case _RegistryMatchKind.localBorn:
      case _RegistryMatchKind.cloudBorn:
        return _registryFoundHint;
      case _RegistryMatchKind.notOnDevice:
        return isOnline
            ? l10n.authNotOnDeviceCheckCloud
            : l10n.authNotOnDeviceOffline;
    }
  }

  Widget _buildSignInModeCard({
    required ThemeData theme,
    required _SignInModeHint mode,
    required AppLocalizations l10n,
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
                  l10n.authModeCloud,
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
                  l10n.authModeCloudOffline,
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
                      l10n.authModeLocalTitle,
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
                      l10n.authModeLocalBody,
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
    final l10n = AppLocalizations.of(context)!;
    final connectivity = ref.watch(connectivityStreamProvider);
    final isOnline = connectivity.maybeWhen(data: (v) => v, orElse: () => true);
    final signInMode = _effectiveSignInMode(isOnline: isOnline);
    final registrySubtitle = _registrySubtitle(isOnline: isOnline, l10n: l10n);
    return Scaffold(
      backgroundColor: AppColors.surfaceF3,
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
                                  l10n.signInWelcomeBack,
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  l10n.signInReady,
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
                                  l10n: l10n,
                                ),
                                const SizedBox(height: 26),
                                _buildLabel(l10n.signInYourEmail),
                                const SizedBox(height: 8),
                                _buildAuthField(
                                  controller: _emailController,
                                  hintText: l10n.signInEmailHint,
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
                                _buildLabel(l10n.signInPasswordLabel),
                                const SizedBox(height: 8),
                                _buildAuthField(
                                  controller: _passwordController,
                                  hintText: l10n.signInPasswordHint,
                                  prefixIcon: Icons.lock_rounded,
                                  obscureText: _obscurePassword,
                                  textInputAction: TextInputAction.done,
                                  validator: (v) => _validatePassword(v, l10n),
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
                                    Text(
                                      l10n.signInKeepMeSignedIn,
                                      style: const TextStyle(
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
                                          : Text(
                                              l10n.signInCta,
                                              style: const TextStyle(
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
                                    label: Text(l10n.signInWithGoogleCta),
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
                                        TextSpan(text: l10n.signInNewToQuest),
                                        TextSpan(
                                          text: l10n.signInRegisterHere,
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
      inputFormatters: [
        if (obscureText)
          const NoSpaceFormatter()
        else
          const TrimLeadingSpaceFormatter(),
      ],
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
