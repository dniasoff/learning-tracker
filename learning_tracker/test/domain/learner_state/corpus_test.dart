// Mirror test for `lib/domain/learner_state/corpus.dart` (C0, DNI-524 AC-6).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

void main() {
  const seder = NodeEntry(level: 'seder', ref: 'Zeraim');
  const berakhot = NodeEntry(level: 'masechta', ref: 'Mishnah Berakhot');
  const peah = NodeEntry(level: 'masechta', ref: 'Mishnah Peah');
  const b1 = NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:1');
  const b2 = NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:2');
  const p1 = NodeEntry(level: 'mishnah', ref: 'Mishnah Peah 1:1');
  const moed = NodeEntry(level: 'seder', ref: 'Moed');

  InMemoryCorpus corpus() => InMemoryCorpus('mishnayos', const [
    CorpusNode(seder, [
      CorpusNode(berakhot, [CorpusNode(b1), CorpusNode(b2)]),
      CorpusNode(peah, [CorpusNode(p1)]),
    ]),
    CorpusNode(moed),
  ]);

  test('roots, children and leaves are in ContentIndex order', () {
    final c = corpus();
    expect(c.curriculumId, 'mishnayos');
    expect(c.roots, [seder, moed]);
    expect(c.childrenOf(seder), [berakhot, peah]);
    expect(c.childrenOf(b1), isEmpty);
    expect(c.leaves, [b1.ref, b2.ref, p1.ref, moed.ref]);
  });

  test('leavesUnder walks the subtree in order; a leaf yields itself', () {
    final c = corpus();
    expect(c.leavesUnder(seder), [b1.ref, b2.ref, p1.ref]);
    expect(c.leavesUnder(berakhot), [b1.ref, b2.ref]);
    expect(c.leavesUnder(b2), [b2.ref]);
  });

  test('parentOf, nodeForRef and isLeaf', () {
    final c = corpus();
    expect(c.parentOf(b1), berakhot);
    expect(c.parentOf(berakhot), seder);
    expect(c.parentOf(seder), isNull);
    expect(c.nodeForRef('Mishnah Peah'), peah);
    expect(c.nodeForRef('Nope'), isNull);
    expect(c.isLeaf(b1), isTrue);
    expect(c.isLeaf(berakhot), isFalse);
  });

  test('an unknown node is handled leniently', () {
    final c = corpus();
    const unknown = NodeEntry(level: 'masechta', ref: 'Unknown');
    expect(c.childrenOf(unknown), isEmpty);
    expect(c.parentOf(unknown), isNull);
    expect(c.isLeaf(unknown), isFalse);
    expect(c.leavesUnder(unknown), isEmpty);
  });

  test('a node that appears twice is rejected', () {
    expect(
      () => InMemoryCorpus('c', const [CorpusNode(b1), CorpusNode(b1)]),
      throwsArgumentError,
    );
  });

  test('unitLevels default to the non-leaf levels of the top two depths', () {
    expect(corpus().unitLevels, ['seder', 'masechta']);
    expect(InMemoryCorpus('c', const [CorpusNode(b1)]).unitLevels, isEmpty);
  });

  test('explicit unitLevels win over the default', () {
    final c = InMemoryCorpus(
      'c',
      const [
        CorpusNode(seder, [CorpusNode(b1)]),
      ],
      unitLevels: const ['seder'],
    );
    expect(c.unitLevels, ['seder']);
    expect(() => c.unitLevels.add('x'), throwsUnsupportedError);
  });

  test('returned lists are unmodifiable', () {
    final c = corpus();
    expect(() => c.leaves.add('x'), throwsUnsupportedError);
    expect(() => c.leavesUnder(seder).add('x'), throwsUnsupportedError);
  });
}
