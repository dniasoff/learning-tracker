// Story 2.9 (DNI-500) T1 — homeSubTracksProvider joins the complete
// sub_tracks read with the engine state and keeps loading/error explicit.
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/sub_tracks/data/repositories/sub_track_sources.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/sub_track_providers.dart';

import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/in_memory_ports.dart';
import '../../../../helpers/learner_state/learner_state_overrides.dart';
import '../../../../helpers/sub_tracks/sub_track_home_fixtures.dart';

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

  test(
    'joins stored tracks with engine state, onHome only, hub order',
    () async {
      final repo = InMemorySubTrackRepository()
        ..seed(scope, [
          homeSubTrack(id: rebbeId, name: 'Rebbe'),
          homeSubTrack(id: schoolId),
        ]);
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
}
