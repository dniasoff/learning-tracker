import 'package:learning_tracker/core/auth/firebase_auth_gateway.dart';
import 'package:learning_tracker/core/auth/firebase_auth_gateway_impl.dart';
import 'package:learning_tracker/core/auth/google_sign_in_gateway.dart';
import 'package:learning_tracker/core/auth/google_sign_in_gateway_impl.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

/// Provides the singleton [FirebaseAuthGateway] used app-wide.
///
/// Tests override this with a fake gateway via
/// `ProviderScope(overrides: [firebaseAuthGatewayProvider.overrideWithValue(fake)])`.
// keepAlive: stateless singleton facade, cheap to keep for app lifetime.
@Riverpod(keepAlive: true)
FirebaseAuthGateway firebaseAuthGateway(Ref ref) {
  return FirebaseAuthGatewayImpl();
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
