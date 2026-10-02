/// The ground picker's curriculum-scoped ContentIndex view (Story 2.7 /
/// DNI-498 AC-2, `prd-deviations` #12): each corpus node's own ContentIndex
/// row, matched by node identity inside the sub-track's curriculum, and the
/// curriculum's hierarchy level metadata.
///
/// Never the cross-curriculum `ContentIndex.lookup`: that index is keyed by
/// ref alone, first curriculum wins, so a ref shared by two curricula (a
/// Chumash pasuk also indexed under Tanach) would resolve to the wrong
/// curriculum's row.
library;

import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// A curriculum's hierarchy level metadata: the labels of the level at a
/// 1-based [depth] under the top-level node whose `level1` value is
/// [level1], or null when the curriculum names no level that deep.
typedef GroundLevelLabels = LevelLabels? Function(int depth, String? level1);

/// The hierarchy level metadata of [curriculum] (`CurriculumLabels`, with
/// its per-book overrides, e.g. Mussar's Tanya parts); names no level for
/// an unknown curriculum.
GroundLevelLabels curriculumLevelLabels(CurriculumId? curriculum) =>
    (depth, level1) {
      if (curriculum == null) return null;
      if (depth < 1 || depth > CurriculumLabels.depth(curriculum)) return null;
      return CurriculumLabels.level(curriculum, depth, parentL1Value: level1);
    };

/// The ContentIndex rows and level metadata of one curriculum's corpus.
final class GroundPickerContent {
  GroundPickerContent._(this._items, this._depths, this._roots, this._levels);

  /// Indexes [corpus]'s nodes against [items], the curriculum's own
  /// ContentIndex rows.
  ///
  /// A node `{level, ref}` at depth `d` of the corpus matches the row of
  /// the same curriculum with `sefariaRef == ref` and hierarchy depth `d`
  /// (the corpus derives a node's level from that depth, so this is the
  /// `{level, ref}` identity). Rows of other curricula never match; within
  /// the curriculum the first row in ContentIndex order wins, as in the
  /// corpus. Nodes without a row resolve to null.
  factory GroundPickerContent.of({
    required Corpus corpus,
    required List<ContentItem> items,
    required GroundLevelLabels levels,
  }) {
    final rows = <(int, String), ContentItem>{};
    final own =
        items.where((i) => i.curriculumId == corpus.curriculumId).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final item in own) {
      rows.putIfAbsent((contentDepthOf(item), item.sefariaRef), () => item);
    }
    final byNode = <NodeEntry, ContentItem>{};
    final depths = <NodeEntry, int>{};
    final roots = <NodeEntry, NodeEntry>{};
    void walk(NodeEntry node, int depth, NodeEntry root) {
      depths[node] = depth;
      roots[node] = root;
      final item = rows[(depth, node.ref)];
      if (item != null) byNode[node] = item;
      for (final child in corpus.childrenOf(node)) {
        walk(child, depth + 1, root);
      }
    }

    for (final root in corpus.roots) {
      walk(root, 1, root);
    }
    return GroundPickerContent._(byNode, depths, roots, levels);
  }

  final Map<NodeEntry, ContentItem> _items;
  final Map<NodeEntry, int> _depths;
  final Map<NodeEntry, NodeEntry> _roots;
  final GroundLevelLabels _levels;

  /// The ContentIndex row of [node] in this curriculum, if any.
  ContentItem? itemOf(NodeEntry node) => _items[node];

  /// The labels of [node]'s hierarchy level: its depth in the curriculum
  /// tree, under its top-level book's overrides. Null for a node outside
  /// the corpus or below the deepest level the curriculum names.
  LevelLabels? levelOf(NodeEntry node) {
    final depth = _depths[node];
    if (depth == null) return null;
    final root = _roots[node]!;
    final level1 = itemOf(node)?.level1 ?? itemOf(root)?.level1;
    return _levels(depth, level1);
  }
}
