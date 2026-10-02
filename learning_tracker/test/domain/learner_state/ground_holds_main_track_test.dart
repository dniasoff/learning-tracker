// Story 2.7 (DNI-498) AC-6 at the engine: a leaf held by a `holdsGround`
// sub-track stays in the corpus (visible, with its progress) but is not
// scheduled on the main track; once every holder has ended, its unlearnt
// leaves are scheduled again (FR-12a) and learnt ones stay learnt.
// Overlapping holders stay independent: ending one does not release a leaf
// another still holds (no reconciliation, UX-DR-167).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

SubTrack _track(
  int n,
  String name,
  List<NodeEntry> ground, {
  bool ended = false,
}) => SubTrack(
  id: engineUlid(n),
  curriculumId: engineCurriculum,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 2,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: engineUlid(900),
  endedAt: ended ? engineAt(5000) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

CurriculumState _run(List<SubTrack> tracks, {List<String> learnt = const []}) =>
    const LearnerStateEngine().run(
      engineInputs(
        subTracks: tracks,
        events: [
          for (final (i, ref) in learnt.indexed) engineLearn(i + 1, ref),
        ],
      ),
    )[engineCurriculum]!;

void main() {
  final corpus = mishnayosCorpus();
  final b2 = corpus.leavesUnder(berakhot2);

  test('a held leaf is visible with its progress but not scheduled', () {
    final state = _run(
      [
        _track(1, 'School', const [berakhot2]),
      ],
      learnt: [b2.first],
    );
    expect(corpus.leaves, containsAll(b2));
    for (final leaf in b2) {
      expect(state.schedulableRefs, isNot(contains(leaf)));
    }
    expect(state.learntLeaves, contains(b2.first));
    expect(state.triState(berakhot2), TriState.partial);
    expect(state.subTracks[engineUlid(1)]!.holdsGround, isTrue);
  });

  test('the holder name tags the held leaves for the main-track views', () {
    final tracks = [
      _track(1, 'School', const [berakhot2]),
    ];
    final state = _run(tracks);
    final held = heldLeafNames(
      groundHolders(
        tracks,
        curriculumId: engineCurriculum,
        holds: (t) => state.subTracks[t.id]?.holdsGround ?? false,
      ),
      corpus,
    );
    expect(
      {for (final l in b2) l: held[l]},
      {
        for (final l in b2) l: ['School'],
      },
    );
    expect(held.containsKey('Mishnah Berakhot 1:1'), isFalse);
  });

  test('after the holder ends, unlearnt returned leaves are scheduled and '
      'learnt ones stay learnt', () {
    final state = _run(
      [
        _track(1, 'School', const [berakhot2], ended: true),
      ],
      learnt: [b2.first],
    );
    expect(state.subTracks[engineUlid(1)]?.holdsGround ?? false, isFalse);
    expect(state.schedulableRefs, contains(b2.last));
    expect(state.schedulableRefs, isNot(contains(b2.first)));
    expect(state.learntLeaves, contains(b2.first));
  });

  test('overlap is never reconciled: another holder keeps the leaf off the '
      'main track after the first ends', () {
    final state = _run([
      _track(1, 'School', const [berakhot2], ended: true),
      _track(2, 'Rebbe', const [berakhot]),
    ]);
    for (final leaf in b2) {
      expect(state.schedulableRefs, isNot(contains(leaf)));
    }
    expect(state.subTracks[engineUlid(2)]!.holdsGround, isTrue);
  });
}
