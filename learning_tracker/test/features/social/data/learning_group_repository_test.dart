import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/learning_group_repository.dart';

void main() {
  test(
    'group list sends the selected profile and decodes its summaries',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = LearningGroupRepository((name, data) async {
        calls.add((name, data));
        return [
          {
            'groupId': 'group-12345678',
            'name': 'Family study',
            'groupType': 'private',
            'role': 'member',
            'memberCount': 3,
            'schoolId': null,
          },
        ];
      });

      final groups = await repository.listMine(
        profileId: 'profile-a',
        parentSessionId: 'session-a',
      );

      expect(groups.single.name, 'Family study');
      expect(calls.single.$1, 'listMyLearningGroups');
      expect(calls.single.$2, {
        'profileId': 'profile-a',
        'parentSessionId': 'session-a',
      });
    },
  );

  test('join sends the reviewed member revision and parent session', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final repository = LearningGroupRepository((name, data) async {
      calls.add((name, data));
      return {'success': true};
    });

    await repository.join(
      inviteCode: 'opaque-token',
      profileId: 'child-profile',
      memberRevision: 7,
      parentSessionId: 'parent-session',
    );

    expect(calls.single.$1, 'joinLearningGroup');
    expect(calls.single.$2, {
      'inviteCode': 'opaque-token',
      'profileId': 'child-profile',
      'memberRevision': 7,
      'parentSessionId': 'parent-session',
    });
  });
}
