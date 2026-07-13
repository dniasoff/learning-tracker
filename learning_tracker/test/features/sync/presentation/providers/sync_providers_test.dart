// Regression test for SM-4 (AUD-sync-04): outboxDrainAndRecordAttempt's
// second ref.read (recordDrainAttempt) must never touch a torn-down ref.
//
// ROOT CAUSE: syncWriteFacadeProvider/outboxSyncWriteFacadeProvider's shared
// onEnqueueDrain closure did:
//   await (ref.read(outboxProcessorProvider)?.drain(profileId) ?? ...);
//   await ref.read(syncOrchestratorProvider)?.recordDrainAttempt();
// with no `ref.mounted` guard between the two awaits. Both providers watch
// activeProfileIdProvider/authStateProvider, so a profile switch or
// sign-out arriving mid-drain rebuilds the provider — disposing the OLD
// `ref` — and the second `ref.read` above throws UnmountedRefException on
// that stale ref.
//
// FIX: `outboxDrainAndRecordAttempt` (lib/features/sync/presentation/
// providers/sync_providers.dart) checks `ref.mounted` after the first await
// and returns early (skipping recordDrainAttempt) if the ref was torn down.
//
// This test exercises `outboxDrainAndRecordAttempt` directly against a real
// ProviderContainer (not a fake Ref) so UnmountedRefException — a real
// Riverpod 3 framework exception — is exercised for real, not simulated.
@Tags(['unit', 'sync', 'sm4', 'regression'])
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/daos/points_balance_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/sync_orchestrator.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart';

class _MockOutboxProcessor extends Mock implements OutboxProcessor {}

class _MockSyncOrchestrator extends Mock implements SyncOrchestrator {}

// ── AUD-sync-08 regression fixtures ─────────────────────────────────────────
//
// outboxSyncWriteFacadeProvider used to mutate PointsBalanceDao.syncSink and
// unawaited-fire reEnqueueUnsyncedLedgerRows(profileId) as synchronous
// statements directly inside its Provider build body (an SM-2 violation —
// "keep provider build pure: no writes, no request-firing, no side
// effects"). Because the provider watches several dependencies (auth tier,
// tutored selection, database, profile id, day clock) that can each change
// independently of a genuine profile switch, the D14 recovery scan re-fired
// on every one of those unrelated rebuilds instead of once per profile per
// session.
//
// Fix: both statements moved into a microtask (build now only constructs and
// returns the facade), and the recovery scan is additionally gated by a
// per-session "already recovered this profile" Set so it fires at most once
// per profile per session.
//
// This uses a spy PointsBalanceDao (bypassing the DAO's own DB-level
// idempotency marker, which `points_balance_dao_test.dart`'s "reconciliation
// is idempotent" test already covers) so the assertions are about *call
// count*, not about the DB end-state two different mechanisms could produce
// identically.

/// Spy [PointsBalanceDao] that records `reEnqueueUnsyncedLedgerRows` calls
/// instead of touching the database, so the test can assert call *count*
/// directly.
class _SpyPointsBalanceDao extends PointsBalanceDao {
  _SpyPointsBalanceDao(super.db);

  int reEnqueueCallCount = 0;
  final List<int> reEnqueueProfileIds = [];

  @override
  Future<void> reEnqueueUnsyncedLedgerRows(int profileId) async {
    reEnqueueCallCount++;
    reEnqueueProfileIds.add(profileId);
  }
}

/// [UserDatabase] whose [pointsBalanceDao] is the spy above, so
/// [outboxSyncWriteFacadeProvider]'s `database.pointsBalanceDao` access
/// resolves to it without needing to fake any other DAO or table.
class _SpyUserDatabase extends UserDatabase {
  _SpyUserDatabase(super.e);

  @override
  late final PointsBalanceDao pointsBalanceDao = _SpyPointsBalanceDao(this);
}

