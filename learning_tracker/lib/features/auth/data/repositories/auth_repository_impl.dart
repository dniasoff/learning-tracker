import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:learning_tracker/features/auth/domain/models/app_user.dart';
import 'package:learning_tracker/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required FirebaseAuth firebaseAuth,
    required GoogleSignIn googleSignIn,
  }) : _firebaseAuth = firebaseAuth,
       _googleSignIn = googleSignIn;

  final FirebaseAuth _firebaseAuth;
  final GoogleSignIn _googleSignIn;
  bool _googleSignInInitialized = false;

  static const _packageName = 'com.jcom.torah.learning_tracker';
  static const _linkDomain = 'https://torah-study-tracker.firebaseapp.com';

  // ── Helpers ────────────────────────────────────────────────────────────────

  AppUser _toAppUser(User user) => AppUser(
    uid: user.uid,
    email: user.email,
    displayName: user.displayName,
    emailVerified: user.emailVerified,
    providers: user.providerData.map((i) => i.providerId).toList(),
  );

  /// Lazily initialize GoogleSignIn on first use.
  ///
  /// google_sign_in v7 requires initialize() before authenticate().
  /// Previously called at startup with no try/catch — crashed offline.
  /// Now deferred to first actual sign-in attempt.
  Future<void> _ensureGoogleSignInInitialized() async {
    if (_googleSignInInitialized) return;
    await _googleSignIn.initialize();
    _googleSignInInitialized = true;
  }

  // ── AuthRepository ─────────────────────────────────────────────────────────

  @override
  Future<void> signInWithEmail(String email, String password) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  @override
  Future<void> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<void> signUp(String email, String password, String displayName) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
  }

  @override
  Future<void> sendEmailVerification() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    await user.sendEmailVerification(
      ActionCodeSettings(
        url: '$_linkDomain/verify-email',
        handleCodeInApp: true,
        androidPackageName: _packageName,
        androidInstallApp: true,
      ),
    );
  }

  @override
  Future<void> sendSignInLinkToEmail(String email) {
    return _firebaseAuth.sendSignInLinkToEmail(
      email: email,
      actionCodeSettings: ActionCodeSettings(
        url: '$_linkDomain/sign-in',
        handleCodeInApp: true,
        androidPackageName: _packageName,
        androidInstallApp: true,
      ),
    );
  }

  @override
  Future<AppUser?> signInWithEmailLink(String email, String emailLink) async {
    final credential = await _firebaseAuth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
    final user = credential.user;
    return user == null ? null : _toAppUser(user);
  }

  @override
  bool isSignInWithEmailLink(String link) {
    return _firebaseAuth.isSignInWithEmailLink(link);
  }

  @override
  Future<void> sendPasswordResetEmail(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  @override
  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _firebaseAuth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    await user.delete();
  }

  @override
  Future<void> changePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated user found');
    }
    await user.updatePassword(newPassword);
  }

  @override
  Future<void> reauthenticateWithEmail(String email, String password) async {
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

  @override
  Future<void> reauthenticateWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await _firebaseAuth.currentUser?.reauthenticateWithCredential(credential);
  }

  @override
  Future<void> linkGoogleProvider() async {
    await _ensureGoogleSignInInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );
    await _firebaseAuth.currentUser?.linkWithCredential(credential);
  }

  @override
  Future<void> linkEmailProvider(String email, String password) async {
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await _firebaseAuth.currentUser?.linkWithCredential(credential);
  }

  @override
  List<String> getLinkedProviders() {
    return _firebaseAuth.currentUser?.providerData
            .map((info) => info.providerId)
            .toList() ??
        [];
  }

  @override
  Stream<AppUser?> onAuthStateChanged() {
    return _firebaseAuth.authStateChanges().map(
      (user) => user == null ? null : _toAppUser(user),
    );
  }

  // ── User state accessors ───────────────────────────────────────────────────

  @override
  AppUser? get currentUser {
    final user = _firebaseAuth.currentUser;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Future<AppUser?> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    await user.reload();
    final refreshed = _firebaseAuth.currentUser;
    return refreshed == null ? null : _toAppUser(refreshed);
  }

  // ── Action-code operations ─────────────────────────────────────────────────

  @override
  Future<void> checkActionCode(String oobCode) {
    return _firebaseAuth.checkActionCode(oobCode);
  }

  @override
  Future<void> applyActionCode(String oobCode) {
    return _firebaseAuth.applyActionCode(oobCode);
  }

  // ── Firebase low-level pass-throughs ──────────────────────────────────────

  @override
  Future<String> createUserAccount(String email, String password) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    return credential.user!.uid;
  }

  @override
  Future<AppUser?> signInAndGetUser(String email, String password) async {
    final credential = await _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = credential.user;
    return user == null ? null : _toAppUser(user);
  }

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _firebaseAuth.currentUser?.updateDisplayName(displayName);
  }

  @override
  Future<void> deleteCurrentFirebaseUser() async {
    final user = _firebaseAuth.currentUser;
    if (user != null) {
      await user.delete();
    }
  }
}
