/// Story 2.7 (DNI-498) FR-10/FR-11: the ground entries a picker selection
/// appends to a sub-track's existing `ground`.
///
/// Pure and engine-adjacent: it reads only [Corpus] and reuses
/// [expandGround] (AD-34, the only expansion function), so "already in this
/// sub-track" means exactly what the engine expands the stored ground to.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// Whether [corpus] holds [node] as a node of its tree (same `level` and
/// `ref`). Every node of a ContentIndex corpus has at least one leaf, so an
/// unknown node, or a known ref under another level, is not held.
bool corpusHoldsNode(Corpus corpus, NodeEntry node) =>
    corpus.leavesUnder(node).isNotEmpty;

/// The entries that add [selected] to a sub-track whose stored ground is
/// [current] (FR-10, FR-11; AD-33 "kept as entered").
///
/// - Picked nodes keep their own `{level, ref}`: an entry is never coarser
///   than the node the parent picked.
/// - A picked node an ancestor pick already includes, and a duplicate pick,
///   add nothing more; the result never overlaps itself.
/// - Leaves already covered by [current] (under any stored entry, at any
///   level) are not added again and the stored entries are never
///   rewritten: a partly covered pick contributes its uncovered children,
///   recursively, and a fully covered one nothing.
/// - The result is in ContentIndex (tree) order, whatever the pick order.
/// - A picked node [corpus] does not hold (see [corpusHoldsNode]) adds
///   nothing; callers reject it before writing (no entry from another
///   curriculum).
///
/// Re-applying the same picks to the resulting ground returns an empty
/// list, which makes a replayed command a no-op.
List<NodeEntry> groundToAppend({
  required List<NodeEntry> current,
  required Iterable<NodeEntry> selected,
  required Corpus corpus,
}) {
  final picked = {
    for (final node in selected)
      if (corpusHoldsNode(corpus, node)) node,
  };
  bool underAnotherPick(NodeEntry node) {
    for (var p = corpus.parentOf(node); p != null; p = corpus.parentOf(p)) {
      if (picked.contains(p)) return true;
    }
    return false;
  }

  final position = {for (final (i, leaf) in corpus.leaves.indexed) leaf: i};
  // Non-overlapping nodes have disjoint leaves, so first-leaf order is
  // ContentIndex pre-order.
  final tops = picked.where((n) => !underAnotherPick(n)).toList()
    ..sort(
      (a, b) => position[corpus.leavesUnder(a).first]!.compareTo(
        position[corpus.leavesUnder(b).first]!,
      ),
    );
  final covered = expandGround(current, corpus).toSet();
  final out = <NodeEntry>[];
  void addUncovered(NodeEntry node) {
    final under = corpus.leavesUnder(node);
    final hit = under.where(covered.contains).length;
    if (hit == under.length) return;
    if (hit == 0) {
      out.add(node);
      return;
    }
    corpus.childrenOf(node).forEach(addUncovered);
  }

  tops.forEach(addUncovered);
  return List.unmodifiable(out);
}
