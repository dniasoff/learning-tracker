/// The AD-31 un-learn planner: which counted events to void and which
/// `before_tracking` node events to re-issue.
///
/// Pure and shared: the owner `LearningCommands.unlearn` writes the plan
/// with SDK batches, and the tutor path (DNI-485/486, ruling B9) sends the
/// same plan as `tutorUnlearn`'s `nodeReissues` payload, so both paths
/// share one implementation of AD-31.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// One counted node event that covers part of the un-learnt set: it is
/// voided, and [reissues] re-cover what it still covers.
final class NodeReissue {
  /// Creates the entry.
  NodeReissue({required this.target, required List<NodeEntry> reissues})
    : reissues = List.unmodifiable(reissues);

  /// The counted node event (`before_tracking` with `level`).
  final LearningEvent target;

  /// The maximal ContentIndex nodes covering `expand(target) \ S`, in
  /// ContentIndex order, pairwise disjoint.
  final List<NodeEntry> reissues;
}

/// The writes of `unlearn(curriculum, S)`.
final class UnlearnPlan {
  /// Creates the plan.
  UnlearnPlan({
    required List<LearningEvent> leafVoids,
    required List<NodeReissue> nodes,
  }) : leafVoids = List.unmodifiable(leafVoids),
       nodes = List.unmodifiable(nodes);

  /// Counted leaf events whose ref is in S: each is voided.
  final List<LearningEvent> leafVoids;

  /// Counted node events covering part of S.
  final List<NodeReissue> nodes;

  /// Whether the plan writes nothing.
  bool get isEmpty => leafVoids.isEmpty && nodes.isEmpty;
}

/// Plans `unlearn(curriculumId, leafSet)` over the [counted] `learn`
/// events (AD-31):
///
/// * every counted event of [curriculumId] whose `ref` is a leaf in
///   [leafSet] is voided;
/// * every counted node event N (it carries `level`) of [curriculumId]
///   with `expand(N) ∩ leafSet ≠ ∅` is voided and re-issued as the maximal
///   [corpus] nodes covering `expand(N) \ leafSet`.
///
/// A node event whose node [corpus] does not hold expands to nothing and
/// is left alone (an unresolvable node never becomes learnt leaves).
UnlearnPlan planUnlearn({
  required String curriculumId,
  required Set<LeafRef> leafSet,
  required Iterable<LearningEvent> counted,
  required Corpus corpus,
}) {
  final leafVoids = <LearningEvent>[];
  final nodes = <NodeReissue>[];
  for (final e in counted) {
    if (!e.isLearn || e.curriculumId != curriculumId) continue;
    final level = e.level;
    if (level == null) {
      if (leafSet.contains(e.ref)) leafVoids.add(e);
      continue;
    }
    final node = NodeEntry(level: level, ref: e.ref!);
    final under = corpus.leavesUnder(node);
    if (!under.any(leafSet.contains)) continue;
    nodes.add(
      NodeReissue(target: e, reissues: maximalCover(node, leafSet, corpus)),
    );
  }
  return UnlearnPlan(leafVoids: leafVoids, nodes: nodes);
}

/// The maximal [corpus] nodes at or under [node] whose leaves avoid
/// [excluded], covering exactly `leavesUnder(node) \ excluded`, in
/// ContentIndex order and without overlap.
List<NodeEntry> maximalCover(
  NodeEntry node,
  Set<LeafRef> excluded,
  Corpus corpus,
) {
  if (!corpus.leavesUnder(node).any(excluded.contains)) return [node];
  if (corpus.isLeaf(node)) return const [];
  return [
    for (final child in corpus.childrenOf(node))
      ...maximalCover(child, excluded, corpus),
  ];
}
