// Story 4.3 (DNI-511) T2: the row's sub-track pick and status source. The
// AC-2 status matrix against the on-track card lives in
// test/features/sub_tracks/domain/talmidim_row_state_test.dart.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/use_cases/build_talmid_row_state.dart';

import '../../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../../helpers/learner_state/engine_fixtures.dart';

SubTrackState _live(String id, {String name = 'Rebbe', String? position}) =>
    SubTrackState(
      subTrackId: id,
      name: name,
      holdsGround: true,
      inForecast: true,
      onHome: true,
      position: position,
    );

void main() {
  test('the newest live sub-track wins across curricula', () {
    final state = forecastState([
      forecastCurriculumState(
        subTracks: {engineUlid(5): _live(engineUlid(5), name: 'School')},
      ),
      forecastCurriculumState(
        curriculumId: 'chumash',
        subTracks: {engineUlid(9): _live(engineUlid(9), name: 'Parsha')},
      ),
    ]);
    final picked = pickTalmidSubTrack(state)!;
    expect(picked.curriculumId, 'chumash');
    expect(picked.state.name, 'Parsha');
  });

  test('a curriculum that is not evaluated offers no sub-track or status', () {
    final state = forecastState([
      forecastCurriculumState(
        evaluated: false,
        projection: const Projection(status: ProjectionStatus.onTrack),
        dailyTarget: 3,
        subTracks: {engineUlid(5): _live(engineUlid(5))},
      ),
    ]);
    expect(pickTalmidSubTrack(state), isNull);
    expect(buildTalmidRowState(state), const TalmidRowReady());
  });

  test("the status follows the picked sub-track's curriculum", () {
    final state = forecastState([
      forecastCurriculumState(
        projection: const Projection(status: ProjectionStatus.behindPace),
        dailyTarget: 4,
      ),
      forecastCurriculumState(
        curriculumId: 'chumash',
        projection: const Projection(status: ProjectionStatus.onTrack),
        dailyTarget: 2,
        subTracks: {
          engineUlid(9): _live(engineUlid(9), position: 'Genesis 1:1'),
        },
      ),
    ]);
    expect(buildTalmidRowState(state).status, TalmidStatus.onTrack);
  });

  test('too early only with a deadline target; no deadline, no status', () {
    expect(
      talmidStatusOf(forecastCurriculumState(dailyTarget: 2)),
      TalmidStatus.tooEarly,
    );
    expect(talmidStatusOf(forecastCurriculumState()), isNull);
    expect(
      talmidStatusOf(
        forecastCurriculumState(
          projection: const Projection(status: ProjectionStatus.noDeadline),
        ),
      ),
      isNull,
    );
  });
}
