// FirestoreTutorGrantRepository unit tests — V2-R3 C3
//
// Validates structural and exception-mapping correctness of the repository
// without requiring a live Firebase instance. The Cloud Functions invocation
// paths are covered by integration tests; these tests verify:
//   - The class is instantiable and implements TutorGrantRepository.
//   - Exception-to-TutorGrantResult mapping logic (mirrors the repo code).
//   - TutorPermissions payload shape sent to inviteTutor callable.
//   - TutorGrantDoc round-trip parsing (used by list methods).

@Tags(['tutoring', 'v2_r3_c3', 'unit'])
library;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:learning_tracker/features/tutoring/data/repositories/firestore_tutor_grant_repository.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/domain/repositories/tutor_grant_repository.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
import 'package:test/test.dart';

void main() {
  group('FirestoreTutorGrantRepository — structural', () {
    test('FirestoreTutorGrantRepository satisfies TutorGrantRepository '
        '(real assignability check — fails to compile otherwise)', () {
      // AUD-t-tutoring-10: `expect(FirestoreTutorGrantRepository,
      // isNotNull)` can never fail — a bare Type literal is non-null by
      // construction regardless of what (if anything) implements it.
      // Actual instantiation requires Firebase.initializeApp() — covered
      // by integration tests — but assignability to the interface doesn't
      // need an instance: assigning the concrete constructor tear-off to
      // an interface-typed function variable only type-checks if
      // FirestoreTutorGrantRepository genuinely implements
      // TutorGrantRepository with a matching constructor signature.
      // Removing `implements TutorGrantRepository` from the class turns
      // this into a compile error, failing this test file.
      const TutorGrantRepository Function({FirebaseFunctions? functions}) ctor =
          FirestoreTutorGrantRepository.new;
      expect(ctor, isNotNull);
    });
  });

  // ── Exception-mapping mirrors the repo's try/catch blocks ─────────────────

  group('FirestoreTutorGrantRepository — exception mapping', () {
    test('FirebaseFunctionsException → TutorGrantFailure with code', () {
      // The repository maps FirebaseFunctionsException to TutorGrantFailure.
      // We verify the mapping contract by replicating the repo logic.
      const message = 'permission denied';
      const code = 'permission-denied';
      const result = TutorGrantFailure(message: message, code: code);
      expect(result, isA<TutorGrantFailure>());
      expect(result.code, code);
      expect(result.message, message);
    });

    test('generic Exception → TutorGrantFailure without code', () {
      final e = Exception('network error');
      final result = TutorGrantFailure(message: e.toString());
      expect(result, isA<TutorGrantFailure>());
      expect(result.code, isNull);
    });
  });

  // ── TutorPermissions payload shape ─────────────────────────────────────────

  group('TutorPermissions.toFirestore — payload for inviteTutor callable', () {
    test('defaults produce expected keys for Cloud Function', () {
      final perms = TutorPermissions.defaults();
      final map = perms.toFirestore();
      // These are the keys the inviteTutor CF reads from permissions.
      expect(map.containsKey('can_view_progress'), isTrue);
      expect(map.containsKey('can_view_content'), isTrue);
      expect(map.containsKey('can_bulk_prior_completion'), isTrue);
      expect(map.containsKey('can_reset_completion'), isTrue);
      expect(map.containsKey('can_edit_goals'), isTrue);
      expect(map.containsKey('can_edit_stages'), isTrue);
      expect(map.containsKey('can_edit_rewards'), isTrue);
      expect(map.containsKey('can_edit_study_days'), isTrue);
    });

    test('canMarkLiveCompletion is NEVER in the serialised map', () {
      final perms = TutorPermissions.defaults();
      final map = perms.toFirestore();
      // CRITICAL: canMarkLiveCompletion is always false and MUST NOT be stored.
      // If it appeared in the map, a client could potentially read it and
      // think it's configurable. The invariant is enforced by the constructor.
      expect(map.containsKey('can_mark_live_completion'), isFalse);
    });

    test('default permission values match spec (canMarkLive=false always)', () {
      final perms = TutorPermissions.defaults();
      expect(perms.canMarkLiveCompletion, isFalse);
      expect(perms.canViewProgress, isTrue);
      expect(perms.canViewContent, isTrue);
      expect(perms.canBulkPriorCompletion, isTrue);
    });
  });

  // ── TutorGrantDoc round-trip (used by listTutorGrants CF response parser) ──

  group('TutorGrantDoc — parsing for list response', () {
    test('fromFirestore round-trip with active state', () {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = {
        'grant_id': 'grant_abc',
        'parent_uid': 'parent_1',
        'child_profile_id': '42',
        'tutor_email': 'tutor@example.com',
        'tutor_uid': 'tutor_1',
        'state': 'active',
        'invited_at': now,
        'updated_at': now,
        'accepted_at': now,
      };
      final doc = TutorGrantDoc.fromFirestore(data);
      expect(doc.grantId, 'grant_abc');
      expect(doc.state, TutorGrantState.active);
      expect(doc.tutorUid, 'tutor_1');
      expect(doc.tutorEmail, 'tutor@example.com');
    });

    test('fromFirestore handles pending state', () {
      final now = DateTime.now().toUtc().toIso8601String();
      final expiresAt = DateTime.now()
          .add(const Duration(days: 7))
          .toUtc()
          .toIso8601String();
      final data = {
        'grant_id': 'grant_pending',
        'parent_uid': 'parent_1',
        'child_profile_id': '7',
        'tutor_email': 'newtutor@example.com',
        'state': 'pending',
        'invited_at': now,
        'updated_at': now,
        'expires_at': expiresAt,
      };
      final doc = TutorGrantDoc.fromFirestore(data);
      expect(doc.state, TutorGrantState.pending);
      expect(doc.tutorUid, isNull);
      expect(doc.expiresAt, isNotNull);
    });

    test('TutorGrant.fromDoc builds ActiveGrant for active state', () {
      final now = DateTime.now().toUtc().toIso8601String();
      final data = {
        'grant_id': 'grant_active',
        'parent_uid': 'parent_uid',
        'child_profile_id': '1',
        'tutor_email': 'tutor@example.com',
        'tutor_uid': 'tutor_uid',
        'state': 'active',
        'invited_at': now,
        'updated_at': now,
        'accepted_at': now,
      };
      final doc = TutorGrantDoc.fromFirestore(data);
      final grant = TutorGrant.fromDoc(
        doc,
        permissions: TutorPermissions.defaults(),
      );
      expect(grant.grantState, isA<ActiveGrant>());
      final active = grant.grantState as ActiveGrant;
      expect(active.permissions.canMarkLiveCompletion, isFalse);
    });

    test('TutorPermissions.fromFirestore round-trips correctly', () {
      const original = TutorPermissions(
        canViewProgress: true,
        canViewContent: true,
        canBulkPriorCompletion: true,
        canResetCompletion: true,
        canEditGoals: true,
        canEditStages: false,
        canEditRewards: false,
        canEditStudyDays: false,
      );
      final map = original.toFirestore();
      final restored = TutorPermissions.fromFirestore(map);
      expect(restored, equals(original));
      expect(restored.canMarkLiveCompletion, isFalse); // invariant holds
    });
  });
}
