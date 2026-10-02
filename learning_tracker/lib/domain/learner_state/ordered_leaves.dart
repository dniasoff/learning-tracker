/// AD-33 main-track leaf order: the corpus reordered by the learner's
/// `track_learning_order` docs.
///
/// This is the only order function (AD-33): the engine's main-track order
/// `O`, `schedulableRefs` and position all read it, and no other code
/// reorders the corpus.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// Every leaf of [corpus] in the learner's main-track order (AD-33).
///
/// At each level of the ContentIndex tree, siblings are ordered as:
///
/// 1. the siblings that have a non-ended order doc in [orderDocs] (matched
///    on `{level, ref}`), ascending by `user_sort_order`; equal sort orders
///    keep ContentIndex order;
/// 2. then the siblings without one, in ContentIndex order.
///
/// It then recurses into each sibling's children, so ordering is at
/// node-entry granularity and a moved node carries its whole subtree.
///
/// * A doc with `ended_at` is ignored. Reset to default sets `ended_at` on
///   every order doc of the curriculum, so an all-ended list yields
///   exactly the ContentIndex order (`corpus.leaves`).
/// * A doc naming a node the corpus does not hold is ignored.
/// * Two live docs for one node: the lower `user_sort_order` wins
///   (deterministic; the writer keeps one doc per node id, so this only
///   arises from a malformed input).
///
/// [orderDocs] are the docs of `corpus.curriculumId`; the engine passes
/// that curriculum's `MainTrackIntent.order` unfiltered. Pure: no clock,
/// no I/O.
List<LeafRef> orderedLeaves(
  Corpus corpus,
  List<MainTrackOrderEntry> orderDocs,
) {
  final sortKey = <NodeEntry, int>{};
  for (final doc in orderDocs) {
    if (doc.endedAt != null) continue;
    final node = NodeEntry(level: doc.level, ref: doc.ref);
    final current = sortKey[node];
    if (current == null || doc.userSortOrder < current) {
      sortKey[node] = doc.userSortOrder;
    }
  }
  if (sortKey.isEmpty) return corpus.leaves;

  final out = <LeafRef>[];
  void visit(List<NodeEntry> siblings) {
    for (final node in _orderSiblings(siblings, sortKey)) {
      if (corpus.isLeaf(node)) {
        out.add(node.ref);
      } else {
        visit(corpus.childrenOf(node));
      }
    }
  }

  visit(corpus.roots);
  return List.unmodifiable(out);
}

/// [siblings] (in ContentIndex order) reordered: keyed siblings by key
/// (stable), then unkeyed siblings in their original order.
List<NodeEntry> _orderSiblings(
  List<NodeEntry> siblings,
  Map<NodeEntry, int> sortKey,
) {
  final keyed = <(int, int, NodeEntry)>[];
  final rest = <NodeEntry>[];
  for (var i = 0; i < siblings.length; i++) {
    final node = siblings[i];
    final key = sortKey[node];
    if (key == null) {
      rest.add(node);
    } else {
      keyed.add((key, i, node));
    }
  }
  if (keyed.isEmpty) return siblings;
  keyed.sort((a, b) {
    final byKey = a.$1.compareTo(b.$1);
    return byKey != 0 ? byKey : a.$2.compareTo(b.$2);
  });
  return [for (final k in keyed) k.$3, ...rest];
}
