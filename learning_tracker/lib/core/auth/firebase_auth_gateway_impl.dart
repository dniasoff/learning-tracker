import 'package:firebase_auth/firebase_auth.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';

/// Concrete [FirebaseAuthGateway].
///
/// **This is the only file in `lib/` outside `lib/core/sync/` permitted to
/// import `package:firebase_auth/firebase_auth.dart`.** The layering audit
/// (`make audit`, rule 1/15 — "No Firebase imports outside core/auth or
/// core/sync") enforces that invariant.
///
/// Methods are thin pass-throughs to [FirebaseAuth] / [User]. The only
/// non-trivial logic is mapping a [User] to the plain-Dart [AuthGatewayUser]
/// returned to callers — that mapping is the boundary that prevents Firebase
/// types from leaking out of `lib/core/auth/`.
class FirebaseAuthGatewayImpl implements FirebaseAuthGateway {
  FirebaseAuthGatewayImpl({FirebaseAuth? firebaseAuth})
    : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  AuthGatewayUser _toAppUser(User user) => AuthGatewayUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
    providers: _providerIds(user.providerData),
  );

  AuthGatewayUser? _toAppUserOrNull(User? user) =>
      user == null ? null : _toAppUser(user);

  /// Projects Firebase [UserInfo] entries to their `providerId` strings.
  ///
  /// The single source of truth for "what does 'linked providers' mean for
  /// this user" — shared by [_toAppUser] and [getLinkedProviders] so the two
  /// can never independently drift on the projection.
  List<String> _providerIds(Iterable<UserInfo> data) =>
      data.map((info) => info.providerId).toList();

  // ── Read-only accessors ──────────────────────────────────────────────────

  @override
  AuthGatewayUser? get currentUser =>
      _toAppUserOrNull(_firebaseAuth.currentUser);

  @override
  Stream<AuthGatewayUser?> authStateChanges() {
    return _firebaseAuth.authStateChanges().map(_toAppUserOrNull);
  }

  @override
  Future<AuthGatewayUser?> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    await user.reload();
    return _toAppUserOrNull(_firebaseAuth.currentUser);
  }

  // ── Email / password ─────────────────────────────────────────────────────

  @override
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<AuthGatewayUser?> signInAndGetUser({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    return _toAppUserOrNull(credential.user);
  }

  @override
  Future<String> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    return user.uid;
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _firebaseAuth.currentUser?.updateDisplayName(displayName);
  }

  // ── Magic links / verification ──────────────────────────────────────────

  @override
  Future<void> sendEmailVerification({
    required String continueUrl,
    required String androidPackageName,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    await user.sendEmailVerification(
      ActionCodeSettings(
        url: continueUrl,
        handleCodeInApp: true,
        androidPackageName: androidPackageName,
        androidInstallApp: true,
      ),
    );
  }

  @override
  Future<void> sendSignInLinkToEmail({
    required String email,
    required String continueUrl,
    required String androidPackageName,
  }) {
    return _firebaseAuth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: continueUrl,
        handleCodeInApp: true,
        androidPackageName: androidPackageName,
        androidInstallApp: true,
      ),
    );
  }

  @override
  Future<AuthGatewayUser?> signInWithEmailLink({
    required String email,
    required String emailLink,
  }) async {
    final credential = await _firebaseAuth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
    return _toAppUserOrNull(credential.user);
  }

  @override
  bool isSignInWithEmailLink(String link) {
    return _firebaseAuth.isSignInWithEmailLink(link);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  // ── Action codes ─────────────────────────────────────────────────────────

  @override
  Future<void> checkActionCode(String oobCode) {
    return _firebaseAuth.checkActionCode(oobCode);
  }

  @override
  Future<void> applyActionCode(String oobCode) {
    return _firebaseAuth.applyActionCode(oobCode);
  }

  // ── Account lifecycle ────────────────────────────────────────────────────

  @override
  Future<void> signOut() => _firebaseAuth.signOut();

  @override
  Future<void> deleteCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    await user.delete();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    await user.updatePassword(newPassword);
  }

  // ── Re-authentication ────────────────────────────────────────────────────

  @override
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  // ── Google credential plumbing ───────────────────────────────────────────

  @override
  Future<void> signInWithGoogleIdToken({required String? idToken}) async {
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> linkWithGoogleIdToken({required String? idToken}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.linkWithCredential(credential);
  }

  @override
  Future<void> reauthenticateWithGoogleIdToken({
    required String? idToken,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> linkWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.linkWithCredential(credential);
  }

  @override
  List<String> getLinkedProviders() {
    final providerData = _firebaseAuth.currentUser?.providerData;
    return providerData == null ? const <String>[] : _providerIds(providerData);
  }
}
