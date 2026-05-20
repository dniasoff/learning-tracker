import 'package:learning_tracker/core/auth/auth_gateway_user.dart';

/// Thin facade around `FirebaseAuth`.
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

  // ── Email / password ─────────────────────────────────────────────────────

  /// Sign in with an existing email/password pair.
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Sign in with email/password and return the resulting user.
  ///
  /// Lower-level than [signInWithEmailAndPassword] — returns the user so
  /// callers (e.g. the upgrade-to-cloud flow) can read the UID immediately.
  Future<AuthGatewayUser?> signInAndGetUser({
    required String email,
    required String password,
  });

  /// Create a new email/password account.
  ///
  /// Returns the UID of the newly created user (or the already-existing user,
  /// per Firebase's "email-already-in-use" handling at the caller).
  Future<String> createUserWithEmailAndPassword({
    required String email,
    required String password,
  });

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

  /// Sign in using the deep-link email link the user tapped.
  Future<AuthGatewayUser?> signInWithEmailLink({
    required String email,
    required String emailLink,
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

  /// Sign out from Firebase Auth.
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

  /// Sign in by exchanging a Google [idToken] for Firebase credentials.
  Future<void> signInWithGoogleIdToken({required String? idToken});

  /// Link the Google account represented by [idToken] to the current user.
  Future<void> linkWithGoogleIdToken({required String? idToken});

  /// Re-authenticate the current user with Google [idToken] credentials.
  Future<void> reauthenticateWithGoogleIdToken({required String? idToken});

  /// Link an email/password credential to the currently signed-in user.
  Future<void> linkWithEmailAndPassword({
    required String email,
    required String password,
  });

  /// Provider IDs linked to the current user
  /// (e.g. `['password', 'google.com']`). Empty list if signed out.
  List<String> getLinkedProviders();
}
