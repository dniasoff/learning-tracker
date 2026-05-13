import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/auth/domain/models/app_user.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_providers.dart';
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
        final profile = await dao.findCloudBornByFirebaseUid(refreshed.uid);
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

  // ─── Transitional shims (delete after 20.6/20.7/20.9 rewrites) ──

  /// Legacy: called from the deprecated `sign_in_screen`,
  /// `signup_screen`, and magic-link providers. Keeps
  /// those files compiling; they will be removed in 20.6/20.7.
  Future<void> promoteToCloud(AppUser firebaseUser) async {
    final dao = ref.read(userDatabaseProvider).userProfileDao;
    var profile = await dao.getUserProfileByFirebaseUid(firebaseUser.uid);
    if (profile == null) {
      // Create a placeholder cloud-born row so downstream code can read it.
      await dao.upsertProfile(
        firebaseUid: firebaseUser.uid,
        email: firebaseUser.email ?? '${firebaseUser.uid}@cloud.placeholder',
        displayName: firebaseUser.displayName ?? '',
        userMode: 'adult',
        updatedAt: DateTimeFactory.nowUtc(),
      );
      profile = await dao.getUserProfileByFirebaseUid(firebaseUser.uid);
    }
    if (profile != null) {
      setCloudBornSession(profile: profile);
    }
  }

  /// Legacy: called from settings_screen sign-out.
  void demoteToLocal() => signOut();
}
