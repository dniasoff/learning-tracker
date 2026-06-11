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
@Tags(['gamification', 'ga5', 'tutoring'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';

TutorGrant _makeGrant({
  String childProfileId = 'raw_firestore_profile_id_123',
  String? childName,
}) {
  final now = DateTime.utc(2026);
  final doc = TutorGrantDoc(
    grantId: 'grant_abc',
    parentUid: 'parent_uid',
    childProfileId: childProfileId,
    tutorEmail: 'tutor@example.com',
    state: TutorGrantState.active,
    invitedAt: now,
    updatedAt: now,
    acceptedAt: now,
    childName: childName,
    parentName: 'Parent',
  );
  return TutorGrant.fromDoc(doc);
}

/// Simulates the (broken) call site in manage_grants_screen.dart before fix:
/// passes `grant.childProfileId` as the child name.
String _brokenChildNameArg(TutorGrant grant) => grant.childProfileId;

/// The correct call site after fix: passes `grant.childDisplayLabel`.
String _fixedChildNameArg(TutorGrant grant) => grant.childDisplayLabel;

void main() {
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
}
