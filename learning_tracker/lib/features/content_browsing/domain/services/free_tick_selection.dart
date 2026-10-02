/// Which leaves a Browse free tick records (Story 1.11, DNI-473; UX-DR-20):
/// a ticked row covers every leaf under it, and "Tick up to here" covers
/// that row's leaves and every earlier leaf of the same masechta (the
/// curriculum's unit), in corpus order.
library;

import 'package:learning_tracker/core/content/content_index_corpus.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';

List<String?> _path(ContentItem item, int depth) =>
    [item.level1, item.level2, item.level3, item.level4].sublist(0, depth);

bool _samePath(List<String?> a, List<String?> b) {
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

List<ContentItem> _orderedLeaves(List<ContentItem> items) =>
    items.where((i) => i.isLeaf).toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

/// The leaves under the Browse row [node] among [items], in corpus order:
/// every leaf whose path starts with [node]'s path (a leaf row is itself).
///
/// Matching by path, not by `sefariaRef`, also serves the grouped rows
/// Browse renders (`groupItemsByNextLevel`).
List<ContentItem> leavesUnder(List<ContentItem> items, ContentItem node) {
  final depth = contentDepthOf(node);
  final path = _path(node, depth);
  return [
    for (final leaf in _orderedLeaves(items))
      if (contentDepthOf(leaf) >= depth && _samePath(_path(leaf, depth), path))
        leaf,
  ];
}

/// The ContentIndex container [items] holds for the Browse row [row], or
/// null when the row is a leaf or no container item has its path.
ContentItem? containerOf(List<ContentItem> items, ContentItem row) {
  final depth = contentDepthOf(row);
  final path = _path(row, depth);
  return items
      .where(
        (i) =>
            !i.isLeaf &&
            contentDepthOf(i) == depth &&
            _samePath(_path(i, depth), path),
      )
      .firstOrNull;
}

/// The ContentIndex depth of [curriculum]'s unit (a masechta): 2 when its
/// depth-2 nodes are named units (Mishnayos, Bavli…), else 1 (Chumash's
/// sefer). Mirrors the corpus `unitLevels` rule.
int unitDepthOf(CurriculumId curriculum, List<ContentItem> items) {
  final corpus = corpusOf(curriculum, items);
  return corpus.unitLevels.length > 1 ? 2 : 1;
}

/// "Tick up to here" on [node]: its leaves and every earlier leaf of the
/// same unit (the first [unitDepth] levels), inclusive, in corpus order. It
/// never crosses into the previous unit.
List<ContentItem> leavesUpToHere(
  List<ContentItem> items,
  ContentItem node, {
  required int unitDepth,
}) {
  final own = leavesUnder(items, node);
  if (own.isEmpty) return const [];
  final last = own.last.sortOrder;
  final depth = contentDepthOf(node) < unitDepth
      ? contentDepthOf(node)
      : unitDepth;
  final unit = _path(node, depth);
  return [
    for (final leaf in _orderedLeaves(items))
      if (leaf.sortOrder <= last &&
          contentDepthOf(leaf) >= depth &&
          _samePath(_path(leaf, depth), unit))
        leaf,
  ];
}

/// The tri-state of [leaves] under [isLearnt] (UX-DR-20).
TriState triStateOf(
  List<ContentItem> leaves,
  bool Function(String ref) isLearnt,
) {
  if (leaves.isEmpty) return TriState.empty;
  final learnt = leaves.where((l) => isLearnt(l.sefariaRef)).length;
  if (learnt == 0) return TriState.empty;
  return learnt == leaves.length ? TriState.complete : TriState.partial;
}
