// Story 2.9 (DNI-500) T1 — homeSubTracksProvider joins the complete
// sub_tracks read with the engine state and keeps loading/error explicit.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';

/// A [SubTrackRepository] whose complete reads the test scripts, so a read
/// with rejected rows can be emitted. Single-subscription: events added
/// before the provider listens are buffered.
final class _ScriptedSubTrackRepository implements SubTrackRepository {
  final reads = StreamController<CompleteRead<SubTrack>>();

  /// Closes the scripted read stream.
  Future<void> close() => reads.close();

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) => reads.stream;

  @override
  Future<void> applyGovernedChange(LearnerScope scope, SubTrackChange change) =>
      throw UnimplementedError();
}

Future<AsyncValue<List<SubTrackHomeItem>>> _settle(
  ProviderContainer container,
) async {
  final sub = container.listen(homeSubTracksProvider, (_, __) {});
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
  final value = sub.read();
  sub.close();
  return value;
}

void main() {
  final scope = c0Scope();

  test('no active learner: empty, the engine is not consulted', () async {
    final container = ProviderContainer(
      overrides: learnerStateOverrides(scope: null),
    );
    addTearDown(container.dispose);
    final value = await _settle(container);
    expect(value, isA<AsyncData<List<SubTrackHomeItem>>>());
    expect(value.requireValue, isEmpty);
  });

  test('no sub-tracks: empty even while the engine is unavailable', () async {
    final repo = InMemorySubTrackRepository();
    final container = ProviderContainer(
      overrides: [
        ...learnerStateOverrides(scope: scope), // engine left as C0 stub
        subTrackRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    addTearDown(container.dispose);
    final value = await _settle(container);
    expect(value.requireValue, isEmpty);
  });

<<<<<<< HEAD
  test(
    'joins stored tracks with engine state, onHome only, hub order',
    () async {
      final repo = InMemorySubTrackRepository()
        ..seed(scope, [
          homeSubTrack(id: rebbeId, name: 'Rebbe'),
          homeSubTrack(id: schoolId),
        ]);
=======
    test('a calendar program marks the curriculum', () async {
      final h = SubTrackHarness(calendarProgramId: 'daf_yomi');
      addTearDown(h.dispose);
      final container = ProviderContainer(overrides: h.overrides());
      addTearDown(container.dispose);
      final intent = container.listen(
        subTrackCurriculumIntentProvider(subTrackTestCurriculum).future,
        (_, _) {},
      );
      expect((await intent.read()).followsCalendarProgram, isTrue);
    });

    test('no learner: both reads fail closed, never empty', () async {
>>>>>>> a2e140b94 (fix(sub-tracks): DNI-495 fail closed on unavailable commands and reads, keep a fractional pace)
      final container = ProviderContainer(
        overrides: [
          ...learnerStateOverrides(
            scope: scope,
            state: homeLearnerState([
              homeState(schoolId, position: 'Mishnah_Berakhot_1.4'),
              homeState(rebbeId, onHome: false),
            ]),
          ),
          subTrackRepositoryProvider.overrideWith((ref) async => repo),
        ],
      );
      addTearDown(container.dispose);
<<<<<<< HEAD
      final value = await _settle(container);
      expect(value.requireValue.map((i) => i.name), ['School']);
    },
  );

  test('no repository (account not ready): empty', () async {
    final container = ProviderContainer(
      overrides: [
        ...learnerStateOverrides(scope: scope),
        subTrackRepositoryProvider.overrideWith((ref) async => null),
      ],
    );
    addTearDown(container.dispose);
    expect((await _settle(container)).requireValue, isEmpty);
  });

  test('an engine error is forwarded for the section error', () async {
    final repo = InMemorySubTrackRepository()
      ..seed(scope, [homeSubTrack(id: schoolId)]);
    final container = ProviderContainer(
      overrides: [
        ...learnerStateOverrides(scope: scope),
        subTrackRepositoryProvider.overrideWith((ref) async => repo),
        learnerStateProvider.overrideWith(
          (ref, _) => Stream<LearnerState>.error(StateError('engine down')),
        ),
      ],
    );
    addTearDown(container.dispose);
    final value = await _settle(container);
    expect(value.hasError, isTrue);
    expect(value.error, isA<StateError>());
  });

  test('a sub-track read error is forwarded', () async {
    final container = ProviderContainer(
      overrides: [
        ...learnerStateOverrides(scope: scope),
        subTracksForScopeProvider.overrideWith(
          (ref, _) => Stream<Never>.error(StateError('read failed')),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect((await _settle(container)).hasError, isTrue);
  });

  test('a scope error is forwarded', () async {
    final container = ProviderContainer(
      overrides: [
        activeLearnerScopeProvider.overrideWith(
          (ref) => Future.error(StateError('scope')),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect((await _settle(container)).hasError, isTrue);
  });

  test('loading while the engine has not emitted', () async {
    final repo = InMemorySubTrackRepository()
      ..seed(scope, [homeSubTrack(id: schoolId)]);
    final never = StreamController<LearnerState>();
    addTearDown(never.close);
    final container = ProviderContainer(
      overrides: [
        ...learnerStateOverrides(scope: scope),
        subTrackRepositoryProvider.overrideWith((ref) async => repo),
        learnerStateProvider.overrideWith((ref, _) => never.stream),
      ],
    );
    addTearDown(container.dispose);
    expect((await _settle(container)).isLoading, isTrue);
  });

  group('rejected sub-track rows are surfaced, never dropped', () {
    const badRow = RejectedRow(
      'bad-row',
      StorageFormatException('SubTrack', 'kind', 'unknown value'),
    );

    ProviderContainer containerFor(_ScriptedSubTrackRepository repo) {
=======
      final tracks = container.listen(
        learnerSubTracksProvider.future,
        (_, _) {},
      );
      await expectLater(
        tracks.read(),
        throwsA(isA<SubTrackReadUnavailableException>()),
      );
      final intent = container.listen(
        subTrackCurriculumIntentProvider('mishnayos').future,
        (_, _) {},
      );
      await expectLater(
        intent.read(),
        throwsA(isA<SubTrackReadUnavailableException>()),
      );
    });

    test('no sub-track repository: an error, not zero rows', () async {
      final h = SubTrackHarness(
        seed: [storedSchoolYear('01JHARN0000000000000000001')],
      );
      addTearDown(h.dispose);
      final container = ProviderContainer(
        overrides: [
          ...h.overrides(subTrackRepository: false),
          subTrackRepositoryProvider.overrideWith((ref) async => null),
        ],
      );
      addTearDown(container.dispose);
      final tracks = container.listen(
        learnerSubTracksProvider.future,
        (_, _) {},
      );
      await expectLater(
        tracks.read(),
        throwsA(
          isA<SubTrackReadUnavailableException>().having(
            (e) => e.port,
            'port',
            'sub_tracks',
          ),
        ),
      );
    });

    test(
      'no governed-intent repository: an error, never a self-paced intent',
      () async {
        final h = SubTrackHarness(calendarProgramId: 'daf_yomi');
        addTearDown(h.dispose);
        final container = ProviderContainer(
          overrides: [
            ...h.overrides(governedIntentRepository: false),
            governedIntentRepositoryProvider.overrideWith((ref) async => null),
          ],
        );
        addTearDown(container.dispose);
        final intent = container.listen(
          subTrackCurriculumIntentProvider(subTrackTestCurriculum).future,
          (_, _) {},
        );
        await expectLater(
          intent.read(),
          throwsA(
            isA<SubTrackReadUnavailableException>().having(
              (e) => e.port,
              'port',
              'governed_intent',
            ),
          ),
        );
      },
    );

    test('pending failures keep only sub-track batches', () async {
      final commands = FakeLearningCommands();
>>>>>>> a2e140b94 (fix(sub-tracks): DNI-495 fail closed on unavailable commands and reads, keep a fractional pace)
      final container = ProviderContainer(
        overrides: [
          ...learnerStateOverrides(
            scope: scope,
            state: homeLearnerState([homeState(schoolId)]),
          ),
          subTrackRepositoryProvider.overrideWith((ref) async => repo),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(repo.close);
      return container;
    }

    test('valid rows alongside a rejected row: an error, not a clean '
        'projection', () async {
      final repo = _ScriptedSubTrackRepository();
      final container = containerFor(repo);
      repo.reads
        ..add(const CompleteReadLoading())
        ..add(
          CompleteReadReady(
            [homeSubTrack(id: schoolId)],
            rejected: const [badRow],
          ),
        );
      final value = await _settle(container);
      expect(value.hasError, isTrue);
      expect(value.hasValue, isFalse);
      final error = value.error;
      expect(error, isA<SubTrackRowsRejectedException>());
      expect(
        (error! as SubTrackRowsRejectedException).rejected.map((r) => r.docId),
        ['bad-row'],
      );
    });

    test('only rejected rows: an error, not an absent section', () async {
      final repo = _ScriptedSubTrackRepository();
      final container = containerFor(repo);
      repo.reads.add(CompleteReadReady(const [], rejected: const [badRow]));
      final value = await _settle(container);
      expect(value.hasError, isTrue);
      expect(value.error, isA<SubTrackRowsRejectedException>());
    });

    test('a later clean read recovers the projection', () async {
      final repo = _ScriptedSubTrackRepository();
      final container = containerFor(repo);
      final sub = container.listen(homeSubTracksProvider, (_, __) {});
      addTearDown(sub.close);
      repo.reads.add(
        CompleteReadReady(
          [homeSubTrack(id: schoolId)],
          rejected: const [badRow],
        ),
      );
      await _settle(container);
      expect(sub.read().hasError, isTrue);

      repo.reads.add(CompleteReadReady([homeSubTrack(id: schoolId)]));
      final value = await _settle(container);
      expect(value.hasError, isFalse);
      expect(value.requireValue.map((i) => i.name), ['School']);
    });
  });
}
