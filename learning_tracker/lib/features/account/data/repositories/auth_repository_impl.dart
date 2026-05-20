import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/core/auth/google_sign_in_gateway.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';

/// Default [AuthRepository] implementation.
///
/// Delegates to the auth gateways in `lib/core/auth/`. Per layering rule 3,
/// this file MUST NOT import the firebase_auth SDK or the google_sign_in SDK
/// directly — the gateways own those.
class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required FirebaseAuthGateway firebaseAuthGateway,
    required GoogleSignInGateway googleSignInGateway,
  }) : _auth = firebaseAuthGateway,
       _google = googleSignInGateway;

  final FirebaseAuthGateway _auth;
  final GoogleSignInGateway _google;

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

  // ── AuthRepository ─────────────────────────────────────────────────────────

  @override
  Future<void> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  @override
  Future<void> signInWithGoogle() async {
    final result = await _google.authenticate();
    await _auth.signInWithGoogleIdToken(idToken: result.idToken);
  }

  @override
  Future<void> signUp(String email, String password, String displayName) async {
    await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await _auth.updateDisplayName(displayName);
  }

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
  Future<AppUser?> signInWithEmailLink(String email, String emailLink) async {
    final user = await _auth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
    return _toAppUserOrNull(user);
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
    final result = await _google.authenticate();
    await _auth.linkWithGoogleIdToken(idToken: result.idToken);
  }

  @override
  Future<void> linkEmailProvider(String email, String password) {
    return _auth.linkWithEmailAndPassword(email: email, password: password);
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

  // ── Action-code operations ─────────────────────────────────────────────────

  @override
  Future<void> checkActionCode(String oobCode) => _auth.checkActionCode(oobCode);

  @override
  Future<void> applyActionCode(String oobCode) => _auth.applyActionCode(oobCode);

  // ── Firebase low-level pass-throughs ──────────────────────────────────────

  @override
  Future<String> createUserAccount(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<AppUser?> signInAndGetUser(String email, String password) async {
    final user = await _auth.signInAndGetUser(
      email: email,
      password: password,
    );
    return _toAppUserOrNull(user);
  }

  @override
  Future<void> updateDisplayName(String displayName) =>
      _auth.updateDisplayName(displayName);

  @override
  Future<void> deleteCurrentFirebaseUser() async {
    if (_auth.currentUser == null) return;
    await _auth.deleteCurrentUser();
  }
}
