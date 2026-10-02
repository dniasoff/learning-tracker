/// Engine stage 3a: node tri-state (FR-15).
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';

/// The [TriState] of a node whose in-scope leaves are [leaves], given the
/// [learnt] set: `complete` when every leaf is learnt, `partial` when some
/// are, `empty` when none are.
///
/// A node with no in-scope leaves (outside the learner's corpus, unknown,
/// or an empty corpus) is `empty`: there is nothing of it to have learnt.
TriState triStateOf(Iterable<LeafRef> leaves, Set<LeafRef> learnt) {
  var total = 0;
  var done = 0;
  for (final leaf in leaves) {
    total++;
    if (learnt.contains(leaf)) done++;
  }
  if (done == 0) return TriState.empty;
  return done == total ? TriState.complete : TriState.partial;
}
