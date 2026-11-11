import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/domain/school.dart';

void main() {
  test(
    'school profile decodes verified status, creation date and admin names',
    () {
      final profile = SchoolProfile.fromWire({
        'schoolId': 'school_12345678',
        'name': 'Beit Midrash',
        'verified': true,
        'createdAt': '2026-11-10T12:00:00.000Z',
        'admins': [
          {'displayName': 'Rivka'},
        ],
        'status': 'active',
      });
      expect(profile.verified, isTrue);
      expect(profile.createdAt, DateTime.utc(2026, 11, 10, 12));
      expect(profile.adminNames, ['Rivka']);
      expect(() => profile.adminNames.add('Other'), throwsUnsupportedError);
    },
  );

  test('school codecs reject incomplete and private-shaped responses', () {
    expect(
      () => SchoolProfile.fromWire({'schoolId': 'x'}),
      throwsFormatException,
    );
    expect(
      () => SchoolProfile.fromWire({
        'schoolId': 'school_12345678',
        'name': 'School',
        'admins': ['not a card'],
      }),
      throwsFormatException,
    );
  });

  test('membership codec decodes a bounded membership card', () {
    final membership = SchoolMembership.fromWire({
      'schoolId': 'school_12345678',
      'name': 'School',
      'verified': false,
      'role': 'member',
      'joinedAt': '2026-11-10T12:00:00.000Z',
    });
    expect(membership.role, 'member');
    expect(membership.verified, isFalse);
    expect(
      () => SchoolMembership.fromWire({'schoolId': 'id'}),
      throwsFormatException,
    );
  });
}
