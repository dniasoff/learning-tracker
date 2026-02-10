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

  /// Sends a passwordless sign-in link to the given email address.
  Future<void> sendSignInLinkToEmail(String email);

  /// Signs in using the email link received via deep link.
  Future<UserCredential> signInWithEmailLink(String email, String emailLink);

  /// Checks whether the given [link] is a valid sign-in email link.
  bool isSignInWithEmailLink(String link);

  /// Signs out the current user.
  Future<void> signOut();

  /// Deletes the current user's account.
  Future<void> deleteAccount();

  /// Stream of auth state changes. Emits `null` when signed out.
  Stream<User?> authStateChanges();
}
