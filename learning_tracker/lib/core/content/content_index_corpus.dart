/// The production [Corpus] adapter over ContentIndex data (AD-42): one
/// curriculum's bundled hierarchy items (`assets/content/hierarchy/
/// <curriculum>.json`, loaded by `curriculumContentProvider`) plus its
/// hierarchy `levelLabels`.
///
/// It lives outside `lib/domain` because ContentIndex depends on Riverpod;
/// the corpus it returns is the pure `InMemoryCorpus` the engine reads.
/// `corporaProvider` (DNI-474) builds one per curriculum through
/// [contentIndexCorpus].
library;

import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';

/// The ContentIndex level name of a 1-based hierarchy [depth]: the
/// lower-cased hierarchy label (`Masechta` → `masechta`), or `level<depth>`
/// when the curriculum has no label that deep.
String contentLevelName(List<String> levelLabels, int depth) =>
    depth <= levelLabels.length
    ? levelLabels[depth - 1].toLowerCase()
    : 'level$depth';

/// Builds the unscoped [Corpus] of [curriculumId] from its ContentIndex
/// [items] (containers and leaves) and hierarchy [levelLabels].
///
/// * Items of other curricula are ignored; the rest are ordered by
///   `sortOrder` (ContentIndex order).
/// * A node's depth is its deepest non-null `levelN` field, and its parent
///   is the nearest earlier node whose level values are a prefix of its
///   own, so a skipped level (e.g. no `level2`) still nests correctly.
/// * Node level = [contentLevelName]; node ref = `sefariaRef`.
/// * A ref seen earlier is dropped together with its subtree
///   (first-write-wins, as in ContentIndex), and a container with no leaf
///   below it is dropped, so every leaf is a real ContentIndex leaf.
/// * `unitLevels` (Consistency → Siyum): the depth-1 level, plus the
///   depth-2 level when every depth-2 value names its own node
///   (`level2 == sefariaRef`, e.g. a masechta), rather than being a
///   positional label such as a bare chapter number (the rule the legacy
///   `hasNamedLevel2Unit` encoded per curriculum). Mishnayos, Bavli and
///   Yerushalmi yield `[seder, masechta]`; Chumash yields `[sefer]`.
Corpus contentIndexCorpus({
  required String curriculumId,
  required List<ContentItem> items,
  required List<String> levelLabels,
}) {
  final sorted = items.where((i) => i.curriculumId == curriculumId).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final roots = <_Node>[];
  final stack = <_Node>[];
  final seenRefs = <String>{};
  var depth2Named = true;
  var hasDepth2Container = false;
  for (final item in sorted) {
    final path = _path(item);
    if (path.isEmpty) continue;
    while (stack.isNotEmpty && !stack.last.isParentOf(path)) {
      stack.removeLast();
    }
    final node = _Node(item, path, contentLevelName(levelLabels, path.length));
    final parent = stack.isEmpty ? null : stack.last;
    stack.add(node);
    if (!seenRefs.add(item.sefariaRef) || (parent?.dropped ?? false)) {
      node.dropped = true;
      continue;
    }
    if (path.length == 2 && !item.isLeaf) {
      hasDepth2Container = true;
      if (item.level2 != item.sefariaRef) depth2Named = false;
    }
    (parent == null ? roots : parent.children).add(node);
  }
  final built = [for (final r in roots) ?r.build()];
  final unitLevels = <String>[
    if (built.any((n) => n.children.isNotEmpty))
      contentLevelName(levelLabels, 1),
    if (hasDepth2Container && depth2Named) contentLevelName(levelLabels, 2),
  ];
  return InMemoryCorpus(curriculumId, built, unitLevels: unitLevels);
}

List<String?> _path(ContentItem item) {
  final values = [item.level1, item.level2, item.level3, item.level4];
  var depth = 0;
  for (var i = 0; i < values.length; i++) {
    if (values[i] != null) depth = i + 1;
  }
  return values.sublist(0, depth);
}

final class _Node {
  _Node(this.item, this.path, this.level);

  final ContentItem item;
  final List<String?> path;
  final String level;
  final List<_Node> children = [];
  bool dropped = false;

  bool isParentOf(List<String?> other) {
    if (path.length >= other.length) return false;
    for (var i = 0; i < path.length; i++) {
      if (path[i] != other[i]) return false;
    }
    return true;
  }

  /// The [CorpusNode], or null for a container with no leaf below it.
  CorpusNode? build() {
    final entry = NodeEntry(level: level, ref: item.sefariaRef);
    if (item.isLeaf && children.isEmpty) return CorpusNode(entry);
    final kids = [for (final c in children) ?c.build()];
    return kids.isEmpty ? null : CorpusNode(entry, kids);
  }
}
