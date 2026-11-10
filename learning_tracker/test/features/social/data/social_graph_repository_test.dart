import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/social_graph_repository.dart';

void main() {
  test('follow request sends only the target social identity', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final repository = SocialGraphRepository((name, data) async {
      calls.add((name, data));
      return {'success': true};
    });

    await repository.sendRequest(
      fromProfileId: 'local-profile',
      toSocialProfileId: List.filled(43, 'x').join(),
    );

    expect(calls.single.$1, 'sendFollowRequest');
    expect(calls.single.$2, {
      'fromProfileId': 'local-profile',
      'toSocialProfileId': List.filled(43, 'x').join(),
    });
  });

  test('profile upsert validates its bounded opaque response', () async {
    final repository = SocialGraphRepository((name, data) async {
      expect(name, 'upsertSocialProfile');
      expect(data['avatarId'], 3);
      return {'success': true, 'socialProfileId': List.filled(43, 'a').join()};
    });

    final result = await repository.upsertProfile(
      profileId: 'local-profile',
      displayName: 'Learner',
      avatarId: 3,
    );

    expect(result, List.filled(43, 'a').join());
  });
}
