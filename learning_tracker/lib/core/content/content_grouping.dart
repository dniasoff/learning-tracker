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

/// Separator for qualified lifetime-scope identifiers (matches the '|' join used
/// by LifetimeTreeBuilder.buildHeLabelLookup).
const String kScopeIdSeparator = '|';

/// The unitIdentifier to STORE/MATCH for a lifetime SCOPE mark at [level].
/// level1 (seder) and level2 (masechta) are unique within a curriculum -> bare.
/// level3 (daf/perek/pasuk) and level4 (amud/mishna/seif) numbers repeat across
/// parents -> QUALIFIED with the full ancestor path so daf 2 is not credited
/// across every masechta.
String scopeUnitIdentifier({
  required int level,
  String? level1,
  String? level2,
  String? level3,
  String? level4,
}) {
  switch (level) {
    case 1:
      return level1 ?? '';
    case 2:
      return level2 ?? '';
    case 3:
      return [
        level1,
        level2,
        level3,
      ].where((s) => s != null && s.isNotEmpty).join(kScopeIdSeparator);
    case 4:
      return [
        level1,
        level2,
        level3,
        level4,
      ].where((s) => s != null && s.isNotEmpty).join(kScopeIdSeparator);
    default:
      return '';
  }
}

/// Builds the scope id for a leaf [item] at [level] (for matching stored marks).
String scopeUnitIdentifierForItem(ContentItem item, int level) =>
    scopeUnitIdentifier(
      level: level,
      level1: item.level1,
      level2: item.level2,
      level3: item.level3,
      level4: item.level4,
    );

/// Returns the rendered display name for [item].
///
/// Use only with items produced by [groupItemsByNextLevel] — those have
/// properly rendered [ContentItem.displayNameHe] / [ContentItem.displayNameEn]
/// via [CurriculumLabelRenderer].
String itemDisplayName(ContentItem item, {required bool useHebrew}) =>
    useHebrew ? item.displayNameHe : item.displayNameEn;
