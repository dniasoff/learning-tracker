import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';

/// Thrown by [FirebaseAuthGatewayImpl] when an operation requires a
/// signed-in user but `FirebaseAuth.currentUser` is null.
///
/// Every call site is a precondition guard: the UI only exposes these
/// operations from screens already gated behind an active session, so a real
/// occurrence is a race (expired/revoked session, e.g. between navigation and
/// the async call landing) rather than a normal user-facing outcome. That is
/// why this extends [InternalException] — "unexpected internal state,
/// should never be shown in the UI" — rather than [PermissionException]:
/// per EH-5, presentation must resolve a stable code/category through
/// `AppLocalizations`/`AppErrorView` rather than render [message]
/// (developer-facing, English-only, for logs/Crashlytics only). A single
/// category is sufficient signal here — there is exactly one failure mode,
/// so a leaf-specific enum (like `ValidationErrorCode`) isn't warranted.
///
/// Replaces the untyped `StateError('No authenticated user found')`
/// previously thrown from every precondition guard in this file
/// (AUD-core-auth-03).
class NotAuthenticatedException extends InternalException {
  const NotAuthenticatedException()
    : super('No authenticated user found: FirebaseAuth.currentUser is null');
}

/// The default (non-named) app's `FirebaseAuth` singleton.
///
/// **Phase 1 (AD-1/AD-2) status.** Same rationale as
/// `core/sync/providers/firestore_instance_provider.dart`'s
/// `_defaultFirestoreInstance`: this is the pre-registry, single-instance
/// auth path the migration-plan Phase 1 rollback contract keeps present
/// "until Phase 6". [FirebaseAuthGatewayImpl]'s injection-seam default
/// (`firebaseAuth ?? ...`) calls this — and only this — so the AD-2/AD-28
/// bare-instance ratchet counts exactly one `FirebaseAuth.instance` site in
/// this file.
FirebaseAuth _defaultFirebaseAuth() => FirebaseAuth.instance;

/// [Provider] wrapper around [_defaultFirebaseAuth], so
/// `lib/data/firestore/account_firebase_providers.dart`'s feature-flag
/// (registry vs. legacy single-instance) shim can reuse this SAME
/// resolution instead of typing a second `FirebaseAuth.instance` literal
/// elsewhere in `lib/` — see that file's `accountFirebaseRegistryEnabledProvider`
/// doc for the flag contract.
final firebaseAuthInstanceProvider = Provider<FirebaseAuth>((ref) {
  return _defaultFirebaseAuth();
});

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
    : _firebaseAuth = firebaseAuth ?? _defaultFirebaseAuth();

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

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) {
    final user = _firebaseAuth.currentUser;
    if (user == null) return Future.value(null);
    return user.getIdToken(forceRefresh);
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
      throw const NotAuthenticatedException();
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
      throw const NotAuthenticatedException();
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
      throw const NotAuthenticatedException();
    }
    await user.delete();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw const NotAuthenticatedException();
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
      throw const NotAuthenticatedException();
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
      throw const NotAuthenticatedException();
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
      throw const NotAuthenticatedException();
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
      throw const NotAuthenticatedException();
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
