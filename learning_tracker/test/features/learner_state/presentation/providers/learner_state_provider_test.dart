// Mirror test for
// `lib/features/learner_state/presentation/providers/learner_state_provider.dart`
// (C0, DNI-524 AC-5; filled by DNI-474 AC-1).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_composition.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

/// The in-memory sources of one learner, wired into a container.
final class _Sources {
  final events = InMemoryLearningEventRepository();
  final subTracks = InMemorySubTrackRepository();
  final changeLog = InMemoryChangeLogRepository();
  final intent = InMemoryGovernedIntentRepository();

  List<Override> overrides({
    LearnerCalendarLoader? calendars,
    bool accountReady = true,
  }) => [
    learningEventRepositoryProvider.overrideWith(
      (ref) async => accountReady ? events : null,
    ),
    subTrackRepositoryProvider.overrideWith((ref) async => subTracks),
    changeLogRepositoryProvider.overrideWith((ref) async => changeLog),
    governedIntentRepositoryProvider.overrideWith((ref) async => intent),
    corporaProvider.overrideWith(
      (ref) async => <String, Corpus>{engineCurriculum: mishnayosCorpus()},
    ),
    learnerCalendarLoaderProvider.overrideWithValue(
      calendars ?? (intent, settings, now) async => const {},
    ),
    localDayClockProvider.overrideWithValue(FakeLocalDayClock(engineAt(10000))),
    learnerStateDayTickProvider.overrideWithValue(const Stream.empty()),
  ];

  Future<void> dispose() async {
    await events.dispose();
    await subTracks.dispose();
    await changeLog.dispose();
    await intent.dispose();
  }
}

LearnerIntent _intent() => LearnerIntent(
  settings: c0Settings,
  mainTracks: {engineCurriculum: engineIntent()},
  goals: const {},
);

void main() {
  final now = DateTime.utc(2026, 9, 1, 12);

  test('learnerStateEngineProvider is the real const engine', () {
    final container = ProviderContainer.test();
    expect(
      container.read(learnerStateEngineProvider),
      same(const LearnerStateEngine()),
    );
  });

  group('learnerStateProvider (DNI-474 AC-1)', () {
    late _Sources sources;
    setUp(() => sources = _Sources());
    tearDown(() => sources.dispose());

    test('is loading while the account is not ready', () async {
      final container = ProviderContainer.test(
        overrides: sources.overrides(accountReady: false),
      );
      final sub = container.listen(learnerStateProvider(c0Scope()), (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(sub.read().isLoading, isTrue);
    });

    test('stays loading until every source is complete, then emits the '
        'engine result over all of them', () async {
      final container = ProviderContainer.test(overrides: sources.overrides());
      final sub = container.listen(learnerStateProvider(c0Scope()), (_, _) {});
      addTearDown(sub.close);
      sources.events.seed(c0Scope(), [
        engineLearn(1, 'Mishnah Berakhot 1:1'),
        engineLearn(2, 'Mishnah Berakhot 1:1', minutes: 5),
        engineLearn(3, 'Mishnah Berakhot 1:2', minutes: 6),
      ]);
      sources.subTracks.seed(c0Scope(), const []);
      sources.changeLog.seed(c0Scope(), const []);
      await pumpEventQueue();
      expect(sub.read().isLoading, isTrue, reason: 'no governed intent yet');

      sources.intent.emit(c0Scope(), _intent());
      await pumpEventQueue();

      final state = sub.read().value!;
      expect(state.nowUtc, engineAt(10000));
      expect(state[engineCurriculum]!.distinctLearnt, 2);
      expect(state[engineCurriculum]!.learntLeaves, {
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
      });
    });

    test('a new event recomputes the state', () async {
      final container = ProviderContainer.test(overrides: sources.overrides());
      sources.events.seed(c0Scope(), [engineLearn(1, 'Mishnah Peah 1:1')]);
      sources.subTracks.seed(c0Scope(), const []);
      sources.changeLog.seed(c0Scope(), const []);
      final sub = container.listen(learnerStateProvider(c0Scope()), (_, _) {});
      addTearDown(sub.close);
      sources.intent.emit(c0Scope(), _intent());
      await pumpEventQueue();
      expect(sub.read().value![engineCurriculum]!.distinctLearnt, 1);

      await sources.events.create(
        c0Scope(),
        engineLearn(2, 'Mishnah Peah 1:2', minutes: 3),
      );
      await pumpEventQueue();
      final peah = sub.read().value![engineCurriculum]!;
      expect(peah.distinctLearnt, 2);
      expect(peah.triState(peah.completedUnits.single.unit), TriState.complete);
    });

    test('a calendar load failure is an AsyncError', () async {
      final container = ProviderContainer.test(
        overrides: sources.overrides(
          calendars: (intent, settings, now) async =>
              throw StateError('calendar db'),
        ),
      );
      sources.events.seed(c0Scope(), const []);
      sources.subTracks.seed(c0Scope(), const []);
      sources.changeLog.seed(c0Scope(), const []);
      sources.intent.emit(c0Scope(), _intent());
      final sub = container.listen(learnerStateProvider(c0Scope()), (_, _) {});
      addTearDown(sub.close);
      sources.intent.emit(c0Scope(), _intent());
      await pumpEventQueue();
      expect(sub.read().error, isA<StateError>());
    });
  });

  group('activeLearnerStateProvider', () {
    test('is AsyncData(null) while no learner is active', () async {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => null),
        ],
      );
      expect(
        await settledAsync(container, activeLearnerStateProvider),
        const AsyncData<LearnerState?>(null),
      );
    });

    test('forwards learnerStateProvider for the active scope', () async {
      final state = LearnerState.empty(now);
      final requested = <LearnerScope>[];
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith((ref, scope) {
            requested.add(scope);
            return Stream.value(state);
          }),
        ],
      );
      final value = await settledAsync(container, activeLearnerStateProvider);
      expect(value.value, same(state));
      expect(requested, [c0Scope()]);
    });

    test('forwards a learner-state error', () async {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith((ref) async => c0Scope()),
          learnerStateProvider.overrideWith(
            (ref, scope) => Stream.error(StateError('read failed')),
          ),
        ],
      );
      final value = await settledAsync(container, activeLearnerStateProvider);
      expect(value.error, isA<StateError>());
    });

    test('forwards a scope error', () async {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith(
            (ref) async => throw StateError('no grant'),
          ),
        ],
      );
      final value = await settledAsync(container, activeLearnerStateProvider);
      expect(value, isA<AsyncError<LearnerState?>>());
      expect(value.error, isA<StateError>());
    });

    test('is loading while the scope resolves', () {
      final container = ProviderContainer.test(
        overrides: [
          activeLearnerScopeProvider.overrideWith(
            (ref) => Completer<LearnerScope?>().future,
          ),
        ],
      );
      expect(
        container.read(activeLearnerStateProvider),
        isA<AsyncLoading<LearnerState?>>(),
      );
    });
  });
}
