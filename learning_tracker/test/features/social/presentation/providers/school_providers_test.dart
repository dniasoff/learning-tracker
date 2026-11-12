import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/school_repository.dart';
import 'package:learning_tracker/features/social/presentation/providers/school_providers.dart';

void main() {
  test('school profile provider uses the shared callable repository', () async {
    final calls = <String>[];
    final repository = SchoolRepository((name, data) async {
      calls.add(name);
      return {
        'schoolId': data['schoolId'],
        'name': 'North School',
        'createdAt': null,
        'admins': <Object?>[],
        'status': 'active',
      };
    });
    final container = ProviderContainer(
      overrides: [schoolRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final profile = await container.read(
      schoolProfileProvider('school_12345678').future,
    );

    expect(calls, ['getSchoolProfile']);
    expect(profile.name, 'North School');
  });
}
