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
}
