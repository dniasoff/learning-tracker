/// Engine stage 2a: the learner's corpus, `ContentIndex ∩ curriculum_scope`
/// (AD-42). The same set drives progress, forecast and siyum.
library;

import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// Storage key `level` of a `{level, ref}` scope doc.
const scopeLevelKey = 'level';

/// Storage key `ref` of a `{level, ref}` scope doc.
const scopeRefKey = 'ref';

/// Legacy storage key `scope_level` (1-based ContentIndex depth).
const legacyScopeLevelKey = 'scope_level';

/// Legacy storage key `scope_value` (the node's value at that depth).
const legacyScopeValueKey = 'scope_value';

/// The node a `curriculum_scopes` doc selects in [corpus], or null when the
/// doc names no node of the corpus.
///
/// Two payload shapes resolve:
/// * the AD-42 node form `{level, ref}`;
/// * the pre-sub-tracks form `{scope_level, scope_value}`, where
///   `scope_value` names a node whose ref equals it at that 1-based depth.
///   (A positional value such as a bare chapter number does not name a
///   node and so does not resolve.)
NodeEntry? resolveScopeNode(Corpus corpus, MainTrackConfigDoc scope) {
  final fields = scope.fields;
  final level = fields[scopeLevelKey];
  final ref = fields[scopeRefKey];
  if (level is String && ref is String) {
    final node = NodeEntry(level: level, ref: ref);
    return corpus.leavesUnder(node).isEmpty ? null : node;
  }
  final depth = fields[legacyScopeLevelKey];
  final value = fields[legacyScopeValueKey];
  if (depth is int && value is String) {
    final node = corpus.nodeForRef(value);
    if (node == null || _depth(corpus, node) != depth) return null;
    return node;
  }
  return null;
}

int _depth(Corpus corpus, NodeEntry node) {
  var depth = 1;
  for (var p = corpus.parentOf(node); p != null; p = corpus.parentOf(p)) {
    depth++;
  }
  return depth;
}

/// The learner's corpus leaves in ContentIndex order (AD-42).
///
/// With no [scope] (or an ended one) this is every leaf of [corpus]. A
/// scope that resolves to no node of the corpus yields no leaves: an
/// unreadable scope never widens the learner's corpus.
List<LeafRef> scopedLeaves(Corpus corpus, MainTrackConfigDoc? scope) {
  if (scope == null || scope.endedAt != null) return corpus.leaves;
  final node = resolveScopeNode(corpus, scope);
  if (node == null) return const [];
  return expandGround([node], corpus);
}
