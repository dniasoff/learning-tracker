// Story 2.11 (DNI-502) T1: the Dashboard forecast read path copies the
// engine's LearnerState values (AD-35, AD-44), is parent-only (NFR-9) and
// passes load errors through for the card's retry (AC-8).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/dashboard/presentation/providers/dashboard_forecast_providers.dart';

import '../../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../../helpers/learner_state/provider_settle.dart';

ProviderContainer _container({bool parent = true, LearnerState? state}) {
  final container = ProviderContainer(
    overrides: forecastOverrides(parent: parent, state: state),
  );
  addTearDown(container.dispose);
  return container;
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
    final value = await settledAsync(
      _container(state: state),
      parentForecastProvider,
    );
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
    final value = await settledAsync(
      _container(parent: false, state: state),
      parentForecastProvider,
    );
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
    // No learner-state override: the C0 stub fails the read.
    final value = await settledAsync(_container(), parentForecastProvider);
    expect(value, isA<AsyncError<List<CurriculumForecast>>>());
  });

  test('the detail opener is unbound until DNI-497 lands', () {
    expect(_container().read(subTrackDetailOpenerProvider), isNull);
  });
}
