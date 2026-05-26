// WS3.3g — Removal lifecycle notifications (DEC-23)
//
// Verifies that:
//   AC1 — tutorNotificationGatewayProvider is declared in
//          manage_tutors_providers.dart.
//   AC2 — manage_tutors_screen.dart (parent revokes) fires
//          notifyTutorOfRevocation via tutorNotificationGatewayProvider.
//   AC3 — manage_grants_screen.dart (tutor resigns) fires
//          notifyParentOfResignation via tutorNotificationGatewayProvider.
//   AC4 — decline_invite_screen.dart (tutor declines) fires
//          notifyParentOfDecline via tutorNotificationGatewayProvider.
//   AC5 — TutorNotificationGateway source exposes all three methods with
//          the correct named parameters.

@Tags(['ws3', 'ws3_3g', 'tutor_mode'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('WS3.3g — Removal lifecycle notifications (DEC-23)', () {
    late String manageTutorsProvidersSrc;
    late String manageTutorsScreenSrc;
    late String manageGrantsScreenSrc;
    late String declineInviteScreenSrc;
    late String notificationServiceSrc;

    setUpAll(() {
      manageTutorsProvidersSrc = File(
        'lib/features/tutoring/presentation/providers/manage_tutors_providers.dart',
      ).readAsStringSync();

      manageTutorsScreenSrc = File(
        'lib/features/tutoring/presentation/screens/manage_tutors_screen.dart',
      ).readAsStringSync();

      manageGrantsScreenSrc = File(
        'lib/features/tutoring/presentation/screens/manage_grants_screen.dart',
      ).readAsStringSync();

      declineInviteScreenSrc = File(
        'lib/features/tutoring/presentation/screens/decline_invite_screen.dart',
      ).readAsStringSync();

      notificationServiceSrc = File(
        'lib/features/tutoring/domain/services/tutor_notification_service.dart',
      ).readAsStringSync();
    });

    // ── AC1: Gateway provider declared ───────────────────────────────────────

    test('AC1: tutorNotificationGatewayProvider is declared', () {
      expect(
        manageTutorsProvidersSrc,
        contains('tutorNotificationGatewayProvider'),
        reason:
            'tutorNotificationGatewayProvider must be declared in '
            'manage_tutors_providers.dart (WS3.3g DEC-23)',
      );
    });

    test('AC1: provider wraps TutorNotificationGateway', () {
      expect(
        manageTutorsProvidersSrc,
        contains('TutorNotificationGateway'),
        reason:
            'tutorNotificationGatewayProvider must instantiate '
            'TutorNotificationGateway',
      );
    });

    test('AC1: provider wires transactionalEmailServiceProvider', () {
      expect(
        manageTutorsProvidersSrc,
        contains('transactionalEmailServiceProvider'),
        reason:
            'tutorNotificationGatewayProvider must inject '
            'transactionalEmailServiceProvider',
      );
    });

    // ── AC2: Revoke fires notifyTutorOfRevocation ─────────────────────────────

    test(
      'AC2: manage_tutors_screen references tutorNotificationGatewayProvider',
      () {
        expect(
          manageTutorsScreenSrc,
          contains('tutorNotificationGatewayProvider'),
          reason:
              'manage_tutors_screen.dart (parent revoke flow) must read '
              'tutorNotificationGatewayProvider to notify the tutor (DEC-23)',
        );
      },
    );

    test('AC2: manage_tutors_screen calls notifyTutorOfRevocation', () {
      expect(
        manageTutorsScreenSrc,
        contains('notifyTutorOfRevocation'),
        reason:
            'manage_tutors_screen.dart must call notifyTutorOfRevocation '
            'after a successful revoke',
      );
    });

    // ── AC3: Resign fires notifyParentOfResignation ───────────────────────────

    test(
      'AC3: manage_grants_screen references tutorNotificationGatewayProvider',
      () {
        expect(
          manageGrantsScreenSrc,
          contains('tutorNotificationGatewayProvider'),
          reason:
              'manage_grants_screen.dart (tutor resign flow) must read '
              'tutorNotificationGatewayProvider to notify the parent (DEC-23)',
        );
      },
    );

    test('AC3: manage_grants_screen calls notifyParentOfResignation', () {
      expect(
        manageGrantsScreenSrc,
        contains('notifyParentOfResignation'),
        reason:
            'manage_grants_screen.dart must call notifyParentOfResignation '
            'after a successful resign',
      );
    });

    // ── AC4: Decline fires notifyParentOfDecline ──────────────────────────────

    test(
      'AC4: decline_invite_screen references tutorNotificationGatewayProvider',
      () {
        expect(
          declineInviteScreenSrc,
          contains('tutorNotificationGatewayProvider'),
          reason:
              'decline_invite_screen.dart must read tutorNotificationGatewayProvider '
              'to notify the parent on decline (DEC-23)',
        );
      },
    );

    test('AC4: decline_invite_screen calls notifyParentOfDecline', () {
      expect(
        declineInviteScreenSrc,
        contains('notifyParentOfDecline'),
        reason:
            'decline_invite_screen.dart must call notifyParentOfDecline '
            'after a successful decline',
      );
    });

    // ── AC5: TutorNotificationGateway domain contract (source-scan) ──────────

    test(
      'AC5: notifyParentOfDecline method exists with correct parameters',
      () {
        expect(
          notificationServiceSrc,
          contains('notifyParentOfDecline('),
          reason: 'TutorNotificationGateway must have notifyParentOfDecline()',
        );
        expect(
          notificationServiceSrc,
          contains('required String parentEmail'),
          reason: 'notifyParentOfDecline must accept parentEmail parameter',
        );
        expect(
          notificationServiceSrc,
          contains('required String tutorEmail'),
          reason: 'notifyParentOfDecline must accept tutorEmail parameter',
        );
      },
    );

    test(
      'AC5: notifyParentOfResignation method exists with correct parameters',
      () {
        expect(
          notificationServiceSrc,
          contains('notifyParentOfResignation('),
          reason:
              'TutorNotificationGateway must have notifyParentOfResignation()',
        );
        expect(
          notificationServiceSrc,
          contains('required String tutorName'),
          reason: 'notifyParentOfResignation must accept tutorName parameter',
        );
      },
    );

    test(
      'AC5: notifyTutorOfRevocation method exists with correct parameters',
      () {
        expect(
          notificationServiceSrc,
          contains('notifyTutorOfRevocation('),
          reason:
              'TutorNotificationGateway must have notifyTutorOfRevocation()',
        );
        expect(
          notificationServiceSrc,
          contains('required String tutorEmail'),
          reason: 'notifyTutorOfRevocation must accept tutorEmail parameter',
        );
        expect(
          notificationServiceSrc,
          contains('required String parentName'),
          reason: 'notifyTutorOfRevocation must accept parentName parameter',
        );
      },
    );

    test('AC5: fire-and-forget — all methods return Future<void>', () {
      // Verify return type is Future<void> (fire-and-forget contract).
      expect(
        notificationServiceSrc,
        contains('Future<void> notifyParentOfDecline'),
        reason: 'notifyParentOfDecline must be Future<void> (fire-and-forget)',
      );
      expect(
        notificationServiceSrc,
        contains('Future<void> notifyParentOfResignation'),
        reason:
            'notifyParentOfResignation must be Future<void> (fire-and-forget)',
      );
      expect(
        notificationServiceSrc,
        contains('Future<void> notifyTutorOfRevocation'),
        reason:
            'notifyTutorOfRevocation must be Future<void> (fire-and-forget)',
      );
    });
  });
}
