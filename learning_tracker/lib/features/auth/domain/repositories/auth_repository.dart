import 'package:learning_tracker/features/auth/domain/models/app_user.dart';

/// Abstract interface for authentication operations.
///
/// [AuthRepositoryImpl] is the sole file allowed to import the Firebase Auth
/// SDK. All callers must go through this interface.
///
/// Methods throw appropriate exceptions on failure (e.g. Firebase throws
/// [PlatformException] sub-types; callers may catch [Exception] broadly).
abstract class AuthRepository {
  /// Signs in with email and password.
  Future<void> signInWithEmail(String email, String password);

  /// Signs in with Google Sign-In.
  Future<void> signInWithGoogle();

  /// Creates a new account with email, password, and display name.
  Future<void> signUp(String email, String password, String displayName);

  /// Sends an email-verification link to the currently signed-in user.
  Future<void> sendEmailVerification();

  /// Sends a passwordless sign-in link to the given email address.
  Future<void> sendSignInLinkToEmail(String email);

  /// Signs in using the email link received via deep link.
  ///
  /// Returns the signed-in [AppUser].
  Future<AppUser?> signInWithEmailLink(String email, String emailLink);

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
  Stream<AppUser?> onAuthStateChanged();

  // ── User state accessors ─────────────────────────────────────────────────

  /// The currently signed-in user, or `null` if signed out.
  AppUser? get currentUser;

  /// Reload the current user's profile from Firebase and return the updated
  /// user, or `null` if nobody is signed in.
  Future<AppUser?> reloadCurrentUser();

  // ── Action-code operations (email verification) ─────────────────────────

  /// Checks the given [oobCode] action code. Throws on invalid/expired code.
  Future<void> checkActionCode(String oobCode);

  /// Applies the given [oobCode] action code (e.g. email verification).
  Future<void> applyActionCode(String oobCode);

  // ── Firebase low-level pass-throughs (upgrade flow) ─────────────────────

  /// Creates a Firebase account without setting a display name.
  ///
  /// Returns the UID of the newly created (or already-existing) user.
  /// Used by [UpgradeToCloudService]; prefer [signUp] for normal registration.
  Future<String> createUserAccount(String email, String password);

  /// Signs in with email + password and returns the resulting user.
  ///
  /// Lower-level than [signInWithEmail] — returns [AppUser?] for callers
  /// that need the UID (e.g. upgrade/collision flows).
  Future<AppUser?> signInAndGetUser(String email, String password);

  /// Updates the display name of the currently signed-in user.
  Future<void> updateDisplayName(String displayName);

  /// Deletes the Firebase account for [uid].
  ///
  /// Must be signed in as that user and recently authenticated.
  Future<void> deleteCurrentFirebaseUser();
}
