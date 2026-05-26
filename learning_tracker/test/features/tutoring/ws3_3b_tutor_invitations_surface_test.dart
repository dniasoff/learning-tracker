// WS3.3b — Tutor invitations surface (DEC-8 visibility rule)
//
// Verifies that:
//   AC1 — TutoredChildrenSection source gates visibility on BOTH active and
//          pending being empty (DEC-8: show iff ≥1 active OR ≥1 pending).
//   AC2 — Section source handles pending grants explicitly (not just active).
//   AC3 — Section navigates to ManageGrantsRoute for "View invitations".
//   AC4 — accept_invite_screen.dart loads the real grant from the provider
//          and falls back to stub when not found.

@Tags(['ws3', 'ws3_3b', 'tutor_mode'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('WS3.3b — TutoredChildrenSection visibility rule (DEC-8)', () {
    late String sectionSrc;
    late String acceptInviteSrc;

    setUpAll(() {
      sectionSrc = File(
        'lib/features/profiles/presentation/widgets/tutored_children_section.dart',
      ).readAsStringSync();

      acceptInviteSrc = File(
        'lib/features/tutoring/presentation/screens/accept_invite_screen.dart',
      ).readAsStringSync();
    });

    test('AC1: Section hides only when both active AND pending are empty', () {
      // Previously: if (activeGrants.isEmpty) return → only checked active.
      // Fixed:     if (activeGrants.isEmpty && pendingGrants.isEmpty) return.
      expect(
        sectionSrc,
        contains('activeGrants.isEmpty && pendingGrants.isEmpty'),
        reason:
            'TutoredChildrenSection must gate visibility on BOTH lists empty '
            '(DEC-8 rule: show iff ≥1 active OR ≥1 pending)',
      );
    });

    test('AC2: Section filters grants into active and pending lists', () {
      expect(
        sectionSrc,
        contains('pendingGrants'),
        reason:
            'TutoredChildrenSection must handle pendingGrants separately from '
            'activeGrants',
      );
      expect(
        sectionSrc,
        contains('PendingGrant'),
        reason: 'Section must filter by PendingGrant state',
      );
    });

    test('AC3: Section has a "View invitations" row navigating to '
        'ManageGrantsRoute', () {
      expect(
        sectionSrc,
        contains('ManageGrantsRoute'),
        reason:
            'TutoredChildrenSection must navigate to ManageGrantsRoute for '
            '"View invitations" (DEC-8)',
      );
      expect(
        sectionSrc,
        contains('_ViewInvitationsRow'),
        reason:
            'Section must render a _ViewInvitationsRow when pending invites exist',
      );
    });

    test('AC4a: AcceptInviteScreen loads real grant from provider', () {
      expect(
        acceptInviteSrc,
        contains('incomingTutorGrantsProvider.future'),
        reason:
            'accept_invite_screen.dart must load the real grant from '
            'incomingTutorGrantsProvider (WS3.3b fix of the hard-coded stub)',
      );
    });

    test(
      'AC4b: AcceptInviteScreen falls back to stub when grant not in list',
      () {
        expect(
          acceptInviteSrc,
          contains('_loadedGrant ?? _buildStubGrant'),
          reason:
              'accept_invite_screen.dart must use real grant when available, '
              'falling back to stub if grant not yet cached',
        );
      },
    );
  });
}
