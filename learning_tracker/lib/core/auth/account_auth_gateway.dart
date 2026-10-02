import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';

/// The ONLY way the app authenticates (parent AD-1 / AD-19, DNI-520).
///
/// Every call names the device-registry account it acts on, and runs on
/// that account's own named `FirebaseApp` (`AccountFirebase`,
/// `lib/data/firestore/account_firebase.dart`). Nothing here — and nothing
/// anywhere else in `lib/` — signs in on the default app, so each sign-in
/// is a single sign-in: there is no "default app first, named app second"
/// double sign-in to keep in step.
///
/// Plain Dart types only ([AuthGatewayUser], `String`), the same boundary as
/// [FirebaseAuthGateway]: callers outside `lib/core/auth/` and
/// `lib/data/firestore/` never see a `firebase_auth` type. The production
/// implementation is `AccountFirebaseAuthGateway`
/// (`lib/data/firestore/account_firebase_auth_gateway.dart`).
abstract interface class AccountAuthGateway {
  /// A [FirebaseAuthGateway] bound to [accountId]'s named-app Auth: it reads
  /// and manages the user signed in THERE. With a `null` [accountId] (no
  /// active account) it behaves as signed out, and its account-free calls
  /// (password reset, sign-in-link checks, action codes) run on the
  /// registry's never-signed-in utility app.
  FirebaseAuthGateway gatewayFor(String? accountId);

  /// Re-attaches to [accountId]'s persisted named-app session (local, works
  /// offline) and returns its signed-in user, or `null` when that account
  /// has no session to re-attach to. Never signs anyone in.
  Future<AuthGatewayUser?> restoreSession(String accountId);

  /// Signs in on [accountId]'s named app with an email/password pair.
  Future<AuthGatewayUser> signInWithEmail(
    String accountId, {
    required String email,
    required String password,
  });

  /// Signs in on [accountId]'s named app with a Google [idToken] obtained
  /// from the Google picker (no Firebase sign-in happens before this).
  Future<AuthGatewayUser> signInWithGoogleIdToken(
    String accountId, {
    required String idToken,
  });

  /// Signs in on [accountId]'s named app with an email sign-in (magic) link.
  Future<AuthGatewayUser> signInWithEmailLink(
    String accountId, {
    required String email,
    required String emailLink,
  });

  /// Creates a new email/password Firebase user on [accountId]'s named app
  /// (cloud sign-up) and sets its [displayName].
  Future<AuthGatewayUser> createUserWithEmail(
    String accountId, {
    required String email,
    required String password,
    required String displayName,
  });

  /// AD-19: gives [accountId] (a local/device-only account) an anonymous
  /// Auth session on its named app via `AccountFirebase.createAnonymousAccount`.
  /// A no-op re-read when the app is already signed in; needs the network
  /// only the first time.
  Future<AuthGatewayUser> ensureAnonymousSession(String accountId);

  /// AD-19 upgrade: links an email/password credential onto [accountId]'s
  /// signed-in user via `AccountFirebase.linkCredential`. The uid — and so
  /// every `users/{uid}/…` path — is unchanged.
  Future<AuthGatewayUser> linkEmail(
    String accountId, {
    required String email,
    required String password,
  });

  /// AD-19 upgrade with a Google [idToken]; same uid guarantee as
  /// [linkEmail].
  Future<AuthGatewayUser> linkGoogleIdToken(
    String accountId, {
    required String idToken,
  });

  /// Signs [accountId]'s named app out (the app and its cache stay alive).
  Future<void> signOut(String accountId);

  /// Tears [accountId]'s named app down completely (e.g. a sign-in attempt
  /// that minted a fresh account id and then failed, or an account removed
  /// from the device). Safe on an id with no session.
  Future<void> discard(String accountId);
}
