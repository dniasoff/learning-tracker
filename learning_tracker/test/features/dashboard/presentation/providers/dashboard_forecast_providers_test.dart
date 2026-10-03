// Story 2.11 (DNI-502) T1: the Dashboard forecast read path copies the
// engine's LearnerState values (AD-35, AD-44), is parent-only (NFR-9) and
// passes load errors through for the card's retry (AC-8).
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_session_provider.dart';

import '../../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../../helpers/learner_state/c0_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

/// Bumped to re-resolve the learner scope (a profile switch).
final _epoch = NotifierProvider<_Epoch, int>(_Epoch.new);

class _Epoch extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

ProviderContainer _container({bool parent = true, LearnerState? state}) {
  final container = ProviderContainer(
    overrides: forecastOverrides(parent: parent, state: state),
  );
  addTearDown(container.dispose);
  return container;
}

/// The parent forecast once the session role has resolved: until then it
/// is an empty list by design (fail closed, NFR-9).
Future<AsyncValue<List<CurriculumForecast>>> _settledForecast(
  ProviderContainer container,
) async {
  await settledAsync(container, parentSessionProvider);
  return settledAsync(container, parentForecastProvider);
}

const _projection = Projection(
  status: ProjectionStatus.behindPace,
  velocityPerDay: 1.5,
  projectedFinish: '2029-03-14',
  deadline: '2028-09-01',
  newlyLearntToday: 3,
);

void main() {
  final state = forecastState([
    forecastCurriculumState(
      projection: _projection,
      dailyTarget: 4,
      streak: const CurriculumStreak(current: 6, best: 9),
      subTracks: {
        schoolSubTrackId: shortfallSubTrack(
          id: schoolSubTrackId,
          name: 'School',
          shortfall: 40,
          lastNode: const NodeEntry(level: 'perek', ref: 'Mishnah Berakhot 3'),
          windowEnd: '2027-07-31',
        ),
        rebbeSubTrackId: shortfallSubTrack(
          id: rebbeSubTrackId,
          name: 'Rebbe',
          shortfall: 0,
        ),
      },
    ),
    // Not evaluated (no active track): never forecast.
    forecastCurriculumState(curriculumId: 'bavli', evaluated: false),
  ]);

  test('a parent session gets the engine values as they are', () async {
    final value = await _settledForecast(_container(state: state));
    final forecasts = value.requireValue;
    expect(forecasts, hasLength(1));
    final f = forecasts.single;
    expect(f.curriculumId, forecastCurriculum);
    expect(f.projection, _projection);
    expect(f.dailyTarget, 4);
    // Only the positive engine shortfall becomes a warning.
    expect(f.shortfalls, [
      const ShortfallWarning(
        curriculumId: forecastCurriculum,
        subTrackId: schoolSubTrackId,
        name: 'School',
        shortfall: 40,
        lastShortfallNode: NodeEntry(level: 'perek', ref: 'Mishnah Berakhot 3'),
        windowEnd: '2027-07-31',
      ),
    ]);
  });

  test('a child session never receives forecast values', () async {
    final value = await _settledForecast(
      _container(parent: false, state: state),
    );
    expect(value.requireValue, isEmpty);
  });

  test('an unresolved role is empty, never loading (NFR-9)', () {
    final container = ProviderContainer(
      overrides: forecastOverrides(
        parentSession: Completer<bool>().future,
        state: state,
      ),
    );
    addTearDown(container.dispose);
    final value = container.read(parentForecastProvider);
    expect(value, isA<AsyncData<List<CurriculumForecast>>>());
    expect(value.requireValue, isEmpty);
  });

  test('today figures are read for every role', () async {
    for (final parent in [true, false]) {
      final value = await settledAsync(
        _container(parent: parent, state: state),
        learnerTodayProvider,
      );
      final today = value.requireValue.single;
      expect(today.done, 3);
      expect(today.target, 4);
      expect(today.streak, const CurriculumStreak(current: 6, best: 9));
    }
  });

  test('a load error is passed through for the retry (AC-8)', () async {
    final container = ProviderContainer(
      overrides: forecastOverrides(
        states: Stream<LearnerState>.error(StateError('read failed')),
      ),
    );
    addTearDown(container.dispose);
    final value = await _settledForecast(container);
    expect(value, isA<AsyncError<List<CurriculumForecast>>>());
  });

  test('a profile switch never serves the previous learner\'s forecast or '
      'today figures (NFR-9)', () async {
    final learnerA = c0Scope(ownerUid: 'owner-a');
    final learnerB = c0Scope(ownerUid: 'owner-b');
    final next = Completer<LearnerScope>();
    var scopeBuilds = 0;
    LearnerState stateOf(int target) => forecastState([
      forecastCurriculumState(projection: _projection, dailyTarget: target),
    ]);
    final container = ProviderContainer(
      overrides: [
        parentSessionProvider.overrideWith((ref) async => true),
        activeLearnerScopeProvider.overrideWith((ref) async {
          ref.watch(_epoch);
          return ++scopeBuilds == 1 ? learnerA : next.future;
        }),
        learnerStateProvider.overrideWith(
          (ref, scope) => Stream.value(stateOf(scope == learnerA ? 4 : 9)),
        ),
      ],
    );
    addTearDown(container.dispose);
    final forecast = container.listen(parentForecastProvider, (_, _) {});
    final today = container.listen(learnerTodayProvider, (_, _) {});
    addTearDown(forecast.close);
    addTearDown(today.close);
    await _settledForecast(container);
    expect(forecast.read().requireValue.single.dailyTarget, 4);
    expect(today.read().requireValue.single.target, 4);

    container.read(_epoch.notifier).bump();
    await pumpEventQueue();
    // The scope re-resolves while Riverpod still retains learner A.
    final scope = container.read(activeLearnerScopeProvider);
    expect(scope.isLoading, isTrue);
    expect(scope.value, learnerA);
    expect(forecast.read().hasValue, isFalse);
    expect(today.read().hasValue, isFalse);

    next.complete(learnerB);
    await pumpEventQueue();
    expect(forecast.read().requireValue.single.dailyTarget, 9);
    expect(today.read().requireValue.single.target, 9);
  });

  test('the detail opener is bound in production (AC-5)', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(subTrackDetailOpenerProvider), subTrackDetailAction);
  });
}
