/// AD-34 ground expansion: a sub-track's `ground` node list to leaves.
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// The leaves under [entries], in [corpus] order (AD-34).
///
/// C0 stub, filled by DNI-465 (1.3).
List<LeafRef> expandGround(List<NodeEntry> entries, Corpus corpus) =>
    c0Stub('DNI-465', 'expandGround');
