import 'package:learning_tracker/features/account/domain/models/app_user.dart';

/// The outcome of the Google account picker — no Firebase sign-in has
/// happened yet when this is returned (DNI-520).
class GoogleAccountPick {
  const GoogleAccountPick({required this.idToken, required this.email});

  /// OAuth ID token to sign a device account's named app in with. `null`
  /// means the platform returned no token: treat as a sign-in failure.
  final String? idToken;

  /// The picked Google account's email, when the platform reports one.
  final String? email;
}

/// Abstract interface for authentication operations.
///
/// **Named-app Auth only (parent AD-1 / AD-19, DNI-520).** An instance is
/// bound to one device account — the active account for
/// `authRepositoryProvider`, or any account via [forAccount] — and its
/// user-scoped calls ([currentUser], [signOut], [reloadCurrentUser], …) act
/// on THAT account's named-app Auth. Every sign-in method takes the target
/// `accountId` explicitly and authenticates that account's own named app,
/// once; nothing here touches the default app's `FirebaseAuth.instance`.
///
/// [AuthRepositoryImpl] delegates to the gateways in `lib/core/auth/`; no
/// caller imports the Firebase Auth SDK.
///
/// Methods throw appropriate exceptions on failure (e.g. Firebase throws
/// [PlatformException] sub-types; callers may catch [Exception] broadly).
abstract class AuthRepository {
  /// The device account this repository is bound to, or `null` (no active
  /// account: signed out; only account-free calls work).
  String? get accountId;

  /// The same repository bound to [accountId]'s named-app Auth instead —
  /// e.g. to check email verification for an account that has just signed
  /// in but is not active yet.
  AuthRepository forAccount(String accountId);

  // ── Sign-in on a named app (AD-1) ────────────────────────────────────────

  /// Signs in on [accountId]'s named app with email and password and
  /// returns the signed-in user.
  Future<AppUser> signInToAccountWithEmail(
    String accountId,
    String email,
    String password,
  );

  /// Shows the Google account picker and returns its ID token. Performs NO
  /// Firebase sign-in — pass the token to [signInToAccountWithGoogle].
  /// Throws `GoogleSignInException` on cancel/failure.
  Future<GoogleAccountPick> pickGoogleAccount();

  /// Silent (no-UI) variant of [pickGoogleAccount]: the last-authorized
  /// Google account only, or `null` when none is available. Never shows UI.
  Future<GoogleAccountPick?> pickGoogleAccountSilently();

  /// Signs in on [accountId]'s named app with a Google [idToken].
  Future<AppUser> signInToAccountWithGoogle(String accountId, String idToken);

  /// Signs in on [accountId]'s named app with an email sign-in link.
  Future<AppUser> signInToAccountWithEmailLink(
    String accountId,
    String email,
    String emailLink,
  );

  /// Cloud sign-up: creates the email/password user on [accountId]'s named
  /// app and sets its display name.
  Future<AppUser> createAccountWithEmail(
    String accountId,
    String email,
    String password,
    String displayName,
  );

  /// AD-19: an anonymous Auth session for a local/device-only account on
  /// its named app (no-op re-read when one already exists).
  Future<AppUser> ensureAnonymousSession(String accountId);

  /// Re-attaches to [accountId]'s persisted named-app session (works
  /// offline). `null` when that account has no session.
  Future<AppUser?> restoreSession(String accountId);

  /// Tears [accountId]'s named app down (a failed/abandoned sign-in on a
  /// freshly minted account id, or an account removed from the device).
  Future<void> discardAccountSession(String accountId);

  // ── Bound-account operations ─────────────────────────────────────────────

  /// Sends an email-verification link to the currently signed-in user.
  Future<void> sendEmailVerification();

  /// Sends a passwordless sign-in link to the given email address.
  Future<void> sendSignInLinkToEmail(String email);

  /// Checks whether the given [link] is a valid sign-in email link.
  bool isSignInWithEmailLink(String link);

  /// Sends a password reset email to the given address.
  Future<void> sendPasswordResetEmail(String email);

  /// Signs the bound account's named app out (and the Google session).
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

  /// AD-19 upgrade: links a Google account to the bound account's user via
  /// `AccountFirebase.linkCredential` — the uid is unchanged.
  Future<void> linkGoogleProvider();

  /// AD-19 upgrade: links an email/password credential to the bound
  /// account's user via `AccountFirebase.linkCredential` — the uid is
  /// unchanged.
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

  /// Return the current user's Firebase ID token, or `null` if nobody is
  /// signed in.
  ///
  /// AU-5: pass `forceRefresh: true` to bypass the SDK's local token cache
  /// and fetch a fresh JWT — the recovery primitive for a synced write that
  /// fails with `permission-denied`/`unauthenticated` against a stale
  /// cached token. See [FirebaseAuthGateway.getIdToken].
  Future<String?> getIdToken({bool forceRefresh = false});

  // ── Action-code operations (email verification) ─────────────────────────

  /// Checks the given [oobCode] action code. Throws on invalid/expired code.
  Future<void> checkActionCode(String oobCode);

  /// Applies the given [oobCode] action code (e.g. email verification).
  Future<void> applyActionCode(String oobCode);

  /// Updates the display name of the currently signed-in user.
  Future<void> updateDisplayName(String displayName);

  /// Deletes the Firebase account for [uid].
  ///
  /// Must be signed in as that user and recently authenticated.
  Future<void> deleteCurrentFirebaseUser();
}
