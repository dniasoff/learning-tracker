import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/social/domain/learning_group.dart';

void main() {
  test('group member carries an opaque summary id for the profile route', () {
    final member = LearningGroupMember.fromWire({
      'memberId': 'opaque-member-id',
      'summaryId': 'opaque-summary-id',
      'displayName': 'Learner',
      'avatarId': 'avatar-1',
      'role': 'member',
      'mode': 'child',
      'isSelf': false,
    });

    expect(member.summaryId, 'opaque-summary-id');
    expect(member.mode, LearningGroupMemberMode.child);
  });

  test('group member rejects a response without its summary id', () {
    expect(
      () => LearningGroupMember.fromWire({
        'memberId': 'opaque-member-id',
        'displayName': 'Learner',
        'avatarId': 'avatar-1',
        'role': 'member',
        'mode': 'adult',
        'isSelf': false,
      }),
      throwsFormatException,
    );
  });
}
