import 'package:learning_tracker/core/auth/auth_providers.dart';
import 'package:learning_tracker/features/account/data/repositories/auth_repository_impl.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    firebaseAuthGateway: ref.watch(firebaseAuthGatewayProvider),
    googleSignInGateway: ref.watch(googleSignInGatewayProvider),
  );
}

@Riverpod(keepAlive: true)
Stream<AppUser?> authState(Ref ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChanged();
}
