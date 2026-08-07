/// Regression test for T-49 (P2-18): a late-settling activation heal must
/// never re-point [activeProfileDocIdProvider] at a profile that is no
/// longer the one selected.
///
/// **Why this test exists instead of a device/offline integration test.**
/// `fake_cloud_firestore` resolves every write synchronously and has no
/// offline queue/reconnect model, so the actual production trigger — an
/// offline-queued `DocumentReference.set()` that only acks after
/// reconnect, well after a DIFFERENT profile has since been selected — is
/// structurally impossible to reproduce against it. No test in this
/// repository can observe that. See
/// `docs/planning/firestore-cutover-log.md`'s `T-49` entry (deferred check
/// `D20`) for the full account of why a device check is the only thing
/// that proves the real scenario.
///
/// This test instead proves the DECIDABLE proxy the fake CAN see: inject a
/// delayed/awaitable Firestore double so profile A's heal write is still
/// in flight when profile B is selected and its own (undelayed) heal
/// settles first — the identical out-of-order-completion shape the real
/// bug has, driven by an injected delay rather than a real network
/// partition. It drives the REAL `SelectedProfileId.select()`
/// (`profile_providers.dart`) and the REAL
/// `FirestoreProfileRepositoryAdapter.ensureRemoteProfile`
/// (`profile_repository_impl.dart`) it dispatches unawaited — the delay is
/// injected one level below, at
/// `FirestoreLearnerProfileRepository.ensureProfile`, so this test
/// exercises the exact write `_ensureFirestoreProfile` awaits in
/// production, not a repository double that bypasses it entirely.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart'
    show activeAccountIdProvider;
import 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider, firestoreLearnerProfileRepositoryProvider;
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

import '../../../../helpers/test_database.dart';

/// Wraps a real [FirestoreLearnerProfileRepository] (backed by a
/// [FakeFirebaseFirestore], so [ensureProfile]'s write really happens) and
/// makes exactly ONE profile id's write await an externally-controlled
/// gate before delegating — simulating "this profile's heal write is
/// still in flight" without needing a real offline queue.
class _DelayableFirestoreLearnerProfileRepository
    extends FirestoreLearnerProfileRepository {
  _DelayableFirestoreLearnerProfileRepository({
    required super.firestore,
    required super.uid,
    required this.delayedProfileId,
    required this.releaseGate,
  });

  final String delayedProfileId;
  final Completer<void> releaseGate;

  @override
  Future<LearnerProfileEntity> ensureProfile({
    required String profileId,
    required String displayName,
    required ProfileMode mode,
    required DateTime createdAt,
    String avatar = '',
  }) async {
    if (profileId == delayedProfileId) {
      await releaseGate.future;
    }
    return super.ensureProfile(
      profileId: profileId,
      displayName: displayName,
      mode: mode,
      createdAt: createdAt,
      avatar: avatar,
    );
  }
}

void main() {
  test(
    'T-49: profile A\'s late-settling activation heal does not re-point '
    'activeProfileDocIdProvider at A after B has since been selected',
    () async {
      const uid = 'uid-t49-race';
      final db = createTestDatabase();
      addTearDown(db.close);
      final accountId = await seedAccount(db);

      const ulidA = 'ulid-t49-profile-a';
      const ulidB = 'ulid-t49-profile-b';
      final idA = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Profile A',
              mode: 'adult',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
              ulid: const Value(ulidA),
            ),
          );
      final idB = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Profile B',
              mode: 'adult',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
              ulid: const Value(ulidB),
            ),
          );

      final firestore = FakeFirebaseFirestore();
      final releaseA = Completer<void>();
      final delayableRepo = _DelayableFirestoreLearnerProfileRepository(
        firestore: firestore,
        uid: uid,
        delayedProfileId: ulidA,
        releaseGate: releaseA,
      );

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          // Keeps syncWriteFacadeProvider (a profileRepositoryProvider
          // dependency) returning null — this test's only concern is the
          // activation heal, not the legacy sync-engine push. Same trick
          // `profile_activation_heal_wiring_test.dart` uses.
          authStateProvider.overrideWithValue(const AuthState.initializing()),
          // Bypasses activeAccountFirebaseProvider/AccountFirebaseHandles
          // entirely — this test only needs control over ONE profile's
          // write timing, which is simplest to inject one level below, at
          // the provider _ensureFirestoreProfile itself awaits.
          firestoreLearnerProfileRepositoryProvider.overrideWith(
            (ref) async => delayableRepo,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeAccountIdProvider.notifier).set('device-acct-1');

      // Activate A: select() sets activeProfileDocIdProvider to A
      // synchronously, then dispatches (unawaited) A's heal — which is now
      // blocked on releaseA.
      container
          .read(selectedProfileIdProvider.notifier)
          .select(idA, ulid: ulidA);
      expect(container.read(activeProfileDocIdProvider), ulidA);

      // Switch to B while A's heal is still in flight: select() sets
      // activeProfileDocIdProvider to B synchronously, then dispatches
      // (unawaited) B's heal — undelayed, so it can settle immediately.
      container
          .read(selectedProfileIdProvider.notifier)
          .select(idB, ulid: ulidB);
      expect(container.read(activeProfileDocIdProvider), ulidB);

      // Drain the event queue so B's heal actually completes.
      await pumpEventQueue();
      expect(
        container.read(activeProfileDocIdProvider),
        ulidB,
        reason: 'sanity: B\'s own (undelayed) heal must not have moved it',
      );

      // Now let A's long-queued heal finally settle — the exact moment
      // T-49 describes ("heal A's queued write acks later on reconnect").
      releaseA.complete();
      await pumpEventQueue();

      // Prove A's heal really did run (not silently skipped) — its
      // Firestore document must now exist...
      final docA = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(ulidA)
          .get();
      expect(
        docA.exists,
        isTrue,
        reason:
            'sanity: A\'s delayed heal must have actually completed and '
            'written its document — otherwise this test would pass for '
            'the wrong reason (the heal never running at all)',
      );

      // ...but activeProfileDocIdProvider must still name B, the profile
      // actually selected — THIS is T-49: a late-settling heal for a
      // previously-selected profile must not clobber a newer selection.
      expect(
        container.read(activeProfileDocIdProvider),
        ulidB,
        reason:
            'T-49: activeProfileDocIdProvider must stay on the CURRENTLY '
            'selected profile (B). A late-settling heal for A — the '
            'PREVIOUSLY selected profile — re-pointing it back to A here '
            'is exactly the clobber race T-49 describes: every subsequent '
            'bookmark/learning_order read and write would silently go to '
            'the wrong profile\'s tree.',
      );
    },
  );
}
