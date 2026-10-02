// DNI-497 (Story 2.6) AC-3 / AC-6 unit: the ground projection is a
// story-owned adapter over the engine (expandGround, triStateOf,
// holdsGround), not a second engine.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/sub_track_ground_projection.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';

SubTrack _sub(
  int id,
  String name,
  List<NodeEntry> ground, {
  String? end,
  bool ended = false,
}) => SubTrack(
  id: engineUlid(id),
  curriculumId: engineCurriculum,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  windowEnd: end,
  ratePerWeek: 2,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: engineUlid(id + 1),
  endedAt: ended ? engineAt(1) : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

/// Runs the real engine, then projects [track] from its outputs.
SubTrackGroundProjection _project(
  SubTrack track, {
  List<SubTrack> others = const [],
  List<LearningEvent> events = const [],
  List<NodeEntry>? ground,
}) {
  final all = [track, ...others];
  final state = const LearnerStateEngine().run(
    engineInputs(events: events, subTracks: all),
  );
  final c = state[engineCurriculum]!;
  return SubTrackGroundProjection.project(
    track: track,
    ground: ground ?? track.ground,
    corpus: mishnayosCorpus(),
    learntLeaves: c.learntLeaves,
    countedLearns: [
      for (final e in events)
        if (state.countedEventIds.contains(e.id)) e,
    ],
    subTracks: all,
    holdsGround: (id) => c.subTracks[id]?.holdsGround ?? false,
  );
}

void main() {
  group('rows follow the stored order and the engine expansion', () {
    test('one row per entry, in stored order', () {
      final shiur = _sub(10, 'Shiur', const [peah, berakhot1]);
      final p = _project(shiur);
      expect(p.entries.map((r) => r.node), [peah, berakhot1]);
      expect(p.entries.map((r) => r.entryIndex), [0, 1]);
      expect(p.entries.every((r) => r.depth == 0), isTrue);
    });

    test('duplicate expanded leaves render once (AD-34 later duplicates '
        'dropped)', () {
      final shiur = _sub(10, 'Shiur', const [berakhot2, berakhot]);
      final p = _project(shiur);
      expect(p.entries[0].leaves, [
        'Mishnah Berakhot 2:1',
        'Mishnah Berakhot 2:2',
      ]);
      // The masechta keeps only the leaves perek 2 did not already hold.
      expect(p.entries[1].leaves, [
        'Mishnah Berakhot 1:1',
        'Mishnah Berakhot 1:2',
        'Mishnah Berakhot 1:3',
      ]);
      final flat = [for (final r in p.entries) ...r.leaves];
      expect(flat, expandGround(shiur.ground, mishnayosCorpus()));
      // Its children never repeat perek 2 either.
      expect(p.childrenOf(p.entries[1]).map((r) => r.node), [berakhot1]);
    });

    test('a groundless sub-track projects no rows', () {
      expect(_project(_sub(10, 'Rebbe', const [])).isGroundless, isTrue);
    });
  });

  group('tri-state and counts derive from all-source learning', () {
    test('complete, partial and empty with nested counts', () {
      final shiur = _sub(10, 'Shiur', const [berakhot, peah, shabbat]);
      final p = _project(
        shiur,
        events: [
          engineLearn(1, 'Mishnah Berakhot 1:1', source: shiur.id),
          engineLearn(2, 'Mishnah Berakhot 2:1'),
          engineLearn(3, 'Mishnah Peah 1:1'),
          engineLearn(4, 'Mishnah Peah 1:2'),
        ],
      );
      final [b, pe, sh] = p.entries;
      expect((b.state, b.learnt, b.total), (TriState.partial, 2, 5));
      expect((pe.state, pe.learnt, pe.total), (TriState.complete, 2, 2));
      expect((sh.state, sh.learnt, sh.total), (TriState.empty, 0, 2));

      final perakim = p.childrenOf(b);
      expect(perakim.map((r) => (r.node, r.depth, r.learnt, r.total)), [
        (berakhot1, 1, 1, 3),
        (berakhot2, 1, 1, 2),
      ]);
      final mishnayot = p.childrenOf(perakim.first);
      expect(mishnayot.map((r) => r.depth), [2, 2, 2]);
      expect(mishnayot.every((r) => r.isLeaf && !r.expandable), isTrue);
      expect(mishnayot.first.state, TriState.complete);
      expect(p.isTickedHere('Mishnah Berakhot 1:1'), isTrue);
      expect(p.isTickedHere('Mishnah Berakhot 2:1'), isFalse);
    });
  });

  group('learnt-elsewhere labels (FR-9, FR-13, UX-DR-91)', () {
    test('main-track learning reads "home"; another sub-track names it; a '
        'leaf ticked here carries no label', () {
      final school = _sub(10, 'School', const [berakhot1, peah, shabbat]);
      final rebbe = _sub(20, 'Rebbe', const [shabbat]);
      final p = _project(
        school,
        others: [rebbe],
        events: [
          engineLearn(1, 'Mishnah Peah 1:1'),
          engineLearn(2, 'Mishnah Peah 1:2'),
          engineLearn(3, 'Mishnah Shabbat 1:1', source: rebbe.id),
          engineLearn(4, 'Mishnah Berakhot 1:1', source: school.id),
        ],
      );
      final [b1, pe, sh] = p.entries;
      expect(b1.learntAt, isNull);
      expect(pe.learntAt, const GroundLearntAt.home());
      expect(sh.learntAt, const GroundLearntAt.subTrack('Rebbe'));
      final leaves = p.childrenOf(b1);
      expect(leaves.first.learntAt, isNull);
      expect(leaves[1].learntAt, isNull, reason: 'not learnt anywhere');
    });

    test('the earliest counted source names the leaf; a voided event does '
        'not count', () {
      final school = _sub(10, 'School', const [peah1Leaf]);
      final rebbe = _sub(20, 'Rebbe', const []);
      final p = _project(
        school,
        others: [rebbe],
        events: [
          engineLearn(1, 'Mishnah Peah 1:1', source: rebbe.id, minutes: 5),
          engineLearn(2, 'Mishnah Peah 1:1', minutes: 1),
          engineVoid(3, 2, minutes: 2),
        ],
      );
      expect(p.entries.single.learntAt, const GroundLearntAt.subTrack('Rebbe'));
    });

    test('mixed sources leave the row unlabelled', () {
      final school = _sub(10, 'School', const [peah]);
      final rebbe = _sub(20, 'Rebbe', const []);
      final p = _project(
        school,
        others: [rebbe],
        events: [
          engineLearn(1, 'Mishnah Peah 1:1'),
          engineLearn(2, 'Mishnah Peah 1:2', source: rebbe.id),
        ],
      );
      expect(p.entries.single.learntAt, isNull);
    });
  });

  group('"In use" (UX-DR-92)', () {
    test('a leaf stays held while any other holdsGround track holds it', () {
      final school = _sub(10, 'School', const [berakhot, peah]);
      final rebbe = _sub(20, 'Rebbe', const [berakhot2]);
      final shiur = _sub(30, 'Shiur', const [berakhot1]);
      final ended = _sub(40, 'Old', const [peah], ended: true);
      final past = _sub(50, 'Past', const [peah], end: '2026-09-02');
      final p = _project(school, others: [rebbe, shiur, ended, past]);
      expect(p.entries[0].inUseBy, ['Rebbe', 'Shiur']);
      expect(p.entries[1].inUseBy, isEmpty);
      final perakim = p.childrenOf(p.entries[0]);
      expect(perakim[0].inUseBy, ['Shiur']);
      expect(perakim[1].inUseBy, ['Rebbe']);
    });
  });

  test('an optimistic order re-projects without changing which leaves '
      'are learnt', () {
    final shiur = _sub(10, 'Shiur', const [berakhot1, peah]);
    final events = [engineLearn(1, 'Mishnah Peah 1:1', source: shiur.id)];
    final p = _project(shiur, events: events, ground: const [peah, berakhot1]);
    expect(p.entries.map((r) => r.node), [peah, berakhot1]);
    expect(p.entries.first.learnt, 1);
  });
}

const peah1Leaf = NodeEntry(level: 'mishnah', ref: 'Mishnah Peah 1:1');
