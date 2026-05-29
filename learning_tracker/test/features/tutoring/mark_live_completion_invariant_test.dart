// Invariant: a tutor session can NEVER perform a live completion write (W4.34).
//
// This is the client-side enforcement layer of the canMarkLiveCompletion=false
// security boundary. The other three enforcement sites are covered elsewhere:
//   • value object (TutorPermissions) — ws3_3d + the VO assertions below,
//   • Firestore rules (owner-only completions) — functions/test/firestore_rules.test.mjs,
//   • Cloud Function (tutorBulkPriorCompletions rejects today+) — Phase 7.

@Tags(['tutor_mode', 'invariant'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/exceptions/permission_exception.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';

ResolvedSession _ownerSession() => ResolvedSession.forOwner(
  selection: const OwnProfileSelection(profileId: '1', ownerUid: 'owner-1'),
  isChildMode: false,
);

ResolvedSession _tutorSession() => ResolvedSession.forTutor(
  selection: const TutoredProfileSelection(
    profileId: '1',
    ownerUid: 'parent-1',
    grantId: 'grant-1',
    permissions: TutorPermissions(),
  ),
);

void main() {
  group('canMarkLiveCompletion invariant (W4.34)', () {
    test('tutor session throws TutorWriteForbiddenException and never runs the '
        'delegate', () async {
      var ran = false;
      final useCase = MarkLiveCompletionUseCase<void>(session: _tutorSession());

      await expectLater(
        () => useCase.call(() async {
          ran = true;
        }),
        throwsA(isA<TutorWriteForbiddenException>()),
      );
      expect(
        ran,
        isFalse,
        reason: 'a tutor must never reach the write delegate',
      );
    });

    test('owner session runs the delegate and returns its result', () async {
      final useCase = MarkLiveCompletionUseCase<int>(session: _ownerSession());

      final result = await useCase.call(() async => 42);

      expect(result, 42);
    });

    test('child-self (own profile) session is allowed through', () async {
      final session = ResolvedSession.forOwner(
        selection: const OwnProfileSelection(
          profileId: '1',
          ownerUid: 'self-1',
        ),
        isChildMode: true,
      );
      final useCase = MarkLiveCompletionUseCase<String>(session: session);

      expect(await useCase.call(() async => 'ok'), 'ok');
      expect(session.isTutorSession, isFalse);
    });

    test(
      'VO invariant: canMarkLiveCompletion is always false, never constructible '
      'as true',
      () {
        expect(
          _tutorSession().effectivePermissions.canMarkLiveCompletion,
          isFalse,
        );
        expect(
          _ownerSession().effectivePermissions.canMarkLiveCompletion,
          isFalse,
        );
        expect(const TutorPermissions().canMarkLiveCompletion, isFalse);
        expect(TutorPermissions.defaults().canMarkLiveCompletion, isFalse);
        expect(TutorPermissions.readOnly().canMarkLiveCompletion, isFalse);
        // copyWith has no canMarkLiveCompletion parameter, so it survives copies.
        expect(
          const TutorPermissions()
              .copyWith(canEditGoals: true)
              .canMarkLiveCompletion,
          isFalse,
        );
      },
    );
  });
}
