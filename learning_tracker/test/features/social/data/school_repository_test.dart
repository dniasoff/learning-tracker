import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/data/school_repository.dart';

void main() {
  test(
    'school creation is callable-only and returns the opaque school id',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = SchoolRepository((name, data) async {
        calls.add((name, data));
        return {'schoolId': 'school_12345678'};
      });
      expect(
        await repository.create(name: 'School', profileId: 'adult-profile'),
        'school_12345678',
      );
      expect(calls.single.$1, 'createSchool');
      expect(calls.single.$2, {'name': 'School', 'profileId': 'adult-profile'});
    },
  );

  test(
    'child join sends parent session and explicit progress consent',
    () async {
      final calls = <(String, Map<String, Object?>)>[];
      final repository = SchoolRepository((name, data) async {
        calls.add((name, data));
        return {'success': true};
      });
      await repository.join(
        inviteCode: 'opaque-invite',
        profileId: 'child-profile',
        parentSessionId: 'parent-session',
        progressConsent: true,
      );
      expect(calls.single.$1, 'joinSchoolWithInvite');
      expect(calls.single.$2, {
        'inviteCode': 'opaque-invite',
        'profileId': 'child-profile',
        'parentSessionId': 'parent-session',
        'progressConsent': true,
      });
    },
  );

  test('report uses a fixed category and school only', () async {
    final calls = <(String, Map<String, Object?>)>[];
    final repository = SchoolRepository((name, data) async {
      calls.add((name, data));
      return {'success': true};
    });
    await repository.report(schoolId: 'school_12345678', category: 'abuse');
    expect(calls.single.$1, 'reportSchool');
    expect(calls.single.$2, {
      'schoolId': 'school_12345678',
      'category': 'abuse',
    });
  });
}
