// Story 2.9 (DNI-500) T1 — the Learn/Dashboard sub-track projection reads
// every number from the engine and only filters, orders and labels.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_home_projection.dart';

import '../../../helpers/learner_state/fake_learner_state.dart';
import '../../../helpers/sub_tracks/sub_track_home_fixtures.dart';

void main() {
  group('projectHomeSubTracks', () {
    test('one item per onHome track, in hub (creation) order', () {
      final items = projectHomeSubTracks(
        // Deliberately out of order: hub order is ascending ULID.
        subTracks: [
          homeSubTrack(id: rebbeId, name: 'Rebbe'),
          homeSubTrack(id: schoolId),
        ],
        learnerState: homeLearnerState([
          homeState(schoolId, position: 'Mishnah_Berakhot_1.4'),
          homeState(rebbeId, position: 'Mishnah_Peah_2.1'),
        ]),
      );
      expect(items.map((i) => i.name), ['School', 'Rebbe']);
      expect(items.first.position, 'Mishnah_Berakhot_1.4');
      expect(items.first.kind, SubTrackRowKind.active);
      expect(items.first.canCapture, isTrue);
    });

    test('one row however many masechtos the ground holds', () {
      final items = projectHomeSubTracks(
        subTracks: [homeSubTrack(id: schoolId)], // two masechtos
        learnerState: homeLearnerState([
          homeState(schoolId, position: 'Mishnah_Berakhot_1.1'),
        ]),
      );
      expect(items, hasLength(1));
    });

    test('engine onHome=false (future start, ended, window passed) and a '
        'track the engine has no state for have no item', () {
      final items = projectHomeSubTracks(
        subTracks: [
          homeSubTrack(id: schoolId),
          homeSubTrack(id: rebbeId, name: 'Rebbe'),
          homeSubTrack(id: futureId, name: 'Future'),
        ],
        learnerState: homeLearnerState([
          homeState(schoolId, onHome: false),
          homeState(rebbeId, position: 'Mishnah_Peah_1.1'),
          // futureId: no engine state at all.
        ]),
      );
      expect(items.map((i) => i.subTrackId), [rebbeId]);
    });

    test('a curriculum with no engine state yields nothing', () {
      expect(
        projectHomeSubTracks(
          subTracks: [homeSubTrack(id: schoolId)],
          learnerState: fakeLearnerState(),
        ),
        isEmpty,
      );
    });

    test('groundless: no position, cannot capture', () {
      final item = projectHomeSubTracks(
        subTracks: [homeSubTrack(id: schoolId, ground: const [])],
        learnerState: homeLearnerState([homeState(schoolId)]),
      ).single;
      expect(item.kind, SubTrackRowKind.groundless);
      expect(item.position, isNull);
      expect(item.canCapture, isFalse);
    });

    test('every leaf ticked (exhausted, or no position) is allRecorded', () {
      for (final state in [
        homeState(schoolId, groundExhausted: true, position: 'x', ticked: 9),
        homeState(schoolId, ticked: 9),
      ]) {
        final item = projectHomeSubTracks(
          subTracks: [homeSubTrack(id: schoolId)],
          learnerState: homeLearnerState([state]),
        ).single;
        expect(item.kind, SubTrackRowKind.allRecorded);
        expect(item.position, isNull);
        expect(item.canCapture, isFalse);
      }
    });

    test('ticked and remaining come from the engine; progress is '
        'ticked / (ticked + remaining)', () {
      final item = projectHomeSubTracks(
        subTracks: [homeSubTrack(id: schoolId)],
        learnerState: homeLearnerState([
          homeState(
            schoolId,
            position: 'b',
            ticked: 1,
            remainingPath: const ['b', 'c', 'd'],
          ),
        ]),
      ).single;
      expect(item.ticked, 1);
      expect(item.remaining, 3);
      expect(item.progress, 0.25);
    });

    test('zero ticked and zero remaining is 0, never a divide by zero', () {
      const item = SubTrackHomeItem(
        subTrackId: schoolId,
        curriculumId: mishnayos,
        name: 'School',
        kind: SubTrackRowKind.groundless,
      );
      expect(item.progress, 0);
      expect(item.progress.isNaN, isFalse);
    });

    test('a leaf shared with another track does not move this track: each '
        'item carries only its own engine position', () {
      final items = projectHomeSubTracks(
        subTracks: [
          homeSubTrack(id: schoolId),
          homeSubTrack(id: rebbeId, name: 'Rebbe'),
        ],
        learnerState: homeLearnerState([
          homeState(schoolId, position: 'Mishnah_Berakhot_1.2', ticked: 1),
          homeState(rebbeId, position: 'Mishnah_Berakhot_1.1'),
        ]),
      );
      expect(items[0].position, 'Mishnah_Berakhot_1.2');
      expect(items[1].position, 'Mishnah_Berakhot_1.1');
    });

    test('items are value objects', () {
      const a = SubTrackHomeItem(
        subTrackId: schoolId,
        curriculumId: mishnayos,
        name: 'School',
        kind: SubTrackRowKind.active,
        position: 'p',
        ticked: 1,
        remaining: 2,
      );
      const b = SubTrackHomeItem(
        subTrackId: schoolId,
        curriculumId: mishnayos,
        name: 'School',
        kind: SubTrackRowKind.active,
        position: 'p',
        ticked: 1,
        remaining: 2,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.toString(), contains(schoolId));
    });
  });
}
