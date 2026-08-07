/// T-49 (P2-18 partial, P2-23 partial, P2-28 complete): a late-settling
/// `activeProfileDocIdProvider` write must never re-point it at a profile
/// that is no longer the one selected — for ALL THREE
/// `_ensureFirestoreProfile`-family callers, across BOTH of
/// `_activateThenEnsureFirestoreProfile`'s awaits. Six cases total (the
/// `R5-A`..`R5-F` matrix a round-5 review reproduced by execution and
/// preserved as a throwaway probe; made permanent here).
///
/// **Why this file exists, and why it does not just extend
/// `profile_activation_heal_race_test.dart`.** That file proves T-49 closed
/// for `ensureRemoteProfile` — the fire-and-forget heal `select()`
/// dispatches — and stays exactly as it is; nothing here duplicates it.
/// P2-18 fixed only that one of `_ensureFirestoreProfile`'s three callers.
/// `createProfile` and `ensureDefaultProfile`'s self-heal branch both still
/// passed `activateProvider: true` and both still raced: P2-22's review
/// reproduced the `createProfile` clobber BY EXECUTION with a throwaway
/// probe, then deleted it — which is exactly why nothing caught the
/// regression the next time someone touched this file. This file started as
/// that probe, made permanent, extended to cover `ensureDefaultProfile` too,
/// plus a third case (`ensureRemoteProfile`) so all three callers of
/// `_ensureFirestoreProfile` were proven, in one place, never to reintroduce
/// this clobber.
///
/// **Two await boundaries, not one — why the file grew a second group
/// (P2-28).** `_activateThenEnsureFirestoreProfile` has TWO awaits, not
/// one: `_resolveFirestoreProfileRepo`'s account-resolution await (a real,
/// sometimes-slow provider chain — `Firebase.initializeApp` + App Check +
/// an `authStateChanges()` read, documented stalling ~38+ seconds in the
/// `T-43` reproduction), THEN `_writeFirestoreProfile`'s network write. The
/// three `WRITE await` tests below (P2-23) gate the write and prove that
/// boundary closed. They do NOT exercise the resolution await at all —
/// `firestoreLearnerProfileRepositoryProvider` resolves immediately in
/// those tests, so a defect confined to the resolution await is invisible
/// to them by construction. P2-23's own fix left exactly that defect open:
/// it hoisted activation above the write but left it AFTER the resolution
/// await, restating the identical false "no later selection to race"
/// reasoning one await earlier. A round-5 review reproduced this BY
/// EXECUTION — gating `firestoreLearnerProfileRepositoryProvider` itself,
/// not `ensureProfile` — and found it RED for both `createProfile` and
/// `ensureDefaultProfile` (`ensureRemoteProfile` structurally immune, it
/// never activates). The three `RESOLUTION await` tests below are that
/// reproduction, made permanent, so a future hoist cannot silently regress
/// either boundary: this file now proves BOTH awaits closed, for all three
/// callers, six cases.
///
/// **Why the fake, not a device.** `fake_cloud_firestore` resolves every
/// write synchronously and has no offline queue/reconnect model, so the
/// actual production trigger — an offline-queued `DocumentReference.set()`
/// that only acks after reconnect, well after a DIFFERENT profile has since
/// been selected — is structurally impossible to reproduce against it (see
/// `docs/planning/firestore-cutover-log.md`'s `T-49`/`D20` entries). Each
/// test below instead proves the decidable proxy the fake CAN see: inject a
/// delayed/awaitable double — of the Firestore write for the `WRITE await`
/// group, of the provider resolution itself for the `RESOLUTION await`
/// group — so one profile's activation path is still in flight while a
/// DIFFERENT, newer profile becomes the one actually selected — the
/// identical out-of-order-completion shape the real bug has, driven by an
/// injected delay rather than a real network partition or a slow native
/// init.
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
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';

import '../../../../helpers/test_database.dart';

