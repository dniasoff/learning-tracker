import 'package:learning_tracker/core/auth/account_auth_gateway.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart'
    show NotAuthenticatedException;
import 'package:learning_tracker/core/auth/google_sign_in_gateway.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';

/// Default [AuthRepository] implementation.
///
/// Delegates to the auth gateways in `lib/core/auth/`. Per layering rule 3,
/// this file MUST NOT import the firebase_auth SDK or the google_sign_in SDK
/// directly — the gateways own those.
///
/// Bound to [accountId]: user-scoped calls go through
/// `AccountAuthGateway.gatewayFor(accountId)` (that account's named-app
/// Auth), and every sign-in names its target account (DNI-520).
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required AccountAuthGateway accountAuthGateway,
    required GoogleSignInGateway googleSignInGateway,
    this.accountId,
    FirebaseAuthGateway? firebaseAuthGateway,
  }) : _accounts = accountAuthGateway,
       _google = googleSignInGateway,
       _auth = firebaseAuthGateway ?? accountAuthGateway.gatewayFor(accountId);

  final AccountAuthGateway _accounts;
  final GoogleSignInGateway _google;
  final FirebaseAuthGateway _auth;

  @override
  final String? accountId;

  static const _packageName = 'com.jcom.torah.learning_tracker';
  static const _linkDomain = 'https://torah-study-tracker.firebaseapp.com';

  // ── Helpers ────────────────────────────────────────────────────────────────

  AppUser _toAppUser(AuthGatewayUser user) => AppUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
    providers: user.providers,
  );

  AppUser? _toAppUserOrNull(AuthGatewayUser? user) =>
      user == null ? null : _toAppUser(user);

  String _requireAccountId() {
    final id = accountId;
    if (id == null) throw const NotAuthenticatedException();
    return id;
  }

  // ── Binding ────────────────────────────────────────────────────────────────

  @override
  AuthRepository forAccount(String accountId) => AuthRepositoryImpl(
    accountAuthGateway: _accounts,
    googleSignInGateway: _google,
    accountId: accountId,
  );

  // ── Sign-in on a named app ─────────────────────────────────────────────────

  @override
  Future<AppUser> signInToAccountWithEmail(
    String accountId,
    String email,
    String password,
  ) async => _toAppUser(
    await _accounts.signInWithEmail(
      accountId,
      email: email,
      password: password,
    ),
  );

  @override
  Future<GoogleAccountPick> pickGoogleAccount() async {
    final result = await _google.authenticate();
    return GoogleAccountPick(idToken: result.idToken, email: result.email);
  }

  @override
  Future<GoogleAccountPick?> pickGoogleAccountSilently() async {
    // Only the last-authorized Google account can be resolved silently — a
    // cross-account switch to a not-cached account yields null (or another
    // account) and needs the interactive picker.
    final result = await _google.authenticateSilently();
    if (result?.idToken == null) return null;
    return GoogleAccountPick(idToken: result!.idToken, email: result.email);
  }

  @override
  Future<AppUser> signInToAccountWithGoogle(
    String accountId,
    String idToken,
  ) async => _toAppUser(
    await _accounts.signInWithGoogleIdToken(accountId, idToken: idToken),
  );

  @override
  Future<AppUser> signInToAccountWithEmailLink(
    String accountId,
    String email,
    String emailLink,
  ) async => _toAppUser(
    await _accounts.signInWithEmailLink(
      accountId,
      email: email,
      emailLink: emailLink,
    ),
  );

  @override
  Future<AppUser> createAccountWithEmail(
    String accountId,
    String email,
    String password,
    String displayName,
  ) async => _toAppUser(
    await _accounts.createUserWithEmail(
      accountId,
      email: email,
      password: password,
      displayName: displayName,
    ),
  );

  @override
  Future<AppUser> ensureAnonymousSession(String accountId) async =>
      _toAppUser(await _accounts.ensureAnonymousSession(accountId));

  @override
  Future<AppUser?> restoreSession(String accountId) async =>
      _toAppUserOrNull(await _accounts.restoreSession(accountId));

  @override
  Future<void> discardAccountSession(String accountId) =>
      _accounts.discard(accountId);

  // ── Bound-account operations ───────────────────────────────────────────────

  @override
  Future<void> sendEmailVerification() {
    return _auth.sendEmailVerification(
      continueUrl: '$_linkDomain/verify-email',
      androidPackageName: _packageName,
    );
  }

  @override
  Future<void> sendSignInLinkToEmail(String email) {
    return _auth.sendSignInLinkToEmail(
      email: email,
      continueUrl: '$_linkDomain/sign-in',
      androidPackageName: _packageName,
    );
  }

  @override
  bool isSignInWithEmailLink(String link) => _auth.isSignInWithEmailLink(link);

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email);
  }

  @override
  Future<void> signOut() async {
    await _google.signOut();
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() => _auth.deleteCurrentUser();

  @override
  Future<void> changePassword(String newPassword) =>
      _auth.updatePassword(newPassword);

  @override
  Future<void> reauthenticateWithEmail(String email, String password) {
    return _auth.reauthenticateWithEmail(email: email, password: password);
  }

  @override
  Future<void> reauthenticateWithGoogle() async {
    final result = await _google.authenticate();
    await _auth.reauthenticateWithGoogleIdToken(idToken: result.idToken);
  }

  @override
  Future<void> linkGoogleProvider() async {
    final id = _requireAccountId();
    final result = await _google.authenticate();
    final idToken = result.idToken;
    if (idToken == null) throw const NotAuthenticatedException();
    await _accounts.linkGoogleIdToken(id, idToken: idToken);
  }

  @override
  Future<void> linkEmailProvider(String email, String password) async {
    final id = _requireAccountId();
    await _accounts.linkEmail(id, email: email, password: password);
  }

  @override
  List<String> getLinkedProviders() => _auth.getLinkedProviders();

  @override
  Stream<AppUser?> onAuthStateChanged() {
    return _auth.authStateChanges().map(_toAppUserOrNull);
  }

  // ── User state accessors ───────────────────────────────────────────────────

  @override
  AppUser? get currentUser => _toAppUserOrNull(_auth.currentUser);

  @override
  Future<AppUser?> reloadCurrentUser() async {
    final refreshed = await _auth.reloadCurrentUser();
    return _toAppUserOrNull(refreshed);
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) =>
      _auth.getIdToken(forceRefresh: forceRefresh);

  // ── Action-code operations ─────────────────────────────────────────────────

  @override
  Future<void> checkActionCode(String oobCode) =>
      _auth.checkActionCode(oobCode);

  @override
  Future<void> applyActionCode(String oobCode) =>
      _auth.applyActionCode(oobCode);

  @override
  Future<void> updateDisplayName(String displayName) =>
      _auth.updateDisplayName(displayName);

  @override
  Future<void> deleteCurrentFirebaseUser() async {
    if (_auth.currentUser == null) return;
    await _auth.deleteCurrentUser();
  }
}
