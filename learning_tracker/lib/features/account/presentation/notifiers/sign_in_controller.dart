import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:internet_connection_checker/internet_connection_checker.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/navigation/app_router.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart'
    show firestoreGatewayProvider;
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/features/account/data/services/magic_link_service.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/domain/services/upgrade_to_cloud_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart'
    as auth_state;
import 'package:learning_tracker/features/account/presentation/widgets/email_verification_dialog.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart'
    show kOnboardingComplete, kOnboardingSkipped;
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── State ──────────────────────────────────────────────────────────────────────

/// Sealed union for the sign-in screen's async state.
sealed class SignInState {
  const SignInState();
}

final class SignInIdle extends SignInState {
  const SignInIdle();
}

final class SignInSubmitting extends SignInState {
  const SignInSubmitting();
}

final class SignInError extends SignInState {
  const SignInError(this.message);

  final String message;
}

// ── Controller ─────────────────────────────────────────────────────────────────

/// Holds sign-in business logic outside [SignInScreen].
///
/// Navigation and dialog interactions are threaded back to the screen via
/// [setCallbacks] — keeping this notifier free of direct [BuildContext] access
/// across async gaps.
///
/// Usage:
///   1. Provider auto-creates one [SignInController] per sign-in screen.
///   2. Screen calls [setCallbacks] in [initState] postframe.
///   3. Sign-in actions ([signInWithEmail], [signInWithGoogle]) are called from
///      the screen; state transitions drive the spinner and error display.
class SignInController extends Notifier<SignInState> {
  @override
  SignInState build() => const SignInIdle();

  Ref get _ref => ref;

  // Callbacks injected by the screen.
  Future<bool> Function(String email, AppLocalizations l10n)? _showVerification;
  void Function(String message)? _showError;

  void setCallbacks({
    required Future<bool> Function(String email, AppLocalizations l10n)
    showVerificationDialog,
    required void Function(String message) showError,
  }) {
    _showVerification = showVerificationDialog;
    _showError = showError;
  }

  // ── Auth-error helpers ──────────────────────────────────────────────────────

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

  String _mapAuthErrorFromException(Object e, AppLocalizations l10n) {
    final code = _extractFirebaseCode(e);
    if (code != null) return _mapAuthError(code, l10n);
    return l10n.authErrSignInGeneric;
  }

  String? _extractFirebaseCode(Object e) {
    final str = e.toString();
    final match = RegExp(r'\[([a-z-]+)\]').firstMatch(str);
    return match?.group(1);
  }

  // ── Email verification helpers ──────────────────────────────────────────────

