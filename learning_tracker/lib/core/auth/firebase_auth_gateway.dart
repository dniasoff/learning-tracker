import 'package:learning_tracker/core/auth/account_auth_gateway.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';

/// Thin facade around ONE account's named-app `FirebaseAuth` (AD-1).
///
/// **Sign-in is not on this interface (DNI-520).** Every sign-in, sign-up
/// and credential link goes through [AccountAuthGateway] with an explicit
/// device-account id, so it can only ever authenticate that account's own
/// named app — never the default app, and never twice. An instance of this
/// interface is bound to one account (see [AccountAuthGateway.gatewayFor])
/// and only reads or manages the user already signed in there. With no
/// account bound it behaves as signed out; its account-free calls (password
/// reset, action codes) then run on the never-signed-in utility app.
///
/// **This is the public seam between the rest of the app and the Firebase
/// Auth SDK.** Production code outside `lib/core/auth/` and `lib/core/sync/`
/// MUST NOT import `package:firebase_auth/firebase_auth.dart`; callers consume
/// auth via this interface instead.
///
/// The concrete implementation lives in
/// `lib/core/auth/firebase_auth_gateway_impl.dart` and is the sole importer
/// of `firebase_auth`.
///
/// All methods return plain Dart types ([AuthGatewayUser], `String`, `bool`,
/// `void`) — never `User`, `UserCredential`, or other Firebase types.
abstract class FirebaseAuthGateway {
  // ── Read-only accessors ──────────────────────────────────────────────────

  /// The currently signed-in user, or `null` if signed out.
  AuthGatewayUser? get currentUser;

  /// Stream of auth-state changes. Emits `null` when signed out.
  Stream<AuthGatewayUser?> authStateChanges();

  /// Reload the current user's profile from Firebase and return the refreshed
  /// snapshot, or `null` if nobody is signed in.
  Future<AuthGatewayUser?> reloadCurrentUser();

  /// Return the current user's Firebase ID token, or `null` if nobody is
  /// signed in.
  ///
  /// AU-5: pass `forceRefresh: true` to bypass the SDK's local token cache
  /// and fetch a fresh JWT from the Firebase Auth backend — the primitive a
  /// synced write needs after a `permission-denied`/`unauthenticated`
  /// failure, since a cached token can be stale (e.g. after a custom-claims
  /// change) without the app ever having been signed out. Unlike
  /// [reloadCurrentUser] — which only refreshes profile fields such as
  /// `displayName`/`emailVerified` and never touches the cached JWT/claims —
  /// this is the only way to force a claims-bearing token refresh.
  Future<String?> getIdToken({bool forceRefresh = false});

  // ── Email / password ─────────────────────────────────────────────────────

  /// Update the display name on the currently signed-in user.
  Future<void> updateDisplayName(String displayName);

  // ── Magic links / verification ──────────────────────────────────────────

  /// Send an email-verification link to the currently signed-in user.
  ///
  /// [continueUrl] is the deep-link target the email should bounce the user
  /// back to once they click "verify".
  Future<void> sendEmailVerification({
    required String continueUrl,
    required String androidPackageName,
  });

  /// Send a passwordless sign-in link to [email].
  Future<void> sendSignInLinkToEmail({
    required String email,
    required String continueUrl,
    required String androidPackageName,
  });

  /// Whether [link] is a valid Firebase sign-in email link.
  bool isSignInWithEmailLink(String link);

  /// Send a password-reset email to [email].
  Future<void> sendPasswordResetEmail(String email);

  // ── Action codes ─────────────────────────────────────────────────────────

  /// Validate the given out-of-band [oobCode]. Throws on invalid/expired.
  Future<void> checkActionCode(String oobCode);

  /// Apply the given out-of-band [oobCode] (e.g. consume email verification).
  Future<void> applyActionCode(String oobCode);

  // ── Account lifecycle ────────────────────────────────────────────────────

  /// Sign this account's named app out of Firebase Auth.
  Future<void> signOut();

  /// Delete the currently signed-in user's account.
  ///
  /// Requires recent authentication — re-authenticate first via
  /// [reauthenticateWithEmail] or [reauthenticateWithGoogleIdToken].
  Future<void> deleteCurrentUser();

  /// Update the current user's password.
  ///
  /// Requires recent authentication.
  Future<void> updatePassword(String newPassword);

  // ── Re-authentication ────────────────────────────────────────────────────

  /// Re-authenticate the current user with email/password credentials.
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  });

  // ── Google credential plumbing ───────────────────────────────────────────

  /// Re-authenticate the current user with Google [idToken] credentials.
  Future<void> reauthenticateWithGoogleIdToken({required String? idToken});

  /// Provider IDs linked to the current user
  /// (e.g. `['password', 'google.com']`). Empty list if signed out.
  List<String> getLinkedProviders();
}
