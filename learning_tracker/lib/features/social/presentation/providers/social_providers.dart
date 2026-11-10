import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/providers/account_functions_provider.dart';
import 'package:learning_tracker/features/social/data/social_graph_repository.dart';
import 'package:learning_tracker/features/social/domain/social_graph.dart';

final socialGraphRepositoryProvider = Provider<SocialGraphRepository>((ref) {
  final resolveFunctions = ref.watch(accountFunctionsProvider);
  return SocialGraphRepository(firebaseSocialCallableInvoker(resolveFunctions));
});

final socialConnectionsProvider = FutureProvider.autoDispose
    .family<SocialConnections, ({String profileId, String? parentSessionId})>(
      (ref, query) => ref
          .watch(socialGraphRepositoryProvider)
          .listConnections(
            query.profileId,
            parentSessionId: query.parentSessionId,
          ),
    );
