// tutored_wipe_wrong_id_test.dart — D18 MIRROR-WIPE WRONG-ID regression
//
// Verifies that the D18 revoke-reconcile wipe uses the tutor's owning
// accounts.id rather than a stale id derived from currentAccountIdProvider,
// which during an active TUTORED session resolves to the talmid's
// learner_profiles.id (a different integer).
//
// Test layout:
//   DB seeded with:
//     accounts row            → id = A  (tutor's real account id)
//     learner_profiles (own)  → id = P1, account_id = A
//     learner_profiles (mirror) → id = P2, account_id = A, is_tutored=true, grant_id='grant-1'
//
//   During a tutored session currentAccountIdProvider resolves to the
//   talmid's local profile id.  In the legacy shared-DB edge case that value
//   can equal P2 (the mirror's learner_profiles.id) or any value != A.
//
//   RED path (old D18 bug):
//     getTutoredMirrorsForAccount(P2) ← using talmid profile id as account id
//     → returns [] because learner_profiles.account_id = A ≠ P2
//     → wipe loop body never runs; stale mirror survives
//
//   GREEN path (fixed):
//     wipeRevokedMirrors(ownerAccountId: A, activeGrantIds: {})
//     → getTutoredMirrorsForAccount(A) returns the mirror row
//     → wipeMirrorForGrant('grant-1') deletes the row
//     → mirror gone ✓
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/tutored_mirror_wipe_service.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../helpers/test_database.dart';

// ---------------------------------------------------------------------------
// Helpers — duplicated locally so this test is self-contained and readable.
// ---------------------------------------------------------------------------

Future<int> _seedAccount(UserDatabase db) async => db
    .into(db.accounts)
    .insert(
      AccountsCompanion.insert(
        email: 'tutor@example.com',
        tier: 'localBorn',
        displayName: 'Tutor',
        createdAt: DateTimeFactory.nowUtc(),
        updatedAt: DateTimeFactory.nowUtc(),
      ),
    );

Future<int> _seedOwnProfile(UserDatabase db, int accountId) async => db
    .into(db.learnerProfiles)
    .insert(
      LearnerProfilesCompanion.insert(
        accountId: accountId,
        displayName: 'Tutor Own Profile',
        mode: 'adult',
        createdAt: DateTimeFactory.nowUtc(),
        updatedAt: DateTimeFactory.nowUtc(),
      ),
    );

