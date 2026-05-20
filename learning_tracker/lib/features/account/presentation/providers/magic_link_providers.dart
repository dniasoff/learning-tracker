import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/features/account/data/services/magic_link_service.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart'
    as auth_state;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'magic_link_providers.g.dart';

/// Single, app-wide [MagicLinkService] that listens for incoming
/// magic-link deep links and promotes the auth state on success.
///
/// Kept alive for the entire app lifetime so the link subscription
/// is never accidentally torn down by a route change.
@Riverpod(keepAlive: true)
MagicLinkService magicLinkService(Ref ref) {
  final service = MagicLinkService(
    authRepository: ref.watch(authRepositoryProvider),
    onSignedIn: (user) async {
      await ref
          .read(auth_state.authStateProvider.notifier)
          .promoteToCloud(user);
    },
  );
  ref.onDispose(service.dispose);
  return service;
}

/// Boots the app-link listener once for the app lifetime.
final magicLinkInitializationProvider = FutureProvider<void>((ref) async {
  await ref.watch(magicLinkServiceProvider).initialize();
});
