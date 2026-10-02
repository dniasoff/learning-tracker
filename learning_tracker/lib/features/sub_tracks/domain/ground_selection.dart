/// Story 2.7 (DNI-498) ground picker: the pure row state, draft selection,
/// filters and tree flattening behind the picker (FR-10, FR-11, FR-15,
/// UX-DR-30, UX-DR-79, UX-DR-92, UX-DR-125).
///
/// Everything here reads the curriculum's ContentIndex [Corpus] and engine
/// outputs only — no Mishnayos level names, no Flutter, no Riverpod. Three
/// predicates stay distinct (T2): a leaf is *in this sub-track* (under its
/// stored ground), *in use* by another `holdsGround` sub-track, or *learnt*
/// (from any source). The draft is the parent's pending picks, separate
/// from both the stored ground and the learner's progress.
library;

import 'package:learning_tracker/domain/learner_state/append_ground.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/expand_ground.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart'
    show TriState;
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/tri_state.dart';

/// A sub-track that holds ground (AD-34 `holdsGround`): its [name] and
/// stored [ground].
final class GroundHolder {
  /// Creates a holder.
  const GroundHolder({
    required this.id,
    required this.name,
    required this.ground,
  });

  /// The sub-track ULID.
  final String id;

  /// Its learner-facing name (the "{name} · In use" tag).
  final String name;

  /// Its stored ground, as entered.
  final List<NodeEntry> ground;
}

/// The sub-tracks of [curriculumId] among [tracks] that hold ground, other
/// than [exceptId], in [tracks] order.
///
/// [holds] is the AD-34 `holdsGround` answer for a track — the engine's
/// `SubTrackState.holdsGround` where the learner state has one. An ended
/// sub-track never holds (it has returned its ground, FR-12a).
List<GroundHolder> groundHolders(
  Iterable<SubTrack> tracks, {
  required String curriculumId,
  required bool Function(SubTrack track) holds,
  String? exceptId,
}) => [
  for (final t in tracks)
    if (t.curriculumId == curriculumId &&
        t.id != exceptId &&
        !t.isEnded &&
        holds(t))
      GroundHolder(id: t.id, name: t.name, ground: t.ground),
];

/// The names of the [holders] holding each leaf, in holder order; a leaf no
/// holder holds is absent. Overlap is shown, never reconciled (FR-13).
Map<LeafRef, List<String>> heldLeafNames(
  List<GroundHolder> holders,
  Corpus corpus,
) {
  final out = <LeafRef, List<String>>{};
  for (final h in holders) {
    for (final leaf in expandGround(h.ground, corpus)) {
      final names = out.putIfAbsent(leaf, () => []);
      if (!names.contains(h.name)) names.add(h.name);
    }
  }
  return out;
}

/// The names holding any leaf under [node], in first-seen order.
List<String> holderNamesUnder(
  NodeEntry node,
  Corpus corpus,
  Map<LeafRef, List<String>> held,
) {
  final names = <String>[];
  for (final leaf in corpus.leavesUnder(node)) {
    for (final name in held[leaf] ?? const <String>[]) {
      if (!names.contains(name)) names.add(name);
    }
  }
  return names;
}

/// A draft checkbox mark (the pending assignment, not progress).
enum GroundSelectionMark {
  /// Nothing under the node is picked.
  unchecked,

  /// Some, not all, of the node's assignable leaves are picked.
  partial,

  /// Every assignable leaf under the node is picked, or already in this
  /// sub-track.
  checked,
}

/// One picker row's derived state.
final class GroundRowState {
  /// Creates a row state.
  const GroundRowState({
    required this.node,
    required this.childCount,
    required this.leafCount,
    required this.progress,
    required this.inThisTrack,
    required this.inUseBy,
    required this.mark,
  });

  /// The ContentIndex node.
  final NodeEntry node;

  /// Its direct children (0 for a leaf).
  final int childCount;

  /// The leaves under it (1 for a leaf).
  final int leafCount;

  /// Its learnt tri-state (FR-15), from any source.
  final TriState progress;

  /// Every leaf under it is already in this sub-track: pre-checked and
  /// disabled (UX-DR-79). Covers a child of a stored ancestor.
  final bool inThisTrack;

  /// The other holding sub-tracks' names ("{name} · In use", UX-DR-92). It
  /// never disables the row.
  final List<String> inUseBy;

  /// The draft mark.
  final GroundSelectionMark mark;

  /// Learnt already ("Chazara"): selectable, only tagged (UX-DR-92).
  bool get isChazara => progress == TriState.complete;

  /// Whether the row's checkbox can change.
  bool get enabled => !inThisTrack;
}

