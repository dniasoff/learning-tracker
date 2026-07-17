import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/content_browsing/content_browsing.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'content_tree.g.dart';

/// O(1) parent / child / adjacent traversal across all 9 curricula.
///
/// Built once from the same data as [ContentIndex] and stored in a keepAlive
/// provider. The four-level `_currentLevel*` ladder pattern is eliminated:
/// callers use [children], [parent], and [adjacent] with [ContentItem]
/// `sefariaRef` keys instead (NFR22, T2.10).
///
/// **Hierarchy model:**
/// Each non-leaf [ContentItem] is identified by a *container key* — a
/// `"curriculumId|l1"`, `"curriculumId|l1|l2"`, etc. string built from its
/// level values.  The tree maps:
///   - container key → list of direct child [ContentItem]s
///   - leaf sefariaRef   → parent container [ContentItem]
///
/// The [adjacent] method is delegated to [ContentIndex] (it already exists
/// and is correct).
class ContentTree {
  ContentTree._({
    required Map<String, List<ContentItem>> childrenByContainerKey,
    required Map<String, ContentItem> parentByRef,
    required Map<String, ContentItem> containerByKey,
    required ContentIndex index,
  }) : _childrenByContainerKey = childrenByContainerKey,
       _parentByRef = parentByRef,
       _containerByKey = containerByKey,
       _index = index;

  final Map<String, List<ContentItem>> _childrenByContainerKey;
  final Map<String, ContentItem> _parentByRef;
  final Map<String, ContentItem> _containerByKey;
  final ContentIndex _index;

  // ── public API ──────────────────────────────────────────────────────────

  /// Returns the direct children of the container whose level values are
  /// described by [stackValues] inside [curriculumId].
  ///
  /// [stackValues] is the navigation stack — an ordered list of level values
  /// such as `["Seder Zeraim"]` (depth 1) or `["Seder Zeraim", "Berachos"]`
  /// (depth 2).  An empty list returns the top-level containers.
  ///
  /// Returns an empty list when no children are found.
  List<ContentItem> children(
    CurriculumId curriculumId,
    List<String> stackValues,
  ) {
    final key = _containerKey(curriculumId.storageKey, stackValues);
    return _childrenByContainerKey[key] ?? const [];
  }

  /// Returns the direct parent container of [sefariaRef], or null when the
  /// item is a top-level container or is unknown.
  ContentItem? parent(String sefariaRef) => _parentByRef[sefariaRef];

  /// Returns the previous and next leaf siblings of [sefariaRef] within its
  /// curriculum (delegates to [ContentIndex.adjacent]).
  AdjacentItems adjacent(String sefariaRef) => _index.adjacent(sefariaRef);

  /// Looks up a [ContentItem] by [sefariaRef] in O(1).
  ContentItem? lookup(String sefariaRef) => _index.lookup(sefariaRef);

  /// Returns the container [ContentItem] whose level values match [stackValues]
  /// within [curriculumId], or null if no such container exists.
  ContentItem? containerFor(
    CurriculumId curriculumId,
    List<String> stackValues,
  ) {
    final key = _containerKey(curriculumId.storageKey, stackValues);
    return _containerByKey[key];
  }

  // ── factory ──────────────────────────────────────────────────────────────

