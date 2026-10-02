// DNI-480 (Story 1.18) AC-1, integration level: every points reader sums
// the one ledger through the engine's AD-50 earning set.
//
// Two devices (two containers) share one Firestore ledger and one synced
// learning-event log; each runs the real engine over the log. A void on
// the log removes its event from `earningEventIds`, and every reader on
// both devices re-reads lower balance and lifetime without any reversal
// row. Spends lower the balance but not lifetime earned.
import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_reward_redemption_repository.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/gamification/data/repositories/reward_redemption_repository_impl.dart';
import 'package:learning_tracker/features/gamification/presentation/providers/points_providers.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/child_redemption_screen.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

import '../../helpers/firestore_fake.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

const _uid = 'points-engine-readers-user';
const _profileId = '01J0000000000000000000P480';

/// The synced learning-event log both devices read.
final class _SyncedLog {
  final List<LearningEvent> events = [];
  final _changes = StreamController<void>.broadcast();

  void append(LearningEvent e) {
    events.add(e);
    _changes.add(null);
  }

  Stream<LearnerState> states() async* {
    const engine = LearnerStateEngine();
    LearnerState run() => engine.run(engineInputs(events: [...events]));
    yield run();
    await for (final _ in _changes.stream) {
      yield run();
    }
  }

  Future<void> close() => _changes.close();
}

final _redemptionProvider =
    Provider<FirestoreRewardRedemptionRepositoryAdapter>(
      (ref) => FirestoreRewardRedemptionRepositoryAdapter(ref: ref),
    );

final _readerProvider = Provider<EnginePointsReader>(
  (ref) => EnginePointsReader(ref: ref),
);

