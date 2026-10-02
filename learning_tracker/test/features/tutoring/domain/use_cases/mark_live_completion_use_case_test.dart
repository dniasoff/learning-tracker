/// H1 regression — MarkLiveCompletionUseCase routing tests.
///
/// Story 1.24 (DNI-486): a tutor session runs ONLY the tutor write (the
/// `tutorRecordLearning` callable through TutorWriteService) and never the
/// owner write (a client Firestore batch); an owner session runs only the
/// owner write. The legacy tutor rejection is deleted (deviation #7).
///
/// These are pure domain tests — no DB, no Flutter, no Riverpod required.
library;

import 'package:flutter_test/flutter_test.dart';
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
  group('H1 — MarkLiveCompletionUseCase routes by session role', () {
    test('a tutor session runs only the tutor write and returns its '
        'result', () async {
      final useCase = MarkLiveCompletionUseCase<String>(
        session: _tutorSession(),
      );
      var ownerCalled = false;
      final result = await useCase.call(() async {
        ownerCalled = true;
        return 'owner';
      }, tutorWrite: () async => 'tutor');
      expect(result, 'tutor');
      expect(
        ownerCalled,
        isFalse,
        reason: 'a tutor must never reach the owner (client-write) delegate',
      );
    });

    test('an owner session runs only the owner write and returns its '
        'result', () async {
      final useCase = MarkLiveCompletionUseCase<String>(
        session: _ownerSession(),
      );
      var tutorCalled = false;
      final result = await useCase.call(
        () async => 'completion_result',
        tutorWrite: () async {
          tutorCalled = true;
          return 'tutor';
        },
      );
      expect(result, 'completion_result');
      expect(tutorCalled, isFalse);
    });

    // ── Session role predicates ───────────────────────────────────────────────
    //
    // These guard against future refactors that accidentally flip the session
    // role predicates, which would send a tutor down the owner write path.

    test('tutor ResolvedSession has isTutorSession = true', () {
      expect(_tutorSession().isTutorSession, isTrue);
    });

    test('owner ResolvedSession has isTutorSession = false', () {
      expect(_ownerSession().isTutorSession, isFalse);
    });
  });
}
