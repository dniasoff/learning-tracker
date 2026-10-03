// Story 4.3 (DNI-511) AC-2 / AC-3 (unit): a talmid row's status and next
// position are the engine's, through the on-track card's own mapping
// (OnTrackView.of), so the row and the card cannot disagree.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/progress/progress.dart';
import 'package:learning_tracker/features/sub_tracks/domain/models/talmid_row_state.dart';
import 'package:learning_tracker/features/sub_tracks/domain/use_cases/build_talmid_row_state.dart';

import '../../../helpers/dashboard/forecast_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';

SubTrackState _sub(
  String id, {
  String name = 'Rebbe',
  String? position,
  bool exhausted = false,
  bool onHome = true,
}) => SubTrackState(
  subTrackId: id,
  name: name,
  holdsGround: true,
  inForecast: true,
  onHome: onHome,
  position: position,
  groundExhausted: exhausted,
);

TalmidRowReady _row(
  Projection projection, {
  int? dailyTarget,
  Map<String, SubTrackState> subTracks = const {},
}) => buildTalmidRowState(
  forecastState([
    forecastCurriculumState(
      projection: projection,
      dailyTarget: dailyTarget,
      subTracks: subTracks,
    ),
  ]),
);

/// The on-track card's chip for the same curriculum state.
PaceReportStatus? _cardStatus(LearnerState state) {
  final c = state[forecastCurriculum]!;
  return OnTrackView.of(c, c.report)?.status;
}

void main() {
  group('AC-2: status is the engine status, mapped as the on-track card', () {
    test('on track', () {
      expect(
        _row(
          const Projection(status: ProjectionStatus.onTrack),
          dailyTarget: 3,
        ).status,
        TalmidStatus.onTrack,
      );
    });

    test('behind pace', () {
      expect(
        _row(
          const Projection(status: ProjectionStatus.behindPace),
          dailyTarget: 5,
        ).status,
        TalmidStatus.behindPace,
      );
    });

    test('under 14 days with a deadline: too early to tell', () {
      expect(
        _row(
          const Projection(status: ProjectionStatus.tooEarly),
          dailyTarget: 2,
        ).status,
        TalmidStatus.tooEarly,
      );
    });

    test('no deadline: no status chip, the detail line stays (FR-20)', () {
      final row = _row(
        const Projection(status: ProjectionStatus.noDeadline),
        subTracks: {
          rebbeSubTrackId: _sub(
            rebbeSubTrackId,
            position: 'Mishnah Beitzah 3:1',
          ),
        },
      );
      expect(row.status, isNull);
      expect(row.line, isA<TalmidTrackNext>());
    });

    test('under 14 days with no deadline: still no chip', () {
      expect(
        _row(const Projection(status: ProjectionStatus.tooEarly)).status,
        isNull,
      );
    });

    group('real engine, 13/14-day boundary', () {
      final now = DateTime.utc(2026, 10, 8, 12);
      final events = [
        forecastLearn(1, 'Mishnah Berakhot 1:1', '2026-09-26'),
        forecastLearn(2, 'Mishnah Berakhot 1:2', '2026-10-01'),
      ];

      test('13 days of history: too early to tell, as the card', () {
        final state = engineForecastState(
          nowUtc: now,
          trackingStartDate: '2026-09-26',
          events: events,
          deadline: '2027-06-01',
        );
        expect(buildTalmidRowState(state).status, TalmidStatus.tooEarly);
        expect(_cardStatus(state), PaceReportStatus.tooEarly);
      });

      test('exactly 14 days: an evaluated status, as the card', () {
        final state = engineForecastState(
          nowUtc: now,
          trackingStartDate: '2026-09-25',
          events: events,
          deadline: '2027-06-01',
        );
        final status = buildTalmidRowState(state).status;
        expect(status, isNot(TalmidStatus.tooEarly));
        expect(status, isNotNull);
        expect(status!.name, _cardStatus(state)!.name);
      });

      test('no deadline: no chip from the real engine either', () {
        final state = engineForecastState(
          nowUtc: now,
          trackingStartDate: '2026-09-01',
          events: events,
        );
        expect(buildTalmidRowState(state).status, isNull);
        expect(_cardStatus(state), isNull);
      });
    });
  });

  group('detail line', () {
    test('the engine next position of the live sub-track', () {
      expect(
        _row(
          const Projection(status: ProjectionStatus.onTrack),
          dailyTarget: 3,
          subTracks: {
            rebbeSubTrackId: _sub(
              rebbeSubTrackId,
              position: 'Mishnah Beitzah 3:1',
            ),
          },
        ).line,
        const TalmidTrackNext(
          subTrackId: rebbeSubTrackId,
          curriculumId: forecastCurriculum,
          name: 'Rebbe',
          position: 'Mishnah Beitzah 3:1',
        ),
      );
    });

    test('AC-3: a groundless sub-track reads no ground yet', () {
      expect(
        _row(
          const Projection(status: ProjectionStatus.noDeadline),
          subTracks: {rebbeSubTrackId: _sub(rebbeSubTrackId)},
        ).line,
        const TalmidTrackNoGround(
          subTrackId: rebbeSubTrackId,
          curriculumId: forecastCurriculum,
          name: 'Rebbe',
        ),
      );
    });

    test('every ground leaf recorded: all recorded, no Add ground', () {
      expect(
        _row(
          const Projection(status: ProjectionStatus.noDeadline),
          subTracks: {rebbeSubTrackId: _sub(rebbeSubTrackId, exhausted: true)},
        ).line,
        isA<TalmidTrackAllRecorded>(),
      );
    });

    test('the newest live sub-track is the one shown; ended ones never', () {
      final row = _row(
        const Projection(status: ProjectionStatus.noDeadline),
        subTracks: {
          // schoolSubTrackId sorts after rebbeSubTrackId, but is not live.
          schoolSubTrackId: _sub(
            schoolSubTrackId,
            name: 'School',
            position: 'Mishnah Berakhot 1:1',
            onHome: false,
          ),
          rebbeSubTrackId: _sub(rebbeSubTrackId, position: 'Mishnah Peah 1:1'),
          engineUlid(1): _sub(
            engineUlid(1),
            name: 'Older',
            position: 'Mishnah Peah 2:1',
          ),
        },
      );
      expect((row.line! as TalmidTrackNext).name, 'Rebbe');
    });

    test('no live sub-track: the main-track position', () {
      final state = forecastState([
        forecastCurriculumState(
          projection: const Projection(status: ProjectionStatus.noDeadline),
        ),
      ]);
      expect(buildTalmidRowState(state).line, isNull);

      final engine = engineForecastState(
        nowUtc: DateTime.utc(2026, 10, 8, 12),
        trackingStartDate: '2026-09-01',
      );
      expect(buildTalmidRowState(engine).line, isA<TalmidMainTrackNext>());
    });

    test('a real engine sub-track with no ground is groundless', () {
      final rebbe = SubTrack(
        id: rebbeSubTrackId,
        curriculumId: engineCurriculum,
        name: 'Rebbe',
        type: SubTrackType.ongoing,
        windowStart: '2026-09-01',
        ratePerWeek: 5,
        weeksPerYear: 39,
        learnsOnShabbos: false,
        ground: const [],
        lastChangeId: engineUlid(2),
      );
      final state = engineForecastState(
        nowUtc: DateTime.utc(2026, 10, 8, 12),
        trackingStartDate: '2026-09-01',
        subTracks: [rebbe],
      );
      expect(buildTalmidRowState(state).line, isA<TalmidTrackNoGround>());
    });
  });
}
