import 'package:learning_tracker/core/auth/auth_providers.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/features/account/data/repositories/auth_repository_impl.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_providers.g.dart';

/// The [AuthRepository] bound to the ACTIVE account's named-app Auth
/// (DNI-520): rebuilt when `activeAccountIdProvider` changes, so
/// [AuthRepository.currentUser] / [AuthRepository.signOut] always act on the
/// active account. Sign-in calls name their target account explicitly.
@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  return AuthRepositoryImpl(
    accountAuthGateway: ref.watch(accountAuthGatewayProvider),
    firebaseAuthGateway: ref.watch(firebaseAuthGatewayProvider),
    googleSignInGateway: ref.watch(googleSignInGatewayProvider),
    accountId: ref.watch(activeAccountIdProvider),
  );
}

/// Raw, reactive Firebase auth-state stream (`authRepository.onAuthStateChanged()`).
///
/// AUD-account-19: this used to be named `authState`/`authStateProvider` —
/// identical to the generated provider name for [AuthStateNotifier]
/// (`auth_state_provider.dart`), the app-wide active-profile notifier. The
/// name collision forced every file that needed both providers to `hide` or
/// `as`-alias one of them. Renamed so `authStateProvider` resolves to exactly
/// one declaration (the notifier) across the codebase; this raw stream is a
/// distinct, narrower primitive — the live Firebase session, not the app's
/// active-profile/tier/session-status state.
@Riverpod(keepAlive: true)
Stream<AppUser?> firebaseAuthState(Ref ref) {
  return ref.watch(authRepositoryProvider).onAuthStateChanged();
}
