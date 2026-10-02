import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/core/providers/path_uid_resolver_provider.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/features/account/data/services/magic_link_service.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/services/named_app_sign_in.dart';
import 'package:learning_tracker/features/account/domain/services/session_persistence_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'magic_link_providers.g.dart';

/// Single, app-wide [MagicLinkService] that listens for incoming
/// magic-link deep links and promotes the auth state on success.
///
/// Kept alive for the entire app lifetime so the link subscription
/// is never accidentally torn down by a route change.
///
/// `authRepositoryProvider` is READ, not watched: it is rebuilt on every
/// account switch (it is bound to the active account's named app,
/// DNI-520), and re-creating this service would re-run [initialize] and
/// re-handle the cold-start link. The service only uses it for account-free
/// calls; the sign-in itself goes through [signInWithMagicLink], which reads
/// everything fresh.
@Riverpod(keepAlive: true)
MagicLinkService magicLinkService(Ref ref) {
  final service = MagicLinkService(
    authRepository: ref.read(authRepositoryProvider),
    signInWithEmailLink: (email, link, {displayName}) =>
        signInWithMagicLink(ref, email, link, displayName: displayName),
    onSignedIn: (user) async {
      await ref
          .read(authStateProvider.notifier)
          .setCloudBornSessionFromFirebaseUser(user);
    },
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Signs in with a magic link on the target account's OWN named app
/// (AD-1, DNI-520): picks the device account for [email] (or mints one),
/// signs its named app in once, applies a pending [displayName], registers
/// or reconciles (AD-24 path uid) the registry row, and activates it.
Future<AppUser?> signInWithMagicLink(
  Ref ref,
  String email,
  String emailLink, {
  String? displayName,
}) async {
  final authRepo = ref.read(authRepositoryProvider);
  final registry = ref.read(deviceRegistryProvider);
  final signIn = NamedAppSignIn(
    auth: authRepo,
    registry: registry,
    pathUids: ref.read(pathUidResolverProvider),
  );
  final session = await signIn.signIn(
    emailHint: email,
    authenticate: (accountId) =>
        authRepo.signInToAccountWithEmailLink(accountId, email, emailLink),
  );
  var user = session.user;
  if (displayName != null) {
    final accountAuth = authRepo.forAccount(session.accountId);
    await accountAuth.updateDisplayName(displayName);
    user = await accountAuth.reloadCurrentUser() ?? user;
  }
  final persistence = SessionPersistenceService(
    prefs: await SharedPreferences.getInstance(),
    registry: registry,
  );
  if (session.isNewToDevice) {
    await persistence.registerAccount(
      accountId: session.accountId,
      email: user.email ?? email,
      displayName: user.displayName ?? '',
      tier: 'cloudBorn',
      firebaseUid: user.uid,
      dbFileName: 'user_acc_${session.accountId}.db',
    );
  } else {
    await signIn.reconcilePathUid(session);
    await persistence.setActiveAccount(session.accountId);
  }
  ref.read(activeAccountIdProvider.notifier).set(session.accountId);
  return user;
}

/// Boots the app-link listener once for the app lifetime.
final magicLinkInitializationProvider = FutureProvider<void>((ref) async {
  await ref.watch(magicLinkServiceProvider).initialize();
});
