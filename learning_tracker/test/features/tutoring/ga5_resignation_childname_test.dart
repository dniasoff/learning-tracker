/// GA-5 regression test — Tutor-grant resignation notification passes raw
/// childProfileId instead of the resolved child display label.
///
/// Root cause:
///   manage_grants_screen.dart:250 passes `widget.grant.childProfileId`
///   (raw Firestore id string) as `childName` to `notifyParentOfResignation`.
///   decline_invite_screen.dart:126 similarly passes `grant.childProfileId`
///   to `notifyParentOfDecline`.
///   Both should use `grant.childDisplayLabel` — the human-readable name.
///
/// Fix: Replace `childProfileId` with `childDisplayLabel` in the
/// `notifyParentOfResignation` and `notifyParentOfDecline` call sites.
///
/// This test verifies the domain-level contract: `childDisplayLabel` returns
/// the denormalised child name when available, and a generic fallback otherwise
/// — never the raw Firestore profile id.
///
/// AUD-t-tutoring-04 (TQ-8): the tests above only ever call the local
/// `_brokenChildNameArg`/`_fixedChildNameArg` proxy functions — they never
/// pump the real screens, so a future regression in either call site would
/// not be caught. The two `testWidgets` groups below close that gap: they
/// pump the real `ManageGrantsScreen` / `DeclineInviteScreen`, drive the
/// resign/decline flow through the UI, and capture (via mocktail
/// `captureAny`) the actual `childName` argument each screen passes to
/// `notifyParentOfResignation`/`notifyParentOfDecline`.
@Tags(['gamification', 'ga5', 'tutoring'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/app_user.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/services/tutor_notification_service.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_grant_use_cases.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
// `declineTutorInviteUseCaseProvider` only — `tutor_grant_providers.dart`
// also generates its own (network-only, unused by these screens)
// `resignTutorGrantUseCaseProvider`, which collides with the offline-first
// one imported above from `manage_tutors_providers.dart` (the one the real
// `ManageGrantsScreen` actually reads).
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show declineTutorInviteUseCaseProvider;
import 'package:learning_tracker/features/tutoring/presentation/screens/decline_invite_screen.dart';
import 'package:learning_tracker/features/tutoring/presentation/screens/manage_grants_screen.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/drift_memory.dart';
import '../../helpers/pump_app.dart';

TutorGrant _makeGrant({
  String childProfileId = 'raw_firestore_profile_id_123',
  String? childName,
  TutorGrantState state = TutorGrantState.active,
}) {
  final now = DateTime.utc(2026);
  final doc = TutorGrantDoc(
    grantId: 'grant_abc',
    parentUid: 'parent_uid',
    childProfileId: childProfileId,
    tutorEmail: 'tutor@example.com',
    state: state,
    invitedAt: now,
    updatedAt: now,
    acceptedAt: state == TutorGrantState.active ? now : null,
    expiresAt: state == TutorGrantState.pending
        ? now.add(const Duration(days: 7))
        : null,
    childName: childName,
    parentName: 'Parent',
  );
  return TutorGrant.fromDoc(doc);
}

// ── Mocks for the widget-pump regression tests below ────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockResignUseCase extends Mock implements ResignTutorGrantUseCase {}

class _MockDeclineUseCase extends Mock implements DeclineTutorInviteUseCase {}

class _MockNotificationGateway extends Mock
    implements TutorNotificationGateway {}

// Fake for registerFallbackValue so `any(named: 'grant')` works with mocktail.
class _FakeTutorGrant extends Fake implements TutorGrant {}

const _kFakeTutor = AppUser(
  uid: 'tutor-uid-1',
  email: 'tutor@example.com',
  displayName: 'Test Tutor',
  emailVerified: true,
  providers: ['password'],
);

/// Simulates the (broken) call site in manage_grants_screen.dart before fix:
/// passes `grant.childProfileId` as the child name.
String _brokenChildNameArg(TutorGrant grant) => grant.childProfileId;

/// The correct call site after fix: passes `grant.childDisplayLabel`.
String _fixedChildNameArg(TutorGrant grant) => grant.childDisplayLabel;

void main() {
  setUpAll(() {
    // mocktail requires a registered fallback value for any type used with
    // `any(named: 'grant')` / `captureAny(named: 'grant')`.
    registerFallbackValue(_FakeTutorGrant());
  });

  group('GA-5: resignation notification uses childDisplayLabel', () {
    test(
      'when childName is set, childDisplayLabel returns the name (not raw id)',
      () {
        final grant = _makeGrant(
          childProfileId: 'raw_id_456',
          childName: 'Yosef Cohen',
        );

        expect(
          grant.childDisplayLabel,
          equals('Yosef Cohen'),
          reason: 'childDisplayLabel should return the human-readable name',
        );
        expect(
          grant.childDisplayLabel,
          isNot(equals(grant.childProfileId)),
          reason: 'childDisplayLabel must NOT equal the raw Firestore id',
        );
      },
    );

    test('broken call site passes raw id — this is the bug', () {
      final grant = _makeGrant(
        childProfileId: 'raw_id_456',
        childName: 'Yosef Cohen',
      );

      // The broken call site passes childProfileId to childName param
      final brokenArg = _brokenChildNameArg(grant);
      expect(
        brokenArg,
        equals('raw_id_456'),
        reason: 'broken call site sends raw Firestore id as child name',
      );
      // This is wrong — the raw id should NOT be the child name in the notification
      expect(
        brokenArg,
        isNot(equals('Yosef Cohen')),
        reason:
            'confirms the broken arg is not the human-readable name (bug still present)',
      );
    });

    test('fixed call site passes childDisplayLabel — this is the fix', () {
      final grant = _makeGrant(
        childProfileId: 'raw_id_456',
        childName: 'Yosef Cohen',
      );

      final fixedArg = _fixedChildNameArg(grant);
      expect(
        fixedArg,
        equals('Yosef Cohen'),
        reason: 'fixed call site sends the human-readable display label',
      );
    });

    test(
      'when childName is null, childDisplayLabel returns generic fallback',
      () {
        final grant = _makeGrant(childProfileId: 'raw_id_789', childName: null);

        expect(
          grant.childDisplayLabel,
          isNot(equals('raw_id_789')),
          reason:
              'childDisplayLabel should never expose the raw Firestore id even as fallback',
        );
        expect(
          grant.childDisplayLabel,
          isNotEmpty,
          reason: 'fallback must be non-empty',
        );
      },
    );

    test(
      'manage_grants notification call passes childDisplayLabel not childProfileId',
      () {
        // This test codifies the EXPECTED call-site behavior after the fix.
        // In the fixed code, manage_grants_screen.dart should call:
        //   notifyParentOfResignation(..., childName: widget.grant.childDisplayLabel)
        // rather than:
        //   notifyParentOfResignation(..., childName: widget.grant.childProfileId)
        //
        // We simulate the call with a grant that has a real child name.
        final grant = _makeGrant(
          childProfileId: 'some_raw_profile_id',
          childName: 'Avraham Levy',
        );

        // Simulate what the FIXED code will pass as childName arg
        final childNameArgAfterFix = grant.childDisplayLabel;

        expect(
          childNameArgAfterFix,
          equals('Avraham Levy'),
          reason:
              'After fix, notification childName param must be the display label',
        );
        expect(
          childNameArgAfterFix,
          isNot(equals('some_raw_profile_id')),
          reason: 'Raw profile id must not appear as the childName param',
        );
      },
    );

    test(
      'decline_invite notification call also uses childDisplayLabel not childProfileId',
      () {
        // decline_invite_screen.dart:126 also passes grant.childProfileId
        // to notifyParentOfDecline — same bug, same fix.
        final grant = _makeGrant(
          childProfileId: 'raw_decline_id',
          childName: 'Miriam Klein',
        );

        // Before fix: would pass grant.childProfileId ('raw_decline_id')
        // After fix: passes grant.childDisplayLabel ('Miriam Klein')
        expect(grant.childDisplayLabel, equals('Miriam Klein'));
        expect(grant.childDisplayLabel, isNot(equals('raw_decline_id')));
      },
    );
  });

  // ── AUD-t-tutoring-04: real call-site regression coverage ──────────────────
  //
  // Unlike the tests above (which exercise the hand-written
  // `_brokenChildNameArg`/`_fixedChildNameArg` proxies), these two groups
  // pump the ACTUAL `ManageGrantsScreen` / `DeclineInviteScreen`, drive the
  // resign/decline flow through real widget interaction, and capture the
  // real argument passed to the notification gateway via mocktail
  // `captureAny`. Reverting either screen's `childName: grant.childProfileId`
  // regression locally makes the corresponding test below fail.

  group('AUD-t-tutoring-04: ManageGrantsScreen resign flow uses '
      'childDisplayLabel at the real call site', () {
    testWidgets('confirming resign sends notifyParentOfResignation with '
        'childDisplayLabel, not childProfileId', (tester) async {
      final grant = _makeGrant(
        childProfileId: 'raw_manage_grants_profile_id',
        childName: 'Chaim Weiss',
      );

      final authRepo = _MockAuthRepository();
      final resignUseCase = _MockResignUseCase();
      final notificationGateway = _MockNotificationGateway();
      final db = inMemoryDb();
      addTearDown(db.close);

      when(() => authRepo.currentUser).thenReturn(_kFakeTutor);
      when(
        () => resignUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());
      when(
        () => notificationGateway.notifyParentOfResignation(
          parentEmail: any(named: 'parentEmail'),
          parentUid: any(named: 'parentUid'),
          tutorName: any(named: 'tutorName'),
          childName: any(named: 'childName'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        pumpApp(
          child: const ManageGrantsScreen(),
          retry: (_, __) => null,
          overrides: [
            incomingTutorGrantsProvider.overrideWith(
              (ref) => Future.value([grant]),
            ),
            resignTutorGrantUseCaseProvider.overrideWithValue(resignUseCase),
            authRepositoryProvider.overrideWithValue(authRepo),
            tutorNotificationGatewayProvider.overrideWithValue(
              notificationGateway,
            ),
            userDatabaseProvider.overrideWithValue(db),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Open the row's resign confirmation dialog, then confirm inside it.
      await tester.tap(find.text('Resign'));
      await tester.pump();
      await tester.tap(find.text('Resign').last);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => notificationGateway.notifyParentOfResignation(
          parentEmail: any(named: 'parentEmail'),
          parentUid: any(named: 'parentUid'),
          tutorName: any(named: 'tutorName'),
          childName: captureAny(named: 'childName'),
        ),
      ).captured;
      expect(
        captured,
        hasLength(1),
        reason: 'notifyParentOfResignation must be called exactly once',
      );
      final childNameArg = captured.single as String;

      expect(
        childNameArg,
        equals('Chaim Weiss'),
        reason:
            'The real manage_grants_screen.dart call site must pass '
            'grant.childDisplayLabel (the human-readable name).',
      );
      expect(
        childNameArg,
        isNot(equals('raw_manage_grants_profile_id')),
        reason:
            'The real call site must NOT pass the raw childProfileId — '
            'this is the GA-5 regression this test guards against.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('AUD-t-tutoring-04: DeclineInviteScreen decline flow uses '
      'childDisplayLabel at the real call site', () {
    testWidgets('confirming decline sends notifyParentOfDecline with '
        'childDisplayLabel, not childProfileId', (tester) async {
      final grant = _makeGrant(
        childProfileId: 'raw_decline_invite_profile_id',
        childName: 'Miriam Klein',
        state: TutorGrantState.pending,
      );

      final authRepo = _MockAuthRepository();
      final declineUseCase = _MockDeclineUseCase();
      final notificationGateway = _MockNotificationGateway();

      when(() => authRepo.currentUser).thenReturn(_kFakeTutor);
      when(
        () => declineUseCase.call(grant: any(named: 'grant')),
      ).thenAnswer((_) async => const TutorGrantSuccess());
      when(
        () => notificationGateway.notifyParentOfDecline(
          parentEmail: any(named: 'parentEmail'),
          parentUid: any(named: 'parentUid'),
          tutorEmail: any(named: 'tutorEmail'),
          childName: any(named: 'childName'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        pumpApp(
          child: DeclineInviteScreen(grant: grant, onDeclined: () {}),
          retry: (_, __) => null,
          overrides: [
            declineTutorInviteUseCaseProvider.overrideWithValue(declineUseCase),
            authRepositoryProvider.overrideWithValue(authRepo),
            tutorNotificationGatewayProvider.overrideWithValue(
              notificationGateway,
            ),
          ],
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.tap(find.text('Decline invite'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      final captured = verify(
        () => notificationGateway.notifyParentOfDecline(
          parentEmail: any(named: 'parentEmail'),
          parentUid: any(named: 'parentUid'),
          tutorEmail: any(named: 'tutorEmail'),
          childName: captureAny(named: 'childName'),
        ),
      ).captured;
      expect(
        captured,
        hasLength(1),
        reason: 'notifyParentOfDecline must be called exactly once',
      );
      final childNameArg = captured.single as String;

      expect(
        childNameArg,
        equals('Miriam Klein'),
        reason:
            'The real decline_invite_screen.dart call site must pass '
            'grant.childDisplayLabel (the human-readable name).',
      );
      expect(
        childNameArg,
        isNot(equals('raw_decline_invite_profile_id')),
        reason:
            'The real call site must NOT pass the raw childProfileId — '
            'this is the GA-5 regression this test guards against.',
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
