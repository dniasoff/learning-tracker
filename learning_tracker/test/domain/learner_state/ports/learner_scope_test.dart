/// Unit tests for [LearnerScope].
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';

import '../../../helpers/learner_state_fixtures.dart';

void main() {
  test('builds the profile path from owner uid + profile ULID', () {
    final scope = LearnerScope(ownerUid: 'owner', profileId: profileUlid);
    expect(scope.profilePath, 'users/owner/learner_profiles/$profileUlid');
    expect(scope, LearnerScope(ownerUid: 'owner', profileId: profileUlid));
  });

  test('rejects empty/slashed uids and non-ULID profile ids', () {
    expect(
      () => LearnerScope(ownerUid: '', profileId: profileUlid),
      throwsArgumentError,
    );
    expect(
      () => LearnerScope(ownerUid: 'a/b', profileId: profileUlid),
      throwsArgumentError,
    );
    expect(
      () => LearnerScope(ownerUid: 'owner', profileId: '42'),
      throwsArgumentError,
    );
  });
}