void main() {
  const b11 = 'Mishnah Berakhot 1:1';
  const b12 = 'Mishnah Berakhot 1:2';
  late FakeFirebaseFirestore firestore;
  late _SyncedLog log;

  Future<void> award(LearningEvent e, int amount) => firestore
      .doc('users/$_uid/learner_profiles/$_profileId/points_ledger/pts_${e.id}')
      .set({
        'ulid': 'pts_${e.id}',
        'entry_kind': 'completion',
        'delta': amount,
        'created_at': DateTime.utc(2026, 9),
        'source': 'live',
        'event_id': e.id,
      });

  FirestorePointsLedgerRepository ledger() => FirestorePointsLedgerRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );

  ProviderContainer device() {
    final states = StreamProvider<LearnerState>((ref) => log.states());
    final container = ProviderContainer.test(
      overrides: [
        firestorePointsLedgerRepositoryProvider.overrideWith(
          (ref) async => ledger(),
        ),
        firestoreRewardRedemptionRepositoryProvider.overrideWith(
          (ref) async => FirestoreRewardRedemptionRepository(
            firestore: firestore,
            uid: _uid,
            profileId: _profileId,
          ),
        ),
        activeLearnerStateProvider.overrideWith((ref) => ref.watch(states)),
      ],
    );
    // Keep the live readers listened to, as screens do.
    container
      ..listen(globalPointsProvider, (_, _) {})
      ..listen(childRedemptionBalanceProvider, (_, _) {})
      ..listen(curriculumBreakdownProvider, (_, _) {});
    return container;
  }

  Future<({int global, int child, int lifetime, Map<CurriculumId, int> split})>
  readAll(ProviderContainer c) async {
    await pumpEventQueue();
    return (
      global: await c.read(globalPointsProvider.future),
      child: await c.read(childRedemptionBalanceProvider.future),
      lifetime: await c.read(_readerProvider).getLifetimeEarned(),
      split: await c.read(curriculumBreakdownProvider.future),
    );
  }

  setUp(() {
    firestore = createFakeFirestore(authenticatedUid: _uid);
    log = _SyncedLog();
  });

  tearDown(() => log.close());

  test('all point readers recompute filtered balance and lifetime after '
      'void', () async {
    final first = engineLearn(1, b11, stage: 1);
    final second = engineLearn(2, b12, stage: 1, minutes: 5);
    // A duplicate main tick of b11: writers attach pts_ to every main
    // dated learn, but only the first learn of a leaf earns.
    final repeat = engineLearn(3, b11, stage: 1, minutes: 10);
    log.events.addAll([first, second, repeat]);
    await award(first, 10);
    await award(second, 5);
    await award(repeat, 7);
    // An orphan pts_ row whose event is not in the log.
    await firestore
        .doc('users/$_uid/learner_profiles/$_profileId/points_ledger/pts_zz')
        .set({
          'ulid': 'pts_zz',
          'entry_kind': 'completion',
          'delta': 99,
          'created_at': DateTime.utc(2026),
          'source': 'live',
          'event_id': 'zz',
        });
    // A non-event parent adjustment always counts.
    await ledger().append(
      entryKind: 'parent_add',
      delta: 3,
      createdAt: DateTime.utc(2026),
    );

    final owner = device();
    final other = device();
    addTearDown(owner.dispose);
    addTearDown(other.dispose);

    for (final c in [owner, other]) {
      final r = await readAll(c);
      expect(r.global, 18, reason: '10 + 5 + parent_add 3');
      expect(r.child, 18);
      expect(r.lifetime, 18);
      expect(r.split, {CurriculumId.mishnayos: 15});
    }

    // A redemption on the owner device debits through the filtered
    // balance: it lowers the balance, never lifetime earned.
    final redeemed = await owner
        .read(_redemptionProvider)
        .createRedemption(rewardTitle: 'Prize', iconIndex: 0, pointsCost: 6);
    expect(redeemed, isNotNull);
    owner.invalidate(childRedemptionBalanceProvider);
    other.invalidate(globalPointsProvider);
    expect(await owner.read(childRedemptionBalanceProvider.future), 12);
    expect(await other.read(globalPointsProvider.future), 12);
    expect(await other.read(_readerProvider).getLifetimeEarned(), 18);

    // Too expensive for the filtered balance: declined, nothing written.
    expect(
      await owner
          .read(_redemptionProvider)
          .createRedemption(rewardTitle: 'Bike', iconIndex: 0, pointsCost: 13),
      isNull,
    );

    final ledgerSize = (await ledger().getLedger()).length;

    // Void the second learn on the synced log: both devices recompute.
    log.append(engineVoid(4, 2, minutes: 20));
    for (final c in [owner, other]) {
      final r = await readAll(c);
      expect(r.global, 7, reason: '10 + 3 - 6; the voided 5 no longer counts');
      expect(r.child, 7);
      expect(r.lifetime, 13, reason: 'lifetime falls after a void (AD-50)');
      expect(r.split, {CurriculumId.mishnayos: 10});
    }
    expect(
      (await ledger().getLedger()).length,
      ledgerSize,
      reason: 'no reversal entry is written',
    );
  });

  test('an engine failure is an error, never a fabricated zero', () async {
    final container = ProviderContainer.test(
      overrides: [
        firestorePointsLedgerRepositoryProvider.overrideWith(
          (ref) async => ledger(),
        ),
        activeLearnerStateProvider.overrideWith(
          (ref) => AsyncError<LearnerState?>(
            StateError('engine failed'),
            StackTrace.empty,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(globalPointsProvider, (_, _) {});

    await expectLater(
      container.read(globalPointsProvider.future),
      throwsA(isA<StateError>()),
    );
  });

  test('no active learner is not ready, never a fabricated zero', () async {
    final container = ProviderContainer.test(
      overrides: [
        firestorePointsLedgerRepositoryProvider.overrideWith(
          (ref) async => ledger(),
        ),
        activeLearnerStateProvider.overrideWith(
          (ref) => const AsyncData<LearnerState?>(null),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(globalPointsProvider, (_, _) {});

    await expectLater(
      container.read(globalPointsProvider.future),
      throwsA(isA<PointsNotReadyException>()),
    );
  });

  test('the earning set filters exactly as the domain totals do', () async {
    final first = engineLearn(1, b11, stage: 1);
    log.events.add(first);
    await award(first, 4);
    final container = device();
    addTearDown(container.dispose);
    await pumpEventQueue();

    expect(
      await container.read(_readerProvider).getTotals(),
      const PointsTotals(balance: 4, lifetimeEarned: 4),
    );
  });
}