  Future<bool> _refreshAndCheckVerified() async {
    final refreshed = await _ref
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
    if (pendingCode == null || pendingCode.isEmpty) return false;

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.checkActionCode(pendingCode);
      await authRepo.applyActionCode(pendingCode);
      await prefs.remove(kPendingVerifyEmailOobCode);
      final refreshed = await authRepo.reloadCurrentUser();
      return refreshed?.emailVerified ?? false;
    } catch (e) {
      final code = _extractFirebaseCode(e);
      if (code == 'expired-action-code' || code == 'invalid-action-code') {
        await prefs.remove(kPendingVerifyEmailOobCode);
        return _refreshAndCheckVerified();
      }
      return false;
    }
  }

  Future<bool> _ensureCloudEmailVerified(
    String email,
    AppLocalizations l10n,
  ) async {
    final authRepo = _ref.read(authRepositoryProvider);
    final signedInUser = authRepo.currentUser;
    if (signedInUser == null) return false;

    final isPasswordAccount = signedInUser.providers.contains('password');
    if (!isPasswordAccount) return true;

    final initiallyVerified = await _refreshAndCheckVerified();
    if (initiallyVerified) return true;

    final verifiedAfterShortWait = await _waitForVerified(maxAttempts: 3);
    if (verifiedAfterShortWait) return true;

    final verifiedFromPendingCode = await _tryApplyPendingVerificationCode();
    if (verifiedFromPendingCode) return true;

    final stillUnverified = !(await _refreshAndCheckVerified());
    if (!stillUnverified) return true;
    final reloadedUser = authRepo.currentUser;
    if (reloadedUser == null) return false;

    final resolvedEmail = reloadedUser.email ?? email;
    final verifiedAfterPrompt =
        await (_showVerification?.call(resolvedEmail, l10n) ??
            Future.value(false));
    if (verifiedAfterPrompt) return true;

    await authRepo.signOut();
    return false;
  }

  // ── Offline restore ─────────────────────────────────────────────────────────

  /// Exposed for regression tests covering the catch-path logging (F19).
  /// Production callers use [signInWithEmail], which invokes this helper
  /// when the email is not registered on this device.
  @visibleForTesting
  Future<bool> tryLocalFallbackSignInForTest({
    required String email,
    required String password,
    required StackRouter router,
    required AppLocalizations l10n,
  }) => _tryLocalFallbackSignIn(
    email: email,
    password: password,
    router: router,
    l10n: l10n,
  );

  Future<bool> _tryLocalFallbackSignIn({
    required String email,
    required String password,
    required StackRouter router,
    required AppLocalizations l10n,
  }) async {
    try {
      final dao = _ref.read(userDatabaseProvider).userProfileDao;
      final service = LocalAuthService(dao: dao);
      final profile = await service.signIn(email: email, password: password);
      final prefs = await SharedPreferences.getInstance();
      _ref
          .read(auth_state.authStateProvider.notifier)
          .setLocalBornSession(profile: profile);
      await _ref.read(authRepositoryProvider).signOut();
      final profiles = await _ref
          .read(userDatabaseProvider)
          .profileDao
          .getProfilesByAccount(_ref.read(currentAccountIdProvider));
      final firstSignInNeedsSetup = profiles.isEmpty;
      // R1o-H3: a user who previously skipped profile creation must land on the
      // empty-login surface, not be looped back into the onboarding wizard.
      final hasSkipped = prefs.getBool(kOnboardingSkipped) ?? false;
      if (firstSignInNeedsSetup && !hasSkipped) {
        await prefs.remove(kOnboardingComplete);
      } else {
        await prefs.setBool(kOnboardingComplete, true);
      }
      _ref.read(selectedProfileIdProvider.notifier).clear();
      if (firstSignInNeedsSetup) {
        unawaited(
          router.replaceAll([
            if (hasSkipped)
              const EmptyLoginRoute()
            else
              const OnboardingRoute(),
          ]),
        );
      } else {
        unawaited(router.replaceAll([const ProfilePickerRoute()]));
      }
      return true;
    } on InvalidCredentialsException {
      // Expected outcome — user has no local account or the password didn't
      // match. Caller (signInWithEmail) falls through to the next strategy
      // (Firebase). No log: a wrong-password attempt is not a system failure.
      return false;
    } catch (e, stackTrace) {
      // Any other failure (DB read error, prefs corruption, navigation
      // crash) is a real problem — the previous empty catch silently
      // swallowed these so a broken local-DB schema would manifest as an
      // unexplained "wrong password" UX. Replace with a structured warning
      // so operators inspecting logs can trace the failure.
      AppLogger.instance.warning(
        event: 'try_local_fallback_sign_in_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Exposed for regression tests covering the catch-path logging (F19).
  /// Production callers use [signInWithEmail], which invokes this helper
  /// when the registered account is cloud-born but the device is offline.
  @visibleForTesting
  Future<bool> tryOfflineCloudRestoreForTest(
    DeviceAccount account,
    StackRouter router,
  ) => _tryOfflineCloudRestore(account, router);

  Future<bool> _tryOfflineCloudRestore(
    DeviceAccount account,
    StackRouter router,
  ) async {
    try {
      _ref
          .read(accountDbFileNameProvider.notifier)
          .setFileName(account.dbFileName);
      _ref.invalidate(userDatabaseProvider);

      final dao = _ref.read(userDatabaseProvider).userProfileDao;
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

      if (profile == null) return false;

      final prefs = await SharedPreferences.getInstance();
      final session = SessionPersistenceService(
        prefs: prefs,
        registry: _ref.read(deviceRegistryProvider),
      );
      await session.setActiveAccount(account.accountId);
      await prefs.setBool(kOnboardingComplete, true);
      _ref
          .read(auth_state.authStateProvider.notifier)
          .setCloudBornSession(profile: profile);
      _ref.read(selectedProfileIdProvider.notifier).clear();
      unawaited(router.replaceAll([const AppShellRoute()]));
      return true;
    } catch (e, stackTrace) {
      // Any failure here (DB swap, profile DAO read, prefs write, navigation)
      // is a real problem — the offline restore path is the user's only way
      // back into their data when network is down. Silently returning false
      // (the previous empty-catch behavior) leaves the user staring at an
      // "incorrect password" toast with no operator breadcrumb.
      AppLogger.instance.warning(
        event: 'try_offline_cloud_restore_failed',
        exception: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  // ── Post sign-in navigation ─────────────────────────────────────────────────

  Future<void> _navigateAfterSignIn(StackRouter router) async {
    final user = _ref.read(authRepositoryProvider).currentUser;
    if (user == null) return;

    final registry = _ref.read(deviceRegistryProvider);

    // Heal pre-existing duplicate-email rows in the device registry.
    // Duplicates can land if an earlier sign-in flow inserted a row for the
    // same email under a different Firebase uid (account-delete + re-signup
    // server-side). One-shot per sign-in; cheap when there are no
    // duplicates (single SELECT + group).
    await registry.dedupeByEmail();

    // Resolve the registry entry for this Firebase user, in two passes:
    //   1. Look up by Firebase uid — the happy path for repeat sign-ins.
    //   2. Fall back to email lookup. If an entry exists for this email
    //      under a *different* uid (the bug Daniel hit: cloud account was
    //      deleted server-side, Firebase Auth re-minted a new uid for the
    //      same email), claim the existing entry by updating its
    //      firebaseUid. Preserves the local DB (no data loss on re-sign-in)
    //      and prevents the duplicate account-picker row.
    var existingEntry = await registry.findByFirebaseUid(user.uid);
    if (existingEntry == null && (user.email?.isNotEmpty ?? false)) {
      final byEmail = await registry.findByEmail(user.email!);
      if (byEmail != null) {
        await registry.updateAccountTier(
          byEmail.accountId,
          byEmail.tier,
          firebaseUid: user.uid,
        );
        existingEntry = await registry.findById(byEmail.accountId);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final session = SessionPersistenceService(prefs: prefs, registry: registry);

    if (existingEntry != null) {
      if (_ref.read(accountDbFileNameProvider) != existingEntry.dbFileName) {
        _ref
            .read(accountDbFileNameProvider.notifier)
            .setFileName(existingEntry.dbFileName);
        _ref.invalidate(userDatabaseProvider);
      }
      await _ref
          .read(auth_state.authStateProvider.notifier)
          .setCloudBornSessionFromFirebaseUser(user);
      await session.setActiveAccount(existingEntry.accountId);
    } else {
      // First sign-in on this device for this email AND this uid.
      // Derive the accountId from the Firebase uid so future sign-ins by
      // the same Firebase user always resolve via findByFirebaseUid above
      // (no chance of accidental duplication even if the registry row is
      // ever lost and recreated).
      final accountId = user.uid;
      final dbFileName = 'user_acc_$accountId.db';
      _ref.read(accountDbFileNameProvider.notifier).setFileName(dbFileName);
      _ref.invalidate(userDatabaseProvider);

      await _ref
          .read(auth_state.authStateProvider.notifier)
          .setCloudBornSessionFromFirebaseUser(user);

      await session.registerAccount(
        accountId: accountId,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        tier: 'cloudBorn',
        firebaseUid: user.uid,
        dbFileName: dbFileName,
      );
    }

    // S7: do NOT invalidate syncEngineProvider here — the orchestrator is a
    // per-session singleton and registers duplicate lifecycle observers /
    // Firestore listeners if rebuilt.
    final orchestrator = _ref.read(syncOrchestratorProvider);
    if (orchestrator != null) {
      // Offline-first: the launch pull is best-effort and MUST NOT block
      // sign-in. A thrown pull error (e.g. a not-yet-deployed Firestore rule
      // denying a newly added collection) previously propagated out of this
      // method and surfaced as a SignInError even though Firebase auth had
      // already succeeded — locking returning users out. Swallow + log; the
      // local Drift state below drives navigation regardless.
      try {
        await orchestrator.pullOnLaunch().timeout(
          const Duration(seconds: 8),
          onTimeout: () {},
        );
      } catch (e, stackTrace) {
        AppLogger.instance.warning(
          event: 'navigate_after_sign_in_pull_failed',
          exception: e,
          stackTrace: stackTrace,
        );
      }
    }

    var profileCount = await _ref
        .read(userDatabaseProvider)
        .profileDao
        .countProfilesForAccount(_ref.read(currentAccountIdProvider));

    var cloudAccountHasProfiles = false;
    if (profileCount == 0) {
      final remoteProfiles =
          await _ref
              .read(firestoreGatewayProvider)
              ?.fetchLearnerProfiles()
              .timeout(
                const Duration(seconds: 8),
                onTimeout: () => const <Map<String, dynamic>>[],
              ) ??
          const <Map<String, dynamic>>[];
      cloudAccountHasProfiles = remoteProfiles.isNotEmpty;

      if (cloudAccountHasProfiles && orchestrator != null) {
        try {
          await orchestrator.pullOnLaunch().timeout(
            const Duration(seconds: 8),
            onTimeout: () {},
          );
        } catch (e, stackTrace) {
          AppLogger.instance.warning(
            event: 'navigate_after_sign_in_pull_failed',
            exception: e,
            stackTrace: stackTrace,
          );
        }
        profileCount = await _ref
            .read(userDatabaseProvider)
            .profileDao
            .countProfilesForAccount(_ref.read(currentAccountIdProvider));
      }
    }

    // Plan §F Phase 4 deliverable 5 — never push the onboarding wizard when
    // the account already owns profiles in the cloud (returning user on a
    // clean install). The check above pulls + recounts; this final
    // re-query reflects any restore that ran in parallel (e.g. the
    // restoreGuard kicked off DeviceRestoreService while we were here) so
    // we don't lose a race against the just-merged Drift state.
    final finalProfileCount = await _ref
        .read(userDatabaseProvider)
        .profileDao
        .countProfilesForAccount(_ref.read(currentAccountIdProvider));

    if (finalProfileCount == 0 && !cloudAccountHasProfiles) {
      // WS2.relax: if the user has previously skipped profile creation,
      // route to the empty-login surface rather than forcing them back into
      // the onboarding wizard. Without this, a 0-profile account that chose
      // "skip" would be trapped in an infinite onboarding loop.
      final hasSkipped = prefs.getBool(kOnboardingSkipped) ?? false;
      if (hasSkipped) {
        await prefs.setBool(kOnboardingComplete, true);
        unawaited(router.replaceAll([const EmptyLoginRoute()]));
      } else {
        unawaited(router.replaceAll([const OnboardingRoute()]));
      }
      return;
    }

    final profiles = await _ref
        .read(userDatabaseProvider)
        .profileDao
        .getProfilesByAccount(_ref.read(currentAccountIdProvider));

    // Multi-profile accounts go to the picker; single-profile accounts go
    // straight to the app shell. Both paths bypass OnboardingRoute.
    if (profiles.length == 1) {
      _ref.read(selectedProfileIdProvider.notifier).select(profiles.first.id);
      final selectedOrchestrator = _ref.read(syncOrchestratorProvider);
      if (selectedOrchestrator != null) {
        unawaited(selectedOrchestrator.pullOnLaunch());
      }
      await prefs.setBool(kOnboardingComplete, true);
      unawaited(router.replaceAll([const AppShellRoute()]));
    } else if (profiles.length > 1) {
      _ref.read(selectedProfileIdProvider.notifier).clear();
      await prefs.setBool(kOnboardingComplete, true);
      unawaited(router.replaceAll([const ProfilePickerRoute()]));
    } else {
      // Cloud account has remote profiles but local pull didn't materialise
      // any — fall back to the app shell; the restoreGuard will pick up
      // the new-device case and route to DeviceRestoreRoute.
      _ref.read(selectedProfileIdProvider.notifier).clear();
      await prefs.setBool(kOnboardingComplete, true);
      unawaited(router.replaceAll([const AppShellRoute()]));
    }
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  /// Smart credential routing: device registry → local → Firebase.
  Future<void> signInWithEmail({
    required String email,
    required String password,
    required StackRouter router,
    required AppLocalizations l10n,
    required GlobalKey<FormState> formKey,
  }) async {
    if (!formKey.currentState!.validate()) return;

    state = const SignInSubmitting();

    final watchdog = Timer(const Duration(seconds: 15), () {
      if (state is SignInSubmitting) {
        state = SignInError(l10n.authSignInTimeout);
        _showError?.call(l10n.authSignInTimeout);
      }
    });

    try {
      final registry = _ref.read(deviceRegistryProvider);
      final account = await registry.findByEmail(email);

      if (account != null && account.accountTier.isLocal) {
        _ref
            .read(accountDbFileNameProvider.notifier)
            .setFileName(account.dbFileName);
        _ref.invalidate(userDatabaseProvider);

        final dao = _ref.read(userDatabaseProvider).userProfileDao;
        final service = LocalAuthService(dao: dao);
        final profile = await service.signIn(email: email, password: password);

        final prefs = await SharedPreferences.getInstance();
        final session = SessionPersistenceService(
          prefs: prefs,
          registry: registry,
        );
        await session.setActiveAccount(account.accountId);

        final isOnline = await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final upgradeSvc = UpgradeToCloudService(
            dao: dao,
            authRepository: _ref.read(authRepositoryProvider),
            registry: registry,
            accountId: account.accountId,
          );
          final finalized = await upgradeSvc.tryFinalizeVerifiedCloudUpgrade(
            localProfile: profile,
            password: password,
          );
          if (finalized != null) {
            final orchestrator = _ref.read(syncOrchestratorProvider);
            if (orchestrator != null) {
              await orchestrator.pushAllLocalData();
              await orchestrator.pullOnLaunch();
            }
            await _navigateAfterSignIn(router);
            state = const SignInIdle();
            return;
          }
        }

        _ref
            .read(auth_state.authStateProvider.notifier)
            .setLocalBornSession(profile: profile);
        await _ref.read(authRepositoryProvider).signOut();
        _ref.read(selectedProfileIdProvider.notifier).clear();
        final profiles = await _ref
            .read(userDatabaseProvider)
            .profileDao
            .getProfilesByAccount(_ref.read(currentAccountIdProvider));
        final firstSignInNeedsSetup = profiles.isEmpty;
        // R1o-H3: respect a prior onboarding-skip so a skipped local user lands
        // on the empty-login surface instead of being trapped in onboarding.
        final hasSkipped = prefs.getBool(kOnboardingSkipped) ?? false;
        if (firstSignInNeedsSetup && !hasSkipped) {
          await prefs.remove(kOnboardingComplete);
        } else {
          await prefs.setBool(kOnboardingComplete, true);
        }
        if (firstSignInNeedsSetup) {
          unawaited(
            router.replaceAll([
              if (hasSkipped)
                const EmptyLoginRoute()
              else
                const OnboardingRoute(),
            ]),
          );
        } else {
          unawaited(router.replaceAll([const ProfilePickerRoute()]));
        }
      } else if (account != null && account.accountTier.isCloud) {
        final isOnline = await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final authRepo = _ref.read(authRepositoryProvider);
          await authRepo
              .signInWithEmail(email, password)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw TimeoutException('Sign-in timed out'),
              );
          final verified = await _ensureCloudEmailVerified(email, l10n);
          if (verified) {
            await _navigateAfterSignIn(router);
          }
        } else {
          final restored = await _tryOfflineCloudRestore(account, router);
          if (!restored) {
            final msg = l10n.authLocalDataMissing;
            _showError?.call(msg);
            state = SignInError(msg);
            return;
          }
        }
      } else {
        final signedInLocally = await _tryLocalFallbackSignIn(
          email: email,
          password: password,
          router: router,
          l10n: l10n,
        );
        if (signedInLocally) {
          state = const SignInIdle();
          return;
        }

        final isOnline = await InternetConnectionChecker.instance.hasConnection;
        if (isOnline) {
          final authRepo = _ref.read(authRepositoryProvider);
          await authRepo
              .signInWithEmail(email, password)
              .timeout(
                const Duration(seconds: 10),
                onTimeout: () => throw TimeoutException('Sign-in timed out'),
              );
          final verified = await _ensureCloudEmailVerified(email, l10n);
          if (verified) {
            await _navigateAfterSignIn(router);
          }
        } else {
          final msg = l10n.authEmailOfflineUnreachable;
          _showError?.call(msg);
          state = SignInError(msg);
          return;
        }
      }
      state = const SignInIdle();
    } on InvalidCredentialsException {
      final msg = l10n.authIncorrectPassword;
      _showError?.call(msg);
      state = SignInError(msg);
    } catch (e) {
      final msg = _mapAuthErrorFromException(e, l10n);
      _showError?.call(msg);
      state = SignInError(msg);
    } finally {
      watchdog.cancel();
      if (state is SignInSubmitting) state = const SignInIdle();
    }
  }

  Future<void> signInWithGoogle({
    required StackRouter router,
    required AppLocalizations l10n,
  }) async {
    state = const SignInSubmitting();

    final watchdog = Timer(const Duration(seconds: 15), () {
      if (state is SignInSubmitting) {
        state = SignInError(l10n.authSignInTimeout);
        _showError?.call(l10n.authSignInTimeout);
      }
    });

    try {
      final authRepo = _ref.read(authRepositoryProvider);
      await authRepo.signInWithGoogle();

      final googleUser = _ref.read(authRepositoryProvider).currentUser;
      if (googleUser == null) {
        state = const SignInIdle();
        return;
      }

      final registry = _ref.read(deviceRegistryProvider);
      final existingEntry = await registry.findByFirebaseUid(googleUser.uid);
      if (existingEntry == null) {
        final accounts = await registry.getAllAccounts();
        if (accounts.length >= kMaxDeviceAccounts) {
          final msg = l10n.authMaxDeviceAccounts(kMaxDeviceAccounts);
          _showError?.call(msg);
          await _ref.read(authRepositoryProvider).signOut();
          state = SignInError(msg);
          return;
        }
      }

      final localMatch = await registry.findByEmail(googleUser.email ?? '');
      if (localMatch != null && localMatch.accountTier.isLocal) {
        final msg = l10n.authOfflineUseUpgrade;
        _showError?.call(msg);
        await _ref.read(authRepositoryProvider).signOut();
        state = SignInError(msg);
        return;
      }

      await _navigateAfterSignIn(router);
      state = const SignInIdle();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        state = const SignInIdle();
      } else {
        final msg = l10n.authGoogleSignInFailed;
        _showError?.call(msg);
        state = SignInError(msg);
      }
    } catch (e) {
      final msg = _mapAuthErrorFromException(e, l10n);
      _showError?.call(msg);
      state = SignInError(msg);
    } finally {
      watchdog.cancel();
      if (state is SignInSubmitting) state = const SignInIdle();
    }
  }

  /// Re-sends the email-verification message, swallowing failures into a
  /// logged warning instead of the previous silent empty-catch.
  ///
  /// Extracted from the inline `onSendAgain` closure so the catch path is
  /// directly testable without driving the full dialog UI.
  Future<void> resendVerificationEmail() async {
    try {
      await _ref.read(authRepositoryProvider).sendEmailVerification();
    } catch (e, stackTrace) {
      AppLogger.instance.warning(
        event: 'send_verification_email_failed',
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Builds the email-verification callback to pass to [showEmailVerificationDialog].
  Future<bool> Function(String email, AppLocalizations l10n)
  buildVerificationCallback(BuildContext context) {
    return (email, l10n) => showEmailVerificationDialog(
      context: context,
      email: email,
      l10n: l10n,
      onSendAgain: resendVerificationEmail,
      onVerified: () async {
        return await _tryApplyPendingVerificationCode() ||
            await _refreshAndCheckVerified() ||
            await _waitForVerified(maxAttempts: 2);
      },
    );
  }
}

/// Riverpod provider — auto-dispose so the controller is recreated on re-entry.
final signInControllerProvider =
    NotifierProvider.autoDispose<SignInController, SignInState>(
      SignInController.new,
    );
