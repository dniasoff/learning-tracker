/// Production [AccountAuthGateway]: every sign-in, sign-up, anonymous
/// session and credential link runs on the named app [AccountFirebase] owns
/// for that device account (parent AD-1 / AD-19, DNI-520).
library;

import 'package:learning_tracker/core/auth/account_auth_gateway.dart';
import 'package:learning_tracker/core/auth/auth_gateway_user.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';

/// [AccountAuthGateway] over the [AccountFirebase] registry.
///
/// The registry methods return [AccountFirebaseHandles]; the signed-in
/// [User] is read back from that bundle's own named-app Auth and mapped to a
/// plain [AuthGatewayUser] here, so no Firebase type leaves this file.
class AccountFirebaseAuthGateway implements AccountAuthGateway {
  AccountFirebaseAuthGateway(this._registry);

  final AccountFirebase _registry;

  @override
  FirebaseAuthGateway gatewayFor(String? accountId) {
    if (accountId == null) {
      return FirebaseAuthGatewayImpl(accountFreeAuth: _registry.utilityAuth);
    }
    return FirebaseAuthGatewayImpl(
      resolveAuth: () => _registry.authFor(accountId),
      accountFreeAuth: _registry.utilityAuth,
      onSignOut: () => _registry.signOut(accountId),
    );
  }

  @override
  Future<AuthGatewayUser?> restoreSession(String accountId) async {
    try {
      return _userOf(await _registry.resolve(accountId));
    } on AccountNotAuthenticatedException {
      return null;
    }
  }

  @override
  Future<AuthGatewayUser> signInWithEmail(
    String accountId, {
    required String email,
    required String password,
  }) async => _userOf(
    await _registry.signInCloudAccountWithEmail(
      accountId,
      email: email,
      password: password,
    ),
  );

  @override
  Future<AuthGatewayUser> signInWithGoogleIdToken(
    String accountId, {
    required String idToken,
  }) async => _userOf(
    await _registry.signInCloudAccountWithGoogleIdToken(
      accountId,
      idToken: idToken,
    ),
  );

  @override
  Future<AuthGatewayUser> signInWithEmailLink(
    String accountId, {
    required String email,
    required String emailLink,
  }) async => _userOf(
    await _registry.signInCloudAccountWithEmailLink(
      accountId,
      email: email,
      emailLink: emailLink,
    ),
  );

  @override
  Future<AuthGatewayUser> createUserWithEmail(
    String accountId, {
    required String email,
    required String password,
    required String displayName,
  }) async {
    final handles = await _registry.createCloudAccountWithEmail(
      accountId,
      email: email,
      password: password,
    );
    await handles.auth.currentUser?.updateDisplayName(displayName);
    return _userOf(handles);
  }

  @override
  Future<AuthGatewayUser> ensureAnonymousSession(String accountId) async =>
      _userOf(await _registry.createAnonymousAccount(accountId));

  @override
  Future<AuthGatewayUser> linkEmail(
    String accountId, {
    required String email,
    required String password,
  }) async {
    await _registry.resolve(accountId);
    return _userOf(
      await _registry.linkEmailCredential(
        accountId,
        email: email,
        password: password,
      ),
    );
  }

  @override
  Future<AuthGatewayUser> linkGoogleIdToken(
    String accountId, {
    required String idToken,
  }) async {
    await _registry.resolve(accountId);
    return _userOf(
      await _registry.linkGoogleIdToken(accountId, idToken: idToken),
    );
  }

  @override
  Future<void> signOut(String accountId) => _registry.signOut(accountId);

  @override
  Future<void> discard(String accountId) => _registry.dispose(accountId);

  /// The user signed in on [handles]' named app, mapped to plain Dart.
  ///
  /// The bundle's uid comes from that same user, so a missing user here is
  /// an invariant breach (the session was signed out between the registry
  /// call returning and this read), reported as such.
  AuthGatewayUser _userOf(AccountFirebaseHandles handles) {
    final user = handles.auth.currentUser;
    if (user == null || user.uid != handles.authUid) {
      throw const NotAuthenticatedException();
    }
    return authGatewayUserFromFirebase(user);
  }
}
