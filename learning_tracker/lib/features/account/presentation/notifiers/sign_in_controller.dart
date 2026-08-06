import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart'
    show firestoreGatewayProvider;
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/utils/firebase_error_code.dart';
import 'package:learning_tracker/features/account/data/services/magic_link_service.dart';
import 'package:learning_tracker/features/account/domain/services/local_auth_service.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/domain/services/upgrade_to_cloud_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/email_verification_dialog.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart'
    show kOnboardingComplete, kOnboardingSkipped;
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart'
    show
        TutorGrantState,
        activeTutoredProfileSelectionProvider,
        tutorGrantRepositoryProvider;
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

/// AUD-account-14: internal-only marker exception carrying an already
/// user-facing (l10n-resolved) message for the "soft" failure branches that
/// previously assigned `state = SignInError(msg)` directly mid-method
/// instead of throwing. Routing them through this type lets
/// [AsyncValue.guard] be the single place that decides the terminal state
/// (see [SignInController._resolveFailureMessage]), rather than ~20 scattered
/// manual `state = ...` call sites.
class _SignInFailure implements Exception {
  const _SignInFailure(this.message);

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
      // Firebase projects with email-enumeration protection enabled (the
      // current default) return `invalid-credential` instead of
      // `wrong-password` for a bad password. Map it to the same clear
      // "Incorrect password" copy so a wrong-password attempt never degrades
      // to the generic "Sign-in failed" message.
      case 'invalid-credential':
        return l10n.authErrWrongPassword;
      case 'user-disabled':
        return l10n.authErrUserDisabled;
      case 'too-many-requests':
        return l10n.authErrTooManyRequests;
      case 'invalid-email':
        return l10n.authErrInvalidEmail;
      case 'network-request-failed':
        return l10n.authErrNetwork;
      // AUD-account-12: a user whose email already has a password-based
      // Firebase account taps "Sign in with Google" using that same
      // address. Without this case the generic fallback gives zero
      // guidance to use the existing password.
      case 'account-exists-with-different-credential':
        return l10n.authErrExistingPasswordAccount;
      default:
        return l10n.authErrSignInGeneric;
    }
  }

  String _mapAuthErrorFromException(Object e, AppLocalizations l10n) {
    final code = extractFirebaseCode(e);
    if (code != null) return _mapAuthError(code, l10n);
    return l10n.authErrSignInGeneric;
  }

  /// AUD-account-14: single point that turns whatever [AsyncValue.guard]
  /// caught into the message shown to the user — the mirror of the old
  /// scattered `_mapAuthErrorFromException` / literal-message call sites.
  ///
  ///   * [_SignInFailure] already carries a resolved l10n message (a "soft"
  ///     failure the body detected without an exception being thrown by a
  ///     lower layer — e.g. no local data for an offline restore).
  ///   * [InvalidCredentialsException] maps to the incorrect-password copy
  ///     (matches the previous `on InvalidCredentialsException` catch).
  ///   * A non-cancel [GoogleSignInException] maps to the generic Google
  ///     failure copy (matches the previous `on GoogleSignInException`
  ///     catch's else-branch) — the cancel/interrupt codes are handled by the
  ///     caller before this is reached, since they resolve to Idle, not Error.
  ///   * Everything else falls back to the existing Firebase-code mapping.
  String _resolveFailureMessage(Object error, AppLocalizations l10n) {
    if (error is _SignInFailure) return error.message;
    if (error is InvalidCredentialsException) return l10n.authIncorrectPassword;
    if (error is GoogleSignInException) return l10n.authGoogleSignInFailed;
    return _mapAuthErrorFromException(error, l10n);
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
      // AUD-account-02: each loop iteration re-enters _refreshAndCheckVerified,
      // which does a fresh `_ref.read(authRepositoryProvider)` — if the
      // notifier was disposed during the 350ms delay below, that read throws.
      if (!ref.mounted) return false;
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
      final code = extractFirebaseCode(e);
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

    // SI-VERIFY-01: signOut() can throw PlatformException(clearCredentialStateAsync…)
    // on emulators/devices without Google Play Services. The user cancelled
    // email verification — wrap in its own try/catch so a cleanup failure
    // never surfaces as "Sign-in failed" (authErrSignInGeneric) to the user.
    // The caller already returns false here, so the sign-in correctly fails.
    try {
      await authRepo.signOut();
    } catch (e) {
      AppLogger.instance.warning(
        event: 'ensure_cloud_email_verified_sign_out_failed',
        exception: e,
      );
    }
    return false;
  }

  /// Exposed for regression tests covering SI-VERIFY-01: a throwing signOut()
  /// in _ensureCloudEmailVerified must not surface as a sign-in error.
  @visibleForTesting
  Future<bool> ensureCloudEmailVerifiedForTest(
    String email,
    AppLocalizations l10n,
  ) => _ensureCloudEmailVerified(email, l10n);

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
          .read(authStateProvider.notifier)
          .setLocalBornSession(profile: profile);
      // SI-LOCAL-01: signOut() can throw PlatformException(clearCredentialStateAsync…)
      // on emulators/devices without Google Play Services. The local account was
      // already created successfully — wrap in its own try/catch so a cleanup
      // failure never rolls the sign-in into an error state.
      try {
        await _ref.read(authRepositoryProvider).signOut();
      } catch (e) {
        AppLogger.instance.warning(
          event: 'try_local_fallback_sign_in_sign_out_failed',
          exception: e,
        );
      }
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
      _resetSessionContextForFreshSignIn();
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
      _ref.read(activeAccountIdProvider.notifier).set(account.accountId);
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
          .read(authStateProvider.notifier)
          .setCloudBornSession(profile: profile);
      _ref.read(selectedProfileIdProvider.notifier).clear();
      _resetSessionContextForFreshSignIn();
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

  /// Reset all per-session context that must NOT survive a fresh sign-in /
  /// session establishment.
  ///
  /// A sign-in must always land in the user's OWN profile in NORMAL mode:
  ///   * Any active tutored (talmid) selection is cleared — the user is not in
  ///     a talmid view; entering one requires an explicit switcher + Tutor PIN.
  ///   * The parent-mode PIN gate is locked (`pinGuard.lock()` clears both the
  ///     guard's cached scope and `parentPinAuthenticatedProfileId` via its
  ///     `onSessionLocked` callback) — reaching parent management requires the
  ///     PIN again.
  ///   * The restore-guard new-device cache is reset so each sign-in gets a
  ///     fresh check. Without this, a cloud account that completed a device
  ///     restore in a prior session (same process, different user) would leave
  ///     `_isNewDevice = false` and skip the redirect for the incoming account
  ///     even when its local DB is empty. (RESTORE-01)
  ///
  /// These pieces of state are `keepAlive` / live in the router singleton,
  /// so without these resets they leak across a sign-out → sign-in within the
  /// same process, auto-restoring the previous tutor/parent/restore context.
  /// This is scoped to session establishment only — ordinary mid-session
  /// navigation and explicit talmid/parent entry are untouched.
  void _resetSessionContextForFreshSignIn() {
    _ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
    _ref.read(routerProvider).pinGuard.lock();
    _ref.read(routerProvider).restoreGuard.resetForNewSession();
  }

  Future<void> _navigateAfterSignIn(StackRouter router) async {
    _resetSessionContextForFreshSignIn();

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
      _ref.read(activeAccountIdProvider.notifier).set(existingEntry.accountId);
      await _ref
          .read(authStateProvider.notifier)
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
      _ref.read(activeAccountIdProvider.notifier).set(accountId);
      _ref.invalidate(userDatabaseProvider);

      await _ref
          .read(authStateProvider.notifier)
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
      // Wrap in try/catch: a new uid that has no Firestore user document yet
      // will get permission-denied from fetchLearnerProfiles (the rules
      // require the document to exist). Treat any error as "no remote profiles"
      // so sign-in is never blocked by a Firestore permission error here.
      //
      // RETURNING-USER ROBUSTNESS: a *thrown* fetch (transient permission-denied
      // from an App Check token blip / a flaky network at sign-in) is
      // indistinguishable from a genuinely-new account here, and falling
      // straight through would dump a RETURNING user into first-profile
      // onboarding. So retry the fetch a few times with backoff before
      // concluding "no remote profiles": a transient failure recovers, while a
      // genuinely doc-less new account keeps denying on every attempt and still
      // (correctly) lands on onboarding. Only *errors* are retried — a timeout
      // resolves to an empty list (no throw) and is not retried.
      var remoteProfiles = const <Map<String, dynamic>>[];
      const maxFetchAttempts = 3;
      for (var attempt = 1; attempt <= maxFetchAttempts; attempt++) {
        try {
          remoteProfiles =
              await _ref
                  .read(firestoreGatewayProvider)
                  ?.fetchLearnerProfiles()
                  .timeout(
                    const Duration(seconds: 8),
                    onTimeout: () => const <Map<String, dynamic>>[],
                  ) ??
              const <Map<String, dynamic>>[];
          break;
        } catch (e, stackTrace) {
          AppLogger.instance.warning(
            event: 'navigate_after_sign_in_fetch_profiles_failed',
            exception: e,
            stackTrace: stackTrace,
            fields: {'attempt': attempt, 'maxAttempts': maxFetchAttempts},
          );
          if (attempt < maxFetchAttempts) {
            await Future<void>.delayed(Duration(milliseconds: 1200 * attempt));
          }
        }
      }
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
      // S6: a profile-less account with ≥1 active tutor grant is a pure tutor.
      // Route directly to the picker (TALMID PROFILES section visible) so they
      // are never forced through the profile-creation wizard. We fire-and-forget
      // with a short timeout so offline users fall through to the existing paths.
      var hasActiveGrant = false;
      try {
        final grants = await _ref
            .read(tutorGrantRepositoryProvider)
            .listIncomingGrants()
            .timeout(const Duration(seconds: 4), onTimeout: () => const []);
        hasActiveGrant = grants.any(
          (g) => g.grantState.rawState == TutorGrantState.active,
        );
      } catch (_) {
        // Network unavailable or CF error — fall through to the default path.
      }
      if (hasActiveGrant) {
        await prefs.setBool(kOnboardingComplete, true);
        unawaited(router.replaceAll([const ProfilePickerRoute()]));
        return;
      }

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

    // SYNC-RECONCILE: local profiles exist but the cloud account has NONE
    // (cloudAccountHasProfiles was false from the fetch above). This is the
    // "never reached the cloud" gap: a profile created while local-born/offline,
    // or whose push failed under a since-fixed identity mismatch, has no cloud
    // document — and a plain cloud-born re-sign-in otherwise only PULLS, so the
    // data would stay stranded locally forever (the "Backup & Sync unavailable"
    // never clears even after re-login). Run the bulk uploader once to enqueue
    // every local entity (profiles + their data) into the outbox. Idempotent
    // (deterministic doc ids + set/merge), best-effort, and MUST NOT block
    // sign-in navigation, so fire-and-forget with the active profile primed so
    // LocalDataUploadService resolves a valid profile id.
    if (profiles.isNotEmpty &&
        !cloudAccountHasProfiles &&
        orchestrator != null) {
      final reconcileProfile = ProfileModel.fromDriftRow(profiles.first);
      _ref
          .read(selectedProfileIdProvider.notifier)
          .select(reconcileProfile.id, ulid: reconcileProfile.ulid);
      unawaited(
        orchestrator.pushAllLocalData().catchError((Object e, StackTrace st) {
          AppLogger.instance.warning(
            event: 'sign_in_reconcile_push_all_local_failed',
            exception: e,
            stackTrace: st,
          );
        }),
      );
    }

    // Multi-profile accounts go to the picker; single-profile accounts go
    // straight to the app shell. Both paths bypass OnboardingRoute.
    if (profiles.length == 1) {
      final soleProfile = ProfileModel.fromDriftRow(profiles.first);
      _ref
          .read(selectedProfileIdProvider.notifier)
          .select(soleProfile.id, ulid: soleProfile.ulid);
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
  ///
  /// AUD-account-14: state transitions are driven by a single
  /// [AsyncValue.guard] around [_signInWithEmailBody] rather than ~10 manual
  /// `state = ...` call sites scattered through the routing logic. Every exit
  /// from the body is either a plain `return` (success → [SignInIdle]) or a
  /// thrown exception (failure → [SignInError]) — there is no longer a code
  /// path through the body that can leave `state` stuck at
  /// [SignInSubmitting] after this method's future completes, because the
  /// terminal assignment happens exactly once, unconditionally, from the
  /// guard's result.
  Future<void> signInWithEmail({
    required String email,
    required String password,
    required StackRouter router,
    required AppLocalizations l10n,
    required GlobalKey<FormState> formKey,
  }) async {
    if (!formKey.currentState!.validate()) return;

    state = const SignInSubmitting();

    // The watchdog is a fire-and-forget Timer callback, not part of the
    // guarded async body — it cannot itself be expressed as an awaited
    // AsyncValue.guard branch, so it keeps its own direct `state = ...`
    // (guarded by the `is SignInSubmitting` race check, unchanged from
    // before this refactor).
    final watchdog = Timer(const Duration(seconds: 15), () {
      if (state is SignInSubmitting) {
        state = SignInError(l10n.authSignInTimeout);
        _showError?.call(l10n.authSignInTimeout);
      }
    });
    // AUD-account-02: this is autoDispose. If the user backs out of the
    // sign-in screen before the watchdog fires, the finally block's
    // `watchdog.cancel()` never runs (the notifier is torn down mid-await,
    // not via a normal try/finally exit) and the Timer keeps running,
    // touching a disposed `state` up to 15s later. Cancel it on disposal too.
    ref.onDispose(watchdog.cancel);

    final result = await AsyncValue.guard(
      () => _signInWithEmailBody(
        email: email,
        password: password,
        router: router,
        l10n: l10n,
      ),
    );
    watchdog.cancel();
    // AUD-account-02: any awaited call inside the guarded body (including
    // deep inside _navigateAfterSignIn / _tryLocalFallbackSignIn /
    // _tryOfflineCloudRestore) can throw/leave a disposed ref if the notifier
    // was torn down mid-flight. AsyncValue.guard already caught that safely;
    // bail out here before touching `state` — there is nothing left to show
    // the user, the screen that would have shown it is already gone.
    if (!ref.mounted) return;

    result.when(
      data: (_) => state = const SignInIdle(),
      error: (error, stackTrace) {
        final msg = _resolveFailureMessage(error, l10n);
        _showError?.call(msg);
        state = SignInError(msg);
      },
      loading: () {}, // unreachable — guard() only ever resolves to data/error
    );
  }

  /// Body of [signInWithEmail], run inside [AsyncValue.guard]. Every "soft"
  /// failure (previously `state = SignInError(msg); return;`) now throws
  /// [_SignInFailure] so the guard captures it uniformly alongside exceptions
  /// thrown by lower layers.
  Future<void> _signInWithEmailBody({
    required String email,
    required String password,
    required StackRouter router,
    required AppLocalizations l10n,
  }) async {
    final registry = _ref.read(deviceRegistryProvider);
    final account = await registry.findByEmail(email);

    if (account != null && account.accountTier.isLocal) {
      _ref
          .read(accountDbFileNameProvider.notifier)
          .setFileName(account.dbFileName);
      _ref.read(activeAccountIdProvider.notifier).set(account.accountId);
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

      final isOnline = await _ref
          .read(internetConnectionCheckerProvider)
          .hasConnection;
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
          return;
        }
      }

      _ref
          .read(authStateProvider.notifier)
          .setLocalBornSession(profile: profile);
      // SI-LOCAL-01: signOut() can throw PlatformException(clearCredentialStateAsync…)
      // on emulators/devices without Google Play Services. The local account
      // authenticated successfully — wrap in its own try/catch so a cleanup
      // failure never surfaces as "Sign-in failed" to the user.
      try {
        await _ref.read(authRepositoryProvider).signOut();
      } catch (e) {
        AppLogger.instance.warning(
          event: 'sign_in_local_sign_out_failed',
          exception: e,
        );
      }
      // SI-08: clear all per-session router state that must NOT survive a
      // fresh sign-in. The local-account path previously only cleared
      // selectedProfileId, leaving the tutored-selection and PIN-gate caches
      // intact. In a multi-account scenario (cloud session interrupted, user
      // signs in with a local account) this leaked the previous session's tutor
      // context and restore-guard state into the new session. Mirrors the
      // _navigateAfterSignIn and _tryLocalFallbackSignIn paths.
      _resetSessionContextForFreshSignIn();
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
      final isOnline = await _ref
          .read(internetConnectionCheckerProvider)
          .hasConnection;
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
          throw _SignInFailure(l10n.authLocalDataMissing);
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
        return;
      }

      final isOnline = await _ref
          .read(internetConnectionCheckerProvider)
          .hasConnection;
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
        throw _SignInFailure(l10n.authEmailOfflineUnreachable);
      }
    }
  }

  /// AUD-account-14: see [signInWithEmail]'s doc comment — the same
  /// single-guard structure replaces the ~9 manual `state = ...` call sites
  /// this method previously had spread across its try/catch/finally.
  Future<void> signInWithGoogle({
    required StackRouter router,
    required AppLocalizations l10n,
  }) async {
    state = const SignInSubmitting();

    // 45 s: Google's account-picker round-trip + Firebase token exchange can
    // take 20–30 s on a slow network. 15 s was too short and caused the
    // watchdog to fire mid-auth, surfacing a spurious "Sign-in failed" toast
    // even though Firebase auth succeeded.
    //
    // The watchdog is a fire-and-forget Timer callback, not part of the
    // guarded async body — see signInWithEmail's identical comment above.
    final watchdog = Timer(const Duration(seconds: 45), () {
      if (state is SignInSubmitting) {
        state = SignInError(l10n.authSignInTimeout);
        _showError?.call(l10n.authSignInTimeout);
      }
    });
    // AUD-account-02: see signInWithEmail's identical comment above.
    ref.onDispose(watchdog.cancel);

    final result = await AsyncValue.guard(
      () => _signInWithGoogleBody(router: router, l10n: l10n),
    );
    watchdog.cancel();
    // AUD-account-02: see signInWithEmail's identical comment above.
    if (!ref.mounted) return;

    result.when(
      data: (_) => state = const SignInIdle(),
      error: (error, stackTrace) {
        // A user-initiated cancel/interrupt is not a failure — it returns to
        // Idle with no error shown, same as the pre-refactor
        // `on GoogleSignInException catch` branch.
        if (error is GoogleSignInException &&
            (error.code == GoogleSignInExceptionCode.canceled ||
                error.code == GoogleSignInExceptionCode.interrupted)) {
          state = const SignInIdle();
          return;
        }
        final msg = _resolveFailureMessage(error, l10n);
        _showError?.call(msg);
        state = SignInError(msg);
      },
      loading: () {}, // unreachable — guard() only ever resolves to data/error
    );
  }

  /// Body of [signInWithGoogle], run inside [AsyncValue.guard]. Every "soft"
  /// failure (previously `state = SignInError(msg); return;`) now throws
  /// [_SignInFailure] so the guard captures it uniformly alongside exceptions
  /// thrown by lower layers (including [GoogleSignInException] itself, which
  /// [signInWithGoogle]'s result handler special-cases for cancel/interrupt).
  Future<void> _signInWithGoogleBody({
    required StackRouter router,
    required AppLocalizations l10n,
  }) async {
    final authRepo = _ref.read(authRepositoryProvider);
    await authRepo.signInWithGoogle();

    final googleUser = _ref.read(authRepositoryProvider).currentUser;
    if (googleUser == null) {
      // DG-GAUTH-01: signInWithGoogle() returned without throwing (no
      // user-cancel / interrupt) but left currentUser null — a silent JWT
      // exchange failure or GMS returning without a live Firebase session.
      // Previously we returned SignInIdle with zero feedback; throwing here
      // routes through the guard so this always surfaces as SignInError,
      // never a silent Idle.
      throw _SignInFailure(l10n.authGoogleSignInFailed);
    }

    final registry = _ref.read(deviceRegistryProvider);
    final existingEntry = await registry.findByFirebaseUid(googleUser.uid);
    if (existingEntry == null) {
      final accounts = await registry.getAllAccounts();
      if (accounts.length >= kMaxDeviceAccounts) {
        // SI-GOOGLE-01: signOut() can throw PlatformException on devices
        // where CredentialManager is partially initialised. The error is
        // about to be shown via the thrown failure below — wrap so cleanup
        // never masks the real error.
        try {
          await _ref.read(authRepositoryProvider).signOut();
        } catch (e) {
          AppLogger.instance.warning(
            event: 'sign_in_google_max_accounts_sign_out_failed',
            exception: e,
          );
        }
        throw _SignInFailure(l10n.authMaxDeviceAccounts(kMaxDeviceAccounts));
      }
    }

    final localMatch = await registry.findByEmail(googleUser.email ?? '');
    if (localMatch != null && localMatch.accountTier.isLocal) {
      // SI-GOOGLE-01: same defensive wrap as above.
      try {
        await _ref.read(authRepositoryProvider).signOut();
      } catch (e) {
        AppLogger.instance.warning(
          event: 'sign_in_google_local_conflict_sign_out_failed',
          exception: e,
        );
      }
      throw _SignInFailure(l10n.authOfflineUseUpgrade);
    }

    await _navigateAfterSignIn(router);
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
