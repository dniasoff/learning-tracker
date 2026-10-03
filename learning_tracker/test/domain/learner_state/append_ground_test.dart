// Mirror test for `lib/domain/learner_state/append_ground.dart` (Story 2.7 /
// DNI-498 AC-4 and edge cases: picked ground appended in tree order, never
// duplicating what the sub-track already covers).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/append_ground.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

const _peah1 = NodeEntry(level: 'chapter', ref: 'Mishnah Peah 1');
const _shabbat1 = NodeEntry(level: 'chapter', ref: 'Mishnah Shabbat 1');
const _berakhot11 = NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:1');

void main() {
  final corpus = mishnayosCorpus();

  List<NodeEntry> append(List<NodeEntry> current, List<NodeEntry> selected) =>
      groundToAppend(current: current, selected: selected, corpus: corpus);

  group('corpusHoldsNode', () {
    test('a node of the tree, at its own level', () {
      expect(corpusHoldsNode(corpus, berakhot), isTrue);
      expect(corpusHoldsNode(corpus, _berakhot11), isTrue);
    });

    test('an unknown ref or a known ref under another level is not held', () {
      expect(
        corpusHoldsNode(
          corpus,
          const NodeEntry(level: 'masechta', ref: 'Berakhot'),
        ),
        isFalse,
      );
      expect(
        corpusHoldsNode(
          corpus,
          const NodeEntry(level: 'perek', ref: 'Mishnah Berakhot 1'),
        ),
        isFalse,
      );
    });
  });

  group('groundToAppend (AC-4)', () {
    test('groundless: the picked nodes in tree order, not pick order', () {
      expect(append(const [], const [_shabbat1, _peah1, berakhot2]), [
        berakhot2,
        _peah1,
        _shabbat1,
      ]);
    });

    test('a node already covered by a stored ancestor is not added', () {
      expect(append(const [berakhot], const [berakhot1, berakhot2]), isEmpty);
      expect(append(const [zeraim], const [_berakhot11]), isEmpty);
    });

    test('an ancestor of stored ground adds only its uncovered part and '
        'never rewrites the stored entry', () {
      const current = [berakhot1];
      expect(append(current, const [zeraim]), [berakhot2, peah]);
    });

    test('a picked node keeps its own level, never coarsened', () {
      // Shabbat perek 1 is the only perek of the only masechta of Moed.
      expect(append(const [], const [_shabbat1]), [_shabbat1]);
      expect(append(const [], const [berakhot1, berakhot2]), [
        berakhot1,
        berakhot2,
      ]);
    });

    test('a partly covered pick adds its uncovered children', () {
      expect(append(const [_berakhot11], const [berakhot1]), const [
        NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:2'),
        NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:3'),
      ]);
    });

    test('ancestor and descendant both picked give one entry', () {
      expect(append(const [], const [berakhot1, berakhot, _berakhot11]), [
        berakhot,
      ]);
    });

    test('duplicate picks give one entry', () {
      expect(append(const [], const [_peah1, _peah1]), [_peah1]);
    });

    test('an empty corpus or an empty pick adds nothing', () {
      expect(
        groundToAppend(
          current: const [],
          selected: const [berakhot],
          corpus: InMemoryCorpus(engineCurriculum, const []),
        ),
        isEmpty,
      );
      expect(append(const [], const []), isEmpty);
    });

    test('a node outside the corpus expands to nothing', () {
      expect(
        append(const [], const [NodeEntry(level: 'masechta', ref: 'Shabbat')]),
        isEmpty,
      );
    });

    test('the appended ground expands to the stored leaves followed by the '
        'new ones; a replay appends nothing', () {
      const current = [_peah1];
      final added = append(current, const [berakhot1, _shabbat1]);
      final ground = [...current, ...added];
      expect(expandGround(ground, corpus), [
        ...corpus.leavesUnder(_peah1),
        ...corpus.leavesUnder(berakhot1),
        ...corpus.leavesUnder(_shabbat1),
      ]);
      expect(append(ground, const [berakhot1, _shabbat1]), isEmpty);
    });
  });
}
