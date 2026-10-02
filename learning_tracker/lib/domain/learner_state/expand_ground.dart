/// AD-34 ground expansion: a list of `{level, ref}` node entries to leaves.
///
/// The only implementation (AD-34). Sub-track ground, `before_tracking`
/// node events and calendar assignments all expand through it.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// The leaves under [entries]: entries in list order, each in [corpus]
/// (ContentIndex) order, with later duplicates dropped (AD-34).
///
/// A leaf entry yields itself. An entry the corpus does not hold (an
/// unknown ref, or a known ref under a different level) expands to
/// nothing: an unresolvable node is never converted into learnt leaves.
List<LeafRef> expandGround(List<NodeEntry> entries, Corpus corpus) {
  final seen = <LeafRef>{};
  final out = <LeafRef>[];
  for (final entry in entries) {
    for (final leaf in corpus.leavesUnder(entry)) {
      if (seen.add(leaf)) out.add(leaf);
    }
  }
  return List.unmodifiable(out);
}
