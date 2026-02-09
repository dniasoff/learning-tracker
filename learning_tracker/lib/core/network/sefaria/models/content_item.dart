/// A single item in a curriculum's content hierarchy.
///
/// Represents both container nodes (seder, masechta, perek) and leaf nodes
/// (individual mishna, daf, pasuk, etc.). Maps directly to the
/// `content_items` table schema.
class ContentItem {
  const ContentItem({
    required this.curriculumId,
    required this.level1,
    this.level2,
    this.level3,
    this.level4,
    required this.displayNameHe,
    required this.displayNameEn,
    required this.sefariaRef,
    required this.sortOrder,
    required this.isLeaf,
  });

  /// Which curriculum this item belongs to (uses CurriculumId.storageKey).
  final String curriculumId;

  /// Top-level grouping (e.g., seder name, masechta name, sefer name).
  final String level1;

  /// Second-level grouping (e.g., masechta, daf, parsha).
  final String? level2;

  /// Third-level grouping (e.g., perek, amud, perek).
  final String? level3;

  /// Fourth-level grouping (e.g., mishna number, pasuk).
  final String? level4;

  /// Hebrew display name for this item.
  final String displayNameHe;

  /// English display name for this item.
  final String displayNameEn;

  /// Sefaria reference string for fetching text content.
  final String sefariaRef;

  /// Sort order within the full curriculum (global ordering).
  final int sortOrder;

  /// Whether this is a leaf node (actual content) vs. a container.
  final bool isLeaf;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ContentItem &&
          runtimeType == other.runtimeType &&
          curriculumId == other.curriculumId &&
          sefariaRef == other.sefariaRef;

  @override
  int get hashCode => Object.hash(curriculumId, sefariaRef);

  @override
  String toString() => 'ContentItem($curriculumId, $sefariaRef, leaf=$isLeaf)';
}
