import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label_renderer.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';

/// Groups [items] by the next hierarchy level, returning unique representatives
/// with display names pre-rendered via [CurriculumLabelRenderer].
///
/// [currentDepth] is the length of the current navigation/breadcrumb stack
/// (0 = top level, showing level-1 items; 1 = one level down, etc.).
///
/// The returned [ContentItem]s carry rendered [ContentItem.displayNameHe] and
/// [ContentItem.displayNameEn] and are safe to display directly — no further
/// rendering is needed at call sites.
///
/// Pass [maxBrowseDepth] to stop at a particular depth (Browse Content caps at
/// `CurriculumLabels.maxBrowseDepth`). Omit it for uncapped drill-down (Bulk
/// Mark, Scope selection, Lifetime Marking).
List<ContentItem> groupItemsByNextLevel({
  required List<ContentItem> items,
  required int currentDepth,
  required CurriculumId curriculumId,
  required TransliterationVariant variant,
  int? maxBrowseDepth,
}) {
  if (maxBrowseDepth != null && currentDepth >= maxBrowseDepth) return const [];
  if (currentDepth >= 4) return items;

  final nextLevel = currentDepth + 1; // 1-indexed level number
  final uniqueItems = <String, ContentItem>{};

  for (final item in items) {
    final rawValue = _levelValueAt(item, currentDepth);
    if (rawValue == null || uniqueItems.containsKey(rawValue)) continue;

    final renderedHe = CurriculumLabelRenderer.renderValue(
      curriculumId: curriculumId,
      level: nextLevel,
      rawValue: rawValue,
      useHebrew: true,
      hebrewName: !item.isLeaf ? item.displayNameHe : null,
      parentL1Value: item.level1,
      transliterationVariant: variant,
    );
    final renderedEn = CurriculumLabelRenderer.renderValue(
      curriculumId: curriculumId,
      level: nextLevel,
      rawValue: rawValue,
      useHebrew: false,
      hebrewName: !item.isLeaf ? item.displayNameHe : null,
      parentL1Value: item.level1,
      transliterationVariant: variant,
    );

    uniqueItems[rawValue] = ContentItem(
      curriculumId: item.curriculumId,
      level1: item.level1,
      level2: currentDepth >= 1 ? item.level2 : null,
      level3: currentDepth >= 2 ? item.level3 : null,
      level4: currentDepth >= 3 ? item.level4 : null,
      displayNameHe: renderedHe,
      displayNameEn: renderedEn,
      sefariaRef: item.sefariaRef,
      sortOrder: item.sortOrder,
      isLeaf: item.isLeaf,
    );
  }

  return uniqueItems.values.toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
}

/// Returns the raw level value for [item] at the given 0-indexed [depth].
String? _levelValueAt(ContentItem item, int depth) => switch (depth) {
  0 => item.level1,
  1 => item.level2,
  2 => item.level3,
  3 => item.level4,
  _ => null,
};

/// Returns the raw level value for [item] at the given 1-indexed [level].
String? levelValueAt(ContentItem item, int level) => switch (level) {
  1 => item.level1,
  2 => item.level2,
  3 => item.level3,
  4 => item.level4,
  _ => null,
};

/// Returns the rendered display name for [item].
///
/// Use only with items produced by [groupItemsByNextLevel] — those have
/// properly rendered [ContentItem.displayNameHe] / [ContentItem.displayNameEn]
/// via [CurriculumLabelRenderer].
String itemDisplayName(ContentItem item, {required bool useHebrew}) =>
    useHebrew ? item.displayNameHe : item.displayNameEn;
