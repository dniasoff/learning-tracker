import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/learning_group_repository.dart';
import 'package:learning_tracker/features/social/presentation/providers/learning_group_providers.dart';

void main() {
  test('group provider returns profile-scoped group summaries', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final repository = LearningGroupRepository((name, data) async {
      calls.add((name, data));
      return [
        {
          'groupId': 'group-12345678',
          'name': 'Family study',
          'groupType': 'private',
          'role': 'member',
          'memberCount': 2,
          'schoolId': null,
        },
      ];
    });
    final container = ProviderContainer(
      overrides: [
        learningGroupRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final groups = await container.read(
      learningGroupsProvider((
        profileId: 'profile-b',
        parentSessionId: null,
      )).future,
    );

    expect(groups.single.name, 'Family study');
    expect(calls.single.$1, 'listMyLearningGroups');
    expect(calls.single.$2, {'profileId': 'profile-b'});
  });

  test(
    'Learn progress provider reconciles the local day before reading published shares',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = LearningGroupRepository((name, data) async {
        calls.add((name, data));
        return switch (name) {
          'listMyLearningGroupDailyTasks' => <Object?>[],
          'listMyLearningGroups' => [
            {
              'groupId': 'group-12345678',
              'name': 'Family study',
              'groupType': 'private',
              'role': 'member',
              'memberCount': 2,
              'schoolId': null,
            },
          ],
          'listLearningGroupTasks' => [
            {
              'taskId': 'task-1',
              'taskName': 'Tamid',
              'curriculumId': 'mishnayos',
              'status': 'published',
              'memberState': 'accepted',
              'scopeUnits': <Object?>[],
              'allocation': {
                'members': [
                  {
                    'memberId': 'member-1',
                    'displayName': 'Ari',
                    'units': <Object?>[],
                    'dailyTasks': <Object?>[],
                    'progress': {'completed': 2, 'total': 5},
                  },
                ],
              },
              'joinRequests': <Object?>[],
            },
          ],
          _ => throw StateError('Unexpected callable $name'),
        };
      });
      final container = ProviderContainer(
        overrides: [
          learningGroupRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final result = await container.read(
        groupTaskProgressForLearnProvider((
          profileId: 'profile-b',
          onDate: '2026-11-11',
        )).future,
      );

      expect(result.single.groupName, 'Family study');
      expect(result.single.task.allocationMembers.single['progress'], {
        'completed': 2,
        'total': 5,
      });
      expect(calls.map((call) => call.$1), [
        'listMyLearningGroupDailyTasks',
        'listMyLearningGroups',
        'listLearningGroupTasks',
      ]);
      expect(calls.first.$2, {
        'profileId': 'profile-b',
        'onDate': '2026-11-11',
      });
    },
  );
}
