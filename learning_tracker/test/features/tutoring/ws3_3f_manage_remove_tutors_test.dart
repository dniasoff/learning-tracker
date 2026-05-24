// WS3.3f — Manage / remove + co-tutors (DEC-10, DEC-22)
//
// Verifies that:
//   AC1 — manage_tutors_screen.dart references InviteTutorRoute (add path).
//   AC2 — manage_tutors_screen.dart references revokeTutorGrantUseCaseProvider
//          (revoke active grants).
//   AC3 — manage_tutors_screen.dart references rescindTutorInviteUseCaseProvider
//          (rescind pending invites).
//   AC4 — manage_tutors_screen.dart has per-child sections (_ChildGrantsSection).
//   AC5 — "Invite a tutor" button is wired into each child section (WS3.3f).

@Tags(['ws3', 'ws3_3f', 'tutor_mode'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('WS3.3f — Manage/remove tutors surface (DEC-10, DEC-22)', () {
    late String manageTutorsSrc;

    setUpAll(() {
      manageTutorsSrc = File(
        'lib/features/tutoring/presentation/screens/manage_tutors_screen.dart',
      ).readAsStringSync();
    });

    // ── AC1: Invite / add path ────────────────────────────────────────────────

    test('AC1: manage_tutors_screen navigates to InviteTutorRoute (add tutor)',
        () {
      expect(
        manageTutorsSrc,
        contains('InviteTutorRoute'),
        reason:
            'manage_tutors_screen.dart must navigate to InviteTutorRoute so '
            'parents can add/invite a new tutor (WS3.3f DEC-10)',
      );
    });

    test('AC1: "Invite a tutor" affordance is present', () {
      expect(
        manageTutorsSrc,
        contains('Invite a tutor'),
        reason:
            'manage_tutors_screen.dart must show an "Invite a tutor" button '
            'to initiate the invite flow for each child profile',
      );
    });

    // ── AC2: Revoke active grants ─────────────────────────────────────────────

    test('AC2: manage_tutors_screen references revokeTutorGrantUseCaseProvider',
        () {
      expect(
        manageTutorsSrc,
        contains('revokeTutorGrantUseCaseProvider'),
        reason:
            'manage_tutors_screen.dart must use revokeTutorGrantUseCaseProvider '
            'to remove active tutors (WS3.3f DEC-22)',
      );
    });

    test('AC2: Revoke action is shown for active grants', () {
      expect(
        manageTutorsSrc,
        contains('_revoke'),
        reason:
            'manage_tutors_screen.dart must expose a revoke action for active '
            'grants (WS3.3f DEC-22)',
      );
    });

    // ── AC3: Rescind pending invites ──────────────────────────────────────────

    test(
        'AC3: manage_tutors_screen references rescindTutorInviteUseCaseProvider',
        () {
      expect(
        manageTutorsSrc,
        contains('rescindTutorInviteUseCaseProvider'),
        reason:
            'manage_tutors_screen.dart must use rescindTutorInviteUseCaseProvider '
            'to cancel pending invitations (WS3.3f DEC-10)',
      );
    });

    test('AC3: Rescind action is shown for pending invites', () {
      expect(
        manageTutorsSrc,
        contains('_rescind'),
        reason:
            'manage_tutors_screen.dart must expose a rescind action for pending '
            'invites (WS3.3f DEC-10)',
      );
    });

    // ── AC4: Per-child sections ───────────────────────────────────────────────

    test('AC4: manage_tutors_screen renders per-child grant sections', () {
      expect(
        manageTutorsSrc,
        contains('_ChildGrantsSection'),
        reason:
            'manage_tutors_screen.dart must organise grants by child profile '
            'via _ChildGrantsSection (DEC-22: co-tutors per child)',
      );
    });

    test('AC4: manage_tutors_screen uses outgoingTutorGrantsProvider', () {
      expect(
        manageTutorsSrc,
        contains('outgoingTutorGrantsProvider'),
        reason:
            'manage_tutors_screen.dart must load grants via '
            'outgoingTutorGrantsProvider (parent perspective)',
      );
    });

    // ── AC5: Invite button per child section ──────────────────────────────────

    test('AC5: Invite button appears in each child section (WS3.3f)', () {
      // Invite button must be inside _ChildGrantsSection (after grants data).
      final childSectionIdx = manageTutorsSrc.indexOf('_ChildGrantsSection');
      final inviteRouteIdx = manageTutorsSrc.indexOf('InviteTutorRoute');
      expect(
        inviteRouteIdx > childSectionIdx,
        isTrue,
        reason:
            'InviteTutorRoute navigation must appear inside the '
            '_ChildGrantsSection scope (invite button per child)',
      );
    });
  });
}
