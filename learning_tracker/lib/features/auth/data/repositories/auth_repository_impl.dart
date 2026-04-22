import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  @override
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

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

  @override
  Future<UserCredential> signInWithGoogle() async {
    await _ensureGoogleSignInInitialized();
    final googleUser = await _googleSignIn.authenticate();
    final googleAuth = googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    return _firebaseAuth.signInWithCredential(credential);
  }

  @override
  Future<UserCredential> signUp(
    String email,
    String password,
    String displayName,
  ) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    await credential.user?.updateDisplayName(displayName);
    return credential;
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
  Future<UserCredential> signInWithEmailLink(String email, String emailLink) {
    return _firebaseAuth.signInWithEmailLink(
      email: email,
      emailLink: emailLink,
    );
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
  Stream<User?> authStateChanges() {
    return _firebaseAuth.authStateChanges();
  }
}
