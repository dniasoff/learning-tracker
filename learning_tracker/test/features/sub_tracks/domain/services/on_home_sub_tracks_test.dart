// Story 2.10 (DNI-501) T1: the onHome sub-tracks every capture surface
// offers, joined with the engine state, in hub order.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/on_home_sub_tracks.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/fake_learner_state.dart';
import '../../helpers/up_to_fixtures.dart';

SubTrack _named(int id, String name, {String start = '2026-09-01'}) {
  final t = fixtureSubTrack(engineUlid(id), name);
  return SubTrack(
    id: t.id,
    curriculumId: t.curriculumId,
    name: name,
    type: t.type,
    windowStart: start,
    ratePerWeek: t.ratePerWeek,
    weeksPerYear: t.weeksPerYear,
    learnsOnShabbos: t.learnsOnShabbos,
    ground: t.ground,
    lastChangeId: t.lastChangeId,
  );
}

void main() {
  final b = _named(2, 'B');
  final a = _named(3, 'A');
  final early = _named(4, 'Z', start: '2026-08-01');
  final off = _named(5, 'Off');

  final state = fakeLearnerState(
    curricula: {
      engineCurriculum: FakeCurriculumState(
        curriculumId: engineCurriculum,
        subTracks: {
          for (final t in [a, b, early]) t.id: fixtureSubTrackState(t.id),
          off.id: fixtureSubTrackState(off.id, onHome: false),
        },
      ),
    },
  );

  test('hub order: window_start, then name, then id; not-onHome and '
      'unknown tracks left out', () {
    final rows = onHomeSubTracks([b, a, early, off, _named(6, 'Ghost')], state);
    expect([for (final r in rows) r.track.name], ['Z', 'A', 'B']);
    expect(rows.first.state.subTrackId, early.id);
  });

  test('filters to one curriculum when asked', () {
    expect(onHomeSubTracks([a], state, curriculumId: 'bavli'), isEmpty);
    expect(onHomeSubTracks([a], state, curriculumId: engineCurriculum), [
      isA<OnHomeSubTrack>().having((r) => r.id, 'id', a.id),
    ]);
  });
}
