// Invariant: a tutor session never performs a CLIENT live completion write.
//
// Story 1.24 (DNI-486, deviation #7) lets a tutor with `can_edit_learning`
// record learning, but only through the Story 1.23 callables (AD-53): the
// owner delegate — a client Firestore batch the rules deny for a tutor —
// is never reached from a tutor session. Firestore rules (owner-only
// learning_events) cover the server side in functions/test.

@Tags(['tutor_mode', 'invariant'])
library;

import 'package:flutter_test/flutter_test.dart';
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
    permissions: TutorPermissions(canEditLearning: true),
  ),
);

void main() {
  group('tutor live completion invariant (W4.34, DNI-486)', () {
    test('a tutor session never runs the owner delegate', () async {
      var ownerRan = false;
      final useCase = MarkLiveCompletionUseCase<void>(session: _tutorSession());

      await useCase.call(() async => ownerRan = true, tutorWrite: () async {});

      expect(
        ownerRan,
        isFalse,
        reason: 'a tutor must never reach the client-write delegate',
      );
    });

    test(
      'owner session runs the owner delegate and returns its result',
      () async {
        final useCase = MarkLiveCompletionUseCase<int>(
          session: _ownerSession(),
        );

        expect(
          await useCase.call(() async => 42, tutorWrite: () async => -1),
          42,
        );
      },
    );

    test('child-self (own profile) session runs the owner delegate', () async {
      final session = ResolvedSession.forOwner(
        selection: const OwnProfileSelection(
          profileId: '1',
          ownerUid: 'self-1',
        ),
        isChildMode: true,
      );
      final useCase = MarkLiveCompletionUseCase<String>(session: session);

      expect(
        await useCase.call(() async => 'ok', tutorWrite: () async => 'tutor'),
        'ok',
      );
      expect(session.isTutorSession, isFalse);
    });
  });
}
