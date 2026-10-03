// Story 4.3 (DNI-511) T1: a roster entry addresses its learner, carries
// can_edit_learning as its only edit permission, and a failed read is a
// retryable NetworkException (AC-6, AppErrorView).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/exceptions/app_exception.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/sub_tracks/domain/repositories/tutor_roster_repository.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

import '../../talmidim_fixtures.dart';

void main() {
  test("the learner scope is the grant's owner and profile", () {
    expect(
      talmidEntry(3, owner: 2).scope,
      LearnerScope(ownerUid: talmidOwner(2), profileId: talmidProfile(3)),
    );
  });

  test('a grant naming a non-ULID profile has no scope (never fabricated)', () {
    const entry = TalmidRosterEntry(
      grantId: 'g',
      ownerUid: 'owner',
      profileId: 'legacy-id',
      permissions: TutorPermissions(),
    );
    expect(entry.scope, isNull);
  });

  test('can_edit_learning is the edit permission; it defaults to false', () {
    expect(talmidEntry(1).canEditLearning, isTrue);
    expect(talmidEntry(1, canEditLearning: false).canEditLearning, isFalse);
    const unset = TalmidRosterEntry(
      grantId: 'g',
      ownerUid: 'owner',
      profileId: 'p',
      permissions: TutorPermissions(),
    );
    expect(unset.canEditLearning, isFalse);
  });

  test('entries compare by value', () {
    expect(talmidEntry(1, name: 'A'), talmidEntry(1, name: 'A'));
    expect(talmidEntry(1, name: 'A'), isNot(talmidEntry(1, name: 'B')));
  });

  test('a failed read is a NetworkException carrying no learner data', () {
    const error = TutorRosterLoadException();
    expect(error, isA<NetworkException>());
    expect(error.toString(), isNot(contains('parent')));
  });
}
