import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:learning_tracker/core/domain/value_objects/account_tier.dart';
import 'package:learning_tracker/features/account/domain/models/account_entity.dart';

part 'auth_state.freezed.dart';

/// Hard-tier classification — set at signup, immutable except via the
/// one-way local → cloud upgrade flow (Epic 20 story 20.9).
///
/// Re-pointed from the deleted Drift `UserTier` to [AccountTier], the live
/// tier enum (`core/domain/value_objects/account_tier.dart`): [Tier.cloud]
/// = created with email/Firebase credentials, [Tier.local] = created
/// offline, device-only. Storage keys remain `'cloudBorn'`/`'localBorn'`.
typedef Tier = AccountTier;

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
///
/// WS9.flows: [userMode] field removed — mode belongs to [LearnerProfiles],
/// not to an [Account]. Use [dashboardUserModeProvider] (which reads
/// [learner_profiles.mode]) to gate child-only UI.
///
/// AUD-account-22: @freezed for generated value equality (single
/// constructor shape — mirrors the `ProfileModel.fromDriftRow` pattern, no
/// call-site breakage).
@freezed
abstract class AuthUser with _$AuthUser {
  const factory AuthUser({
    /// The account's uid — the Firestore `users/{uid}` doc-id / Firebase uid
    /// for cloud-born accounts, the device-registry `accountId` for
    /// credential-less local-born accounts (which have no Firebase uid).
    ///
    /// Replaced the deleted Drift `profileId` int FK: identity is a String
    /// everywhere in the Firestore world (uid / ULID / doc-id) — see
    /// [AccountEntity] and [LearnerProfileEntity].
    required String uid,
    required String email,
    required String displayName,
    String? firebaseUid,
  }) = _AuthUser;

  const AuthUser._();

  /// Builds the UI descriptor from the Firestore account record.
  ///
  /// For cloud-born accounts the account uid IS the Firebase uid, so
  /// [firebaseUid] and [uid] coincide. Local-born (credential-less) accounts
  /// have no Firestore document and are built from the device registry row
  /// instead (see `auth_state_provider.dart`).
  factory AuthUser.fromAccount(AccountEntity account) => AuthUser(
    uid: account.uid,
    email: account.email ?? '',
    displayName: account.displayName,
    firebaseUid: account.uid,
  );
}

/// Unified auth state — one notifier holds identity, tier, and session
/// status. Replaces the sealed `AppAuthState` hierarchy from v1.
///
/// AUD-account-22: hand-rolled value `==`/`hashCode` rather than `@freezed`.
/// Unlike [AuthUser]/`AppUser` (same finding, converted to `@freezed`
/// cleanly), this class exposes three *named `const` constructors sharing
/// one flat field shape* (`initializing()`/`signedOut()`/`signedIn(...)`)
/// used with the `const` keyword at 60+ call sites across features well
/// beyond `features/account` (profiles, settings, tutoring, onboarding).
/// `@freezed`'s multi-constructor support models genuine sum-type *unions*
/// (each variant gets its own field set and generated subclass) — bending
/// it to reproduce three fixed-value presets of ONE shape would either
/// drop `const`-constructibility everywhere (real, cross-feature call-site
/// breakage — the AC this fix must not cause) or require a full sealed-type
/// redesign (new getter model, `copyWith` semantics change) well beyond
/// this finding's low-risk recommendation. The finding's own recommendation
/// explicitly sanctions "at minimum implement value ==/hashCode" as the
/// low-risk alternative; that is what this class does. (This mirrors the
/// existing, unflagged `ProfileSession` pattern in
/// `features/profiles/domain/models/profile_session.dart`.)
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

  const AuthState.signedIn({required AuthUser user, required this.tier})
    : currentUser = user,
      sessionStatus = SessionStatus.signedIn;

  final AuthUser? currentUser;
  final Tier? tier;
  final SessionStatus sessionStatus;

  bool get isSignedIn => sessionStatus == SessionStatus.signedIn;
  bool get isInitializing => sessionStatus == SessionStatus.initializing;
  bool get isCloudBorn => tier == Tier.cloud;
  bool get isLocalBorn => tier == Tier.local;

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

  // AUD-account-22: value equality — see the class doc comment for why this
  // is hand-rolled rather than @freezed-generated. [currentUser] now carries
  // real value equality itself ([AuthUser] is @freezed), so two AuthState
  // instances describing the same signed-in identity compare equal here too.
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthState &&
          runtimeType == other.runtimeType &&
          currentUser == other.currentUser &&
          tier == other.tier &&
          sessionStatus == other.sessionStatus;

  @override
  int get hashCode => Object.hash(currentUser, tier, sessionStatus);

  @override
  String toString() =>
      'AuthState(currentUser: $currentUser, tier: $tier, '
      'sessionStatus: $sessionStatus)';
}
