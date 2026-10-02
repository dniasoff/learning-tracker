// Mirror test for
// `lib/features/progress/domain/services/lifetime_tree_builder.dart`
// (DNI-474: the tree lays out the engine's learnt set; tri-state and counts
// per node; provenance from counted learning).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';
import 'package:learning_tracker/features/progress/domain/services/learner_progress.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';

import '../../../../helpers/learner_state/progress_fixtures.dart';

void main() {
  const builder = LifetimeTreeBuilder();
  final leaves = progressContent().where((i) => i.isLeaf).toList();

  test('build counts the engine learnt leaves of the curriculum only', () {
    final summary = builder.build(
      curriculum: CurriculumId.mishnayos,
      leaves: leaves,
      learnedRefs: {'Mishnah Peah 1:1', 'Mishnah Peah 1:2', 'Not A Leaf'},
      heLabelLookup: const {},
    );
    expect(summary.learnedLeafCount, 2);
    expect(summary.totalLeafCount, 9);
    expect(summary.percentage, closeTo(2 / 9, 1e-9));
    expect(summary.learnedLeafRefs, {'Mishnah Peah 1:1', 'Mishnah Peah 1:2'});
    expect(summary.allLeafRefs, hasLength(9));
  });

  test('every node carries its tri-state and learnt / total counts', () {
    final tree = builder.buildTree(CurriculumId.mishnayos, leaves, {
      'Mishnah Peah 1:1',
      'Mishnah Peah 1:2',
      'Mishnah Berakhot 2:1',
    });
    final zeraim = tree.first;
    expect(zeraim.rawValue, 'Zeraim');
    expect(zeraim.state, LifetimeNodeState.partial);
    expect((zeraim.learntCount, zeraim.totalCount), (3, 7));
    final peah = zeraim.children.last;
    expect(peah.rawValue, 'Mishnah Peah');
    expect(peah.state, LifetimeNodeState.full);
    expect((peah.learntCount, peah.totalCount), (2, 2));
    final moed = tree.last;
    expect(moed.state, LifetimeNodeState.none);
    expect((moed.learntCount, moed.totalCount), (0, 2));
    final leaf = peah.children.single.children.first;
    expect(leaf.leafRef, 'Mishnah Peah 1:1');
    expect((leaf.learntCount, leaf.totalCount), (1, 1));
  });

  test('node order follows ContentIndex sortOrder', () {
    final tree = builder.buildTree(CurriculumId.mishnayos, leaves, const {});
    expect(tree.map((n) => n.rawValue), ['Zeraim', 'Moed']);
    expect(tree.first.children.map((n) => n.rawValue), [
      'Mishnah Berakhot',
      'Mishnah Peah',
    ]);
  });

  test('Hebrew labels come from the container lookup', () {
    final tree = builder.buildTree(
      CurriculumId.mishnayos,
      leaves,
      const {},
      heLabelLookup: LifetimeTreeBuilder.buildHeLabelLookup(progressContent()),
    );
    expect(tree.first.hebrewName, 'he:Seder Zeraim');
  });

  test('provenance: first learnt before tracking with no tracked learning '
      'is bulk-marked, otherwise live; chazaros counts every counted '
      'event', () {
    final state = progressState([
      progressGround(1, 'Mishnah Peah', 'masechta'),
      progressLearn(2, 'Mishnah Peah 1:1', minutes: 1),
      progressLearn(3, 'Mishnah Berakhot 1:1', minutes: 2),
      progressLearn(4, 'Mishnah Berakhot 1:1', minutes: 3),
    ]);
    final provenance = LifetimeTreeBuilder.provenanceFromActivity(
      leafActivityOf(state, progressCorpus()),
    );
    expect(
      provenance['Mishnah Peah 1:2'],
      const LifetimeLeafProvenance(
        source: LifetimeLeafSource.bulkMarked,
        chazarosCount: 1,
      ),
    );
    expect(provenance['Mishnah Peah 1:1']!.source, LifetimeLeafSource.live);
    expect(provenance['Mishnah Berakhot 1:1']!.chazarosCount, 2);
  });

  test('lifetimeNodeStateOf / triStateOfNode round-trip', () {
    for (final s in TriState.values) {
      expect(triStateOfNode(lifetimeNodeStateOf(s)), s);
    }
  });
}
