import 'package:firebase_auth/firebase_auth.dart';
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

/// Maps a Firebase [User] to the plain-Dart [AuthGatewayUser] — the
/// boundary that keeps Firebase types inside `lib/core/auth/` and
/// `lib/data/firestore/`. Shared with `AccountFirebaseAuthGateway`.
AuthGatewayUser authGatewayUserFromFirebase(User user) => AuthGatewayUser(
  uid: user.uid,
  email: user.email,
  displayName: user.displayName,
  emailVerified: user.emailVerified,
  providers: _providerIds(user.providerData),
);

/// Projects Firebase [UserInfo] entries to their `providerId` strings — the
/// single definition of "linked providers", shared by
/// [authGatewayUserFromFirebase] and
/// [FirebaseAuthGatewayImpl.getLinkedProviders].
List<String> _providerIds(Iterable<UserInfo> data) =>
    data.map((info) => info.providerId).toList();

/// Same check as `FirebaseAuth.isSignInWithEmailLink` (FlutterFire's
/// platform interface implements it as this pure string test), so it needs
/// no `FirebaseAuth` instance at all.
bool isFirebaseSignInEmailLink(String link) =>
    (link.contains('mode=signIn') || link.contains('mode%3DsignIn')) &&
    (link.contains('oobCode=') || link.contains('oobCode%3D'));

/// Concrete [FirebaseAuthGateway], bound to ONE account's named-app
/// `FirebaseAuth` (AD-1, DNI-520).
///
/// There is no default-app fallback: the gateway reads its `FirebaseAuth`
/// through the injected resolver (the active account's named app, from
/// `AccountFirebase.authFor`) and, when that is `null` (no account bound, or
/// its session not created yet in this process), behaves as signed out.
/// Account-free calls then use [accountFreeAuth] — the registry's
/// never-signed-in utility app. Nothing in this class signs a user in; that
/// is [AccountAuthGateway]'s job.
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
  /// [firebaseAuth] binds a fixed instance (tests); [resolveAuth] binds a
  /// live lookup (production: `AccountFirebase.authFor(accountId)`). With
  /// neither, the gateway is unbound and always signed out. [onSignOut]
  /// replaces the plain `FirebaseAuth.signOut()` so the registry can also
  /// drop its cached handles.
  FirebaseAuthGatewayImpl({
    FirebaseAuth? firebaseAuth,
    FirebaseAuth? Function()? resolveAuth,
    Future<FirebaseAuth> Function()? accountFreeAuth,
    Future<void> Function()? onSignOut,
  }) : _resolveAuth = resolveAuth ?? (() => firebaseAuth),
       _accountFreeAuth = accountFreeAuth,
       _onSignOut = onSignOut;

  final FirebaseAuth? Function() _resolveAuth;
  final Future<FirebaseAuth> Function()? _accountFreeAuth;
  final Future<void> Function()? _onSignOut;

  FirebaseAuth? get _auth => _resolveAuth();

  /// The bound account's Auth, else the utility app's, for calls that need
  /// an Auth instance but no signed-in user.
  Future<FirebaseAuth> _authForAccountFreeCall() async {
    final bound = _auth;
    if (bound != null) return bound;
    final fallback = _accountFreeAuth;
    if (fallback == null) throw const NotAuthenticatedException();
    return fallback();
  }

  User _requireUser() {
    final user = _auth?.currentUser;
    if (user == null) throw const NotAuthenticatedException();
    return user;
  }

  AuthGatewayUser? _toAppUserOrNull(User? user) =>
      user == null ? null : authGatewayUserFromFirebase(user);

  // ── Read-only accessors ──────────────────────────────────────────────────

  @override
  AuthGatewayUser? get currentUser => _toAppUserOrNull(_auth?.currentUser);

  @override
  Stream<AuthGatewayUser?> authStateChanges() {
    final auth = _auth;
    if (auth == null) return Stream<AuthGatewayUser?>.value(null);
    return auth.authStateChanges().map(_toAppUserOrNull);
  }

  @override
  Future<AuthGatewayUser?> reloadCurrentUser() async {
    final user = _auth?.currentUser;
    if (user == null) return null;
    await user.reload();
    return _toAppUserOrNull(_auth?.currentUser);
  }

  @override
  Future<String?> getIdToken({bool forceRefresh = false}) {
    final user = _auth?.currentUser;
    if (user == null) return Future.value(null);
    return user.getIdToken(forceRefresh);
  }

  // ── Email / password ─────────────────────────────────────────────────────

  @override
  Future<void> updateDisplayName(String displayName) async {
    await _auth?.currentUser?.updateDisplayName(displayName);
  }

  // ── Magic links / verification ──────────────────────────────────────────

  @override
  Future<void> sendEmailVerification({
    required String continueUrl,
    required String androidPackageName,
  }) async {
    final user = _requireUser();
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
  }) async {
    final auth = await _authForAccountFreeCall();
    return auth.sendSignInLinkToEmail(
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
  bool isSignInWithEmailLink(String link) => isFirebaseSignInEmailLink(link);

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    final auth = await _authForAccountFreeCall();
    return auth.sendPasswordResetEmail(email: email);
  }

  // ── Action codes ─────────────────────────────────────────────────────────

  @override
  Future<void> checkActionCode(String oobCode) async {
    final auth = await _authForAccountFreeCall();
    await auth.checkActionCode(oobCode);
  }

  @override
  Future<void> applyActionCode(String oobCode) async {
    final auth = await _authForAccountFreeCall();
    return auth.applyActionCode(oobCode);
  }

  // ── Account lifecycle ────────────────────────────────────────────────────

  @override
  Future<void> signOut() async {
    final onSignOut = _onSignOut;
    if (onSignOut != null) return onSignOut();
    await _auth?.signOut();
  }

  @override
  Future<void> deleteCurrentUser() async {
    final user = _requireUser();
    await user.delete();
  }

  @override
  Future<void> updatePassword(String newPassword) async {
    final user = _requireUser();
    await user.updatePassword(newPassword);
  }

  // ── Re-authentication ────────────────────────────────────────────────────

  @override
  Future<void> reauthenticateWithEmail({
    required String email,
    required String password,
  }) async {
    final user = _requireUser();
    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  // ── Google credential plumbing ───────────────────────────────────────────

  @override
  Future<void> reauthenticateWithGoogleIdToken({
    required String? idToken,
  }) async {
    final user = _requireUser();
    final credential = GoogleAuthProvider.credential(idToken: idToken);
    await user.reauthenticateWithCredential(credential);
  }

  @override
  List<String> getLinkedProviders() {
    final providerData = _auth?.currentUser?.providerData;
    return providerData == null ? const <String>[] : _providerIds(providerData);
  }
}
