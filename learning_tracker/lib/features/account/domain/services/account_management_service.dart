import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/onboarding_screen.dart'
    show kOnboardingComplete;
import 'package:shared_preferences/shared_preferences.dart';

/// Service for account management operations:
/// sign out, delete account, change password, link providers.
class AccountManagementService {
  AccountManagementService({
    required AuthRepository authRepository,
    FlutterSecureStorage? secureStorage,
  }) : _authRepository = authRepository,
       _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final AuthRepository _authRepository;

  /// Device-scoped secure storage — holds parent/profile/tutor PIN hashes and
  /// lockout state. These are NOT in SharedPreferences and survive a
  /// `prefs.clear()`, so account teardown must wipe them explicitly
  /// (otherwise an old tutor PIN keeps verifying after a fresh sign-up).
  final FlutterSecureStorage _secureStorage;

  /// Clears the app-level session/onboarding flags in SharedPreferences
  /// (onboarding-complete plus resumable onboarding/add-track state) so the
  /// account picker shows on next launch. This method itself never touches
  /// Firebase — it leaves whatever Firebase session is currently live
  /// exactly as it found it.
  ///
  /// AUD-account-23: that Firebase-preserving property is NOT what powers
  /// the instant "tap a tile → dashboard in < 200ms" account-switch
  /// experience. Both current callers immediately follow this call with a
  /// genuinely hard sign-out — `showSignOutConfirmation` with
  /// `authRepositoryProvider.signOut()`, and `showDeleteLocalAccountFlow`
  /// with `authStateProvider.notifier.signOut()` (a no-op on the Firebase
  /// session for local-born accounts, which never hold one) — so no call
  /// site relies on a cached token surviving this method today. The fast
  /// tile-tap resume is real, but it comes from navigating straight to the
  /// account picker WITHOUT calling `signOut()` at all — see the
  /// "Switch Account" entry points in
  /// `features/profiles/presentation/widgets/profile_switcher_sheet.dart`
  /// and `features/settings/presentation/widgets/account_actions_sheet.dart`,
  /// which push [AccountPickerRoute] while leaving the live session intact.
  ///
  /// The hard sign-out (clearing the Firebase token) happens when the
  /// account is removed — see
  /// [AccountLifecycleService.removeCloudFromDevice].
  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kOnboardingComplete);
    // Clear transient onboarding/add-track state
    for (final key in [
      'onboarding_phase',
      'onboarding_profile_id',
      'onboarding_profile_name',
      'onboarding_profile_mode',
      'onboarding_language',
      'add_track_step',
      'add_track_curriculum',
      'add_track_scope',
      'add_track_program',
      'add_track_program_name',
      'add_track_study_days',
      'add_track_label',
    ]) {
      await prefs.remove(key);
    }
  }

  /// Deletes the current user's account and all associated data.
  ///
  /// Requires [reauthenticateWithEmail] or [reauthenticateWithGoogle]
  /// to be called first. Cascade:
  /// 1. Delete Firestore user document and subcollections
  /// 2. Delete Firebase Auth account
  /// 3. Clear SharedPreferences + secure storage
  ///
  /// Throws [StateError] if there is no signed-in user or if the signed-in
  /// user's UID does not match [uid], preventing accidental cross-account
  /// deletion in the event of a race or session mismatch.
  Future<void> deleteAccount(String uid) async {
    // Guard: verify the current session matches the account being deleted.
    final currentUser = _authRepository.currentUser;
    if (currentUser == null) {
      throw StateError('deleteAccount($uid): no user is currently signed in.');
    }
    if (currentUser.uid != uid) {
      throw StateError(
        'deleteAccount($uid): current user UID (${currentUser.uid}) does not '
        'match the account being deleted.',
      );
    }

    // 1. Delete Firestore data.
    await _deleteFirestoreUserData(uid);

    // 2. Delete Firebase Auth account.
    //
    //    This can throw (e.g. `requires-recent-login`, transient network) AFTER
    //    the Firestore wipe. The deletion overlay treats the account as
    //    gone regardless and routes the user back to sign-in/sign-up, so if we
    //    let the throw skip the local-state teardown below, the stale
    //    onboarding-complete flag and tutor PIN survive into the next sign-up
    //    (Bug 5 / Bug 6). Run the local teardown in `finally` so it ALWAYS
    //    happens, then rethrow so the caller still surfaces the auth error.
    try {
      await _authRepository.deleteAccount();
    } finally {
      // 3. Wipe ALL device-local per-account state. Pre-launch: aggressive
      //    clearing is safe — nothing here should survive a delete.
      await clearLocalDeviceState();
    }
  }

  /// Wipes every piece of device-local per-account state that must NOT survive
  /// an account deletion or hard sign-out:
  ///
  /// - SharedPreferences in full (onboarding-complete flag, onboarding/add-track
  ///   resume state, last-active-account pointer, selected-profile, cached
  ///   settings).
  /// - Secure storage in full (parent/profile/tutor PIN hashes + lockout state)
  ///   — `prefs.clear()` does not touch secure storage, so an old tutor PIN
  ///   would otherwise keep verifying after a fresh sign-up (Bug 6).
  Future<void> clearLocalDeviceState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    // Belt-and-suspenders: even after clear(), make sure the onboarding-complete
    // flag is explicitly false so a fresh sign-up always routes through the
    // wizard (Bug 5).
    await prefs.remove(kOnboardingComplete);
    try {
      await _secureStorage.deleteAll();
    } catch (_) {
      // Secure storage may be unavailable in some environments (tests without
      // the platform channel). Swallow so DB/prefs teardown is not undone.
    }
  }

  /// Changes the password for the current email/password user.
  ///
  /// Requires recent authentication (FR104).
  Future<void> changePassword(String newPassword) async {
    await _authRepository.changePassword(newPassword);
  }

  /// Re-authenticates the current user with email and password.
  Future<void> reauthenticateWithEmail(String email, String password) async {
    await _authRepository.reauthenticateWithEmail(email, password);
  }

  /// Re-authenticates the current user with Google.
  Future<void> reauthenticateWithGoogle() async {
    await _authRepository.reauthenticateWithGoogle();
  }

  /// Links a Google account to the current user (FR105).
  Future<void> linkGoogleProvider() async {
    await _authRepository.linkGoogleProvider();
  }

  /// Links an email/password credential to the current user (FR105).
  Future<void> linkEmailProvider(String email, String password) async {
    await _authRepository.linkEmailProvider(email, password);
  }

  /// Returns the list of provider IDs linked to the current user.
  List<String> getLinkedProviders() {
    return _authRepository.getLinkedProviders();
  }

  /// Deletes all Firestore data for the current user via the `deleteAccountData`
  /// Cloud Function, which uses Admin SDK `recursiveDelete` server-side.
  ///
  /// The [uid] is passed explicitly so the Cloud Function can validate it
  /// server-side if desired. The CF currently also infers the caller from
  /// Firebase Auth context; the client-side guard in [deleteAccount] is the
  /// primary safety net — the explicit uid is belt-and-suspenders.
  Future<void> _deleteFirestoreUserData(String uid) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteAccountData',
      );
      await callable.call<Map<String, dynamic>>(<String, dynamic>{'uid': uid});
    } catch (e, stackTrace) {
      // Log but don't rethrow — auth deletion + local cleanup still proceed.
      // The onUserDeleted Cloud Function will also fire when Auth account is
      // deleted and will handle any remaining data as a safety net.
      //
      // AUD-account-13: this catch previously had zero AppLogger call despite
      // the comment above claiming "Log but don't rethrow" — a failure of the
      // primary Firestore-deletion path (network error, quota, not-yet-deployed
      // CF, permission-denied) had zero telemetry. uid only, no other PII.
      AppLogger.instance.error(
        event: 'delete_firestore_user_data_failed',
        fields: {'uid': uid},
        exception: e,
        stackTrace: stackTrace,
      );
    }
  }
}
