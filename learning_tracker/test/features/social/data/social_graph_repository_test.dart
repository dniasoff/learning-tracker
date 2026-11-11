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

  test(
    'summary publication sends the strict snapshot through the callable',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = SocialGraphRepository((name, data) async {
        calls.add((name, data));
        return {'success': true};
      });
      final summary = {
        'streak': {'by_curriculum': <Object?>[]},
        'current_tracks': <Object?>[],
        'weekly_learning': {
          'week_start': '2026-11-08',
          'by_curriculum': <Object?>[],
        },
        'siyumim': <Object?>[],
      };

      await repository.publishSummary(
        profileId: 'profile-ulid',
        parentSessionId: 'session-id',
        summary: summary,
      );

      expect(calls.single.$1, 'publishSocialSummary');
      expect(calls.single.$2, {
        'profileId': 'profile-ulid',
        'parentSessionId': 'session-id',
        'summary': summary,
      });
    },
  );
}