/// The picker's inputs for one sub-track: the curriculum [corpus], this
/// sub-track's stored [ownGround], the learner's [learnt] leaves and the
/// [held] leaves of every other holding sub-track.
final class GroundPickerModel {
  /// Indexes the inputs.
  GroundPickerModel({
    required this.corpus,
    required this.ownGround,
    required Set<LeafRef> learnt,
    required Map<LeafRef, List<String>> held,
  }) : _learnt = learnt,
       _held = held,
       _own = expandGround(ownGround, corpus).toSet();

  /// The curriculum's ContentIndex tree.
  final Corpus corpus;

  /// This sub-track's stored ground, as entered.
  final List<NodeEntry> ownGround;

  final Set<LeafRef> _learnt;
  final Map<LeafRef, List<String>> _held;
  final Set<LeafRef> _own;

  /// This model with [ground] as the sub-track's ground (the ground an
  /// in-flight confirm shows before the store echoes it).
  GroundPickerModel withOwnGround(List<NodeEntry> ground) => GroundPickerModel(
    corpus: corpus,
    ownGround: ground,
    learnt: _learnt,
    held: _held,
  );

  /// Whether [leaf] is under this sub-track's stored ground.
  bool isOwnLeaf(LeafRef leaf) => _own.contains(leaf);

  /// Whether [leaf] can be newly assigned without a tag: not in this
  /// sub-track, not in use elsewhere and not learnt.
  bool isAvailableLeaf(LeafRef leaf) =>
      !_own.contains(leaf) &&
      !_held.containsKey(leaf) &&
      !_learnt.contains(leaf);

  /// Whether *Available only* keeps [node]: some leaf under it is available
  /// (UX-DR-125). A view filter only; it never changes the draft.
  bool isAvailable(NodeEntry node) =>
      corpus.leavesUnder(node).any(isAvailableLeaf);

  /// The row state of [node] under [draft].
  GroundRowState rowOf(NodeEntry node, GroundDraft draft) {
    final leaves = corpus.leavesUnder(node);
    final inThisTrack = leaves.isNotEmpty && leaves.every(_own.contains);
    return GroundRowState(
      node: node,
      childCount: corpus.childrenOf(node).length,
      leafCount: leaves.length,
      progress: triStateOf(leaves, _learnt),
      inThisTrack: inThisTrack,
      inUseBy: holderNamesUnder(node, corpus, _held),
      mark: inThisTrack ? GroundSelectionMark.checked : draft.markOf(node),
    );
  }

  /// The entries confirming [draft] appends (the same function the
  /// command applies to the latest stored ground).
  List<NodeEntry> appended(GroundDraft draft) =>
      groundToAppend(current: ownGround, selected: draft.picks, corpus: corpus);

  /// The live footer count of [draft] (UX-DR-30).
  GroundAppendSummary summaryOf(GroundDraft draft) {
    final entries = appended(draft);
    if (entries.isEmpty) return const GroundAppendSummary(0, null);
    final level = entries.first.level;
    if (entries.every((e) => e.level == level)) {
      return GroundAppendSummary(entries.length, level, sample: entries.first);
    }
    // Mixed levels: count in the curriculum's leaf unit.
    final leaves = expandGround(entries, corpus);
    final leaf = corpus.nodeForRef(leaves.first);
    return GroundAppendSummary(leaves.length, leaf?.level, sample: leaf);
  }
}

/// How many [level] units confirming appends; [level] is null when nothing
/// is picked or the level is unknown. [sample] is one node at that level
/// (to resolve the level's display name by its depth).
final class GroundAppendSummary {
  /// Creates a summary.
  const GroundAppendSummary(this.count, this.level, {this.sample});

  /// A node at [level], when there is one.
  final NodeEntry? sample;

  /// The unit count.
  final int count;

  /// The ContentIndex level the count is in.
  final String? level;

  @override
  bool operator ==(Object other) =>
      other is GroundAppendSummary &&
      other.count == count &&
      other.level == level;

  @override
  int get hashCode => Object.hash(count, level);

  @override
  String toString() => 'GroundAppendSummary($count $level)';
}

/// The parent's pending picks: ContentIndex nodes, never two where one is
/// under the other. Immutable; every edit returns a new draft.
///
/// Selecting a parent selects its descendants (UX-DR-30); clearing one
/// descendant of a picked ancestor replaces that ancestor by its other
/// branches, so picks stay at the coarsest level the parent chose.
final class GroundDraft {
  /// A draft with [picks] (normalised by the edit methods).
  GroundDraft._(this._model, Set<NodeEntry> picks)
    : picks = Set.unmodifiable(picks),
      _picked = expandGround(picks.toList(), _model.corpus).toSet();

  /// The empty draft of [model] (open, or after *Reset changes*).
  factory GroundDraft.empty(GroundPickerModel model) =>
      GroundDraft._(model, const {});

