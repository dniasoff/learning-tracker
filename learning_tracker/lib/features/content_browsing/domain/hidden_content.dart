import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// The refs pre-filled by the optional Hidden content "Suggested" action.
///
/// These are node refs, not an expanded leaf list. Keeping the preset at the
/// same granularity as the editor means it remains small and new descendants
/// added to the bundled curriculum are hidden automatically.
const suggestedHiddenContentRefs = <String>{
  'Niddah',
  'Jerusalem Talmud Niddah',
  'Mishnah Niddah',
  'Mishneh Torah, Forbidden Intercourse',
  'Mishnah Zavim',
};

/// Applies a child's hidden node refs to a raw curriculum hierarchy.
///
/// A hidden container removes itself and all descendants. The hierarchy asset
/// stores level values rather than an explicit parent ref, so this builds a
/// temporary `(curriculum, level path) -> node ref` index and checks every
/// ancestor path before retaining an item. The raw repository and stored
/// learning history are never changed.
abstract final class HiddenContentFilter {
  /// Returns [items] with hidden nodes and their descendants removed.
  static List<ContentItem> visible(
    List<ContentItem> items,
    Set<String> hiddenRefs,
  ) {
    if (hiddenRefs.isEmpty) return items;

    final refsByPath = <String, String>{};
    for (final item in items) {
      if (item.isLeaf) continue;
      final path = _levels(item);
      if (path.isEmpty) continue;
      refsByPath[_pathKey(item.curriculumId, path)] = item.sefariaRef;
    }

    return [
      for (final item in items)
        if (!_isHidden(item, hiddenRefs, refsByPath)) item,
    ];
  }

  static bool _isHidden(
    ContentItem item,
    Set<String> hiddenRefs,
    Map<String, String> refsByPath,
  ) {
    if (hiddenRefs.contains(item.sefariaRef)) return true;
    final levels = _levels(item);
    for (var depth = 1; depth <= levels.length; depth++) {
      final ancestor =
          refsByPath[_pathKey(item.curriculumId, levels.take(depth).toList())];
      if (ancestor != null && hiddenRefs.contains(ancestor)) return true;
    }
    return false;
  }

  static List<String> _levels(ContentItem item) => [
    item.level1,
    if (item.level2 != null) item.level2!,
    if (item.level3 != null) item.level3!,
    if (item.level4 != null) item.level4!,
  ];

  static String _pathKey(String curriculumId, List<String> levels) =>
      '$curriculumId|${levels.length}|${levels.join('|')}';
}
