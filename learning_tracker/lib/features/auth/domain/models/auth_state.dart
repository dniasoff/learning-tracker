import 'package:learning_tracker/core/database/daos/user_profile_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

/// Hard-tier classification — set at signup, immutable except via the
/// one-way local → cloud upgrade flow (Epic 20 story 20.9).
typedef Tier = UserTier;

/// Session lifecycle state.
enum SessionStatus {
  /// App has not yet resolved the initial session (splash window).
  /// Must not hang — see 19.6 startup hardening.
  initializing,

  /// No user is signed in. Router should redirect to signup.
  signedOut,

  /// A user is signed in, regardless of tier or connectivity.
  signedIn,
}

/// Minimal user descriptor surfaced to the UI layer. Anything tier-
/// specific (passwordHash, firebaseUid) lives on the DB row, not here.
class AuthUser {
  const AuthUser({
    required this.profileId,
    required this.email,
    required this.displayName,
    required this.userMode,
    this.firebaseUid,
  });

  factory AuthUser.fromProfile(UserProfile profile) => AuthUser(
        profileId: profile.id,
        email: profile.email,
        displayName: profile.displayName,
        userMode: profile.userMode,
        firebaseUid: profile.firebaseUid,
      );

  final int profileId;
  final String email;
  final String displayName;
  final String userMode;
  final String? firebaseUid;
}

/// Unified auth state — one notifier holds identity, tier, and session
/// status. Replaces the sealed `AppAuthState` hierarchy from v1.
class AuthState {
  const AuthState({
    required this.currentUser,
    required this.tier,
    required this.sessionStatus,
  });

  const AuthState.initializing()
      : currentUser = null,
        tier = null,
        sessionStatus = SessionStatus.initializing;

  const AuthState.signedOut()
      : currentUser = null,
        tier = null,
        sessionStatus = SessionStatus.signedOut;

  const AuthState.signedIn({
    required AuthUser user,
    required Tier this.tier,
  })  : currentUser = user,
        sessionStatus = SessionStatus.signedIn;

  final AuthUser? currentUser;
  final Tier? tier;
  final SessionStatus sessionStatus;

  bool get isSignedIn => sessionStatus == SessionStatus.signedIn;
  bool get isInitializing => sessionStatus == SessionStatus.initializing;
  bool get isCloudBorn => tier == Tier.cloudBorn;
  bool get isLocalBorn => tier == Tier.localBorn;

  /// Display identifier for logs / fallback UI. Falls back to email
  /// when there's no display name, and to `'anon'` when signed out.
  String get displayIdentifier {
    final name = currentUser?.displayName;
    if (name != null && name.isNotEmpty) return name;
    return currentUser?.email ?? 'anon';
  }

  AuthState copyWith({
    AuthUser? currentUser,
    Tier? tier,
    SessionStatus? sessionStatus,
    bool clearUser = false,
    bool clearTier = false,
  }) {
    return AuthState(
      currentUser: clearUser ? null : (currentUser ?? this.currentUser),
      tier: clearTier ? null : (tier ?? this.tier),
      sessionStatus: sessionStatus ?? this.sessionStatus,
    );
  }
}
