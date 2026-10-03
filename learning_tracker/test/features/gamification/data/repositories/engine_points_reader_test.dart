// DNI-480 (AD-50): the engine points readers sum the ledger through the
// engine's earning set and never report a fabricated zero.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/gamification/data/repositories/engine_points_reader.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

import '../../../../helpers/firestore_fake.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';

const _uid = 'engine-reader-user';
const _profileId = '01J0000000000000000000P480';
const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';

final _readerProvider = Provider<EnginePointsReader>(
  (ref) => EnginePointsReader(ref: ref),
);

void main() {
  late FakeFirebaseFirestore firestore;

  FirestorePointsLedgerRepository ledger() => FirestorePointsLedgerRepository(
    firestore: firestore,
    uid: _uid,
    profileId: _profileId,
  );

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

  LearnerState run(List<LearningEvent> events) =>
      const LearnerStateEngine().run(engineInputs(events: events));

  ProviderContainer build({
    AsyncValue<LearnerState?>? state,
    bool nullRepo = false,
  }) => ProviderContainer.test(
    overrides: [
      firestorePointsLedgerRepositoryProvider.overrideWith(
        (ref) async => nullRepo ? null : ledger(),
      ),
      activeLearnerStateProvider.overrideWith(
        (ref) => state ?? const AsyncValue<LearnerState?>.loading(),
      ),
    ],
  );

  setUp(() => firestore = createFakeFirestore(authenticatedUid: _uid));

  test('PointsNotReadyException is a StateError that says why', () {
    final e = PointsNotReadyException('no active learner');
    expect(e, isA<StateError>());
    expect(e.toString(), contains('no active learner'));
    expect(e.toString(), contains('refusing to report points as 0'));
  });

  group('with a ready learner state', () {
    late LearningEvent first;
    late LearningEvent second;
    late LearningEvent repeat;
    late ProviderContainer c;

    setUp(() async {
      first = engineLearn(1, _b11, stage: 1);
      second = engineLearn(2, _b12, stage: 1, minutes: 5);
      repeat = engineLearn(3, _b11, stage: 1, minutes: 10);
      await award(first, 10);
      await award(second, 5);
      await award(repeat, 7); // duplicate main tick: does not earn
      c = build(state: AsyncValue.data(run([first, second, repeat])));
    });

    test('balance and lifetime count only earning events', () async {
      final reader = c.read(_readerProvider);
      expect(await reader.getBalance(), 15);
      expect(await reader.getLifetimeEarned(), 15);
    });

    test('a void drops both totals without a reversal row', () async {
      final voided = LearningEvent.voidOf(
        id: engineUlid(9),
        targetId: first.id,
        recordedAt: engineAt(20),
        actor: first.actor,
      );
      final c2 = build(
        state: AsyncValue.data(run([first, second, repeat, voided])),
      );
      final reader = c2.read(_readerProvider);
      // The earning set changed: the voided first learn stops earning and
      // the formerly duplicate tick of the same leaf (7) now earns.
      expect(await reader.getBalance(), 12);
      expect(await reader.getLifetimeEarned(), 12);
      expect(await ledger().getLedger(), hasLength(3));
    });

    test('getEarnedPoints joins earning rows to their curriculum', () async {
      final earned = await c.read(_readerProvider).getEarnedPoints();
      expect(earned.map((e) => e.eventId).toSet(), {first.id, second.id});
      expect(earned.map((e) => e.points).fold<int>(0, (a, b) => a + b), 15);
      expect(earned.map((e) => e.curriculumId).toSet(), {
        CurriculumId.mishnayos,
      });
    });

    test(
      'the earning set and counted learns providers expose the engine',
      () async {
        expect(await c.read(activeEarningEventIdsProvider.future), {
          first.id,
          second.id,
        });
        expect(await c.read(activeCountedLearnsProvider.future), {
          first.id: first.curriculumId,
          second.id: second.curriculumId,
          repeat.id: repeat.curriculumId,
        });
      },
    );
  });

  test('a ledger without event rows needs no learner state', () async {
    await ledger().append(
      entryKind: 'parent_add',
      delta: 4,
      createdAt: DateTime.utc(2026),
    );
    final c = build(); // learner state stays loading forever
    final reader = c.read(_readerProvider);
    expect(await reader.getBalance(), 4);
    expect(await reader.getLifetimeEarned(), 4);
    expect(await reader.getEarnedPoints(), isEmpty);
  });

  test('no ready ledger repository throws PointsNotReadyException', () async {
    final c = build(nullRepo: true);
    final reader = c.read(_readerProvider);
    await expectLater(
      reader.getBalance(),
      throwsA(isA<PointsNotReadyException>()),
    );
    await expectLater(
      reader.getEarnedPoints(),
      throwsA(isA<PointsNotReadyException>()),
    );
  });

  test('no active learner is not ready, never a zero', () async {
    await award(engineLearn(1, _b11, stage: 1), 10);
    final c = build(state: const AsyncValue.data(null));
    await expectLater(
      c.read(_readerProvider).getBalance(),
      throwsA(isA<PointsNotReadyException>()),
    );
  });

  test('a failed learner state forwards its error', () async {
    await award(engineLearn(1, _b11, stage: 1), 10);
    final c = build(
      state: AsyncValue.error(StateError('boom'), StackTrace.empty),
    );
    await expectLater(
      c.read(_readerProvider).getLifetimeEarned(),
      throwsA(isA<StateError>().having((e) => e.message, 'message', 'boom')),
    );
  });

  test(
    'watchActivePointsTotals reads the filtered totals in a provider',
    () async {
      final e = engineLearn(1, _b11, stage: 1);
      await award(e, 8);
      final totals = FutureProvider((ref) => watchActivePointsTotals(ref));
      final c = build(state: AsyncValue.data(run([e])));
      final t = await c.read(totals.future);
      expect((t.balance, t.lifetimeEarned), (8, 8));
    },
  );
}
