/// Unit tests for `learner_state_repository_providers.dart` (DNI-464 T8):
/// repositories are built only from `activeAccountFirebaseProvider`'s
/// handle; the own-profile scope's `{uid}` comes only from the persisted
/// path uid (`PathUidResolver.pathUidFor`, ruling B1), never from the live
/// Auth uid; a tutored scope's owner comes from the validated grant.
library;

import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/registry/device_registry_database.dart';
import 'package:learning_tracker/core/database/registry/path_uid_resolver.dart';
import 'package:learning_tracker/core/providers/registry_provider.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/callable_oversized_governed_write_port.dart';
import 'package:learning_tracker/data/repositories/firestore_change_log_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_points_amount_reader.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/learner_state/provider_settle.dart';
import '../../helpers/learner_state_fixtures.dart';

class _MockApp extends Mock implements FirebaseApp {}

class _MockAuth extends Mock implements FirebaseAuth {}

const _accountId = 'acc-1';

/// The LIVE Auth uid on the handles — deliberately different from every
/// persisted path uid below, so a test that reads it fails.
const _liveUid = 'live-auth-uid';

AccountFirebaseHandles _handles(FakeFirebaseFirestore firestore) =>
    AccountFirebaseHandles(
      app: _MockApp(),
      firestore: firestore,
      auth: _MockAuth(),
      uid: _liveUid,
    );

Future<DeviceRegistryDatabase> _registry({String? boundUid}) async {
  final db = DeviceRegistryDatabase(NativeDatabase.memory());
  addTearDown(db.close);
  await db.addAccount(
    DeviceAccountsCompanion.insert(
      accountId: _accountId,
      email: 'parent@test.com',
      displayName: 'Parent',
      tier: 'cloudBorn',
      dbFileName: 'user_acc_1.db',
      createdAt: DateTime.utc(2026),
      lastUsedAt: DateTime.utc(2026),
    ),
  );
  if (boundUid != null) {
    await PathUidResolver(
      db,
    ).reconcileLiveUid(accountId: _accountId, liveUid: boundUid);
  }
  return db;
}

