// Mirror test for `lib/domain/learner_state/ports/tutor_scope_grant_source.dart`
// (AG-5), Story 4.2a (DNI-523): the pure grant validation the tutor-device
// read path applies per learner scope.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/ports/ports.dart';

import '../../../helpers/learner_state_fixtures.dart';

const _tutor = 'tutor-uid';
const _parent = 'parent-uid';

TutorGrantRecord _grant(
  String id, {
  String tutorUid = _tutor,
  String parentUid = _parent,
  String profileId = profileUlid,
  String state = 'active',
}) => (
  id: id,
  data: <String, Object?>{
    'tutor_uid': tutorUid,
    'parent_uid': parentUid,
    'child_profile_id': profileId,
    'state': state,
  },
);

void main() {
  final scope = LearnerScope(ownerUid: _parent, profileId: profileUlid);

  TutorScopeGrantVerdict evaluate(List<TutorGrantRecord> grants) =>
      evaluateTutorScopeGrants(tutorUid: _tutor, scope: scope, grants: grants);

  group('evaluateTutorScopeGrants', () {
    test('an active grant naming the tutor, owner and profile grants', () {
      expect(evaluate([_grant('g1')]), const TutorScopeGranted('g1'));
    });

    test('no grant at all is noGrant', () {
      expect(
        evaluate(const []),
        const TutorScopeDenied(TutorScopeDenialReason.noGrant),
      );
    });

    for (final state in [
      'pending',
      'revoked_by_parent',
      'revoked_by_tutor',
      'expired',
      'declined',
      'rescinded',
    ]) {
      test('a matching grant in state $state is grantNotActive', () {
        expect(
          evaluate([_grant('g1', state: state)]),
          const TutorScopeDenied(TutorScopeDenialReason.grantNotActive),
        );
      });
    }

    test('a grant for another tutor, owner or profile does not count', () {
      expect(
        evaluate([
          _grant('g1', tutorUid: 'someone-else'),
          _grant('g2', parentUid: 'other-parent'),
          _grant('g3', profileId: ulidA),
        ]),
        const TutorScopeDenied(TutorScopeDenialReason.noGrant),
      );
    });

    test('an active grant wins over inactive ones; the lowest active id is '
        'reported', () {
      expect(
        evaluate([
          _grant('g3', state: 'revoked_by_parent'),
          _grant('g2'),
          _grant('g1'),
        ]),
        const TutorScopeGranted('g1'),
      );
    });

    test('an empty tutor uid is notSignedIn, even with a matching grant', () {
      expect(
        evaluateTutorScopeGrants(
          tutorUid: '',
          scope: scope,
          grants: [_grant('g1', tutorUid: '')],
        ),
        const TutorScopeDenied(TutorScopeDenialReason.notSignedIn),
      );
    });
  });

  group('value semantics', () {
    test('verdicts and the exception compare by value', () {
      expect(const TutorScopeGranted('g1'), const TutorScopeGranted('g1'));
      expect(
        const TutorScopeGranted('g1'),
        isNot(const TutorScopeGranted('g2')),
      );
      expect(
        TutorScopeAccessDeniedException(
          scope,
          TutorScopeDenialReason.noGrant,
        ),
        TutorScopeAccessDeniedException(
          LearnerScope(ownerUid: _parent, profileId: profileUlid),
          TutorScopeDenialReason.noGrant,
        ),
      );
      expect(
        TutorScopeAccessDeniedException(
          scope,
          TutorScopeDenialReason.permissionDenied,
        ).toString(),
        contains('permissionDenied'),
      );
    });
  });
}
