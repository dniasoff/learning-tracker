/// Engine stage 2b: the distinct learnt-leaf set (AD-31, AD-32).
///
/// A leaf is learnt iff it has ≥ 1 counted `learn` event (see
/// `counted_events.dart`) from any source, stage or date state. Repeats
/// add nothing (FR-14).
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// The leaves [event] covers in [corpus], in ContentIndex order (AD-31).
///
/// * A `before_tracking` event with a `level` is a node event: it covers
///   `expandGround([{level, ref}])`.
/// * Any other `learn` event covers its `ref` when that ref is a leaf of
///   [corpus].
/// * A `void`, an unknown ref, or a leaf-level event whose ref is a
///   container covers nothing: an invalid record is never converted into
///   learnt leaves.
List<LeafRef> coveredLeaves(LearningEvent event, Corpus corpus) {
  final ref = event.ref;
  if (!event.isLearn || ref == null) return const [];
  final level = event.level;
  if (level != null) {
    return expandGround([NodeEntry(level: level, ref: ref)], corpus);
  }
  final node = corpus.nodeForRef(ref);
  if (node == null || !corpus.isLeaf(node)) return const [];
  return [ref];
}

/// The distinct leaves covered by [countedLearns] that are in the learner's
/// corpus ([inScope]).
Set<LeafRef> learntLeaves(
  Iterable<LearningEvent> countedLearns,
  Corpus corpus,
  bool Function(LeafRef leaf) inScope,
) {
  final out = <LeafRef>{};
  // fyh.325: a later event on an already-added node covers exactly the
  // same leaves, all already in [out], so it is skipped instead of being
  // re-expanded (a log can hold many node events on one whole volume).
  final addedNodes = <(String, String)>{};
  for (final event in countedLearns) {
    final level = event.level;
    final ref = event.ref;
    if (level != null &&
        ref != null &&
        event.isLearn &&
        !addedNodes.add((level, ref))) {
      continue;
    }
    for (final leaf in coveredLeaves(event, corpus)) {
      if (inScope(leaf)) out.add(leaf);
    }
  }
  return out;
}
