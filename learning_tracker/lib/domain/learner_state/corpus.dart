/// The ContentIndex corpus the learner-state engine reads (AD-34, AD-35).
///
/// [Corpus] is the **unscoped** ContentIndex tree of one curriculum; the
/// engine applies `curriculum_scope` itself. The production adapter over
/// `ContentIndex` lives outside `lib/domain` (DNI-465 adds
/// `lib/core/content/content_index_corpus.dart`), because `ContentIndex`
/// depends on Riverpod. [InMemoryCorpus] is the real, pure implementation
/// engine tests and fakes use.
library;

import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// A ContentIndex leaf, identified by its `sefariaRef`.
typedef LeafRef = String;

/// The ContentIndex tree of one curriculum.
///
/// Every list is in ContentIndex order (pre-order over the tree), and
/// `leavesUnder(leaf) == [leaf.ref]`.
abstract interface class Corpus {
  /// The curriculum this tree belongs to.
  String get curriculumId;

  /// The top-level nodes.
  List<NodeEntry> get roots;

  /// The direct children of [node]; empty for a leaf.
  List<NodeEntry> childrenOf(NodeEntry node);

  /// The parent of [node], or null for a root.
  NodeEntry? parentOf(NodeEntry node);

  /// The node whose ref is [ref], or null when the corpus has none.
  NodeEntry? nodeForRef(String ref);

  /// Whether [node] is a leaf (a node with no children).
  bool isLeaf(NodeEntry node);

  /// Every leaf ref, in ContentIndex order.
  List<LeafRef> get leaves;

  /// The leaf refs at or below [node], in ContentIndex order.
  List<LeafRef> leavesUnder(NodeEntry node);

  /// The ContentIndex levels whose nodes are units, outermost first
  /// (Consistency → Siyum; AD-33 FR-12a). Mishnayos: `[seder, masechta]`.
  ///
  /// Every node at one of these levels is a siyum unit, and the innermost
  /// level is the FR-12a main-track unit (the "current unit"). Resolved
  /// from ContentIndex metadata by the corpus builder; empty when the
  /// curriculum has no unit level. Added by DNI-465 (additive C0 change).
  List<String> get unitLevels;
}

/// One node of an [InMemoryCorpus] tree.
final class CorpusNode {
  /// Creates a node with its ordered [children].
  const CorpusNode(this.entry, [this.children = const []]);

  /// The node itself.
  final NodeEntry entry;

  /// Its children, in ContentIndex order.
  final List<CorpusNode> children;
}

/// A pure, in-memory [Corpus] built from a [CorpusNode] tree.
///
/// Lookups by an unknown node are lenient: [childrenOf] and [leavesUnder]
/// return an empty list, [parentOf] returns null and [isLeaf] returns
/// false. [nodeForRef] returns the first node in ContentIndex order whose
/// ref matches. A tree that holds the same [NodeEntry] twice throws
/// [ArgumentError].
///
/// [unitLevels] defaults to the levels of the non-leaf nodes at the top
/// two depths, in ContentIndex order (a Mishnayos-shaped tree yields
/// `[seder, masechta]`). The ContentIndex adapter
/// (`lib/core/content/content_index_corpus.dart`) always passes them
/// explicitly from hierarchy metadata.
final class InMemoryCorpus implements Corpus {
  /// Indexes [roots] for [curriculumId].
  InMemoryCorpus(
    this.curriculumId,
    List<CorpusNode> roots, {
    List<String>? unitLevels,
  }) : roots = List.unmodifiable(roots.map((n) => n.entry)),
       unitLevels = List.unmodifiable(unitLevels ?? _defaultUnitLevels(roots)) {
    for (final root in roots) {
      _index(root, null);
    }
    _leaves = List.unmodifiable(_order.where(isLeaf).map((n) => n.ref));
  }

  static List<String> _defaultUnitLevels(List<CorpusNode> roots) {
    final levels = <String>[];
    void add(CorpusNode node) {
      if (node.children.isNotEmpty && !levels.contains(node.entry.level)) {
        levels.add(node.entry.level);
      }
    }

    roots.forEach(add);
    for (final root in roots) {
      root.children.forEach(add);
    }
    return levels;
  }

  @override
  final List<String> unitLevels;

  @override
  final String curriculumId;

  @override
  final List<NodeEntry> roots;

  final Map<NodeEntry, List<NodeEntry>> _children = {};
  final Map<NodeEntry, NodeEntry?> _parents = {};
  final Map<String, NodeEntry> _byRef = {};
  final List<NodeEntry> _order = [];
  late final List<LeafRef> _leaves;

  /// Per node, the half-open range of [_leaves] at or below it. Leaves are
  /// in pre-order, so a subtree's leaves are one contiguous run (fyh.325).
  final Map<NodeEntry, (int, int)> _leafRange = {};

  /// [leavesUnder] memo: the corpus is immutable, so each node's list is
  /// built once instead of walking the subtree on every call (fyh.325).
  final Map<NodeEntry, List<LeafRef>> _leavesUnder = {};
  var _leafCount = 0;

  void _index(CorpusNode node, NodeEntry? parent) {
    final entry = node.entry;
    if (_parents.containsKey(entry)) {
      throw ArgumentError.value(entry, 'roots', 'node appears twice');
    }
    _parents[entry] = parent;
    _byRef.putIfAbsent(entry.ref, () => entry);
    _order.add(entry);
    _children[entry] = List.unmodifiable(node.children.map((c) => c.entry));
    final start = _leafCount;
    if (node.children.isEmpty) _leafCount++;
    for (final child in node.children) {
      _index(child, entry);
    }
    _leafRange[entry] = (start, _leafCount);
  }

  @override
  List<NodeEntry> childrenOf(NodeEntry node) => _children[node] ?? const [];

  @override
  NodeEntry? parentOf(NodeEntry node) => _parents[node];

  @override
  NodeEntry? nodeForRef(String ref) => _byRef[ref];

  @override
  bool isLeaf(NodeEntry node) {
    final children = _children[node];
    return children != null && children.isEmpty;
  }

  @override
  List<LeafRef> get leaves => _leaves;

  @override
  List<LeafRef> leavesUnder(NodeEntry node) {
    final cached = _leavesUnder[node];
    if (cached != null) return cached;
    final range = _leafRange[node];
    if (range == null) return const [];
    final (start, end) = range;
    return _leavesUnder[node] = List.unmodifiable(_leaves.sublist(start, end));
  }
}