/// Wraps a real [FirestoreLearnerProfileRepository] (backed by a
/// [FakeFirebaseFirestore], so [ensureProfile]'s write really happens) and
/// makes exactly ONE profile id's write await an externally-controlled gate
/// before delegating — simulating "this profile's write is still in flight"
/// without needing a real offline queue. Mirrors
/// `profile_activation_heal_race_test.dart`'s helper of the same shape.
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
  const uid = 'uid-t49-p223';

  // Constructing FirestoreProfileRepositoryAdapter requires a Ref
  // (Riverpod's Ref is sealed) — obtain one the way production does: read a
  // throwaway Provider that builds the adapter from the container's ref.
  // Mirrors profile_repository_impl_test.dart's own helper of the same name.
  FirestoreProfileRepositoryAdapter buildAdapter(
    ProviderContainer container,
    ProfileRepositoryImpl driftRepository,
  ) {
    final adapterProvider = Provider<FirestoreProfileRepositoryAdapter>(
      (ref) => FirestoreProfileRepositoryAdapter(
        ref: ref,
        driftRepository: driftRepository,
      ),
    );
    return container.read(adapterProvider);
  }

  // ══ GROUP 1: the WRITE await (P2-23) ══

  test('T-49 (createProfile): a late-settling create-time activation write '
      'does not re-point activeProfileDocIdProvider at the just-created '
      'profile after a different profile has since been selected', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final accountId = await seedAccount(db);
    const ulidB = 'ulid-p223-profile-b';
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
    const ulidC = 'ulid-p223-profile-c';
    final releaseC = Completer<void>();
    final delayableRepo = _DelayableFirestoreLearnerProfileRepository(
      firestore: firestore,
      uid: uid,
      delayedProfileId: ulidC,
      releaseGate: releaseC,
    );

    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        authStateProvider.overrideWithValue(const AuthState.initializing()),
        firestoreLearnerProfileRepositoryProvider.overrideWith(
          (ref) async => delayableRepo,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeAccountIdProvider.notifier).set('device-acct-1');
    final adapter = buildAdapter(container, ProfileRepositoryImpl(db));

    // Onboarding (or any create flow) mints profile C. Its own Firestore
    // write is delayed — modeling "still in flight when the caller moved
    // on" (`onboarding_profile_creation_step.dart:133`'s own comment:
    // "repo.createProfile(...) above is a DB write that may still be in
    // flight when the step widget is popped"). Deliberately NOT awaited
    // here yet, so the test can interleave a later selection while it is
    // still pending — the Future survives regardless, held by `_ref`.
    final createFuture = adapter.createProfile(
      accountId: accountId,
      displayName: 'Profile C',
      mode: 'adult',
      ulid: ulidC,
    );

    // Let the create reach its delayed Firestore write (Drift insert +
    // provider resolution have real awaits of their own).
    await pumpEventQueue();

    // The create flow was abandoned; the user is really on B — modeling
    // the onboarding step's own `if (!mounted) return;` (never calling
    // `select(C)`) plus something else (e.g. the router's auto-select)
    // confirming B.
    container.read(selectedProfileIdProvider.notifier).select(idB, ulid: ulidB);
    expect(
      container.read(activeProfileDocIdProvider),
      ulidB,
      reason: 'sanity: still B while C\'s create is in flight',
    );

    // Now let C's long-queued create finally settle — the exact moment
    // T-49 describes ("the queued write acks later, after a newer
    // selection").
    releaseC.complete();
    await createFuture;
    await pumpEventQueue();

    // Prove C's create really did run (not silently skipped) — its
    // Firestore document must now exist...
    final docC = await firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(ulidC)
        .get();
    expect(
      docC.exists,
      isTrue,
      reason:
          'sanity: C\'s delayed create must have actually completed and '
          'written its document — otherwise this test would pass for the '
          'wrong reason (the write never running at all)',
    );
    expect(
      container.read(selectedProfileIdProvider),
      idB,
      reason: 'sanity: B is still the selection',
    );

    // ...but activeProfileDocIdProvider must still name B, the profile
    // actually selected — THIS is T-49 for the createProfile path: a
    // late-settling create-time activation must not clobber a newer
    // selection.
    expect(
      container.read(activeProfileDocIdProvider),
      ulidB,
      reason:
          'T-49 (createProfile): activeProfileDocIdProvider must stay on '
          'the CURRENTLY selected profile (B). A late-settling create for '
          'C — a profile the flow that created it already abandoned — '
          're-pointing it back to C here is exactly the clobber T-49 '
          'describes: every subsequent bookmark/learning_order read and '
          'write would silently go to the wrong profile\'s tree.',
    );
  });

  test(
    'T-49 (ensureDefaultProfile self-heal): a late-settling self-heal '
    'activation write does not re-point activeProfileDocIdProvider at the '
    'newly-healed profile after a different profile has since been selected',
    () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      // Two accounts: B already has a profile (selected below); the
      // self-heal account starts with ZERO profiles so
      // ensureDefaultProfile actually takes its self-heal/creation branch
      // rather than the fast (already-has-a-profile) path.
      final accountIdB = await seedAccount(db);
      const ulidB = 'ulid-p223-profile-b2';
      final idB = await db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountIdB,
              displayName: 'Profile B',
              mode: 'adult',
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
              ulid: const Value(ulidB),
            ),
          );
      final selfHealAccountId = await seedAccount2(db);

      final firestore = FakeFirebaseFirestore();
      const ulidD = 'ulid-p223-profile-d';
      final releaseD = Completer<void>();
      final delayableRepo = _DelayableFirestoreLearnerProfileRepository(
        firestore: firestore,
        uid: uid,
        delayedProfileId: ulidD,
        releaseGate: releaseD,
      );

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          authStateProvider.overrideWithValue(const AuthState.initializing()),
          firestoreLearnerProfileRepositoryProvider.overrideWith(
            (ref) async => delayableRepo,
          ),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeAccountIdProvider.notifier).set('device-acct-1');
      final adapter = buildAdapter(container, ProfileRepositoryImpl(db));

      final ensureDefaultFuture = adapter.ensureDefaultProfile(
        accountId: selfHealAccountId,
        defaultDisplayName: 'Healed D',
        ulid: ulidD,
      );

      await pumpEventQueue();

      // Meanwhile the account actually in front of the user is B.
      container
          .read(selectedProfileIdProvider.notifier)
          .select(idB, ulid: ulidB);
      expect(
        container.read(activeProfileDocIdProvider),
        ulidB,
        reason: "sanity: still B while D's self-heal is in flight",
      );

      releaseD.complete();
      await ensureDefaultFuture;
      await pumpEventQueue();

      final docD = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(ulidD)
          .get();
      expect(
        docD.exists,
        isTrue,
        reason:
            "sanity: D's delayed self-heal create must have actually "
            'completed and written its document',
      );
      expect(
        container.read(selectedProfileIdProvider),
        idB,
        reason: 'sanity: B is still the selection',
      );

      expect(
        container.read(activeProfileDocIdProvider),
        ulidB,
        reason:
            'T-49 (ensureDefaultProfile): activeProfileDocIdProvider must '
            'stay on the CURRENTLY selected profile (B), not the '
            'self-healed account\'s brand new profile (D).',
      );
    },
  );

  test('T-49 (ensureRemoteProfile, regression guard): a late-settling '
      'activation-heal write still does not re-point activeProfileDocIdProvider '
      '— this is the caller P2-18 already fixed; proven here too so all three '
      'callers are covered in one file', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final accountId = await seedAccount(db);
    const ulidA = 'ulid-p223-profile-a';
    const ulidB = 'ulid-p223-profile-b3';
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
        authStateProvider.overrideWithValue(const AuthState.initializing()),
        firestoreLearnerProfileRepositoryProvider.overrideWith(
          (ref) async => delayableRepo,
        ),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeAccountIdProvider.notifier).set('device-acct-1');

    container.read(selectedProfileIdProvider.notifier).select(idA, ulid: ulidA);
    expect(container.read(activeProfileDocIdProvider), ulidA);

    container.read(selectedProfileIdProvider.notifier).select(idB, ulid: ulidB);
    expect(container.read(activeProfileDocIdProvider), ulidB);

    await pumpEventQueue();
    expect(container.read(activeProfileDocIdProvider), ulidB);

    releaseA.complete();
    await pumpEventQueue();

    final docA = await firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(ulidA)
        .get();
    expect(docA.exists, isTrue);

    expect(
      container.read(activeProfileDocIdProvider),
      ulidB,
      reason:
          'T-49 (ensureRemoteProfile): must stay fixed — this caller '
          'never activates the provider at all (P2-18).',
    );
  });

  // ══ GROUP 2: the RESOLUTION await (P2-28) — the SAME method's OTHER
  // await, the one P2-23 left unguarded. Gates
  // `firestoreLearnerProfileRepositoryProvider` itself, not `ensureProfile`
  // — see the library doc comment above for why GROUP 1 cannot see this
  // boundary at all. ══

  test('T-49 (createProfile, RESOLUTION await): a late-resolving Firestore '
      'repo provider does not re-point activeProfileDocIdProvider at the '
      'just-created profile after a different profile has since been '
      'selected', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    final accountId = await seedAccount(db);
    const ulidB = 'ulid-p228-profile-b';
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
    const ulidC = 'ulid-p228-profile-c';
    final repo = FirestoreLearnerProfileRepository(
      firestore: firestore,
      uid: uid,
    );
    final releaseResolution = Completer<void>();

    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        authStateProvider.overrideWithValue(const AuthState.initializing()),
        firestoreLearnerProfileRepositoryProvider.overrideWith((ref) async {
          await releaseResolution.future;
          return repo;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeAccountIdProvider.notifier).set('device-acct-1');
    final adapter = buildAdapter(container, ProfileRepositoryImpl(db));

    // Onboarding (or any create flow) mints profile C. Resolving WHICH
    // Firestore repo to write through — not the write itself — is what is
    // delayed here, modeling `repository_providers.dart`'s documented
    // ~38+s native-init stall (`T-43`). Deliberately NOT awaited yet, so
    // the test can interleave a later selection while resolution is still
    // pending.
    final createFuture = adapter.createProfile(
      accountId: accountId,
      displayName: 'Profile C',
      mode: 'adult',
      ulid: ulidC,
    );

    // Let the create reach its delayed provider resolution (Drift insert
    // has a real await of its own).
    await pumpEventQueue();

    // The create flow was abandoned; the user is really on B.
    container.read(selectedProfileIdProvider.notifier).select(idB, ulid: ulidB);
    expect(
      container.read(activeProfileDocIdProvider),
      ulidB,
      reason: "sanity: still B while C's provider resolution is in flight",
    );

    // Now let the delayed resolution finally settle — the exact moment
    // T-49's third reopening describes.
    releaseResolution.complete();
    await createFuture;
    await pumpEventQueue();

    // Prove C's create really did run (not silently skipped) — its
    // Firestore document must now exist...
    final docC = await firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(ulidC)
        .get();
    expect(
      docC.exists,
      isTrue,
      reason:
          "sanity: C's create must have actually completed and written its "
          'document — otherwise this test would pass for the wrong reason '
          '(the write never running at all)',
    );
    expect(
      container.read(selectedProfileIdProvider),
      idB,
      reason: 'sanity: B is still the selection',
    );

    // ...but activeProfileDocIdProvider must still name B.
    expect(
      container.read(activeProfileDocIdProvider),
      ulidB,
      reason:
          'T-49 (createProfile, RESOLUTION await): activeProfileDocIdProvider '
          'must stay on the CURRENTLY selected profile (B). This is the '
          'await P2-23 left unguarded: a late-resolving '
          'firestoreLearnerProfileRepositoryProvider re-pointing it back to '
          'C here is the same clobber GROUP 1 proves fixed, one await '
          'earlier.',
    );
  });

  test('T-49 (ensureDefaultProfile self-heal, RESOLUTION await): a '
      'late-resolving Firestore repo provider does not re-point '
      'activeProfileDocIdProvider at the newly-healed profile after a '
      'different profile has since been selected', () async {
    final db = createTestDatabase();
    addTearDown(db.close);
    // Two accounts: B already has a profile (selected below); the
    // self-heal account starts with ZERO profiles so ensureDefaultProfile
    // actually takes its self-heal/creation branch rather than the fast
    // (already-has-a-profile) path.
    final accountIdB = await seedAccount(db);
    const ulidB = 'ulid-p228-profile-b2';
    final idB = await db
        .into(db.learnerProfiles)
        .insert(
          LearnerProfilesCompanion.insert(
            accountId: accountIdB,
            displayName: 'Profile B',
            mode: 'adult',
            createdAt: DateTimeFactory.nowUtc(),
            updatedAt: DateTimeFactory.nowUtc(),
            ulid: const Value(ulidB),
          ),
        );
    final selfHealAccountId = await seedAccount2(db);

    final firestore = FakeFirebaseFirestore();
    const ulidD = 'ulid-p228-profile-d';
    final repo = FirestoreLearnerProfileRepository(
      firestore: firestore,
      uid: uid,
    );
    final releaseResolution = Completer<void>();

    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        authStateProvider.overrideWithValue(const AuthState.initializing()),
        firestoreLearnerProfileRepositoryProvider.overrideWith((ref) async {
          await releaseResolution.future;
          return repo;
        }),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeAccountIdProvider.notifier).set('device-acct-1');
    final adapter = buildAdapter(container, ProfileRepositoryImpl(db));

    final ensureDefaultFuture = adapter.ensureDefaultProfile(
      accountId: selfHealAccountId,
      defaultDisplayName: 'Healed D',
      ulid: ulidD,
    );

    await pumpEventQueue();

    // Meanwhile the account actually in front of the user is B.
    container.read(selectedProfileIdProvider.notifier).select(idB, ulid: ulidB);
    expect(
      container.read(activeProfileDocIdProvider),
      ulidB,
      reason: "sanity: still B while D's provider resolution is in flight",
    );

    releaseResolution.complete();
    await ensureDefaultFuture;
    await pumpEventQueue();

    final docD = await firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(ulidD)
        .get();
    expect(
      docD.exists,
      isTrue,
      reason:
          "sanity: D's self-heal create must have actually completed and "
          'written its document',
    );
    expect(
      container.read(selectedProfileIdProvider),
      idB,
      reason: 'sanity: B is still the selection',
    );

    expect(
      container.read(activeProfileDocIdProvider),
      ulidB,
      reason:
          'T-49 (ensureDefaultProfile, RESOLUTION await): '
          'activeProfileDocIdProvider must stay on the CURRENTLY selected '
          "profile (B), not the self-healed account's brand new profile "
          '(D).',
    );
  });

  test(
    'T-49 (ensureRemoteProfile, RESOLUTION await, regression guard): a '
    'late-resolving Firestore repo provider still does not re-point '
    'activeProfileDocIdProvider — this caller never activates at all '
    '(P2-18), structurally immune to this boundary too; proven here so '
    'all three callers are covered across both boundaries in one file',
    () async {
      final db = createTestDatabase();
      addTearDown(db.close);
      final accountId = await seedAccount(db);
      const ulidA = 'ulid-p228-profile-a';
      const ulidB = 'ulid-p228-profile-b3';
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
      final repo = FirestoreLearnerProfileRepository(
        firestore: firestore,
        uid: uid,
      );
      final releaseResolution = Completer<void>();

      final container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          authStateProvider.overrideWithValue(const AuthState.initializing()),
          firestoreLearnerProfileRepositoryProvider.overrideWith((ref) async {
            await releaseResolution.future;
            return repo;
          }),
        ],
      );
      addTearDown(container.dispose);
      container.read(activeAccountIdProvider.notifier).set('device-acct-1');
      final adapter = buildAdapter(container, ProfileRepositoryImpl(db));

      container
          .read(selectedProfileIdProvider.notifier)
          .select(idA, ulid: ulidA);
      expect(container.read(activeProfileDocIdProvider), ulidA);

      // select() dispatches ensureRemoteProfile(idA) fire-and-forget; its
      // resolution is gated, still in flight below.
      unawaited(adapter.ensureRemoteProfile(idA));
      await pumpEventQueue();

      container
          .read(selectedProfileIdProvider.notifier)
          .select(idB, ulid: ulidB);
      expect(container.read(activeProfileDocIdProvider), ulidB);

      releaseResolution.complete();
      await pumpEventQueue();

      final docA = await firestore
          .collection('users')
          .doc(uid)
          .collection('learner_profiles')
          .doc(ulidA)
          .get();
      expect(docA.exists, isTrue, reason: "sanity: A's delayed heal DID land");

      expect(
        container.read(activeProfileDocIdProvider),
        ulidB,
        reason:
            'T-49 (ensureRemoteProfile, RESOLUTION await): must stay fixed — '
            'this caller never activates the provider at all (P2-18).',
      );
    },
  );
}
