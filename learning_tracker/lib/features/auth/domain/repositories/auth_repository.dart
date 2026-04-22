import 'package:firebase_auth/firebase_auth.dart';

/// Abstract interface for authentication operations.
///
/// All methods throw [FirebaseAuthException] on failure.
abstract class AuthRepository {
  /// Signs in with email and password.
  Future<UserCredential> signInWithEmail(String email, String password);

  /// Signs in with Google Sign-In.
  Future<UserCredential> signInWithGoogle();

  /// Creates a new account with email, password, and display name.
  Future<UserCredential> signUp(
    String email,
    String password,
    String displayName,
  );

  /// Sends an email-verification link to the currently signed-in user.
  Future<void> sendEmailVerification();

  /// Sends a passwordless sign-in link to the given email address.
  Future<void> sendSignInLinkToEmail(String email);

  /// Signs in using the email link received via deep link.
  Future<UserCredential> signInWithEmailLink(String email, String emailLink);

  /// Checks whether the given [link] is a valid sign-in email link.
  bool isSignInWithEmailLink(String link);

  /// Sends a password reset email to the given address.
  Future<void> sendPasswordResetEmail(String email);

  /// Signs out the current user.
  Future<void> signOut();

  /// Deletes the current user's account.
  Future<void> deleteAccount();

  /// Changes the password for the current email/password user.
  ///
  /// Requires recent authentication; call [reauthenticateWithEmail] first.
  Future<void> changePassword(String newPassword);

  /// Re-authenticates the current user with email and password.
  ///
  /// Required before destructive operations (delete, password change).
  Future<void> reauthenticateWithEmail(String email, String password);

  /// Re-authenticates the current user with Google credentials.
  Future<void> reauthenticateWithGoogle();

  /// Links a Google account to the current email/password user.
  Future<void> linkGoogleProvider();

  /// Links an email/password credential to the current Google user.
  Future<void> linkEmailProvider(String email, String password);

  /// Returns the list of provider IDs linked to the current user.
  List<String> getLinkedProviders();

  /// Stream of auth state changes. Emits `null` when signed out.
  Stream<User?> authStateChanges();
}
