import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart'
    show GoogleSignInException, GoogleSignInExceptionCode;
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/router_provider.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/core/providers/path_uid_resolver_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/core/utils/firebase_error_code.dart';
import 'package:learning_tracker/features/account/data/repositories/account_repository_adapter.dart';
import 'package:learning_tracker/features/account/data/services/magic_link_service.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/domain/services/named_app_sign_in.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/account/presentation/widgets/email_verification_dialog.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_resume_store.dart'
    show kOnboardingComplete, kOnboardingSkipped;
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
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
  bool _emailVerificationDialogOpen = false;

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
    // The base Exception type adds no useful diagnostic detail; preserve the
    // established generic copy for it. Concrete internal exception types do
    // provide a safe, non-sensitive diagnostic without exposing the message.
    if (e.runtimeType == Exception().runtimeType) {
      return l10n.authErrSignInGeneric;
    }
    return '${l10n.authErrSignInGeneric} (${e.runtimeType})';
  }

  /// AUD-account-14: single point that turns whatever [AsyncValue.guard]
  /// caught into the message shown to the user — the mirror of the old
  /// scattered `_mapAuthErrorFromException` / literal-message call sites.
  ///
  ///   * [_SignInFailure] already carries a resolved l10n message (a "soft"
  ///     failure the body detected without an exception being thrown by a
  ///     lower layer — e.g. no local data for an offline restore).
  ///   * A non-cancel [GoogleSignInException] maps to the generic Google
  ///     failure copy (matches the previous `on GoogleSignInException`
  ///     catch's else-branch) — the cancel/interrupt codes are handled by the
  ///     caller before this is reached, since they resolve to Idle, not Error.
  ///   * Everything else falls back to the existing Firebase-code mapping.
  String _resolveFailureMessage(Object error, AppLocalizations l10n) {
    if (error is _SignInFailure) return error.message;
    // AccountFirebase's own ≤5 named-app bound (DNI-520).
    if (error is MaxAccountsReachedException) {
      return l10n.authMaxDeviceAccounts(kMaxDeviceAccounts);
    }
    if (error is GoogleSignInException) return l10n.authGoogleSignInFailed;
    return _mapAuthErrorFromException(error, l10n);
  }

  // ── Email verification helpers ──────────────────────────────────────────────

  /// The account whose email verification is being checked: the account
  /// that has just signed in on its named app (not yet active) while
  /// [_ensureCloudEmailVerified] runs, else the active account.
  AuthRepository? _verifyingAuth;

  AuthRepository get _verificationAuth =>
      _verifyingAuth ?? _ref.read(authRepositoryProvider);

  Future<bool> _refreshAndCheckVerified() async {
    final refreshed = await _verificationAuth.reloadCurrentUser();
    return refreshed?.emailVerified ?? false;
  }

  Future<bool> _waitForVerified({required int maxAttempts}) async {
    for (var i = 0; i < maxAttempts; i++) {
      // AUD-account-02: each loop iteration re-enters _refreshAndCheckVerified,
      // which may do a fresh `_ref.read(authRepositoryProvider)` — if the
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
      final authRepo = _verificationAuth;
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
    AppLocalizations l10n, {
    AuthRepository? accountAuth,
  }) async {
    final previous = _verifyingAuth;
    _verifyingAuth = accountAuth ?? previous;
    try {
      return await _ensureCloudEmailVerifiedOn(_verificationAuth, email, l10n);
    } finally {
      _verifyingAuth = previous;
    }
  }

  Future<bool> _ensureCloudEmailVerifiedOn(
    AuthRepository authRepo,
    String email,
    AppLocalizations l10n,
  ) async {
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
    final verifiedAfterPrompt = await (() async {
      _emailVerificationDialogOpen = true;
      try {
        return await (_showVerification?.call(resolvedEmail, l10n) ??
            Future.value(false));
      } finally {
        _emailVerificationDialogOpen = false;
      }
    })();
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
    AppLocalizations l10n, {
    AuthRepository? accountAuth,
  }) => _ensureCloudEmailVerified(email, l10n, accountAuth: accountAuth);

  // ── Offline restore ─────────────────────────────────────────────────────────

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
    if (account.firebaseUid == null) return false;
    try {
      _ref.read(activeAccountIdProvider.notifier).set(account.accountId);

      // No local Drift cache anymore (P3-5) — Firestore's own offline
      // persistence (account_firebase.dart) transparently serves the
      // cached users/{uid} doc when offline, so this reads the same way
      // whether online or off.
      final syntheticUser = AppUser(
        uid: account.firebaseUid!,
        email: account.email,
        displayName: account.displayName,
        emailVerified: true,
        providers: const <String>[],
      );
      final accountEntity = await FirestoreAccountRepositoryAdapter(
        ref: _ref,
      ).ensureAccountForFirebaseUser(syntheticUser);

      final prefs = await SharedPreferences.getInstance();
      final session = SessionPersistenceService(
        prefs: prefs,
        registry: _ref.read(deviceRegistryProvider),
      );
      await session.setActiveAccount(account.accountId);
      await prefs.setBool(kOnboardingComplete, true);
      _ref
          .read(authStateProvider.notifier)
          .setCloudBornSession(account: accountEntity);
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
  }

  /// The single named-app sign-in helper (DNI-520) for this controller.
  NamedAppSignIn _namedAppSignIn() => NamedAppSignIn(
    auth: _ref.read(authRepositoryProvider),
    registry: _ref.read(deviceRegistryProvider),
    pathUids: _ref.read(pathUidResolverProvider),
  );

  /// Activates [session] — the account whose named app the user has just
  /// signed in on (once; AD-1) — and routes on its profiles.
  ///
  /// The registry row is reconciled (AD-24 path uid) or registered BEFORE
  /// [activeAccountIdProvider] is set, because the active account's
  /// repositories resolve their `users/{uid}` path from that persisted row.
  Future<void> _navigateAfterSignIn(
    StackRouter router,
    NamedAppSession session,
  ) async {
    _resetSessionContextForFreshSignIn();

    final user = session.user;
    final accountId = session.accountId;
    final registry = _ref.read(deviceRegistryProvider);
    final prefs = await SharedPreferences.getInstance();
    final persistence = SessionPersistenceService(
      prefs: prefs,
      registry: registry,
    );

    if (session.isNewToDevice) {
      // First sign-in on this device for this account. dbFileName is
      // vestigial post-P3-5 (no per-account Drift DB is ever opened again)
      // but the registry row still carries it so AccountLifecycleService can
      // defensively delete a stale on-disk .sqlite file left over from
      // before the archival.
      await persistence.registerAccount(
        accountId: accountId,
        email: user.email ?? '',
        displayName: user.displayName ?? '',
        tier: 'cloudBorn',
        firebaseUid: user.uid,
        dbFileName: 'user_acc_$accountId.db',
      );
      _ref.read(activeAccountIdProvider.notifier).set(accountId);
      await _ref
          .read(authStateProvider.notifier)
          .setCloudBornSessionFromFirebaseUser(user);
    } else {
      await _namedAppSignIn().reconcilePathUid(session);
      _ref.read(activeAccountIdProvider.notifier).set(accountId);
      await _ref
          .read(authStateProvider.notifier)
          .setCloudBornSessionFromFirebaseUser(user);
      await persistence.setActiveAccount(accountId);
    }

    // Wrap in try/catch with backoff: an account doc is always ensured to
    // exist by setCloudBornSessionFromFirebaseUser above, but a *thrown*
    // fetch (transient permission-denied from an App Check token blip / a
    // flaky network at sign-in) would otherwise be indistinguishable from
    // a genuinely profile-less account, and falling straight through would
    // dump a RETURNING user into first-profile onboarding. Only *errors*
    // are retried — an empty result is trusted immediately.
    var profiles = const <LearnerProfileEntity>[];
    const maxFetchAttempts = 3;
    for (var attempt = 1; attempt <= maxFetchAttempts; attempt++) {
      try {
        profiles = await _ref.read(profileRepositoryProvider).getProfiles();
        break;
      } catch (e, stackTrace) {
        AppLogger.instance.warning(
          event: 'navigate_after_sign_in_fetch_profiles_failed',
          exception: e,
          stackTrace: stackTrace,
          fields: {'attempt': attempt, 'maxAttempts': maxFetchAttempts},
        );
        if (attempt == maxFetchAttempts) rethrow;
        await Future<void>.delayed(Duration(milliseconds: 1200 * attempt));
      }
    }

    if (profiles.isEmpty) {
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

    // Multi-profile accounts go to the picker; single-profile accounts go
    // straight to the app shell. Both paths bypass OnboardingRoute. Every
    // other case was already handled above (profiles.isEmpty) or is
    // structurally unreachable now that `profiles` IS the Firestore-direct
    // state (P3-7: no separate local-materialization step to lag behind it).
    if (profiles.length == 1) {
      _ref
          .read(selectedProfileIdProvider.notifier)
          .select(profiles.first.profileId);
      await prefs.setBool(kOnboardingComplete, true);
      unawaited(router.replaceAll([const AppShellRoute()]));
    } else {
      _ref.read(selectedProfileIdProvider.notifier).clear();
      await prefs.setBool(kOnboardingComplete, true);
      unawaited(router.replaceAll([const ProfilePickerRoute()]));
    }
  }

  // ── Public actions ──────────────────────────────────────────────────────────

  /// Smart credential routing: device registry → Firebase.
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
      if (state is SignInSubmitting && !_emailVerificationDialogOpen) {
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
    // deep inside _navigateAfterSignIn / _tryOfflineCloudRestore) can
    // throw/leave a disposed ref if the notifier
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

    final isOnline = await _ref
        .read(internetConnectionCheckerProvider)
        .hasConnection;
    if (!isOnline) {
      if (account == null) {
        throw _SignInFailure(l10n.authEmailOfflineUnreachable);
      }
      final restored = await _tryOfflineCloudRestore(account, router);
      if (!restored) {
        throw _SignInFailure(l10n.authLocalDataMissing);
      }
      return;
    }

    // One sign-in, on the account's own named app (AD-1, DNI-520).
    final signIn = _namedAppSignIn();
    final authRepo = _ref.read(authRepositoryProvider);
    final session = await signIn.signIn(
      emailHint: email,
      authenticate: (accountId) => authRepo
          .signInToAccountWithEmail(accountId, email, password)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Sign-in timed out'),
          ),
    );
    final verified = await _ensureCloudEmailVerified(
      email,
      l10n,
      accountAuth: authRepo.forAccount(session.accountId),
    );
    if (!verified) {
      // _ensureCloudEmailVerified already signed the named app out; tear a
      // freshly minted account's app down too.
      if (session.isNewToDevice) await signIn.abandon(session);
      return;
    }
    await _navigateAfterSignIn(router, session);
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
    // The Google picker only — no Firebase sign-in yet.
    final pick = await authRepo.pickGoogleAccount();
    final idToken = pick.idToken;
    if (idToken == null) {
      // DG-GAUTH-01: the picker returned without throwing (no user-cancel /
      // interrupt) but with no token — a silent failure that must surface as
      // SignInError, never a silent Idle.
      throw _SignInFailure(l10n.authGoogleSignInFailed);
    }

    // One sign-in, on the account's own named app (AD-1, DNI-520).
    final signIn = _namedAppSignIn();
    final session = await signIn.signIn(
      emailHint: pick.email,
      authenticate: (accountId) =>
          authRepo.signInToAccountWithGoogle(accountId, idToken),
    );

    if (session.isNewToDevice) {
      final accounts = await _ref.read(deviceRegistryProvider).getAllAccounts();
      if (accounts.length >= kMaxDeviceAccounts) {
        // SI-GOOGLE-01: abandon() signs the new account's named app (and
        // the Google session) out best-effort; a cleanup failure never masks
        // the cap error below. The ACTIVE account is left untouched.
        await signIn.abandon(session);
        throw _SignInFailure(l10n.authMaxDeviceAccounts(kMaxDeviceAccounts));
      }
    }

    await _navigateAfterSignIn(router, session);
  }

  /// Re-sends the email-verification message, swallowing failures into a
  /// logged warning instead of the previous silent empty-catch.
  ///
  /// Extracted from the inline `onSendAgain` closure so the catch path is
  /// directly testable without driving the full dialog UI.
  Future<void> resendVerificationEmail() async {
    try {
      await _verificationAuth.sendEmailVerification();
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
