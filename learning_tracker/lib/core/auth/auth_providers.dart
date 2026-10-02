import 'package:flutter_riverpod/flutter_riverpod.dart' show Provider;
import 'package:learning_tracker/core/auth/account_auth_gateway.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/core/auth/google_sign_in_gateway.dart';
import 'package:learning_tracker/core/auth/google_sign_in_gateway_impl.dart';
import 'package:learning_tracker/data/firestore/account_firebase_auth_gateway.dart';
import 'package:learning_tracker/data/firestore/account_firebase_providers.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

/// The app's only way to authenticate: per-account, named-app Auth over the
/// `AccountFirebase` registry (parent AD-1 / AD-19, DNI-520).
///
/// Tests override this with a fake via
/// `accountAuthGatewayProvider.overrideWithValue(fake)`.
// keepAlive: wraps the keepAlive registry; stateless itself.
final accountAuthGatewayProvider = Provider<AccountAuthGateway>(
  (ref) => AccountFirebaseAuthGateway(ref.watch(accountFirebaseRegistryProvider)),
);

/// The [FirebaseAuthGateway] bound to the ACTIVE account's named-app Auth
/// (`activeAccountIdProvider`), rebuilt whenever the active account
/// changes. With no active account it is signed out, and its account-free
/// calls run on the registry's never-signed-in utility app — there is no
/// `FirebaseAuth.instance` (default app) path anywhere (DNI-520).
///
/// Tests override this with a fake gateway via
/// `ProviderScope(overrides: [firebaseAuthGatewayProvider.overrideWithValue(fake)])`.
@Riverpod(keepAlive: true)
FirebaseAuthGateway firebaseAuthGateway(Ref ref) {
  final accountId = ref.watch(activeAccountIdProvider);
  return ref.watch(accountAuthGatewayProvider).gatewayFor(accountId);
}

/// Provides the singleton [GoogleSignInGateway] used app-wide.
///
/// Tests override this with a fake gateway via
/// `ProviderScope(overrides: [googleSignInGatewayProvider.overrideWithValue(fake)])`.
// keepAlive: stateless singleton facade, cheap to keep for app lifetime.
@Riverpod(keepAlive: true)
GoogleSignInGateway googleSignInGateway(Ref ref) {
  return GoogleSignInGatewayImpl();
}
