/// H1 regression — MarkLiveCompletionUseCase enforcement tests.
///
/// Verifies that [MarkLiveCompletionUseCase] correctly blocks tutor sessions
/// from executing live completion writes, and allows owner sessions through.
///
/// These are pure domain tests — no DB, no Flutter, no Riverpod required.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/exceptions/permission_exception.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/mark_live_completion_use_case.dart';

// ── Helpers ───────────────────────────────────────────────────────────────────

/// Owner [ResolvedSession] — mirrors the real construction in
/// _CompletionSectionState._sessionForCurrentUser when isTutor = false.
ResolvedSession _ownerSession() => ResolvedSession.forOwner(
  selection: const OwnProfileSelection(profileId: 'p1', ownerUid: 'uid1'),
  isChildMode: false,
);

/// Tutor [ResolvedSession] — mirrors the real construction in
/// _CompletionSectionState._sessionForCurrentUser when isTutor = true.
ResolvedSession _tutorSession() => ResolvedSession.forTutor(
  selection: const TutoredProfileSelection(
    profileId: 'p1',
    ownerUid: 'uid1',
    grantId: 'grant1',
    permissions: TutorPermissions(),
  ),
);

void main() {
  group('H1 — MarkLiveCompletionUseCase tutor boundary enforcement', () {
    // ── Core invariant: tutor sessions are ALWAYS blocked ────────────────────

    test('tutor session throws TutorWriteForbiddenException', () async {
      final useCase = MarkLiveCompletionUseCase<String>(
        session: _tutorSession(),
      );

      var delegateCalled = false;
      await expectLater(
        () => useCase.call(() async {
          delegateCalled = true;
          return 'result';
        }),
        throwsA(isA<TutorWriteForbiddenException>()),
      );

      // The delegate must NEVER be called when the session is a tutor.
      expect(
        delegateCalled,
        isFalse,
        reason: 'The write delegate must not be called for tutor sessions',
      );
    });

    test('tutor session throws regardless of delegate implementation', () {
      final useCase = MarkLiveCompletionUseCase<int>(session: _tutorSession());

      // Even an always-succeed delegate is blocked.
      expect(
        () => useCase.call(() async => 42),
        throwsA(isA<TutorWriteForbiddenException>()),
      );
    });

    // ── Owner sessions are passed through ────────────────────────────────────

    test(
      'owner session executes the delegate and returns its result',
      () async {
        final useCase = MarkLiveCompletionUseCase<String>(
          session: _ownerSession(),
        );

        final result = await useCase.call(() async => 'completion_result');

        expect(result, 'completion_result');
      },
    );

    test('owner session does not throw TutorWriteForbiddenException', () {
      final useCase = MarkLiveCompletionUseCase<void>(session: _ownerSession());

      expect(() => useCase.call(() async {}), returnsNormally);
    });

    // ── Session role predicates ───────────────────────────────────────────────
    //
    // These guard against future refactors that accidentally flip the session
    // role predicates, which would silently re-enable the tutor write path.

    test('tutor ResolvedSession has isTutorSession = true', () {
      expect(_tutorSession().isTutorSession, isTrue);
    });

    test('owner ResolvedSession has isTutorSession = false', () {
      expect(_ownerSession().isTutorSession, isFalse);
    });

    // ── TutorPermissions invariant ────────────────────────────────────────────

    test('TutorPermissions.canMarkLiveCompletion is always false', () {
      // This is the hardcoded field in TutorPermissions — it must NEVER be true.
      const perms = TutorPermissions();
      expect(
        perms.canMarkLiveCompletion,
        isFalse,
        reason:
            'canMarkLiveCompletion must be hardcoded false in TutorPermissions',
      );

      // Also check non-default permissive construction.
      const permissive = TutorPermissions(
        canViewProgress: true,
        canViewContent: true,
        canBulkPriorCompletion: true,
        canResetCompletion: true,
        canEditGoals: true,
        canEditStages: true,
        canEditRewards: true,
        canEditStudyDays: true,
      );
      expect(permissive.canMarkLiveCompletion, isFalse);
    });
  });
}
