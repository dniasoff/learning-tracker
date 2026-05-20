import 'package:google_sign_in/google_sign_in.dart';
import 'package:learning_tracker/features/account/data/repositories/auth_repository_impl.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

@Riverpod(keepAlive: true)
GoogleSignIn googleSignIn(Ref ref) {
  return GoogleSignIn.instance;
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(googleSignIn: ref.watch(googleSignInProvider));
}

@Riverpod(keepAlive: true)
Stream<AppUser?> authState(Ref ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChanged();
}
