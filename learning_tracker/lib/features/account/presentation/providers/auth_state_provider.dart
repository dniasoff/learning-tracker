import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/data/repositories/account_repository_adapter.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_state_provider.g.dart';

/// Unified auth state notifier (Epic 20 v2 §3).
///
/// Single source of truth for `currentUser + tier + sessionStatus`.
/// Replaces the sealed `AppAuthState` hierarchy. Cloud-born and
/// local-born accounts differ only by backend — the UI reads the
/// same shape from this notifier regardless.
@Riverpod(keepAlive: true)
class AuthStateNotifier extends _$AuthStateNotifier {
  @override
  AuthState build() {
    _init();
    // AUD-account-19: react to Firebase-side session invalidation (disabled
    // account, revoked refresh token, forced sign-out elsewhere) that
    // happens WITHOUT this app calling signOut()/any mutation itself.
    // Without this, nothing re-derives this notifier's state from a live
    // Firebase change — the app keeps believing a cloud-born session is
    // valid until an unrelated explicit action happens to touch it.
    //
    // Scope: only detect the "session became unauthenticated" transition
    // (stream settles to null) while we currently believe a cloud-born
    // session is signed in. A non-null emission is intentionally ignored
    // here — every path that authenticates to a NEW identity already
    // drives this notifier's state directly (setCloudBornSession /
    // setLocalBornSession), so re-deriving from the stream on every
    // non-null event would race and duplicate that explicit transition.
    ref.listen<AsyncValue<AppUser?>>(firebaseAuthStateProvider, (
      previous,
      next,
    ) {
      if (next is AsyncData<AppUser?> &&
          next.value == null &&
          state.isSignedIn &&
          state.tier == Tier.cloud) {
        state = const AuthState.signedOut();
      }
    });
    return const AuthState.initializing();
  }

  Future<void> _init() async {
    // AUD-account-03 / AUD-account-11: this whole body must never leave
    // `state` stuck at AuthState.initializing() — build() kicks this off
    // fire-and-forget, so an unhandled exception here is an unobserved
    // Future rejection that silently strands `sessionStatus` forever,
    // contradicting the domain model's own "must not hang" doc comment.
    try {
      // Cloud-born accounts require a valid Firebase session. If Firebase
      // has no current user (reinstall, signed out, etc.), we are signed
      // out — never resurrect a cloudBorn account without Firebase
      // confirming the session. The Firestore `users/{uid}` account doc is
      // resolved through [FirestoreAccountRepositoryAdapter] (the
      // AD-23/AD-28 seam; presentation/domain must not import the data
      // ring directly).
      final authRepo = ref.read(authRepositoryProvider);
      final firebaseUser = authRepo.currentUser;
      if (firebaseUser != null) {
        try {
          final refreshed = await authRepo.reloadCurrentUser();
          final isPasswordAccount =
              refreshed?.providers.contains('password') ?? false;
          if (refreshed != null &&
              !(isPasswordAccount && !refreshed.emailVerified)) {
            // Ensure the `users/{uid}` doc exists (placeholder created on
            // first sign-in) and restore the session from the account
            // record. Tier comes from the LIVE Firebase session, not from
            // any persisted field: cloud-born = linked credentials present.
            // An anonymous session (no providers) is the credential-less
            // local-born case and must never be labelled cloud-born.
            final adapter = FirestoreAccountRepositoryAdapter(ref: ref);
            final account = await adapter.ensureAccountForFirebaseUser(
              refreshed,
            );
            final hasLinkedCredentials = refreshed.providers.isNotEmpty;
            state = AuthState.signedIn(
              user: AuthUser.fromAccount(account),
              tier: hasLinkedCredentials ? Tier.cloud : Tier.local,
            );
            return;
          } else {
            await authRepo.signOut();
          }
        } on Exception catch (e, st) {
          // AUD-account-03: reloadCurrentUser() (User.reload()) is a network
          // round-trip that throws (e.g. FirebaseAuthException with code
          // network-request-failed) on an entirely ordinary offline cold
          // start. Log and fall through to the local-born restore path below
          // instead of leaving the session unresolved — mirrors the
          // defensive try/catch pattern in sign_in_controller.dart. The
          // adapter's AccountRepositoryNotReadyException (no active device
          // account) lands here too — the "cannot establish the account
          // record" case, which must never be reported as success.
          AppLogger.instance.warning(
            event: 'auth_state_init_cloud_reload_failed',
            exception: e,
            stackTrace: st,
          );
        }
      }

      // Local-born accounts are credential-less and device-only: no Firebase
      // session, no Firestore document — their only home is the device
      // registry. Restore the last-active local-born row if present. Respect
      // the active pointer (D10): never silently auto-activate an arbitrary
      // account against a null/dangling pointer.
      final registry = ref.read(deviceRegistryProvider);
      final activeAccountId = await registry.getLastActiveAccountId();
      if (activeAccountId != null) {
        final account = await registry.findById(activeAccountId);
        if (account != null && account.accountTier.isLocal) {
          state = AuthState.signedIn(
            user: AuthUser(
              uid: account.firebaseUid ?? account.accountId,
              email: account.email,
              displayName: account.displayName,
              firebaseUid: account.firebaseUid,
            ),
            tier: Tier.local,
          );
          return;
        }
      }

      state = const AuthState.signedOut();
    } on Exception catch (e, st) {
      // AUD-account-11: final safety net — any other exception in this
      // method (e.g. a registry/DB read failure) must still resolve `state`
      // to a terminal status rather than leaving it at `initializing`
      // forever.
      AppLogger.instance.error(
        event: 'auth_state_init_failed',
        exception: e,
        stackTrace: st,
      );
      state = const AuthState.signedOut();
    }
  }

  /// Promote the current session to signed-in (cloud-born).
  /// Invoked from the cloud-born sign-up/sign-in flows.
  void setCloudBornSession({required AccountEntity account}) {
    state = AuthState.signedIn(
      user: AuthUser.fromAccount(account),
      tier: Tier.cloud,
    );
  }

  /// Set the current session to signed-in (local-born).
  /// Invoked from `LocalAuthService.signIn`.
  void setLocalBornSession({required DeviceAccount account}) {
    state = AuthState.signedIn(
      user: AuthUser(
        uid: account.firebaseUid ?? account.accountId,
        email: account.email,
        displayName: account.displayName,
        firebaseUid: account.firebaseUid,
      ),
      tier: Tier.local,
    );
  }

  /// Clear the session. Used by sign-out and by the upgrade flow's
  /// collision rollback path.
  void signOut() {
    state = const AuthState.signedOut();
  }

  /// Ensure a cloud-born [AccountEntity] row exists for [firebaseUser] and
  /// activate the session. Called from sign-in, signup, and magic-link flows.
  ///
  /// If no account document exists yet (first sign-in on this device), a
  /// placeholder `users/{uid}` document is created so downstream code has
  /// something to read. The learner profile (child/adult mode) is a separate
  /// [LearnerProfiles] row created during onboarding — it is NOT set here.
  Future<void> setCloudBornSessionFromFirebaseUser(AppUser firebaseUser) async {
    final adapter = FirestoreAccountRepositoryAdapter(ref: ref);
    final account = await adapter.ensureAccountForFirebaseUser(firebaseUser);
    setCloudBornSession(account: account);
  }
}