ProviderContainer _container(
  FakeFirebaseFirestore firestore,
  DeviceRegistryDatabase registry,
) {
  final container = ProviderContainer(
    retry: (_, _) => null,
    overrides: [
      activeAccountFirebaseProvider.overrideWith(
        (ref) async => _handles(firestore),
      ),
      deviceRegistryProvider.overrideWithValue(registry),
    ],
  );
  addTearDown(container.dispose);
  container.read(activeAccountIdProvider.notifier).set(_accountId);
  return container;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'no active account → every provider resolves null (not ready)',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(
        await container.read(learningEventRepositoryProvider.future),
        isNull,
      );
      expect(await container.read(subTrackRepositoryProvider.future), isNull);
      expect(await container.read(learningWritePortProvider.future), isNull);
      expect(await container.read(pointsAmountReaderProvider.future), isNull);
      expect(await container.read(changeLogRepositoryProvider.future), isNull);
      expect(await container.read(governedDocReaderProvider.future), isNull);
      expect(
        await container.read(oversizedGovernedWritePortProvider.future),
        isNull,
      );
      expect(await container.read(activeLearnerScopeProvider.future), isNull);
    },
  );

  ProviderContainer failingHandles(
    Exception error,
    DeviceRegistryDatabase registry,
  ) {
    final container = ProviderContainer(
      retry: (_, _) => null,
      overrides: [
        activeAccountFirebaseProvider.overrideWith((ref) async => throw error),
        deviceRegistryProvider.overrideWithValue(registry),
      ],
    );
    addTearDown(container.dispose);
    container.read(activeAccountIdProvider.notifier).set(_accountId);
    container.read(activeProfileDocIdProvider.notifier).set(profileUlid);
    return container;
  }

  test('an active account id with no authenticated session (signed out / '
      'restored before sign-in) → every provider resolves null (not ready), '
      'not a terminal AsyncError (ruling B1)', () async {
    final container = failingHandles(
      const AccountNotAuthenticatedException(_accountId),
      await _registry(boundUid: 'path-uid'),
    );

    expect(
      await container.read(learningEventRepositoryProvider.future),
      isNull,
    );
    expect(await container.read(subTrackRepositoryProvider.future), isNull);
    expect(await container.read(activeLearnerScopeProvider.future), isNull);
  });

  test('a real infrastructure failure resolving the handle still surfaces '
      'as an error (only unauthenticated maps to not ready)', () async {
    final container = failingHandles(
      const FormatException('firebase init failed'),
      await _registry(boundUid: 'path-uid'),
    );

    await expectLater(
      container.read(learningEventRepositoryProvider.future),
      throwsFormatException,
    );
    await expectLater(
      container.read(subTrackRepositoryProvider.future),
      throwsFormatException,
    );
    await expectLater(
      container.read(activeLearnerScopeProvider.future),
      throwsFormatException,
    );
  });

  test('active account → repositories over that account\'s Firestore handle; '
      'scope still null until a profile is active', () async {
    final firestore = FakeFirebaseFirestore();
    final container = _container(
      firestore,
      await _registry(boundUid: 'path-uid'),
    );

    final events = await container.read(learningEventRepositoryProvider.future);
    final subTracks = await container.read(subTrackRepositoryProvider.future);
    expect(events, isA<FirestoreLearningEventRepository>());
    expect(subTracks, isA<FirestoreSubTrackRepository>());
    // DNI-469: the chunked write port and the AD-50 amount reader.
    expect(
      await container.read(learningWritePortProvider.future),
      isA<FirestoreLearningEventRepository>(),
    );
    expect(
      await container.read(pointsAmountReaderProvider.future),
      isA<FirestorePointsAmountReader>(),
    );
    // DNI-470: the change log and the governed-doc reads.
    expect(
      await container.read(changeLogRepositoryProvider.future),
      isA<FirestoreChangeLogRepository>(),
    );
    expect(
      await container.read(governedDocReaderProvider.future),
      isA<FirestoreChangeLogRepository>(),
    );
    expect(
      await container.read(oversizedGovernedWritePortProvider.future),
      isA<CallableOversizedGovernedWritePort>(),
    );
    expect(await container.read(activeLearnerScopeProvider.future), isNull);

    // The repository writes through the SAME handle.
    final scope = LearnerScope(ownerUid: 'path-uid', profileId: profileUlid);
    await events!.create(scope, datedLearn());
    final doc = await firestore
        .doc(
          'users/path-uid/learner_profiles/$profileUlid/learning_events/$ulidA',
        )
        .get();
    expect(doc.exists, isTrue);
  });

  test('own profile → scope uid is the PERSISTED path uid, never the live '
      'Auth uid', () async {
    final container = _container(
      FakeFirebaseFirestore(),
      await _registry(boundUid: 'persisted-uid'),
    );
    container.read(activeProfileDocIdProvider.notifier).set(profileUlid);

    final scope = await container.read(activeLearnerScopeProvider.future);
    expect(
      scope,
      LearnerScope(ownerUid: 'persisted-uid', profileId: profileUlid),
    );
    expect(scope!.ownerUid, isNot(_liveUid));
  });

  test('an account whose path uid is not yet bound → not ready (null), not '
      'the live Auth uid', () async {
    final container = _container(FakeFirebaseFirestore(), await _registry());
    container.read(activeProfileDocIdProvider.notifier).set(profileUlid);

    expect(await container.read(activeLearnerScopeProvider.future), isNull);
  });

  test('an active account id with no registry row is an error', () async {
    final registry = DeviceRegistryDatabase(NativeDatabase.memory());
    addTearDown(registry.close);
    final container = _container(FakeFirebaseFirestore(), registry);
    container.read(activeProfileDocIdProvider.notifier).set(profileUlid);

    await expectLater(
      container.read(activeLearnerScopeProvider.future),
      throwsA(isA<UnknownDeviceAccountException>()),
    );
  });

  test('reconciliation: an initial bind re-resolves the scope to the newly '
      'persisted uid', () async {
    final registry = await _registry();
    final container = _container(FakeFirebaseFirestore(), registry);
    container.read(activeProfileDocIdProvider.notifier).set(profileUlid);
    final sub = container.listen(activeLearnerScopeProvider, (_, _) {});
    addTearDown(sub.close);

    expect(await container.read(activeLearnerScopeProvider.future), isNull);

    final bind = await PathUidResolver(
      registry,
    ).reconcileLiveUid(accountId: _accountId, liveUid: 'anon-uid-1');
    expect(bind.kind, PathUidReconcileKind.initialBind);
    await pumpEventQueue();
    expect(
      await container.read(activeLearnerScopeProvider.future),
      LearnerScope(ownerUid: 'anon-uid-1', profileId: profileUlid),
    );
  });

  test('an AD-19 anon-uid remap with the old tree not yet re-homed REFUSES '
      'the scope: no read moves to the empty new namespace, no write splits '
      'the account, and the old data is untouched (review R2)', () async {
    final firestore = FakeFirebaseFirestore();
    final registry = await _registry(boundUid: 'anon-uid-1');
    final container = _container(firestore, registry);
    container.read(activeProfileDocIdProvider.notifier).set(profileUlid);
    final sub = container.listen(activeLearnerScopeProvider, (_, _) {});
    addTearDown(sub.close);

    // The learner's data lives under the original uid.
    final oldScope = LearnerScope(
      ownerUid: 'anon-uid-1',
      profileId: profileUlid,
    );
    expect(await container.read(activeLearnerScopeProvider.future), oldScope);
    final events = (await container.read(
      learningEventRepositoryProvider.future,
    ))!;
    await events.create(oldScope, datedLearn());
    const oldEvent =
        'users/anon-uid-1/learner_profiles/$profileUlid/learning_events/$ulidA';
    final before = (await firestore.doc(oldEvent).get()).data();

    final remap = await PathUidResolver(
      registry,
    ).reconcileLiveUid(accountId: _accountId, liveUid: 'anon-uid-2');
    expect(remap.kind, PathUidReconcileKind.remapped);
    await pumpEventQueue();

    await expectLater(
      container.read(activeLearnerScopeProvider.future),
      throwsA(
        isA<LearnerScopeRehomePendingException>()
            .having((e) => e.previousUid, 'previousUid', 'anon-uid-1')
            .having((e) => e.pathUid, 'pathUid', 'anon-uid-2'),
      ),
    );
    expect(
      (await firestore.collection('users/anon-uid-2/learner_profiles').get())
          .docs,
      isEmpty,
    );
    expect((await firestore.doc(oldEvent).get()).data(), before);

    // Once the re-home consumer has moved the tree and cleared the
    // breadcrumb, the scope opens on the new uid.
    await (registry.update(registry.deviceAccounts)
          ..where((t) => t.accountId.equals(_accountId)))
        .write(const DeviceAccountsCompanion(previousFirebaseUid: Value(null)));
    await pumpEventQueue();
    expect(
      await container.read(activeLearnerScopeProvider.future),
      LearnerScope(ownerUid: 'anon-uid-2', profileId: profileUlid),
    );
  });

  test('tutored session → owner uid is the validated grant\'s parent_uid, '
      'not this account\'s path uid', () async {
    final firestore = FakeFirebaseFirestore();
    await firestore.collection('tutor_grants').doc('grant-1').set({
      'state': 'active',
      'tutor_uid': _liveUid,
      'parent_uid': 'parent-uid',
      'child_profile_id': profileUlid,
    });
    final container = _container(
      firestore,
      await _registry(boundUid: 'tutor-path-uid'),
    );
    container
        .read(activeTutoredProfileSelectionProvider.notifier)
        .enter(
          const TutoredProfileSelection(
            profileId: profileUlid,
            ownerUid: 'parent-uid',
            grantId: 'grant-1',
            permissions: TutorPermissions(),
          ),
        );

    expect(
      await container.read(activeLearnerScopeProvider.future),
      LearnerScope(ownerUid: 'parent-uid', profileId: profileUlid),
    );
  });

  test('a non-ULID active profile id is an error, not an empty read', () async {
    final container = _container(
      FakeFirebaseFirestore(),
      await _registry(boundUid: 'path-uid'),
    );
    container.read(activeProfileDocIdProvider.notifier).set('42');
    await expectLater(
      container.read(activeLearnerScopeProvider.future),
      throwsFormatException,
    );
  });

  group('C0 (DNI-524) contract providers are stubs resolving to '
      'AsyncError', () {
    for (final (provider, owner, what) in [
      (
        governedIntentRepositoryProvider,
        'DNI-470',
        'governedIntentRepositoryProvider',
      ),
    ]) {
      test(what, () async {
        final container = ProviderContainer.test();
        expect(
          await settledAsync<Object?>(container, provider),
          isAsyncC0Stub(owner, what),
        );
      });
    }
  });
}