/// Settable [ActiveProfileId] override: [build] returns the initial value,
/// and the test mutates `.notifier.state` afterwards (the proven Riverpod
/// pattern for driving a provider through several values in one test — see
/// e.g. `reminderEnabledProvider.notifier).state = false` in
/// `lifetime_folder_styled_and_notif_providers_test.dart`) to simulate a
/// profile switch.
class _MutableActiveProfileId extends ActiveProfileId {
  _MutableActiveProfileId(this._initial);
  final int _initial;

  @override
  int build() => _initial;
}

/// Settable [AuthStateNotifier] override, same rationale as
/// [_MutableActiveProfileId] — lets the test drive an "unrelated" rebuild
/// (auth state changes, tier/profile untouched) via `.notifier.state = `.
/// Overriding [build] (rather than calling `super.build()`) also means the
/// real class's own `_init()` fire-and-forget startup call never fires, so
/// this override never touches FirebaseAuth.
class _MutableAuthState extends AuthStateNotifier {
  _MutableAuthState(this._initial);
  final AuthState _initial;

  @override
  AuthState build() => _initial;
}

const _kCloudUser1 = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'cloud1@test.com',
    displayName: 'Cloud User 1',
    firebaseUid: 'uid-cloud',
  ),
  tier: Tier.cloudBorn,
);

/// Same tier/uid as [_kCloudUser1] (still cloud-born, still the same
/// account) but a different [AuthUser.email]/[displayName] so it compares
/// unequal — this is the "unrelated rebuild" trigger: an auth-state refresh
/// that carries no profile switch.
const _kCloudUser1Refreshed = AuthState.signedIn(
  user: AuthUser(
    profileId: 1,
    email: 'cloud1-refreshed@test.com',
    displayName: 'Cloud User 1 (refreshed)',
    firebaseUid: 'uid-cloud',
  ),
  tier: Tier.cloudBorn,
);

