import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/social_graph_repository.dart';
import 'package:learning_tracker/features/social/presentation/providers/social_providers.dart';

final _opaqueSocialId = List.filled(43, 'a').join();

void main() {
  test(
    'social connections provider uses the callable repository and strict decoder',
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

      final state = await container.read(
        socialConnectionsProvider((
          profileId: 'profile-7',
          parentSessionId: null,
        )).future,
      );

      expect(state.followers, isEmpty);
      expect(calls, hasLength(1));
      expect(calls.single.$1, 'listSocialConnections');
      expect(calls.single.$2, {'profileId': 'profile-7'});
    },
  );

  test(
    'follow request callable receives only the opaque target identity',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = SocialGraphRepository((name, data) async {
        calls.add((name, data));
        return {'success': true};
      });

      await repository.sendRequest(
        fromProfileId: 'local-profile-id',
        toSocialProfileId: _opaqueSocialId,
      );

      expect(calls.single.$1, 'sendFollowRequest');
      expect(calls.single.$2, {
        'fromProfileId': 'local-profile-id',
        'toSocialProfileId': _opaqueSocialId,
      });
      expect(calls.single.$2.containsKey('toOwnerUid'), isFalse);
    },
  );
}
