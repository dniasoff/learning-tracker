// Mirror test for `lib/features/sub_tracks/domain/ground_selection.dart`
// (Story 2.7 / DNI-498 AC-2, AC-3 and the tree edge cases): distinct
// in-this-track / in-use / learnt predicates, parent selection, the draft
// mark, Available only, search, flattening and the live count — over a
// Mishnayos and a non-Mishnayos (Chumash-shaped) ContentIndex.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ground_selection.dart';

import '../../../helpers/learner_state/chumash_fixtures.dart';
import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state_fixtures.dart';

const _peah1 = NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1');
const _b11 = NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:1');
const _b12 = NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:2');
const _b13 = NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:3');

SubTrack _track(
  String id,
  String name, {
  List<NodeEntry> ground = const [],
  bool ended = false,
  String curriculumId = engineCurriculum,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 2,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: ulidE,
  endedAt: ended ? t1 : null,
  endReason: ended ? SubTrackEndReason.ended : null,
);

void main() {
  final corpus = mishnayosCorpus();

  GroundPickerModel model({
    List<NodeEntry> own = const [],
    Set<LeafRef> learnt = const {},
    Map<LeafRef, List<String>> held = const {},
    Corpus? on,
  }) => GroundPickerModel(
    corpus: on ?? corpus,
    ownGround: own,
    learnt: learnt,
    held: held,
  );

  group('holders (AC-3, AC-6)', () {
    final tracks = [
      _track(ulidA, 'School', ground: const [berakhot1]),
      _track(ulidB, 'Rebbe', ground: const [berakhot]),
      _track(ulidD, 'Ended', ground: const [peah], ended: true),
      _track(ulidE, 'Other', ground: const [peah], curriculumId: 'bavli'),
    ];

    test('other non-ended holding sub-tracks of the curriculum only', () {
      final holders = groundHolders(
        tracks,
        curriculumId: engineCurriculum,
        holds: (_) => true,
        exceptId: ulidA,
      );
      expect(holders.map((h) => h.name), ['Rebbe']);
    });

    test('the engine holdsGround answer is honoured (a passed window '
        'does not hold)', () {
      final holders = groundHolders(
        tracks,
        curriculumId: engineCurriculum,
        holds: (t) => t.id != ulidB,
      );
      expect(holders.map((h) => h.name), ['School']);
    });

    test('overlapping holders are all named, never reconciled', () {
      final held = heldLeafNames(
        groundHolders(
          tracks,
          curriculumId: engineCurriculum,
          holds: (_) => true,
        ),
        corpus,
      );
      expect(held['Mishnah Berakhot 1:1'], ['School', 'Rebbe']);
      expect(held['Mishnah Berakhot 2:1'], ['Rebbe']);
      expect(held.containsKey('Mishnah Peah 1:1'), isFalse);
      expect(holderNamesUnder(zeraim, corpus, held), ['School', 'Rebbe']);
    });
  });

  group('AC-3 row state', () {
    test('stored ground is pre-checked and disabled, a child of a stored '
        'ancestor included', () {
      final m = model(own: const [berakhot]);
      final draft = GroundDraft.empty(m);
      for (final node in [berakhot, berakhot1, _b11]) {
        final row = m.rowOf(node, draft);
        expect(row.inThisTrack, isTrue, reason: '$node');
        expect(row.enabled, isFalse);
        expect(row.mark, GroundSelectionMark.checked);
      }
      final seder = m.rowOf(zeraim, draft);
      expect(seder.inThisTrack, isFalse);
      expect(seder.enabled, isTrue);
    });

    test('ground in use elsewhere stays selectable and names its holder', () {
      final m = model(
        held: {
          'Mishnah Peah 1:1': const ['Rebbe'],
        },
      );
      final row = m.rowOf(peah, GroundDraft.empty(m));
      expect(row.inUseBy, ['Rebbe']);
      expect(row.enabled, isTrue);
      final picked = GroundDraft.empty(m).toggle(peah);
      expect(picked.markOf(peah), GroundSelectionMark.checked);
    });

    test('learnt ground is Chazara and selectable; partial progress is not '
        'a selection', () {
      final m = model(learnt: {..._leavesOf(corpus, berakhot1)});
      final draft = GroundDraft.empty(m);
      final perek = m.rowOf(berakhot1, draft);
      expect(perek.progress, TriState.complete);
      expect(perek.isChazara, isTrue);
      expect(perek.enabled, isTrue);
      final masechta = m.rowOf(berakhot, draft);
      expect(masechta.progress, TriState.partial);
      expect(masechta.isChazara, isFalse);
      expect(masechta.mark, GroundSelectionMark.unchecked);
      expect(m.rowOf(_b11, draft).leafCount, 1);
      expect(m.rowOf(berakhot, draft).childCount, 2);
      expect(m.rowOf(berakhot, draft).leafCount, 5);
    });
  });

  group('AC-3 draft selection', () {
    test('selecting a parent selects its descendants', () {
      final m = model();
      final d = GroundDraft.empty(m).toggle(berakhot);
      for (final node in [berakhot, berakhot1, berakhot2, _b12]) {
        expect(d.markOf(node), GroundSelectionMark.checked, reason: '$node');
      }
      expect(d.markOf(zeraim), GroundSelectionMark.partial);
      expect(d.markOf(peah), GroundSelectionMark.unchecked);
      expect(m.appended(d), [berakhot]);
    });

    test('clearing one descendant of a picked parent keeps its siblings at '
        'the coarsest level', () {
      final m = model();
      final d = GroundDraft.empty(m).toggle(zeraim).toggle(_b12);
      expect(d.markOf(_b12), GroundSelectionMark.unchecked);
      expect(d.markOf(berakhot1), GroundSelectionMark.partial);
      expect(d.markOf(zeraim), GroundSelectionMark.partial);
      expect(m.appended(d), [_b11, _b13, berakhot2, peah]);
    });

    test('a partial node toggles to whole, a whole one clears', () {
      final m = model();
      final partial = GroundDraft.empty(m).toggle(_b11);
      final whole = partial.toggle(berakhot1);
      expect(whole.markOf(berakhot1), GroundSelectionMark.checked);
      expect(whole.picks, {berakhot1});
      expect(whole.toggle(berakhot1).isEmpty, isTrue);
    });

    test('picking every child marks the parent checked', () {
      final m = model();
      final d = GroundDraft.empty(m).toggle(berakhot1).toggle(berakhot2);
      expect(d.markOf(berakhot), GroundSelectionMark.checked);
      expect(m.appended(d), [berakhot1, berakhot2]);
    });

    test('an ancestor of stored ground picks only the uncovered rest', () {
      final m = model(own: const [berakhot1]);
      final d = GroundDraft.empty(m).toggle(berakhot);
      expect(d.markOf(berakhot), GroundSelectionMark.checked);
      expect(m.appended(d), [berakhot2]);
      // Clearing the ancestor leaves the stored ground untouched.
      expect(d.toggle(berakhot).isEmpty, isTrue);
      expect(m.appended(d.toggle(berakhot)), isEmpty);
    });

    test('a node wholly in this sub-track or unknown to the corpus does not '
        'toggle', () {
      final m = model(own: const [berakhot1]);
      final empty = GroundDraft.empty(m);
      expect(empty.toggle(berakhot1).isEmpty, isTrue);
      expect(empty.toggle(_b11).isEmpty, isTrue);
      final unknown = empty.toggle(
        const NodeEntry(level: 'masechta', ref: 'Mishnah Nowhere'),
      );
      expect(unknown.isEmpty, isTrue);
    });

    test('Reset changes is a new empty draft; stored ground is untouched', () {
      final m = model(own: const [berakhot1]);
      final d = GroundDraft.empty(m).toggle(peah);
      final reset = GroundDraft.empty(m);
      expect(reset.isEmpty, isTrue);
      expect(d.isEmpty, isFalse);
      expect(m.rowOf(berakhot1, reset).inThisTrack, isTrue);
    });
  });

  group('AC-2 live count in the curriculum unit', () {
    test('uniform picks count in their own level', () {
      final m = model();
      final d = GroundDraft.empty(m).toggle(berakhot1).toggle(berakhot2);
      expect(m.summaryOf(d), const GroundAppendSummary(2, 'chapter'));
      expect(
        m.summaryOf(GroundDraft.empty(m)),
        const GroundAppendSummary(0, null),
      );
    });

    test('mixed levels count leaves in the leaf unit', () {
      final m = model();
      final d = GroundDraft.empty(m).toggle(berakhot1).toggle(peah);
      expect(m.summaryOf(d), const GroundAppendSummary(5, 'mishnah'));
    });

    test('a non-Mishnayos curriculum counts in its own levels', () {
      final m = model(on: chumashCorpus());
      final d = GroundDraft.empty(m).toggle(genesis1).toggle(exodus1);
      expect(m.summaryOf(d), const GroundAppendSummary(2, 'chapter'));
      final mixed = d.toggle(verse('Genesis 2:1'));
      expect(m.summaryOf(mixed), const GroundAppendSummary(6, 'verse'));
    });
  });

  group('AC-3 Available only (UX-DR-125)', () {
    test('hides in-use, learnt and already-assigned ground', () {
      final m = model(
        own: const [berakhot1],
        learnt: {..._leavesOf(corpus, berakhot2)},
        held: {
          for (final l in _leavesOf(corpus, peah)) l: const ['Rebbe'],
        },
      );
      expect(m.isAvailable(berakhot), isFalse);
      expect(m.isAvailable(peah), isFalse);
      expect(m.isAvailable(zeraim), isFalse);
      expect(m.isAvailable(moed), isTrue);
    });

    test('everything assigned or learnt leaves no root', () {
      final m = model(
        own: const [zeraim],
        learnt: {..._leavesOf(corpus, moed)},
      );
      expect(corpus.roots.where(m.isAvailable), isEmpty);
    });
  });

  group('edge: search, tree and boundaries', () {
    String label(NodeEntry n) => n.ref;

    test('search keeps matches with their ancestor path and descendants', () {
      final kept = nodesMatching(
        corpus,
        (n) => groundLabelMatches('peah', [label(n)]),
      );
      expect(kept, containsAll([zeraim, peah, _peah1]));
      expect(kept.contains(berakhot), isFalse);
      expect(kept.contains(moed), isFalse);
    });

    test('a query matching nothing keeps nothing', () {
      expect(
        nodesMatching(corpus, (n) => groundLabelMatches('zzz', [label(n)])),
        isEmpty,
      );
    });

    test('matching is case-insensitive over every label, Hebrew included', () {
      expect(groundLabelMatches(' BERA ', ['Berakhot', 'ברכות']), isTrue);
      expect(groundLabelMatches('ברכ', ['Berakhot', 'ברכות']), isTrue);
      expect(groundLabelMatches('', const []), isTrue);
      expect(groundLabelMatches('x', const []), isFalse);
    });

    test('flattening follows ContentIndex order and expansion', () {
      final rows = flattenGroundTree(
        corpus,
        expanded: {zeraim, berakhot},
        visible: (_) => true,
      );
      expect(
        [for (final r in rows) (r.node, r.depth)],
        [
          (zeraim, 0),
          (berakhot, 1),
          (berakhot1, 2),
          (berakhot2, 2),
          (peah, 1),
          (moed, 0),
        ],
      );
      final all = flattenGroundTree(
        corpus,
        expanded: const {},
        visible: (_) => true,
        expandAll: true,
      );
      expect(all.length, 18);
    });

    test('an empty curriculum yields no rows and no picks', () {
      final empty = InMemoryCorpus('empty', const []);
      final m = model(on: empty);
      expect(
        flattenGroundTree(empty, expanded: const {}, visible: (_) => true),
        isEmpty,
      );
      expect(m.summaryOf(GroundDraft.empty(m)).count, 0);
    });

    test('an unrecognised level is carried through, not crashed on', () {
      final odd = InMemoryCorpus('odd', const [
        CorpusNode(NodeEntry(level: 'level7', ref: 'Odd'), [
          CorpusNode(NodeEntry(level: 'level8', ref: 'Odd 1')),
        ]),
      ]);
      final m = model(on: odd);
      final d = GroundDraft.empty(
        m,
      ).toggle(const NodeEntry(level: 'level7', ref: 'Odd'));
      expect(m.summaryOf(d), const GroundAppendSummary(1, 'level7'));
    });

    test('duplicate and overlapping picks never produce invalid entries', () {
      final m = model();
      final d = GroundDraft.empty(
        m,
      ).toggle(berakhot1).toggle(_b11).toggle(berakhot);
      expect(m.appended(d), [berakhot]);
    });
  });
}

List<LeafRef> _leavesOf(Corpus corpus, NodeEntry node) =>
    corpus.leavesUnder(node);