Future<int> _seedTutoredMirror(
  UserDatabase db, {
  required int accountId,
  required String grantId,
}) async => db.profileDao.upsertTutoredProfile(
  accountId: accountId,
  parentUid: 'parent-uid',
  remoteChildProfileId: 'remote-child',
  grantId: grantId,
  displayName: 'Child',
  mode: 'child',
  now: DateTimeFactory.nowUtc(),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('D18 MIRROR-WIPE WRONG-ID — wipeRevokedMirrors', () {
    // Arrange shared state for all sub-tests:
    //   accountId (A)  = accounts.id of the tutor
    //   ownProfileId   = learner_profiles.id of the tutor's own profile
    //   mirrorId (P2)  = learner_profiles.id of the talmid mirror row
    //
    // During an active tutored session, currentAccountIdProvider can return
    // ownProfileId or mirrorId — any value that is NOT accountId causes the
    // old path to miss the mirror.

    test('OLD PATH (reproduces bug): getTutoredMirrorsForAccount with wrong id '
        'returns empty and mirror is NOT wiped', () async {
      // accounts.id = A (auto-assigned, e.g. 1)
      // learner_profiles.id for own profile = P1 (auto-assigned, same as A in
      //   a fresh per-user DB where both tables start at 1)
      // learner_profiles.id for talmid mirror = P2 (= A + 1 in a fresh DB)
      //
      // The bug: during a TUTORED session currentAccountIdProvider can yield
      // P2 (the mirror's learner_profiles.id) instead of A (accounts.id).
      // getTutoredMirrorsForAccount(P2) filters on account_id = A so returns
      // empty → wipe is skipped.
      final accountId = await _seedAccount(db); // A
      await _seedOwnProfile(db, accountId); // P1 (= A in fresh DB)
      final mirrorId = await _seedTutoredMirror(
        db,
        accountId: accountId,
        grantId: 'grant-1',
      ); // P2 (= A + 1 in fresh DB) — different from accountId

      // Confirm the talmid mirror id is distinct from the account id.
      // If they were equal the bug would not manifest (lucky coincidence).
      expect(
        mirrorId,
        isNot(equals(accountId)),
        reason:
            'test precondition: mirror learner_profiles.id must differ from accounts.id',
      );

      // Old D18 path: getTutoredMirrorsForAccount(mirrorId)
      // account_id column = A; we query with P2 → empty result → no wipe.
      final mirrors = await db.profileDao.getTutoredMirrorsForAccount(
        mirrorId, // wrong id — talmid's learner_profiles.id
      );
      expect(
        mirrors,
        isEmpty,
        reason:
            'query with talmid learner_profiles.id returns empty — '
            'this IS the bug; mirror is NOT found and wipe is silently skipped',
      );

      // Confirm the mirror row is still present (bug: stale mirror survives).
      final mirrorRow = await db.profileDao.getProfileById(mirrorId);
      expect(
        mirrorRow,
        isNotNull,
        reason: 'mirror NOT wiped — stale row persists (the bug)',
      );

      // Sanity: correct id DOES find the mirror.
      final mirrorsViaCorrectId = await db.profileDao
          .getTutoredMirrorsForAccount(accountId);
      expect(
        mirrorsViaCorrectId,
        hasLength(1),
        reason: 'only accounts.id finds the mirror — confirms the bug path',
      );
    });

    test(
      'NEW PATH (fix): wipeRevokedMirrors with ownerAccountId from accounts table '
      'wipes the mirror even when called with no active grants',
      () async {
        final accountId = await _seedAccount(db); // A
        await _seedOwnProfile(db, accountId); // P1 — must not be deleted
        final mirrorId = await _seedTutoredMirror(
          db,
          accountId: accountId,
          grantId: 'grant-1',
        ); // P2

        // Simulate the D18 CF success path: grants list is now empty (revoked).
        // The fixed path resolves ownerAccountId directly from accounts.id (A),
        // not from currentAccountIdProvider.
        final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
        await svc.wipeRevokedMirrors(
          ownerAccountId: accountId, // A — correct, from accounts table
          activeGrantIds: const {}, // grant-1 is not active → should be wiped
        );

        // Mirror row must be gone.
        expect(
          await db.profileDao.getProfileById(mirrorId),
          isNull,
          reason:
              'mirror wiped by wipeRevokedMirrors with correct ownerAccountId',
        );
      },
    );

    test(
      'NEW PATH: wipeRevokedMirrors preserves mirrors still in activeGrantIds',
      () async {
        final accountId = await _seedAccount(db);
        await _seedOwnProfile(db, accountId);
        final keepMirrorId = await _seedTutoredMirror(
          db,
          accountId: accountId,
          grantId: 'grant-keep',
        );
        final wipeMirrorId = await db.profileDao.upsertTutoredProfile(
          accountId: accountId,
          parentUid: 'parent-uid-2',
          remoteChildProfileId: 'remote-child-2',
          grantId: 'grant-wipe',
          displayName: 'Child 2',
          mode: 'child',
          now: DateTimeFactory.nowUtc(),
        );

        final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
        await svc.wipeRevokedMirrors(
          ownerAccountId: accountId,
          activeGrantIds: const {'grant-keep'}, // grant-keep is still active
        );

        // grant-keep mirror preserved.
        expect(
          await db.profileDao.getProfileById(keepMirrorId),
          isNotNull,
          reason: 'active grant mirror must survive',
        );
        // grant-wipe mirror deleted.
        expect(
          await db.profileDao.getProfileById(wipeMirrorId),
          isNull,
          reason: 'revoked grant mirror must be wiped',
        );
      },
    );

    test(
      'NEW PATH: wipeRevokedMirrors is idempotent when no mirrors exist',
      () async {
        final accountId = await _seedAccount(db);
        await _seedOwnProfile(db, accountId);

        final svc = TutoredMirrorWipeService(profileDao: db.profileDao);
        // Should not throw.
        await svc.wipeRevokedMirrors(
          ownerAccountId: accountId,
          activeGrantIds: const {},
        );
      },
    );

    test(
      'NEW PATH: wipeRevokedMirrors fires onWipe for each wiped grant',
      () async {
        final accountId = await _seedAccount(db);
        await _seedTutoredMirror(db, accountId: accountId, grantId: 'grant-A');
        await db.profileDao.upsertTutoredProfile(
          accountId: accountId,
          parentUid: 'parent-uid-2',
          remoteChildProfileId: 'remote-2',
          grantId: 'grant-B',
          displayName: 'Child B',
          mode: 'child',
          now: DateTimeFactory.nowUtc(),
        );

        final wiped = <String>[];
        final svc = TutoredMirrorWipeService(
          profileDao: db.profileDao,
          onWipe: wiped.add,
        );
        await svc.wipeRevokedMirrors(
          ownerAccountId: accountId,
          activeGrantIds: const {}, // both revoked
        );

        expect(wiped, containsAll(['grant-A', 'grant-B']));
        expect(wiped.length, 2);
      },
    );
  });
}
