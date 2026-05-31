// D18: a parent-revoked talmid must NOT resurrect as ACTIVE on the tutor's
// device. `incomingTutorGrantsProvider` reconciles the locally-mirrored
// talmidim against the Cloud Function result — but ONLY when the CF call
// genuinely succeeded (online). On a confirmed success a mirror whose grant is
// no longer active/pending is wiped; on an offline failure the mirror is kept.

@Tags(['tutoring'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart'
    show currentAccountIdProvider;
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/use_cases/tutor_invite_use_cases.dart';
// The manual incomingTutorGrantsProvider (with the D18 mirror reconciliation)
// lives here; hide the same-named codegen provider from tutor_grant_providers.
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show tutorGrantRepositoryProvider;

import '../../helpers/drift_memory.dart';

/// Fake repository whose incoming-grants call returns a fixed (grants, ok)
/// outcome so the test controls online-success vs offline-failure.
class _FakeRepo extends Fake implements TutorGrantRepository {
  _FakeRepo({required this.grants, required this.ok});
  final List<TutorGrant> grants;
  final bool ok;

  @override
  Future<({List<TutorGrant> grants, bool ok})>
  listIncomingGrantsWithStatus() async => (grants: grants, ok: ok);

  @override
  Future<List<TutorGrant>> listIncomingGrants() async => grants;
}

void main() {
  ProviderContainer makeContainer(_FakeRepo repo, UserDatabase db) {
    final c = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        currentAccountIdProvider.overrideWithValue(1),
        authStateProvider.overrideWithValue(
          const AuthState.signedIn(
            user: AuthUser(
              profileId: 1,
              email: 't@t.com',
              displayName: 'Tutor',
              firebaseUid: 'tutor-uid',
            ),
            tier: Tier.cloudBorn,
          ),
        ),
        tutorGrantRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<void> seedRevokedMirror(UserDatabase db) async {
    await db.profileDao.upsertTutoredProfile(
      accountId: 1,
      parentUid: 'parent-uid',
      remoteChildProfileId: 'remote-child-1',
      grantId: 'g-revoked',
      displayName: 'Talmid',
      mode: 'child',
      now: DateTime.utc(2026, 5, 30),
    );
  }

  test('D18: CF SUCCESS without the grant → mirror wiped, talmid does not '
      'resurrect', () async {
    final db = inMemoryDb();
    addTearDown(db.close);
    await seedProfile(db); // account 1
    await seedRevokedMirror(db);

    // CF succeeded (online) and returned NO grants — the grant was revoked.
    final container = makeContainer(_FakeRepo(grants: const [], ok: true), db);

    final result = await container.read(incomingTutorGrantsProvider.future);

    expect(result, isEmpty, reason: 'revoked talmid must not appear');
    expect(
      await db.profileDao.getTutoredMirrorsForAccount(1),
      isEmpty,
      reason: 'the stale mirror must be wiped on an authoritative success',
    );
  });

  test(
    'D18: CF OFFLINE failure → mirror retained, cached talmid still visible',
    () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      await seedProfile(db);
      await seedRevokedMirror(db);

      // CF failed (offline) — must NOT wipe; keep the cached talmid.
      final container = makeContainer(
        _FakeRepo(grants: const [], ok: false),
        db,
      );

      final result = await container.read(incomingTutorGrantsProvider.future);

      expect(
        result,
        hasLength(1),
        reason: 'cached talmid reconstructed offline',
      );
      expect(result.single.grantId, 'g-revoked');
      expect(
        await db.profileDao.getTutoredMirrorsForAccount(1),
        hasLength(1),
        reason: 'mirror retained on offline failure',
      );
    },
  );
}
