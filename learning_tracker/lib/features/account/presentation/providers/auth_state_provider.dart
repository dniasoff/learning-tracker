import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
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
    return const AuthState.initializing();
  }

  Future<void> _init() async {
    // Cloud-born accounts require a valid Firebase session. If Firebase
    // has no current user (reinstall, signed out, etc.), we are signed
    // out — never resurrect a cloudBorn profile row from SQLite without
    // Firebase confirming the session.
    final authRepo = ref.read(authRepositoryProvider);
    final firebaseUser = authRepo.currentUser;
    if (firebaseUser != null) {
      final refreshed = await authRepo.reloadCurrentUser();
      final isPasswordAccount =
          refreshed?.providers.contains('password') ?? false;
      if (refreshed != null &&
          !(isPasswordAccount && !refreshed.emailVerified)) {
        final dao = ref.read(userDatabaseProvider).userProfileDao;
        var profile = await dao.findCloudBornByFirebaseUid(refreshed.uid);
        if (profile == null) {
          // Profile tier may be stale (was created locally before cloud sign-in
          // or the upgrade flow didn't flip the tier). Upgrade it now so sync
          // activates on this and every subsequent launch.
          final any = await dao.getUserProfileByFirebaseUid(refreshed.uid);
          if (any != null) {
            await dao.upgradeLocalToCloud(
              profileId: any.id,
              firebaseUid: refreshed.uid,
              updatedAt: DateTimeFactory.nowUtc(),
            );
            profile = await dao.findCloudBornByFirebaseUid(refreshed.uid);
          }
        }
        if (profile != null) {
          state = AuthState.signedIn(
            user: AuthUser.fromProfile(profile),
            tier: Tier.cloudBorn,
          );
          return;
        }
      } else {
        await authRepo.signOut();
      }
    }

    // Local-born accounts don't need Firebase auth — they store data
    // locally only. Restore the first local-born row if present.
    final dao = ref.read(userDatabaseProvider).userProfileDao;
    final locals = await dao.findByTier(UserTier.localBorn);
    if (locals.isNotEmpty) {
      state = AuthState.signedIn(
        user: AuthUser.fromProfile(locals.first),
        tier: Tier.localBorn,
      );
      return;
    }

    state = const AuthState.signedOut();
  }

  /// Promote the current session to signed-in (cloud-born).
  /// Invoked from the cloud-born sign-up/sign-in flows.
  void setCloudBornSession({required UserProfile profile}) {
    state = AuthState.signedIn(
      user: AuthUser.fromProfile(profile),
      tier: Tier.cloudBorn,
    );
  }

  /// Set the current session to signed-in (local-born).
  /// Invoked from `LocalAuthService.signIn`.
  void setLocalBornSession({required UserProfile profile}) {
    state = AuthState.signedIn(
      user: AuthUser.fromProfile(profile),
      tier: Tier.localBorn,
    );
  }

  /// Clear the session. Used by sign-out and by the upgrade flow's
  /// collision rollback path.
  void signOut() {
    state = const AuthState.signedOut();
  }

  /// Ensure a cloud-born [Account] row exists for [firebaseUser] and activate
  /// the session. Called from sign-in, signup, and magic-link flows.
  ///
  /// If no account row exists yet (first sign-in on this device), a placeholder
  /// row is created so downstream code has something to read. The learner
  /// profile (child/adult mode) is a separate [LearnerProfiles] row created
  /// during onboarding — it is NOT set here.
  ///
  /// WS9.shims: renamed from [promoteToCloud]; shim label and [demoteToLocal]
  /// alias removed. The function is a real, permanent part of the sign-in path.
  Future<void> setCloudBornSessionFromFirebaseUser(AppUser firebaseUser) async {
    final dao = ref.read(userDatabaseProvider).userProfileDao;
    var profile = await dao.getUserProfileByFirebaseUid(firebaseUser.uid);
    if (profile == null) {
      // Create a placeholder cloud-born row so downstream code can read it.
      await dao.upsertProfile(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? '${firebaseUser.uid}@cloud.placeholder',
        displayName: firebaseUser.displayName ?? '',
        updatedAt: DateTimeFactory.nowUtc(),
      );
      profile = await dao.getUserProfileByFirebaseUid(firebaseUser.uid);
    }
    if (profile != null) {
      setCloudBornSession(profile: profile);
    }
  }
}
