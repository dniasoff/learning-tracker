// DNI-467 AC-1: `orderedLeaves(corpus, orderDocs)` is the only main-track
// order function (AD-33).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/ordered_leaves.dart';

import '../../helpers/learner_state/engine_fixtures.dart';

MainTrackOrderEntry _order(NodeEntry node, int sort, {DateTime? endedAt}) =>
    MainTrackOrderEntry(
      docId: '${engineCurriculum}_${node.level}_${node.ref}',
      curriculumId: engineCurriculum,
      level: node.level,
      ref: node.ref,
      userSortOrder: sort,
      lastChangeId: engineUlid(900),
      endedAt: endedAt,
    );

void main() {
  final corpus = mishnayosCorpus();

  test('no docs is the ContentIndex order', () {
    expect(orderedLeaves(corpus, const []), corpus.leaves);
  });

  test('non-ended docs sort siblings by user_sort_order', () {
    // Moed before Zeraim at the root level; within Zeraim, Peah before
    // Berakhot.
    final leaves = orderedLeaves(corpus, [
      _order(zeraim, 2),
      _order(moed, 1),
      _order(peah, 1),
      _order(berakhot, 2),
    ]);
    expect(leaves, [
      'Mishnah Shabbat 1:1',
      'Mishnah Shabbat 1:2',
      'Mishnah Peah 1:1',
      'Mishnah Peah 1:2',
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
    ]);
  });

  test('siblings without a doc follow the keyed ones in ContentIndex '
      'order', () {
    // Only Peah has a doc: it leads Zeraim, Berakhot follows; the root
    // level is untouched.
    final leaves = orderedLeaves(corpus, [_order(peah, 5)]);
    expect(leaves, [
      'Mishnah Peah 1:1',
      'Mishnah Peah 1:2',
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
      'Mishnah Shabbat 1:1',
      'Mishnah Shabbat 1:2',
    ]);
  });

  test('ordering recurses: a moved node carries its subtree and child docs '
      'reorder inside it', () {
    final leaves = orderedLeaves(corpus, [
      _order(berakhot2, 1),
      _order(berakhot1, 2),
      _order(const NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:3'), 0),
    ]);
    expect(leaves.take(5), [
      'Mishnah Berakhot 2:1',
      'Mishnah Berakhot 2:2',
      'Mishnah Berakhot 1:3',
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
    ]);
    expect(leaves, hasLength(corpus.leaves.length));
  });

  test('ended docs are ignored', () {
    final leaves = orderedLeaves(corpus, [
      _order(moed, 0, endedAt: engineAt(5)),
      _order(peah, 0),
    ]);
    expect(leaves.first, 'Mishnah Peah 1:1');
    expect(leaves.last, 'Mishnah Shabbat 1:2');
  });

  test('reset to default (every doc ended) equals the ContentIndex order', () {
    final leaves = orderedLeaves(corpus, [
      _order(moed, 0, endedAt: engineAt(5)),
      _order(peah, 0, endedAt: engineAt(5)),
      _order(berakhot2, 0, endedAt: engineAt(5)),
    ]);
    expect(leaves, corpus.leaves);
  });

  test('equal sort orders keep ContentIndex order; a duplicate doc for one '
      'node uses its lowest sort; unknown nodes are ignored', () {
    final leaves = orderedLeaves(corpus, [
      _order(peah, 1),
      _order(berakhot, 1),
      _order(berakhot, 9),
      _order(const NodeEntry(level: 'masechta', ref: 'Mishnah Nope'), 0),
    ]);
    expect(leaves.first, 'Mishnah Berakhot 1:1');
    expect(leaves[5], 'Mishnah Peah 1:1');
  });

  test('the engine uses orderedLeaves as the main-track order O', () {
    final intent = engineIntent();
    final reordered = MainTrackIntent(
      curriculumId: engineCurriculum,
      track: intent.track,
      order: [_order(moed, 0)],
    );
    final state = const LearnerStateEngine().run(
      engineInputs(intents: {engineCurriculum: reordered}),
    )[engineCurriculum]!;
    expect(state.schedulableRefs.first, 'Mishnah Shabbat 1:1');
    expect(state.mainTrackPosition, 'Mishnah Shabbat 1:1');
  });
}