void main() {
  group('outboxDrainAndRecordAttempt (SM-4 / AUD-sync-04)', () {
    late _MockOutboxProcessor mockProcessor;
    late _MockSyncOrchestrator mockOrchestrator;
    late Completer<int> drainCompleter;

    setUp(() {
      mockProcessor = _MockOutboxProcessor();
      mockOrchestrator = _MockSyncOrchestrator();
      drainCompleter = Completer<int>();
      when(
        () => mockProcessor.drain(any()),
      ).thenAnswer((_) => drainCompleter.future);
      when(
        () => mockOrchestrator.recordDrainAttempt(),
      ).thenAnswer((_) async {});
    });

    test('container disposed mid-drain (profile switch/sign-out): the second '
        'ref.read does not throw UnmountedRefException, and '
        'recordDrainAttempt is safely skipped', () async {
      final container = ProviderContainer(
        overrides: [
          outboxProcessorProvider.overrideWithValue(mockProcessor),
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
        ],
      );

      // Capture a real Ref sourced from this container (the same kind of
      // Ref a Provider<T>((ref) {...}) closure would capture).
      late Ref capturedRef;
      final hostProvider = Provider<void>((ref) {
        capturedRef = ref;
      });
      container.read(hostProvider);

      // Start the drain — this synchronously does the first ref.read
      // (outboxProcessorProvider) and then suspends on the drain future.
      final resultFuture = outboxDrainAndRecordAttempt(capturedRef, 7);

      // Simulate a profile switch/sign-out tearing this provider tree down
      // WHILE the drain's network round trip is still in flight.
      container.dispose();
      expect(
        capturedRef.mounted,
        isFalse,
        reason:
            'container.dispose() must tear down the captured ref — '
            'this is the exact staleness this test simulates',
      );

      // Let the in-flight drain settle now that the ref is torn down.
      drainCompleter.complete(3);

      // The core assertion: no UnmountedRefException (or any exception)
      // reaches the caller.
      await expectLater(resultFuture, completes);

      // And recordDrainAttempt must never have been called against the
      // stale ref.
      verifyNever(() => mockOrchestrator.recordDrainAttempt());
    });

    test('ref still mounted when the drain settles: recordDrainAttempt '
        'completes normally', () async {
      final container = ProviderContainer(
        overrides: [
          outboxProcessorProvider.overrideWithValue(mockProcessor),
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
        ],
      );
      addTearDown(container.dispose);

      late Ref capturedRef;
      final hostProvider = Provider<void>((ref) {
        capturedRef = ref;
      });
      container.read(hostProvider);

      final resultFuture = outboxDrainAndRecordAttempt(capturedRef, 7);

      // No teardown this time — the ref stays mounted throughout.
      drainCompleter.complete(3);
      await expectLater(resultFuture, completes);

      verify(() => mockOrchestrator.recordDrainAttempt()).called(1);
    });
  });

  // ── AUD-t-cross-05 ─────────────────────────────────────────────────────
  //
  // GAP: `write_tee_status_update_test.dart` only unit-tests
  // `SyncOrchestratorImpl.recordDrainAttempt()` by calling it directly from
  // the test body against a bare orchestrator — it never builds an
  // `OutboxSyncWriteFacade` or fires the real `onEnqueueDrain` closure. The
  // `outboxDrainAndRecordAttempt (SM-4 / AUD-sync-04)` group above has the
  // same gap from the other side: it calls `outboxDrainAndRecordAttempt`
  // directly, bypassing the facade's enqueue path entirely. Neither test
  // would fail if a future refactor dropped the `onEnqueueDrain:` wiring
  // from `syncWriteFacadeProvider`/`outboxSyncWriteFacadeProvider` in this
  // file — the original bug (a write-tee drain failure leaves the sync
  // badge falsely "Synced") could silently reappear with the whole suite
  // green.
  //
  // FIX (coverage-only — the production wiring was already correct, see
  // sync_providers.dart:89/174): this test drives the write-tee END TO END
  // through the REAL production wiring — build the facade from
  // `outboxSyncWriteFacadeProvider` (whose `onEnqueueDrain` closure is the
  // genuine `() => outboxDrainAndRecordAttempt(ref, profileId)`, not a
  // test-supplied stand-in), call a real facade write method, and assert
  // `recordDrainAttempt()` fires as a side effect of the enqueue — the test
  // body itself never calls `recordDrainAttempt()`.
  group('OutboxSyncWriteFacade write-tee → recordDrainAttempt, end to end '
      '(AUD-t-cross-05)', () {
    late UserDatabase db;
    late _MockOutboxProcessor mockProcessor;
    late _MockSyncOrchestrator mockOrchestrator;
    late ProviderContainer container;

    setUp(() async {
      db = inMemoryDb();
      await seedProfile(db);

      mockProcessor = _MockOutboxProcessor();
      mockOrchestrator = _MockSyncOrchestrator();
      when(() => mockProcessor.drain(any())).thenAnswer((_) async => 0);
      when(
        () => mockOrchestrator.recordDrainAttempt(),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWith(
            () => _MutableActiveProfileId(1),
          ),
          authStateProvider.overrideWith(() => _MutableAuthState(_kCloudUser1)),
          outboxProcessorProvider.overrideWithValue(mockProcessor),
          syncOrchestratorProvider.overrideWithValue(mockOrchestrator),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('OutboxSyncWriteFacade.pushSettings enqueue fires the real '
        'onEnqueueDrain closure, which drains and calls '
        'recordDrainAttempt() — the test never calls it directly', () async {
      final facade = container.read(outboxSyncWriteFacadeProvider);
      expect(
        facade,
        isNotNull,
        reason: 'cloud-born + not tutored → a real facade is built',
      );

      // The real write-tee: enqueuing fires OutboxSyncWriteFacade's
      // fire-and-forget `_kickDrainTee`, which invokes the PRODUCTION
      // `onEnqueueDrain` closure wired in `outboxSyncWriteFacadeProvider`
      // above (sync_providers.dart:174) — not a test-supplied stand-in.
      await facade!.pushSettings({'curriculum_id': 'mishnayos'});

      // The tee is unawaited — pump the event queue so the drain +
      // recordDrainAttempt chain settles before asserting.
      await pumpEventQueue();

      verify(() => mockProcessor.drain(1)).called(1);
      // The core assertion: recordDrainAttempt() fired as a SIDE EFFECT
      // of the enqueue, through the real onEnqueueDrain closure — this
      // test body never calls orchestrator.recordDrainAttempt() itself.
      verify(() => mockOrchestrator.recordDrainAttempt()).called(1);
    });

    test('a second pushSettings enqueue drains and records again — the tee '
        'fires on every write, not just the first', () async {
      final facade = container.read(outboxSyncWriteFacadeProvider);
      await facade!.pushSettings({'curriculum_id': 'mishnayos'});
      await pumpEventQueue();
      await facade.pushCurriculumTrack({
        'curriculum_id': 'mishnayos',
        'track_id': 't1',
      });
      await pumpEventQueue();

      verify(() => mockProcessor.drain(1)).called(2);
      verify(() => mockOrchestrator.recordDrainAttempt()).called(2);
    });
  });

  group('outboxSyncWriteFacadeProvider — D14 recovery scan dedup '
      '(AUD-sync-08 regression)', () {
    late _SpyUserDatabase db;
    late ProviderContainer container;

    setUp(() {
      db = _SpyUserDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          userDatabaseProvider.overrideWithValue(db),
          activeProfileIdProvider.overrideWith(
            () => _MutableActiveProfileId(1),
          ),
          authStateProvider.overrideWith(() => _MutableAuthState(_kCloudUser1)),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('reEnqueueUnsyncedLedgerRows fires once per profile per session — '
        'not on an unrelated rebuild of the same profile, but again on a '
        'genuine profile switch (simulates two profile switches)', () async {
      // Keep the provider alive across rebuilds like a real widget tree
      // would — an unwatched autoDispose provider would be torn down
      // between reads, defeating the point of this test.
      final sub = container.listen(outboxSyncWriteFacadeProvider, (_, _) {});
      addTearDown(sub.close);

      final spyDao = db.pointsBalanceDao as _SpyPointsBalanceDao;

      // First build — profile 1. The sink wiring + recovery scan are
      // deferred to a microtask (AUD-sync-08 fix); re-read (Riverpod
      // rebuilds lazily on next read once a watched dependency changed)
      // and flush the microtask queue.
      expect(container.read(outboxSyncWriteFacadeProvider), isNotNull);
      await pumpEventQueue();

      expect(
        spyDao.reEnqueueCallCount,
        1,
        reason: 'the D14 recovery scan must fire once for profile 1',
      );
      expect(spyDao.reEnqueueProfileIds, [1]);

      // Unrelated rebuild: outboxSyncWriteFacadeProvider also watches
      // authStateProvider — refresh it to an unequal-but-still-
      // cloud-born value while the profile id stays 1. This is exactly
      // the "once per rebuild" bug AUD-sync-08 flagged: any watched
      // dependency changing re-fired the scan for the same,
      // already-recovered profile.
      container.read(authStateProvider.notifier).state = _kCloudUser1Refreshed;
      container.read(outboxSyncWriteFacadeProvider);
      await pumpEventQueue();

      expect(
        spyDao.reEnqueueCallCount,
        1,
        reason:
            'a rebuild that does not change the profile id must NOT '
            're-fire the recovery scan — it already ran for profile 1 '
            'this session',
      );

      // Profile switch #1: 1 -> 2. A genuinely new profile must still
      // get its own one-shot recovery scan.
      container.read(activeProfileIdProvider.notifier).state = 2;
      container.read(outboxSyncWriteFacadeProvider);
      await pumpEventQueue();

      expect(
        spyDao.reEnqueueCallCount,
        2,
        reason:
            'switching to a second profile must fire its own one-shot '
            'recovery scan',
      );
      expect(spyDao.reEnqueueProfileIds, [1, 2]);

      // Profile switch #2: back to profile 1, already recovered this
      // session — must not re-fire a second time for it.
      container.read(activeProfileIdProvider.notifier).state = 1;
      container.read(outboxSyncWriteFacadeProvider);
      await pumpEventQueue();

      expect(
        spyDao.reEnqueueCallCount,
        2,
        reason:
            'returning to an already-recovered profile within the same '
            'session must not re-fire the scan a second time for it',
      );
      expect(spyDao.reEnqueueProfileIds, [1, 2]);
    });
  });
}
