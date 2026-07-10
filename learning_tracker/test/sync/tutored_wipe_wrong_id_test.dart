// tutored_wipe_wrong_id_test.dart — D18 MIRROR-WIPE WRONG-ID regression
//
// AUD-core-sync-28: this file originally guarded a `wipeRevokedMirrors` /
// `resolveOwnerAccountIdForWipe` fix pair that was built but never wired into
// production (see git history for the removed code). Re-verifying the
// premise against the shipped code shows the claimed hazard does not exist:
//
//   `currentAccountIdProvider` (profile_providers.dart) is derived ONLY from
//   `authStateProvider.currentUser?.profileId`, which in turn is set only by
//   `AuthStateNotifier`'s Firebase/local-account resolution
//   (`_init`, `setCloudBornSession`, `setLocalBornSession`,
//   `setCloudBornSessionFromFirebaseUser`) — none of which read
//   `activeTutoredProfileSelectionProvider` or
//   `resolvedTutoredLocalProfileIdProvider` (the providers that DO carry the
//   talmid's local `learner_profiles.id` during a tutored session — see
//   `activeProfileIdProvider` in active_profile_provider.dart, a completely
//   separate provider). So `currentAccountIdProvider` cannot resolve to the
//   talmid's `learner_profiles.id`: it always yields the tutor's own
//   `accounts.id`, tutored session or not.
//
// This file now:
//   (1) proves that claim directly — entering a tutored session does not
//       move `currentAccountIdProvider`;
//   (2) exercises the REAL shipped revoke-reconcile mechanics (the
//       `getTutoredMirrorsForAccount` + `TutoredMirrorWipeService
//       .wipeMirrorForGrant` loop that `incomingTutorGrantsProvider` in
//       manage_tutors_providers.dart runs inline), scoped by the tutor's real
//       `accounts.id`, and shows a revoked mirror is wiped while an
//       still-active one survives.
//
// The full-container version of (2) — including the CF success/offline-failure
// branching — is covered by
// test/features/tutoring/incoming_tutor_grants_reconcile_test.dart; this file
// stays focused on the id-resolution question the original D18 regression was
// about.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/tutored_mirror_wipe_service.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show currentAccountIdProvider;
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

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

/// Runs the same reconcile mechanics `incomingTutorGrantsProvider` runs
/// inline on a confirmed CF success: wipe every mirror for [accountId] whose
/// grant id is not in [activeGrantIds].
Future<void> _reconcileRevokedMirrors(
  UserDatabase db, {
  required int accountId,
  required Set<String> activeGrantIds,
  void Function(String grantId)? onWipe,
}) async {
  final svc = TutoredMirrorWipeService(
    profileDao: db.profileDao,
    onWipe: onWipe,
  );
  final mirrors = await db.profileDao.getTutoredMirrorsForAccount(accountId);
  for (final m in mirrors) {
    final gid = m.tutorGrantId;
    if (gid != null && !activeGrantIds.contains(gid)) {
      await svc.wipeMirrorForGrant(gid);
    }
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  group('D18 MIRROR-WIPE — currentAccountIdProvider id-resolution', () {
    test(
      'currentAccountIdProvider stays fixed to the tutor\'s accounts.id even '
      'while a tutored session is active (refutes the retired D18 docstring '
      'claim that it can resolve to the talmid\'s learner_profiles.id)',
      () async {
        final accountId = await _seedAccount(db); // A
        await _seedOwnProfile(db, accountId); // P1
        final mirrorId = await _seedTutoredMirror(
          db,
          accountId: accountId,
          grantId: 'grant-1',
        ); // P2

        // Precondition: the mirror's local learner_profiles.id must differ
        // from accounts.id, otherwise a leak couldn't be observed here.
        expect(
          mirrorId,
          isNot(equals(accountId)),
          reason:
              'test precondition: mirror learner_profiles.id must differ '
              'from accounts.id',
        );

        final container = ProviderContainer(
          overrides: [
            userDatabaseProvider.overrideWithValue(db),
            authStateProvider.overrideWithValue(
              AuthState.signedIn(
                user: AuthUser(
                  profileId: accountId,
                  email: 'tutor@example.com',
                  displayName: 'Tutor',
                  firebaseUid: 'tutor-uid',
                ),
                tier: Tier.localBorn,
              ),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Before entering a tutored session: resolves to the tutor's own id.
        expect(container.read(currentAccountIdProvider), accountId);

        // Enter a tutored session whose resolved local mirror id IS the
        // talmid's learner_profiles.id — the exact scenario the retired D18
        // docstring claimed would leak into currentAccountIdProvider.
        container
            .read(activeTutoredProfileSelectionProvider.notifier)
            .enter(
              const TutoredProfileSelection(
                profileId: 'remote-child',
                ownerUid: 'parent-uid',
                grantId: 'grant-1',
                permissions: TutorPermissions(),
              ),
            );
        container
            .read(resolvedTutoredLocalProfileIdProvider.notifier)
            .resolve(mirrorId);

        // The claim under test: currentAccountIdProvider must NOT have
        // picked up the talmid's mirror id — it stays the tutor's accounts.id.
        expect(
          container.read(currentAccountIdProvider),
          accountId,
          reason:
              'currentAccountIdProvider is derived from authStateProvider '
              'only; it is architecturally independent of '
              'activeTutoredProfileSelectionProvider and '
              'resolvedTutoredLocalProfileIdProvider, so it cannot resolve '
              'to the talmid\'s learner_profiles.id',
        );
      },
    );
  });

  group('D18 MIRROR-WIPE — real shipped reconcile path', () {
    test('reconcile wipes a mirror whose grant is no longer active, scoped by '
        'the tutor\'s real accounts.id', () async {
      final accountId = await _seedAccount(db); // A
      await _seedOwnProfile(db, accountId); // P1 — must not be deleted
      final mirrorId = await _seedTutoredMirror(
        db,
        accountId: accountId,
        grantId: 'grant-1',
      ); // P2

      // Simulate the D18 CF success path: grants list is now empty (revoked).
      await _reconcileRevokedMirrors(
        db,
        accountId: accountId,
        activeGrantIds: const {},
      );

      // Mirror row must be gone.
      expect(
        await db.profileDao.getProfileById(mirrorId),
        isNull,
        reason: 'mirror wiped by the real reconcile path using accounts.id',
      );
      // Tutor's own profile must be untouched.
      expect(await db.profileDao.getProfileById(accountId), isNotNull);
    });

    test('reconcile preserves mirrors still in activeGrantIds', () async {
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

      await _reconcileRevokedMirrors(
        db,
        accountId: accountId,
        activeGrantIds: const {'grant-keep'},
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
    });

    test('reconcile is idempotent when no mirrors exist', () async {
      final accountId = await _seedAccount(db);
      await _seedOwnProfile(db, accountId);

      // Should not throw.
      await _reconcileRevokedMirrors(
        db,
        accountId: accountId,
        activeGrantIds: const {},
      );
    });

    test('reconcile fires onWipe for each wiped grant', () async {
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
      await _reconcileRevokedMirrors(
        db,
        accountId: accountId,
        activeGrantIds: const {}, // both revoked
        onWipe: wiped.add,
      );

      expect(wiped, containsAll(['grant-A', 'grant-B']));
      expect(wiped.length, 2);
    });
  });
}