  /// The draft of earlier [picks] over a (possibly refreshed) [model]:
  /// picks the corpus does not hold, or under another pick, are dropped.
  factory GroundDraft.of(GroundPickerModel model, Iterable<NodeEntry> picks) {
    final corpus = model.corpus;
    final held = {
      for (final p in picks)
        if (corpusHoldsNode(corpus, p)) p,
    };
    bool underAnother(NodeEntry node) {
      for (var p = corpus.parentOf(node); p != null; p = corpus.parentOf(p)) {
        if (held.contains(p)) return true;
      }
      return false;
    }

    return GroundDraft._(model, {
      for (final p in held)
        if (!underAnother(p)) p,
    });
  }

  final GroundPickerModel _model;
  final Set<LeafRef> _picked;

  /// The picked nodes.
  final Set<NodeEntry> picks;

  /// Whether nothing is picked.
  bool get isEmpty => picks.isEmpty;

  /// The draft mark of [node]: its leaves not already in this sub-track,
  /// all / some / none picked.
  GroundSelectionMark markOf(NodeEntry node) {
    var assignable = 0;
    var picked = 0;
    for (final leaf in _model.corpus.leavesUnder(node)) {
      if (_model.isOwnLeaf(leaf)) continue;
      assignable++;
      if (_picked.contains(leaf)) picked++;
    }
    if (assignable == 0) return GroundSelectionMark.checked;
    if (picked == 0) return GroundSelectionMark.unchecked;
    return picked == assignable
        ? GroundSelectionMark.checked
        : GroundSelectionMark.partial;
  }

  /// Toggles [node]: a checked node is cleared, anything else is picked
  /// whole (its descendants with it). A node already wholly in this
  /// sub-track, or one the corpus does not hold, is left as is.
  GroundDraft toggle(NodeEntry node) {
    final corpus = _model.corpus;
    if (!corpusHoldsNode(corpus, node)) return this;
    final leaves = corpus.leavesUnder(node);
    if (leaves.every(_model.isOwnLeaf)) return this;
    final next = {...picks}..removeWhere((p) => _isUnder(p, node));
    if (markOf(node) != GroundSelectionMark.checked) {
      return GroundDraft._(_model, next..add(node));
    }
    // Clearing: replace a picked ancestor by its branches beside [node].
    final path = <NodeEntry>[];
    for (var n = node; ; n = corpus.parentOf(n)!) {
      path.add(n);
      if (next.contains(n) || corpus.parentOf(n) == null) break;
    }
    final ancestor = path.last;
    if (ancestor != node && next.remove(ancestor)) {
      for (var i = path.length - 1; i > 0; i--) {
        for (final child in corpus.childrenOf(path[i])) {
          if (child != path[i - 1]) next.add(child);
        }
      }
    }
    next.remove(node);
    return GroundDraft._(_model, next);
  }

  /// Whether [node] is [ancestor] or under it.
  bool _isUnder(NodeEntry node, NodeEntry ancestor) {
    for (NodeEntry? n = node; n != null; n = _model.corpus.parentOf(n)) {
      if (n == ancestor) return true;
    }
    return false;
  }
}

/// One visible picker row: its [node] and [depth] (0 for a root).
typedef GroundTreeRow = ({NodeEntry node, int depth});

/// The rows to draw, in ContentIndex order (the tree flattened).
///
/// A node is drawn when [visible] keeps it; its children are drawn when it
/// is in [expanded] (or [expandAll], used while searching). [visible] keeps
/// an ancestor of any kept node, so a match's path stays on screen.
List<GroundTreeRow> flattenGroundTree(
  Corpus corpus, {
  required Set<NodeEntry> expanded,
  required bool Function(NodeEntry node) visible,
  bool expandAll = false,
}) {
  final rows = <GroundTreeRow>[];
  void walk(NodeEntry node, int depth) {
    if (!visible(node)) return;
    rows.add((node: node, depth: depth));
    if (expandAll || expanded.contains(node)) {
      for (final child in corpus.childrenOf(node)) {
        walk(child, depth + 1);
      }
    }
  }

  for (final root in corpus.roots) {
    walk(root, 0);
  }
  return rows;
}

/// The nodes a search keeps: every node [matches] accepts, with its
/// descendants and its ancestor path, so a match is always reachable.
Set<NodeEntry> nodesMatching(
  Corpus corpus,
  bool Function(NodeEntry node) matches,
) {
  final kept = <NodeEntry>{};
  void keepAll(NodeEntry node) {
    kept.add(node);
    corpus.childrenOf(node).forEach(keepAll);
  }

  bool walk(NodeEntry node) {
    if (matches(node)) {
      keepAll(node);
      return true;
    }
    var any = false;
    for (final child in corpus.childrenOf(node)) {
      if (walk(child)) any = true;
    }
    if (any) kept.add(node);
    return any;
  }

  corpus.roots.forEach(walk);
  return kept;
}

/// Case-insensitive substring match of a trimmed [query] against any of
/// [labels] (English and Hebrew); an empty query matches everything.
bool groundLabelMatches(String query, Iterable<String> labels) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return labels.any((l) => l.toLowerCase().contains(q));
}
