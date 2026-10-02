// Mirror test for `lib/features/learning/domain/commands/unlearn_plan.dart`
// (DNI-469 AC-6: partial un-learn of a node event; exact, disjoint,
// maximal complement cover).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learning/domain/commands/unlearn_plan.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';

const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';
const _b21 = 'Mishnah Berakhot 2:1';
const _p11 = 'Mishnah Peah 1:1';

void main() {
  final corpus = mishnayosCorpus();

  UnlearnPlan plan(Set<String> s, List<LearningEvent> counted) => planUnlearn(
    curriculumId: engineCurriculum,
    leafSet: s,
    counted: counted,
    corpus: corpus,
  );

  test('maximal cover of Zeraim minus Berakhot 1:2 is exact, disjoint and '
      'maximal, in ContentIndex order', () {
    final cover = maximalCover(zeraim, {_b12}, corpus);
    expect(cover, [
      const NodeEntry(level: 'mishnah', ref: _b11),
      const NodeEntry(level: 'mishnah', ref: _b13),
      berakhot2,
      peah,
    ]);
    final leaves = [for (final n in cover) ...corpus.leavesUnder(n)];
    expect(leaves.toSet(), {
      ...corpus.leavesUnder(zeraim),
    }..remove(_b12));
    expect(leaves, hasLength(leaves.toSet().length), reason: 'no overlap');
  });

  test('an untouched node is its own cover; a fully covered one has none', () {
    expect(maximalCover(peah, {_b12}, corpus), [peah]);
    expect(
      maximalCover(berakhot1, {_b11, _b12, _b13}, corpus),
      isEmpty,
    );
  });

  test('a counted node event covering part of S is re-issued; leaf events '
      'in S are voided; others are left alone', () {
    final node = engineGround(1, zeraim);
    final leafIn = engineLearn(2, _b12);
    final leafOut = engineLearn(3, _p11);
    final other = engineLearn(4, _b12, curriculumId: 'other');
    final outside = engineGround(5, moed);
    final p = plan({_b12, _b21}, [node, leafIn, leafOut, other, outside]);

    expect(p.leafVoids, [leafIn]);
    expect(p.nodes.single.target, node);
    expect(p.nodes.single.reissues, [
      const NodeEntry(level: 'mishnah', ref: _b11),
      const NodeEntry(level: 'mishnah', ref: _b13),
      const NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 2:2'),
      peah,
    ]);
  });

  test('a node event wholly inside S is voided with no re-issue', () {
    final p = plan({_b11, _b12, _b13}, [engineGround(1, berakhot1)]);
    expect(p.nodes.single.reissues, isEmpty);
  });

  test('an unresolvable node event is never touched; empty plan', () {
    final unknown = engineGround(
      1,
      const NodeEntry(level: 'masechta', ref: 'Mishnah Unknown'),
    );
    final p = plan({_b11}, [unknown]);
    expect(p.isEmpty, isTrue);
  });
}
