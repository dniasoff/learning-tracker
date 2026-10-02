// Mirror test for
// `lib/features/sub_tracks/presentation/providers/held_ground_provider.dart`
// (Story 2.7 / DNI-498 AC-6): the main track's held leaves and their
// holders, from the engine's holdsGround; ended sub-tracks hold nothing and
// an unresolved read shows nothing held.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/presentation/providers/held_ground_provider.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state_fixtures.dart';
import '../../../../helpers/sub_tracks/ground_picker_harness.dart';

Future<Map<String, List<String>>> _held(
  GroundPickerWorld world, [
  String curriculumId = engineCurriculum,
]) async {
  final container = ProviderContainer(overrides: world.overrides);
  addTearDown(container.dispose);
  addTearDown(world.dispose);
  final provider = mainTrackHeldGroundProvider(curriculumId);
  container.listen(provider, (_, _) {});
  return container.read(provider.future);
}

SubTrack _t(
  String id,
  String name, {
  required List<NodeEntry> ground,
  bool ended = false,
  String? windowEnd,
}) => fixtureTrack(
  id,
  name,
  curriculumId: engineCurriculum,
  ground: ground,
  ended: ended,
  windowEnd: windowEnd,
);

void main() {
  final corpus = mishnayosCorpus();

  test('every leaf a holding sub-track holds names its holders', () async {
    final held = await _held(
      GroundPickerWorld(
        corpus: corpus,
        tracks: [
          _t(schoolId, 'School', ground: const [berakhot2]),
          _t(rebbeId, 'Rebbe', ground: const [berakhot]),
          _t(ulidD, 'Ended', ground: const [peah], ended: true),
        ],
      ),
    );
    for (final leaf in corpus.leavesUnder(berakhot2)) {
      expect(held[leaf], ['School', 'Rebbe']);
    }
    for (final leaf in corpus.leavesUnder(berakhot1)) {
      expect(held[leaf], ['Rebbe']);
    }
    expect(held.keys, isNot(contains('Mishnah Peah 1:1')));
  });

  test('a sub-track the engine says no longer holds is not shown', () async {
    final held = await _held(
      GroundPickerWorld(
        corpus: corpus,
        tracks: [
          _t(schoolId, 'School', ground: const [berakhot2]),
        ],
        subTrackStates: {
          schoolId: const SubTrackState(
            subTrackId: schoolId,
            holdsGround: false,
            inForecast: false,
            onHome: false,
          ),
        },
      ),
    );
    expect(held, isEmpty);
  });

  test(
    'an expired window the engine says no longer holds is not shown',
    () async {
      // Not ended, but its window closed (AD-34: today > window_end).
      final held = await _held(
        GroundPickerWorld(
          corpus: corpus,
          tracks: [
            _t(
              schoolId,
              'School',
              ground: const [berakhot2],
              windowEnd: '2026-09-15',
            ),
          ],
          subTrackStates: {
            schoolId: const SubTrackState(
              subTrackId: schoolId,
              holdsGround: false,
              inForecast: false,
              onHome: false,
            ),
          },
        ),
      );
      expect(held, isEmpty);
    },
  );

  test('a live sub-track with no engine state holds nothing', () async {
    final held = await _held(
      GroundPickerWorld(
        corpus: corpus,
        tracks: [
          _t(schoolId, 'School', ground: const [berakhot2]),
        ],
        subTrackStates: const {},
      ),
    );
    expect(held, isEmpty);
  });

  test(
    'no live sub-track of the curriculum: nothing held, no corpus read',
    () async {
      final world = GroundPickerWorld(
        corpus: corpus,
        tracks: [
          _t(schoolId, 'School', ground: const [berakhot2], ended: true),
        ],
      );
      expect(await _held(world), isEmpty);
      expect(world.corpusReads, 0);
    },
  );
}
