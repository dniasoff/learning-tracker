import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/social_graph_repository.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';

void main() {
  test(
    'connections provider calls the repository and decodes its result',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = SocialGraphRepository((name, data) async {
        calls.add((name, data));
        return {
          'outgoingRequests': const <Object?>[],
          'incomingRequests': const <Object?>[],
          'following': const <Object?>[],
          'followers': const <Object?>[],
        };
      });
      final container = ProviderContainer(
        overrides: [
          socialGraphRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        socialConnectionsProvider((
          profileId: 'local-profile',
          parentSessionId: null,
        )).future,
      );

      expect(result.followers, isEmpty);
      expect(calls.single.$1, 'listSocialConnections');
      expect(calls.single.$2, {'profileId': 'local-profile'});
    },
  );
}