  /// Builds a [ContentTree] from a map of `CurriculumId → List<ContentItem>`.
  /// Used in tests and by the Riverpod provider.
  factory ContentTree.fromCurricula(
    Map<CurriculumId, List<ContentItem>> byCurriculum,
  ) {
    final index = ContentIndex.fromCurricula(byCurriculum);

    final childrenByContainerKey = <String, List<ContentItem>>{};
    final parentByRef = <String, ContentItem>{};
    final containerByKey = <String, ContentItem>{};

    for (final entry in byCurriculum.entries) {
      final currKey = entry.key.storageKey;
      final items = entry.value;

      for (final item in items) {
        if (!item.isLeaf) {
          // Register this container under its own key.
          final levels = _levelsOf(item);
          final key = _containerKey(currKey, levels);
          containerByKey[key] = item;

          // Add this container as a child of its parent container.
          final parentLevels = levels.sublist(0, levels.length - 1);
          final parentKey = _containerKey(currKey, parentLevels);
          childrenByContainerKey.putIfAbsent(parentKey, () => []).add(item);
        } else {
          // Leaf: register as child of its deepest container.
          final ancestorLevels = _ancestorLevels(item);
          final parentKey = _containerKey(currKey, ancestorLevels);
          childrenByContainerKey.putIfAbsent(parentKey, () => []).add(item);

          // Record parent for the leaf itself if there is one.
          if (ancestorLevels.isNotEmpty) {
            final parentContainerKey = _containerKey(currKey, ancestorLevels);
            final parentItem = containerByKey[parentContainerKey];
            if (parentItem != null) {
              parentByRef[item.sefariaRef] = parentItem;
            }
          }
        }
      }
    }

    // Sort each child list by sortOrder so display is stable. Runs once,
    // after every curriculum has been indexed above — sorting inside the
    // curriculum loop would re-sort each earlier curriculum's already-sorted
    // list on every subsequent iteration (AUD-core-content-03).
    for (final list in childrenByContainerKey.values) {
      list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }

    // Second pass: fill in parent refs for containers and for any leaves whose
    // parent container was not yet registered when they were processed above.
    for (final entry in byCurriculum.entries) {
      final currKey = entry.key.storageKey;
      for (final item in entry.value) {
        if (parentByRef.containsKey(item.sefariaRef)) continue;

        // For a leaf, _ancestorLevels(item) already returns the immediate
        // parent container's own key (see pass 1's leaf branch above, which
        // uses it directly). For a container, _levelsOf(item) returns the
        // item's own key, so it still needs one "walk up" truncation to
        // reach its parent's key. Applying that truncation to both
        // uniformly (as this used to do) walked leaves past their true
        // parent to the grandparent whenever the leaf preceded its own
        // container in source order (AUD-core-content-02).
        var candidateLevels = <String>[];
        if (item.isLeaf) {
          candidateLevels = _ancestorLevels(item);
        } else {
          final ownLevels = _levelsOf(item);
          candidateLevels = ownLevels.sublist(0, ownLevels.length - 1);
        }

        // Source data doesn't always materialise a ContentItem for every
        // intermediate level (e.g. a 4-level leaf whose Perek grouping has
        // no explicit container row) — containerByKey then has no entry at
        // the immediate ancestor key. In that case keep walking up until an
        // actually-registered container is found, matching [children]'s
        // existing tolerance for "virtual" ungrouped levels.
        ContentItem? parentItem;
        while (candidateLevels.isNotEmpty) {
          parentItem = containerByKey[_containerKey(currKey, candidateLevels)];
          if (parentItem != null) break;
          candidateLevels = candidateLevels.sublist(
            0,
            candidateLevels.length - 1,
          );
        }
        if (parentItem != null) {
          parentByRef[item.sefariaRef] = parentItem;
        }
      }
    }

    return ContentTree._(
      childrenByContainerKey: childrenByContainerKey,
      parentByRef: parentByRef,
      containerByKey: containerByKey,
      index: index,
    );
  }

  // ── helpers ───────────────────────────────────────────────────────────────

  /// Returns the level values that identify this *container* item.
  /// A container has level1 set; level2/3/4 may be null.
  static List<String> _levelsOf(ContentItem item) {
    final out = <String>[item.level1];
    if (item.level2 != null) out.add(item.level2!);
    if (item.level3 != null) out.add(item.level3!);
    if (item.level4 != null) out.add(item.level4!);
    return out;
  }

  /// Returns the level values of the immediate parent container of [item].
  /// For a leaf at depth 4 the ancestor is at depth 3, etc.
  static List<String> _ancestorLevels(ContentItem item) {
    if (item.level4 != null) {
      return [item.level1, item.level2!, item.level3!];
    }
    if (item.level3 != null) return [item.level1, item.level2!];
    if (item.level2 != null) return [item.level1];
    return [];
  }

  /// Builds a canonical string key for a container node.
  ///
  /// An empty [stackValues] represents the virtual root; its key is just the
  /// curriculumId storage key — i.e. the top-level "all children" bucket for
  /// that curriculum.
  static String _containerKey(
    String curriculumStorageKey,
    List<String> stackValues,
  ) {
    if (stackValues.isEmpty) return curriculumStorageKey;
    return '$curriculumStorageKey|${stackValues.join('|')}';
  }
}

/// Provides a single [ContentTree] built from all 9 curricula.
///
/// `keepAlive: true` — the tree must never be discarded mid-session; it is
/// built once on first use and held for the lifetime of the app.
@Riverpod(keepAlive: true)
Future<ContentTree> contentTree(Ref ref) async {
  final byCurriculum = <CurriculumId, List<ContentItem>>{};
  for (final c in CurriculumId.all) {
    byCurriculum[c] = await ref.watch(curriculumContentProvider(c).future);
  }
  return ContentTree.fromCurricula(byCurriculum);
}
